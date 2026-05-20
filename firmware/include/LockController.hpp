#pragma once
#include <Arduino.h>
#include "LedcSerwoManager.hpp"
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>

enum class ActionSource {
    NONE,
    KEYPAD,
    BLUETOOTH,
    WIFI,
    SYSTEM
};

enum class LockSystemState {
    IDLE_LOCKED,
    ENTERING_PIN,
    CHANGING_PIN,
    UNLOCKED,
    BLOCKED_TEMP,
    IDLE_STARTED
};

enum class ActionResult {
    SUCCESS,
    WRONG_PIN,
    ACCESS_DENIED,
    ALREADY_IN_STATE,
    ERROR
};

class LockController {
public:
    static LockController& getInstance() {
        static LockController instance;
        return instance;
    }
    LockController(const LockController&) = delete;
    LockController& operator=(const LockController&) = delete;

    void init(LedcSerwoManager* servo);
    void update(); 
    
    ActionResult attemptUnlock(const String& pinAttempt, ActionSource source);
    ActionResult forceUnlock(ActionSource source);
    ActionResult changePin(const String& oldPin, const String& newPin, ActionSource source);
    ActionResult attemptLock(ActionSource source);
    void notifyActivity(LockSystemState state, ActionSource source);

    LockSystemState getCurrentState();
    ActionSource getLastActionSource();
    unsigned long getBlockedTimeRemaining();

private:
    LockController();

    LedcSerwoManager* servo_;
    SemaphoreHandle_t lockMutex_;

    LockSystemState currentState_;
    ActionSource lastSource_;
    String currentPin_;

    int failedAttempts_;
    const int MAX_FAILED_ATTEMPTS = 3;
    unsigned long stateTimerStart_;
    
    const unsigned long UNLOCK_DURATION = 10000;
    const unsigned long BLOCK_DURATION = 30000;
    const unsigned long INTERACTION_TIMEOUT = 10000;

    void executePhysicalUnlock();
    void executePhysicalLock();
};