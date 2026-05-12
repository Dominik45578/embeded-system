#include "MqttManager.hpp"

MqttManager::MqttManager() : client(espClient)
{
    client.setServer(mqtt_server, 1883);
}

MqttManager::~MqttManager()
{
}

void MqttManager::setupWiFi() {
    Serial.print("Connecting to ");
    Serial.println(ssid);

    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid, password);

    int i = 0;
    while ( WiFi.status() != WL_CONNECTED) {
        delay(100);
        Serial.print(".");
        if(i = 10){
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
        } else {
            Serial.print("failed, rc=");
            Serial.print(client.state());
            Serial.println(" retry in 5 sec");
            delay(5000);
        }
    }
}

void MqttManager::loop() {
    if (WiFi.status() != WL_CONNECTED) {
        return;
    }

    if (!client.connected()) {
        reconnect();
    }

    client.loop();
}

void MqttManager::publish(const String& topic, const MqttMessage message) {
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("Cannot publish due to Wifi error");
        return;
    }

    if (!client.connected()) {
        reconnect();
    }

    doc["deviceId"] = message.getDeviceId();
    doc["lockState"] = message.getLockState();
    doc["source"] = message.getSource();
    doc["timeStamp"] = message.getTimeStamp();

    String outputJson = "";
    serializeJson(doc, outputJson);

    boolean success = client.publish(topic.c_str(), outputJson.c_str());
    Serial.println("Sent?:");
    Serial.println(success);
}
