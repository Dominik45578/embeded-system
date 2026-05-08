#pragma once
#include "BleManager.hpp"
#include <Arduino.h>

enum class BleAppState {
    OFF,                
    PAIRING,            
    IDLE_SCAN,          
    CONNECTED           
};

class BleAppController {
public:
    BleAppController(); 

    void init();
    void loop();
    void startPairingMode();
    BleAppState getCurrentState() const { return currentState; }

private:
    BleAppState currentState;

    unsigned long stateEnterMillis = 0;
    unsigned long lastPeriodicWakeupMillis = 0;
    unsigned long lastStatsSendMillis = 0;
    
    // Konfiguracja czasowa (w milisekundach)
    const unsigned long PAIRING_TIMEOUT = 60000;      // 60s
    const unsigned long IDLE_WAKEUP_INTERVAL = 300000; // 5 min
    const unsigned long IDLE_ACTIVE_TIME = 15000;      // 15s
    const unsigned long STATS_INTERVAL = 2000;         // 2s

    bool isRadioTemporarilyAwake = false;

    void handleStateOff();
    void handleStatePairing();
    void handleStateIdle();
    void handleStateConnected();
    
    void checkConnectionQualityAndAdjustPower();
    void sendDeveloperStats();
    void changeState(BleAppState newState);
};