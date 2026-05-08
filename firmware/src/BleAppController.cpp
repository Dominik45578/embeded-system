#include "BleAppController.hpp"

BleAppController::BleAppController(BleManager* manager) : manager_(manager), currentState(BleAppState::OFF) {}

void BleAppController::init() {
    Serial.println("[BleAppController] Inicjalizacja kontrolera...");
    manager_->createNewService("FF10")
        .addCharacteristic("FF11")
            .readAccess()
            .notifyAccess()
            .buildCharacteristic()
        .buildService();

    int pairedCount = 0;

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

    if (currentState != BleAppState::CONNECTED && manager_->getActiveConnectionsCount() > 0) {
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
        manager_->manageAdvertising(BleAdvertisingMode::STOPPED);
        manager_->setPerformanceProfile(BlePerformanceProfile::ECO);
        isStopped = true;
    }
}

void BleAppController::handleStatePairing() {
    static bool isBroadcastingFast = false;
    if (!isBroadcastingFast) {
        manager_->setPerformanceProfile(BlePerformanceProfile::STANDARD);
        manager_->manageAdvertising(BleAdvertisingMode::FAST);
        isBroadcastingFast = true;
    }

    if (millis() - stateEnterMillis > PAIRING_TIMEOUT) {
        Serial.println("[BleAppController] Timeout parowania. Wracam do usypiania.");
        isBroadcastingFast = false; // Reset flagi
        changeState(BleAppState::OFF); // lub IDLE_SCAN, zależnie czy mamy już sparowane
    }
}

void BleAppController::handleStateIdle() {
    if (!isRadioTemporarilyAwake) {
        if (millis() - lastPeriodicWakeupMillis > IDLE_WAKEUP_INTERVAL) {
            Serial.println("[BleAppController] Cykliczne wybudzenie radia na 15 sekund...");
            manager_->setPerformanceProfile(BlePerformanceProfile::ECO);
            manager_->manageAdvertising(BleAdvertisingMode::SLOW);       
            isRadioTemporarilyAwake = true;
            stateEnterMillis = millis(); // Re-używamy timera
        }
    } else {
        if (millis() - stateEnterMillis > IDLE_ACTIVE_TIME) {
            Serial.println("[BleAppController] Koniec okna nasłuchu. Usypiam radio.");
            manager_->manageAdvertising(BleAdvertisingMode::STOPPED);
            isRadioTemporarilyAwake = false;
            lastPeriodicWakeupMillis = millis(); // Zapisujemy czas zakończenia
        }
    }
}

void BleAppController::handleStateConnected() {
    if (manager_->getActiveConnectionsCount() == 0) {
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
    int currentRssi = -75;

    static BlePerformanceProfile lastProfile = BlePerformanceProfile::STANDARD;
    BlePerformanceProfile newProfile = lastProfile;

    if (currentRssi < -85) {
        newProfile = BlePerformanceProfile::OTA_UPDATE; 
    } else if (currentRssi > -60) {
        newProfile = BlePerformanceProfile::ECO;
    } else {
        newProfile = BlePerformanceProfile::STANDARD;
    }

    if (newProfile != lastProfile) {
        Serial.println("[BleAppController] Zmiana jakości sygnału! Aktualizuję moc anteny.");
        manager_->setPerformanceProfile(newProfile);
        lastProfile = newProfile;
    }
}

void BleAppController::sendDeveloperStats() {
    String stats = "{\"uptime\":" + String(millis() / 1000) + ",\"rssi\":-75}";
}