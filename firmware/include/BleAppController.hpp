#pragma once
#include "BleManager.hpp"
#include <Arduino.h>

enum class BleAppState {
    OFF,                // Całkowicie uśpiony (brak parowań lub oszczędzanie energii)
    PAIRING,            // Aktywne parowanie (widoczny dla wszystkich przez ograniczony czas)
    IDLE_SCAN,          // Posiada parowania, budzi się cyklicznie na 15s
    CONNECTED           // Połączony z telefonem
};

class BleAppController {
public:
    BleAppController(BleManager* manager);

    void init();

    void loop();

    void startPairingMode();

    BleAppState getCurrentState() const { return currentState; }

private:
    BleManager* manager_;
    BleAppState currentState;

    unsigned long stateEnterMillis = 0;
    unsigned long lastPeriodicWakeupMillis = 0;
    unsigned long lastStatsSendMillis = 0;
    
    const unsigned long PAIRING_TIMEOUT = 60000;      // 60 sekund na sparowanie
    const unsigned long IDLE_WAKEUP_INTERVAL = 300000; // Budzenie co 5 minut (300 000 ms)
    const unsigned long IDLE_ACTIVE_TIME = 15000;      // Nasłuchuje przez 15 sekund
    const unsigned long STATS_INTERVAL = 2000;         // Wysyłaj statystyki co 2 sekundy

    bool isRadioTemporarilyAwake = false;

    void handleStateOff();
    void handleStatePairing();
    void handleStateIdle();
    void handleStateConnected();

    void checkConnectionQualityAndAdjustPower();
    void sendDeveloperStats();
    
    void changeState(BleAppState newState);
};