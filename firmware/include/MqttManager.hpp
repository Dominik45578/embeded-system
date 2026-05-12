#ifndef MQTT_MANAGER_HPP
#define MQTT_MANAGER_HPP

#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <model/MqttMessage.h>

class MqttManager
{
private:
    const char* ssid = "cin";
    const char* password = "12345678";
    const char* mqtt_server = "broker.mqtt-dashboard.com";

    WiFiClient espClient;
    PubSubClient client;
    JsonDocument doc;

    void reconnect();

public:
    MqttManager();
    ~MqttManager();
    void setupWiFi();
    void loop();
    void publish(const String& topic, const MqttMessage message);
};

#endif // MQTT_MANAGER_HPP


