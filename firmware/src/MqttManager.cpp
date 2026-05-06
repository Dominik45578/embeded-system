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

    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
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

void MqttManager::publish(const String& topic, const char* message) {
    if (WiFi.status() != WL_CONNECTED) {
        return;
    }

    if (!client.connected()) {
        reconnect();
    }

    boolean success = client.publish(topic.c_str(), message);
    Serial.println("Sent?:");
    Serial.println(success);
}
