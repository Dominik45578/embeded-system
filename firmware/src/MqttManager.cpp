#include "MqttManager.hpp"
#include "LockController.hpp"

MqttManager::MqttManager(const char* global_topic, const String& device_topic) : client(espClient)
{
    this->global_topic = String(global_topic);
    this->device_topic = device_topic;

    auto& config = ConfigOrchestrator::getInstance().getConfig();
    
    this->mqtt_server_address = config.get<String>("mqtt.server", "broker.hivemq.com");
    uint32_t port = config.get<uint32_t>("mqtt.port", 1883);

    client.setServer(this->mqtt_server_address.c_str(), port);
    
    client.setCallback([this](char* topic, byte* payload, unsigned int length) {
        this->callback(topic, payload, length);
    });
}

MqttManager::~MqttManager()
{
}

void MqttManager::setupWiFi() {
    auto& config = ConfigOrchestrator::getInstance().getConfig();
    String ssid = config.get<String>("wifi.ssid", "");
    String password = config.get<String>("wifi.password", "");

    Serial.print("Connecting to ");
    Serial.println(ssid);

    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid.c_str(), password.c_str());

    int i = 0;
    while (WiFi.status() != WL_CONNECTED) {
        delay(100);
        Serial.print(".");
    
        if(i == 50){ 
            Serial.println("Wifi setup error");
            return;
        }
        i++;
    }

    Serial.println();
    Serial.println("WiFi connected");
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
}

void MqttManager::reconnect() {
    while (!client.connected()) {
        Serial.print("Attempting MQTT connection...");
        String clientId = "ESP32Client-";
        clientId += String(random(0xffff), HEX);

        if (client.connect(clientId.c_str())) {
            Serial.println("connected");
            client.subscribe(device_topic.c_str());
        } else {
            Serial.print("failed, rc=");
            Serial.print(client.state());
            Serial.println(" retry in 5 sec");
            delay(5000);
        }
    }
}

void MqttManager::callback(char* topic, byte* payload, unsigned int length) {
    Serial.print("Message arrived [");
    Serial.print(topic);
    Serial.print("] ");
    for (int i = 0; i < length; i++) {
        Serial.print((char)payload[i]);
    }
    Serial.println();

    if (strcmp(topic, device_topic.c_str()) == 0) {
        JsonDocument incomingDoc;
        deserializeJson(incomingDoc, payload);
        
        const char* action = incomingDoc["command"];

        if (action != nullptr && strcmp(action, "UNLOCK") == 0) {
            Serial.println("Otrzymano prosbe o zdalne otwarcie zamkna (WiFi)");
            ActionResult res = LockController::getInstance().forceUnlock(ActionSource::WIFI);

            if (res == ActionResult::SUCCESS) {
                Serial.println("Otwarto zamek zdalnie przez WiFi");
                publish(MqttMessage(device_topic, "UNLOCKED", "WIFI"));
            }
            else {
                Serial.println("Podczas otwierania zamka przez WiFi wystapil blad");
            }
        }
        else if (action != nullptr && strcmp(action, "CHECK_ALIVE") == 0) {
            Serial.println("Otrzymano żądanie CHECK_ALIVE");

            publish(
                MqttMessage(
                    device_topic,
                    "IDLE_KEEP_ALIVE",
                    "SYSTEM"
                )
            );

            Serial.println("Wysłano odpowiedź KEEP_ALIVE");
        }
        else if (action != nullptr && strcmp(action, "LOCK") == 0) {
            LockController::getInstance().attemptLock(ActionSource::WIFI);
        }
    }
} // <--- TUTAJ brakowało tej klamry, która zamyka metodę callback

void MqttManager::loop() {
    if (WiFi.status() != WL_CONNECTED) {
        return;
    }

    if (!client.connected()) {
        reconnect();
    }

    client.loop();
}

void MqttManager::publish(const MqttMessage message) {
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("Cannot publish due to Wifi error");
        return;
    }

    if (!client.connected()) {
        reconnect();
    }

    doc.clear();
    doc["deviceId"] = message.getDeviceId();
    doc["lockState"] = message.getLockState();
    doc["source"] = message.getSource();
    doc["timeStamp"] = message.getTimeStamp();

    String outputJson = "";
    serializeJson(doc, outputJson);

    boolean success = client.publish(global_topic.c_str(), outputJson.c_str());
    Serial.println("Sent?:");
    Serial.println(success);
}