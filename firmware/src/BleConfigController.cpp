#include "BleConfigController.hpp"
#include "ConfigManager.hpp" 

BleConfigController::BleConfigController() 
    : pendingSsid_(""), 
      pendingPassword_(""), 
      expectingPassword_(false), 
      pendingBroker_(""), 
      pendingTopic_("") {}

void BleConfigController::init() {
    Serial.println("[BleConfigController] Inicjalizacja serwisu konfiguracji sieciowej (FF40)...");

    BleManager::getInstance().createNewService("FF40")
        .addCharacteristic("FF41") 
            .readAccess()
            .buildCharacteristic()
        .addCharacteristic("FF42")
            .writeAccess()
            .onWrite([this](const std::string& data) {
                String payload = String(data.c_str());
                payload.trim();
                this->handleWifiWrite(payload);
            })
            .buildCharacteristic()
        .addCharacteristic("FF43")
            .readAccess()
            .buildCharacteristic()
        .addCharacteristic("FF44")
            .writeAccess()
            .onWrite([this](const std::string& data) {
                String payload = String(data.c_str());
                payload.trim();
                this->handleMqttWrite(payload);
            })
            .buildCharacteristic()
        .addCharacteristic("FF45")
            .writeAccess()
            .onWrite([this](const std::string& data) {
                if (!data.empty()) {
                    uint8_t stateByte = static_cast<uint8_t>(data[0]);
                    this->handleConfigStateWrite(stateByte);
                } else {
                    Serial.println("[BleConfigController] Ostrzeżenie: Pusty pakiet na charakterystyce FF45");
                }
            })
            .buildCharacteristic()
        .addCharacteristic("FF46")
            .readAccess()
            .notifyAccess()
            .buildCharacteristic()
        .buildService();

    loadAndPublishCurrentConfig();
}

void BleConfigController::update() {
    // Implementacja asynchroniczna poprzez callbacki stosu BLE.
}

void BleConfigController::handleWifiWrite(const String& payload) {
    if (!expectingPassword_) {
        pendingSsid_ = payload;
        expectingPassword_ = true;
        Serial.println("[BleConfigController] FF42 -> Buforowanie SSID: '" + pendingSsid_ + "'. Oczekiwanie na hasło.");
    } else {
        pendingPassword_ = payload;
        expectingPassword_ = false;
        Serial.println("[BleConfigController] FF42 -> Buforowanie Hasła zakończone. Oczekiwanie na bajt zatwierdzenia (2).");
    }
}

void BleConfigController::handleMqttWrite(const String& payload) {
    int commaIndex = payload.indexOf(',');
    if (commaIndex != -1) {
        pendingBroker_ = payload.substring(0, commaIndex);
        pendingTopic_ = payload.substring(commaIndex + 1);
        
        pendingBroker_.trim();
        pendingTopic_.trim();
        
        Serial.println("[BleConfigController] FF44 -> Buforowanie MQTT. Broker: " + pendingBroker_ + ", Topic: " + pendingTopic_ + ". Oczekiwanie na bajt zatwierdzenia (4).");
    } else {
        Serial.println("[BleConfigController] FF44 -> Błąd: Nieprawidłowy format danych MQTT. Oczekiwano 'broker,topic'.");
    }
}

void BleConfigController::handleConfigStateWrite(uint8_t stateByte) {
    Serial.print("[BleConfigController] FF45 -> Odebrano kod kontrolny stanu: ");
    Serial.println(stateByte);

    switch (stateByte) {
        case 1: 
            expectingPassword_ = false;
            pendingSsid_ = "";
            pendingPassword_ = "";
            Serial.println("[BleConfigController] Rozpoczęto nową sekwencję zapisu Wi-Fi. Wyczyszczono bufory tymczasowe.");
            break;

        case 2: 
            saveAndApplyWifi();
            break;

        case 3: 
            pendingBroker_ = "";
            pendingTopic_ = "";
            Serial.println("[BleConfigController] Rozpoczęto nową sekwencję zapisu MQTT. Wyczyszczono bufory tymczasowe.");
            break;

        case 4: 
            saveAndApplyMqtt();
            break;

        case 5:
            executeDeviceReboot();
            break;

        default:
            Serial.print("[BleConfigController] Nieobsługiwany kod stanu charakterystyki FF45: ");
            Serial.println(stateByte);
            break;
    }
}

void BleConfigController::loadAndPublishCurrentConfig() {
    AppConfig config = ConfigOrchestrator::getInstance().getConfig();

    String currentSsid = config.get<String>("wifi.ssid");
    BleManager::getInstance().updateAndNotify("FF40", "FF41", currentSsid.c_str());

    String currentBroker = config.get<String>("mqtt.broker");
    String currentTopic = config.get<String>("mqtt.topic");
    String mqttCombined = currentBroker + "," + currentTopic;
    BleManager::getInstance().updateAndNotify("FF40", "FF43", mqttCombined.c_str());

    publishConfigJson(config);
}

void BleConfigController::publishConfigJson(const AppConfig& config) {
    String ssid = config.get<String>("wifi.ssid");
    String password = config.get<String>("wifi.password");
    String broker = config.get<String>("mqtt.broker");
    String topic = config.get<String>("mqtt.topic");

    String jsonPayload = "{"
                         "\"wifi\":{\"ssid\":\"" + ssid + "\",\"password\":\"" + password + "\"},"
                         "\"mqtt\":{\"broker\":\"" + broker + "\",\"topic\":\"" + topic + "\"}"
                         "}";

    BleManager::getInstance().updateAndNotify("FF40", "FF46", jsonPayload.c_str());
    Serial.println("[BleConfigController] Rozgłoszono zaktualizowany JSON konfiguracyjny na charakterystyce FF46.");
}

void BleConfigController::saveAndApplyWifi() {
    if (pendingSsid_.isEmpty()) {
        Serial.println("[BleConfigController] Błąd zapisu Wi-Fi: Brak zbuforowanego parametru SSID.");
        return;
    }

    AppConfig config = ConfigOrchestrator::getInstance().getConfig();
    config.set<String>("wifi.ssid", pendingSsid_);
    config.set<String>("wifi.password", pendingPassword_);
    ConfigOrchestrator::getInstance().updateConfig(config);

    Serial.println("[BleConfigController] Konfiguracja Wi-Fi została pomyślnie zapisana.");
    
    // Synchronizacja tradycyjnej charakterystyki oraz zunifikowanego JSONa
    BleManager::getInstance().updateAndNotify("FF40", "FF41", pendingSsid_.c_str());
    publishConfigJson(config);
}

void BleConfigController::saveAndApplyMqtt() {
    if (pendingBroker_.isEmpty() || pendingTopic_.isEmpty()) {
        Serial.println("[BleConfigController] Błąd zapisu MQTT: Brak kompletnych parametrów brokera lub tematu.");
        return;
    }

    AppConfig config = ConfigOrchestrator::getInstance().getConfig();
    config.set<String>("mqtt.broker", pendingBroker_);
    config.set<String>("mqtt.topic", pendingTopic_);
    ConfigOrchestrator::getInstance().updateConfig(config);

    Serial.println("[BleConfigController] Konfiguracja MQTT została pomyślnie zapisana.");

    String mqttCombined = pendingBroker_ + "," + pendingTopic_;
    BleManager::getInstance().updateAndNotify("FF40", "FF43", mqttCombined.c_str());
    publishConfigJson(config);
}

void BleConfigController::executeDeviceReboot() {
    Serial.println("[BleConfigController] Żądanie restartu systemowego. Zamykanie podsystemów...");
    delay(1500); 
    ESP.restart();
}