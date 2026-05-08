#include "BleLockController.hpp"

BleLockController::BleLockController() {
    lastNotifiedState_ = LockSystemState::IDLE_LOCKED;
}

void BleLockController::init() {
    Serial.println("[BleLockController] Inicjalizacja serwisu zamka...");

    BleManager::getInstance().createNewService("FF20")
        
        .addCharacteristic("FF21")
            .writeAccess()
            .onWrite([this](const std::string& data) {
                Serial.print("Odebrano : ");
                Serial.println(data.c_str());
                String payload = String(data.c_str());
                payload.trim(); // Usuwamy białe znaki
                this->handleCommand(payload);
            })
            .buildCharacteristic()

        .addCharacteristic("FF22")
            .readAccess()
            .notifyAccess()
            .buildCharacteristic()

        .buildService();
}

void BleLockController::update() {
    LockSystemState currentState = LockController::getInstance().getCurrentState();

    if (currentState != lastNotifiedState_) {
        lastNotifiedState_ = currentState;
        String stateMsg = "STATE:" + stateToString(currentState);
        
        sendNotification(stateMsg);
        Serial.println("[BleLockController] Wysłano status do telefonu: " + stateMsg);
    }
}

void BleLockController::handleCommand(const String& payload) {
    Serial.println("[BleLockController] Odebrano komendę: " + payload);

    int firstColon = payload.indexOf(':');
    
    String cmd = payload;
    String args = "";

    if (firstColon != -1) {
        cmd = payload.substring(0, firstColon);
        args = payload.substring(firstColon + 1);
    }


    if (cmd == "UNLOCK") {
        String pin = args;
        ActionResult res = LockController::getInstance().attemptUnlock(pin, ActionSource::BLUETOOTH);
        
        if (res == ActionResult::WRONG_PIN) {
            sendNotification("ERROR:WRONG_PIN");
        } else if (res == ActionResult::ACCESS_DENIED) {
            sendNotification("ERROR:ACCESS_DENIED");
        }
        return;
    }

    if (cmd == "LOCK") {
        LockController::getInstance().attemptLock(ActionSource::BLUETOOTH);
        return;
    }

    if (cmd == "CHANGE") {
        int secondColon = args.indexOf(':');
        if (secondColon != -1) {
            String oldPin = args.substring(0, secondColon);
            String newPin = args.substring(secondColon + 1);
            
            ActionResult res = LockController::getInstance().changePin(oldPin, newPin, ActionSource::BLUETOOTH);
            
            if (res == ActionResult::SUCCESS) {
                sendNotification("SUCCESS:PIN_CHANGED");
            } else {
                sendNotification("ERROR:CHANGE_FAILED");
            }
        } else {
            sendNotification("ERROR:BAD_FORMAT");
        }
        return;
    }

    Serial.println("[BleLockController] Nieznana komenda BLE!");
}

void BleLockController::sendNotification(const String& message) {
    BleManager::getInstance().updateAndNotify("FF20", "FF22", message.c_str());
}

String BleLockController::stateToString(LockSystemState state) {
    switch (state) {
        case LockSystemState::IDLE_LOCKED: return "LOCKED";
        case LockSystemState::ENTERING_PIN: return "ENTERING_PIN";
        case LockSystemState::CHANGING_PIN: return "CHANGING_PIN";
        case LockSystemState::UNLOCKED: return "UNLOCKED";
        case LockSystemState::BLOCKED_TEMP: return "BLOCKED";
        default: return "UNKNOWN";
    }
}