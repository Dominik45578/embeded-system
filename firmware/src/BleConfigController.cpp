#include "BleConfigController.hpp"
#include "ConfigManager.hpp" // Zawiera definicję ConfigOrchestrator oraz AppConfig

BleConfigController::BleConfigController() 
    : pendingSsid_(""), 
      pendingPassword_(""), 
      expectingPassword_(false), 
      pendingBroker_(""), 
      pendingTopic_("") {}

void BleConfigController::init() {
    Serial.println("[BleConfigController] Inicjalizacja serwisu konfiguracji sieciowej (FF40)...");

    BleManager::getInstance().createNewService("FF40")
        .addCharacteristic("FF41") // WiFi Read
            .readAccess()
            .buildCharacteristic()
        .addCharacteristic("FF42") // WiFi Write
            .writeAccess()
            .onWrite([this](const std::string& data) {
                String payload = String(data.c_str());
                payload.trim();
                this->handleWifiWrite(payload);
            })
            .buildCharacteristic()
        .addCharacteristic("FF43") // MQTT Read
            .readAccess()
            .buildCharacteristic()
        .addCharacteristic("FF44") // MQTT Write
            .writeAccess()
            .onWrite([this](const std::string& data) {
                String payload = String(data.c_str());
                payload.trim();
                this->handleMqttWrite(payload);
            })
            .buildCharacteristic()
        .addCharacteristic("FF45") // Config State
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
        .buildService();

    loadAndPublishCurrentConfig();
}

void BleConfigController::update() {
    // Implementacja opcjonalna - stan synchronizowany jest asynchronicznie poprzez przerwania/callbacks stosu BLE.
}

void BleConfigController::handleWifiWrite(const String& payload) {
    if (!expectingPassword_) {
        pendingSsid_ = payload;
        expectingPassword_ = true;
        Serial.println("[BleConfigController] FF42 -> Odebrano SSID: '" + pendingSsid_ + "'. Oczekiwanie na hasło w kolejnej sekwencji.");
    } else {
        pendingPassword_ = payload;
        expectingPassword_ = false;
        Serial.println("[BleConfigController] FF42 -> Odebrano Hasło (Długość: " + String(pendingPassword_.length()) + "). Dane gotowe do zatwierdzenia bajtem stanu.");
    }
}

void BleConfigController::handleMqttWrite(const String& payload) {
    // Format zapisu: "adres_brokera,temat_mqtt"
    int commaIndex = payload.indexOf(',');
    if (commaIndex != -1) {
        pendingBroker_ = payload.substring(0, commaIndex);
        pendingTopic_ = payload.substring(commaIndex + 1);
        
        pendingBroker_.trim();
        pendingTopic_.trim();
        
        Serial.println("[BleConfigController] FF44 -> Parsowanie MQTT sukces. Broker: " + pendingBroker_ + ", Topic: " + pendingTopic_);
    } else {
        Serial.println("[BleConfigController] FF44 -> Błąd: Nieprawidłowy format danych MQTT. Oczekiwano struktury 'broker,topic'.");
    }
}

void BleConfigController::handleConfigStateWrite(uint8_t stateByte) {
    Serial.print("[BleConfigController] FF45 -> Odebrano bajt kontroli stanu konfiguracji: ");
    Serial.println(stateByte);

    switch (stateByte) {
        case 1: // Zastosuj i zapisz konfigurację Wi-Fi
            saveAndApplyWifi();
            break;
        case 2: // Zastosuj i zapisz konfigurację MQTT
            saveAndApplyMqtt();
            break;
        case 3: // Reset maszyny stanów sekwencji Wi-Fi (np. w przypadku błędu transmisji aplikacji)
            expectingPassword_ = false;
            pendingSsid_ = "";
            pendingPassword_ = "";
            Serial.println("[BleConfigController] Zresetowano sekwencję zapisu Wi-Fi.");
            break;
        case 4: // Restart urządzenia (Soft-Reboot)
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

    // Pobranie i aktualizacja wartości lokalnego bufora charakterystyki READ dla Wi-Fi (FF41)
    String currentSsid = config.get<String>("wifi.ssid");
    BleManager::getInstance().updateAndNotify("FF40", "FF41", currentSsid.c_str());

    // Pobranie, konkatenacja i aktualizacja bufora charakterystyki READ dla MQTT (FF43)
    String currentBroker = config.get<String>("mqtt.broker");
    String currentTopic = config.get<String>("mqtt.topic");
    String mqttCombined = currentBroker + "," + currentTopic;
    BleManager::getInstance().updateAndNotify("FF40", "FF43", mqttCombined.c_str());

    Serial.println("[BleConfigController] Zsynchronizowano stan charakterystyk READ z bieżącą konfiguracją systemową.");
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

    Serial.println("[BleConfigController] Nowa konfiguracja Wi-Fi została pomyślnie zatomizowana w ConfigOrchestrator.");
    
    // Uaktualnienie wartości odczytu charakterystyki dla klienta BLE
    BleManager::getInstance().updateAndNotify("FF40", "FF41", pendingSsid_.c_str());
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

    Serial.println("[BleConfigController] Nowa konfiguracja MQTT została pomyślnie zatomizowana w ConfigOrchestrator.");

    // Uaktualnienie wartości odczytu charakterystyki połączonej dla klienta BLE
    String mqttCombined = pendingBroker_ + "," + pendingTopic_;
    BleManager::getInstance().updateAndNotify("FF40", "FF43", mqttCombined.c_str());
}

void BleConfigController::executeDeviceReboot() {
    Serial.println("[BleConfigController] Żądanie restartu systemowego zaakceptowane. Zamykanie podsystemów...");
    delay(1500); // Bezpieczny margines czasowy na zakończenie asynchronicznych operacji zapisu Flash i rozłączenie BLE
    ESP.restart();
}