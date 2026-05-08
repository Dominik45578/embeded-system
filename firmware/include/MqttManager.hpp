#ifndef MQTT_MANAGER_HPP
#define MQTT_MANAGER_HPP

#include <WiFi.h>
#include <PubSubClient.h>

class MqttManager
{
private:
    const char* ssid = "cin";
    const char* password = "12345678";
    const char* mqtt_server = "broker.mqtt-dashboard.com";

    WiFiClient espClient;
    PubSubClient client;

    void reconnect();

public:
    MqttManager();
    ~MqttManager();
    void setupWiFi();
    void loop();
    void publish(const String& topic, const char* message);
};

#endif // MQTT_MANAGER_HPP


