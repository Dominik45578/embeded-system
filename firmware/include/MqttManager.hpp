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
    const char* global_topic;
    String device_topic;

    WiFiClient espClient;
    PubSubClient client;
    JsonDocument doc;

    void reconnect();

public:
    MqttManager(const char* global_topic, const String& device_topic);
    ~MqttManager();
    void setupWiFi();
    void loop();
    void callback(char* topic, byte* payload, unsigned int length);
    void publish(const MqttMessage message);
};

#endif // MQTT_MANAGER_HPP


