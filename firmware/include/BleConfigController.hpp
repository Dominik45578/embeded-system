#pragma once
#include <Arduino.h>
#include "BleManager.hpp"
#include "ConfigManager.hpp"

class BleConfigController {
public:
    /**
     * @brief Konstruktor inicjalizujący stan maszyny stanów sekwencyjnego zapisu danych.
     */
    BleConfigController();

    /**
     * @brief Rejestruje serwis 0xFF40 oraz stowarzyszone charakterystyki (FF41 - FF45) w stosie BLE.
     */
    void init();

    /**
     * @brief Metoda cykliczna wywoływana w głównej pętli programu (opcjonalna, zgodna z interfejsem kontrolerów).
     */
    void update();

private:
    // Buwory dla sekwencyjnego zapisu Wi-Fi (Charakterystyka FF42)
    String pendingSsid_;
    String pendingPassword_;
    bool expectingPassword_;

    // Buwory dla zapisu konfiguracji MQTT (Charakterystyka FF44)
    String pendingBroker_;
    String pendingTopic_;

    // Metody obsługi zdarzeń zapisu (Callbacks)
    void handleWifiWrite(const String& payload);
    void handleMqttWrite(const String& payload);
    void handleConfigStateWrite(uint8_t stateByte);

    void loadAndPublishCurrentConfig();
    void saveAndApplyWifi();
    void saveAndApplyMqtt();
    void executeDeviceReboot();
    void publishConfigJson(const AppConfig& config) ;
};