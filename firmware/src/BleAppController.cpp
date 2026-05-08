#include "BleAppController.hpp"

BleAppController::BleAppController() : currentState(BleAppState::OFF) {}

void BleAppController::init() {
    Serial.println("[BleAppController] Inicjalizacja bluetooth....");
    BleManager::getInstance().init("Lockly-Zamek");


    Serial.println("[BleAppController] Inicjalizacja kontrolera...");
    BleManager::getInstance().createNewService("FF10")
        .addCharacteristic("FF11")
            .readAccess()
            .notifyAccess()
            .buildCharacteristic()
        .buildService();

    int pairedCount = BleManager::getInstance().getPairedCount(); 

    if (pairedCount > 0) {
        changeState(BleAppState::IDLE_SCAN);
    } else {
        changeState(BleAppState::OFF);
    }
}

void BleAppController::loop() {
    switch (currentState) {
        case BleAppState::OFF:
            handleStateOff();
            break;
        case BleAppState::PAIRING:
            handleStatePairing();
            break;
        case BleAppState::IDLE_SCAN:
            handleStateIdle();
            break;
        case BleAppState::CONNECTED:
            handleStateConnected();
            break;
    }

    if (currentState != BleAppState::CONNECTED && BleManager::getInstance().getActiveConnectionsCount() > 0) {
        changeState(BleAppState::CONNECTED);
    }
}

void BleAppController::startPairingMode() {
    Serial.println("[BleAppController] Wymuszono tryb parowania (Przycisk)!");
    changeState(BleAppState::PAIRING);
}

void BleAppController::changeState(BleAppState newState) {
    currentState = newState;
    stateEnterMillis = millis();
    
    Serial.print("[BleAppController] Zmiana stanu na: ");
    switch(newState) {
        case BleAppState::OFF: Serial.println("OFF"); break;
        case BleAppState::PAIRING: Serial.println("PAIRING"); break;
        case BleAppState::IDLE_SCAN: Serial.println("IDLE_SCAN"); break;
        case BleAppState::CONNECTED: Serial.println("CONNECTED"); break;
    }
}

void BleAppController::handleStateOff() {
    static bool isStopped = false;
    if (!isStopped) {
        BleManager::getInstance().manageAdvertising(BleAdvertisingMode::STOPPED);
        BleManager::getInstance().setPerformanceProfile(BlePerformanceProfile::ECO);
        isStopped = true;
    }
}

void BleAppController::handleStatePairing() {
    static bool isBroadcastingFast = false;
    if (!isBroadcastingFast) {
        BleManager::getInstance().setPerformanceProfile(BlePerformanceProfile::STANDARD);
        BleManager::getInstance().manageAdvertising(BleAdvertisingMode::FAST);
        isBroadcastingFast = true;
    }

    if (millis() - stateEnterMillis > PAIRING_TIMEOUT) {
        Serial.println("[BleAppController] Timeout parowania. Wracam do usypiania.");
        isBroadcastingFast = false; 
        
        if (BleManager::getInstance().getPairedCount() > 0) {
            changeState(BleAppState::IDLE_SCAN);
        } else {
            changeState(BleAppState::OFF);
        }
    }
}

void BleAppController::handleStateIdle() {
    if (!isRadioTemporarilyAwake) {
        if (millis() - lastPeriodicWakeupMillis > IDLE_WAKEUP_INTERVAL) {
            Serial.println("[BleAppController] Cykliczne wybudzenie radia na 15 sekund...");
            BleManager::getInstance().setPerformanceProfile(BlePerformanceProfile::ECO);
            BleManager::getInstance().manageAdvertising(BleAdvertisingMode::SLOW);
            isRadioTemporarilyAwake = true;
            stateEnterMillis = millis(); 
        }
    } else {
        if (millis() - stateEnterMillis > IDLE_ACTIVE_TIME) {
            Serial.println("[BleAppController] Koniec okna nasłuchu. Usypiam radio.");
            BleManager::getInstance().manageAdvertising(BleAdvertisingMode::STOPPED);
            isRadioTemporarilyAwake = false;
            lastPeriodicWakeupMillis = millis(); 
        }
    }
}

void BleAppController::handleStateConnected() {
    if (BleManager::getInstance().getActiveConnectionsCount() == 0) {
        Serial.println("[BleAppController] Rozłączono. Przechodzę w tryb IDLE.");
        changeState(BleAppState::IDLE_SCAN);
        return;
    }

    checkConnectionQualityAndAdjustPower();

    if (millis() - lastStatsSendMillis > STATS_INTERVAL) {
        sendDeveloperStats();
        lastStatsSendMillis = millis();
    }
}

void BleAppController::checkConnectionQualityAndAdjustPower() {
    int currentRssi = BleManager::getInstance().getAverageRssi();

    static BlePerformanceProfile lastProfile = BlePerformanceProfile::STANDARD;
    BlePerformanceProfile newProfile = lastProfile;

    if (currentRssi < -85 && currentRssi != -100) {
        newProfile = BlePerformanceProfile::OTA_UPDATE; 
    } else if (currentRssi > -60) {
        newProfile = BlePerformanceProfile::ECO;
    } else {
        newProfile = BlePerformanceProfile::STANDARD;
    }

    if (newProfile != lastProfile) {
        Serial.print("[BleAppController] Jakość sygnału: ");
        Serial.print(currentRssi);
        Serial.println(" dBm. Aktualizuję moc anteny.");
        
        BleManager::getInstance().setPerformanceProfile(newProfile);
        lastProfile = newProfile;
    }
}

void BleAppController::sendDeveloperStats() {
    int currentRssi = BleManager::getInstance().getAverageRssi();
    int paired = BleManager::getInstance().getPairedCount();
    unsigned long uptimeSeconds = millis() / 1000;
    
    String statsPayload = "{\"uptime\":" + String(uptimeSeconds) + 
                          ",\"rssi\":" + String(currentRssi) + 
                          ",\"paired\":" + String(paired) + "}";
    
    bool success = BleManager::getInstance().updateAndNotify("FF10", "FF11", statsPayload.c_str());
    
    if(!success) {
        Serial.println("[BleAppController] Błąd wysyłania statystyk! Sprawdź UUID.");
    }
}