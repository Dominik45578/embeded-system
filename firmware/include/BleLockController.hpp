#pragma once
#include <Arduino.h>
#include "BleManager.hpp"
#include "LockController.hpp"

class BleLockController {
public:
    BleLockController();

    void init();

    void update();

private:
    LockSystemState lastNotifiedState_;

    void handleCommand(const String& payload);
    void sendNotification(const String& message);
    String stateToString(LockSystemState state);
};