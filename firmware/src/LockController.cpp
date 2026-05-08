#include "LockController.hpp"

LockController::LockController() {
    lockMutex_ = xSemaphoreCreateMutex();
    currentState_ = LockSystemState::IDLE_LOCKED;
    lastSource_ = ActionSource::SYSTEM;
    currentPin_ = "1234";
    failedAttempts_ = 0;
    stateTimerStart_ = 0;
    servo_ = nullptr;
}

void LockController::init(LedcSerwoManager* servo) {
    servo_ = servo;
    executePhysicalLock();
}

void LockController::update() {
    if (xSemaphoreTake(lockMutex_, 10) == pdTRUE) {
        unsigned long elapsed = millis() - stateTimerStart_;

        // 1. Zamknięcie po czasie otwarcia
        if (currentState_ == LockSystemState::UNLOCKED && elapsed >= UNLOCK_DURATION) {
            currentState_ = LockSystemState::IDLE_LOCKED;
            lastSource_ = ActionSource::SYSTEM;
            executePhysicalLock();
        }

        // 2. Zdjęcie kary
        if (currentState_ == LockSystemState::BLOCKED_TEMP && elapsed >= BLOCK_DURATION) {
            failedAttempts_ = 0;
            currentState_ = LockSystemState::IDLE_LOCKED;
            lastSource_ = ActionSource::SYSTEM;
        }

        // 3. Timeout interakcji (ktoś wciskał na klawiaturze i sobie poszedł)
        if ((currentState_ == LockSystemState::ENTERING_PIN || 
             currentState_ == LockSystemState::CHANGING_PIN) && elapsed >= INTERACTION_TIMEOUT) {
            currentState_ = LockSystemState::IDLE_LOCKED;
            lastSource_ = ActionSource::SYSTEM;
        }

        xSemaphoreGive(lockMutex_);
    }
}

void LockController::notifyActivity(LockSystemState state, ActionSource source) {
    if (xSemaphoreTake(lockMutex_, portMAX_DELAY) == pdTRUE) {
        if (currentState_ == LockSystemState::BLOCKED_TEMP) {
            xSemaphoreGive(lockMutex_);
            return;
        }
        currentState_ = state;
        lastSource_ = source;
        stateTimerStart_ = millis(); // Resetuje timeout!
        xSemaphoreGive(lockMutex_);
    }
}

ActionResult LockController::attemptUnlock(const String& pinAttempt, ActionSource source) {
    if (xSemaphoreTake(lockMutex_, portMAX_DELAY) == pdTRUE) {
        
        if (currentState_ == LockSystemState::BLOCKED_TEMP) {
            xSemaphoreGive(lockMutex_);
            return ActionResult::ACCESS_DENIED;
        }

        if (currentState_ == LockSystemState::UNLOCKED) {
            xSemaphoreGive(lockMutex_);
            return ActionResult::ALREADY_IN_STATE;
        }

        if (pinAttempt == currentPin_) {
            failedAttempts_ = 0;
            currentState_ = LockSystemState::UNLOCKED;
            lastSource_ = source;
            stateTimerStart_ = millis();
            executePhysicalUnlock();
            xSemaphoreGive(lockMutex_);
            return ActionResult::SUCCESS;
        } else {
            failedAttempts_++;
            if (failedAttempts_ >= MAX_FAILED_ATTEMPTS) {
                currentState_ = LockSystemState::BLOCKED_TEMP;
                stateTimerStart_ = millis();
            } else {
                currentState_ = LockSystemState::IDLE_LOCKED;
            }
            lastSource_ = source;
            xSemaphoreGive(lockMutex_);
            return ActionResult::WRONG_PIN;
        }
    }
    return ActionResult::ERROR;
}

ActionResult LockController::changePin(const String& oldPin, const String& newPin, ActionSource source) {
    if (xSemaphoreTake(lockMutex_, portMAX_DELAY) == pdTRUE) {
        
        if (currentState_ == LockSystemState::BLOCKED_TEMP) {
            xSemaphoreGive(lockMutex_);
            return ActionResult::ACCESS_DENIED;
        }

        if (oldPin != currentPin_) {
            failedAttempts_++;
            if (failedAttempts_ >= MAX_FAILED_ATTEMPTS) {
                currentState_ = LockSystemState::BLOCKED_TEMP;
                stateTimerStart_ = millis();
            } else {
                currentState_ = LockSystemState::IDLE_LOCKED;
            }
            lastSource_ = source;
            xSemaphoreGive(lockMutex_);
            return ActionResult::WRONG_PIN;
        }

        if (newPin.length() < 4) {
            currentState_ = LockSystemState::IDLE_LOCKED;
            xSemaphoreGive(lockMutex_);
            return ActionResult::ERROR;
        }

        currentPin_ = newPin;
        failedAttempts_ = 0;
        currentState_ = LockSystemState::IDLE_LOCKED;
        lastSource_ = source;
        xSemaphoreGive(lockMutex_);
        return ActionResult::SUCCESS;
    }
    return ActionResult::ERROR;
}

ActionResult LockController::attemptLock(ActionSource source) {
    if (xSemaphoreTake(lockMutex_, portMAX_DELAY) == pdTRUE) {
        if (currentState_ == LockSystemState::IDLE_LOCKED) {
            xSemaphoreGive(lockMutex_);
            return ActionResult::ALREADY_IN_STATE;
        }
        currentState_ = LockSystemState::IDLE_LOCKED;
        lastSource_ = source;
        executePhysicalLock();
        xSemaphoreGive(lockMutex_);
        return ActionResult::SUCCESS;
    }
    return ActionResult::ERROR;
}

void LockController::executePhysicalUnlock() {
    if (servo_) {
        servo_->atachLedc();
        servo_->openLock(100);
    }
}

void LockController::executePhysicalLock() {
    if (servo_) {
        servo_->closeLock(100);
        delay(500); 
        servo_->detachLedc();
    }
}

LockSystemState LockController::getCurrentState() {
    LockSystemState state = LockSystemState::IDLE_LOCKED;
    if (xSemaphoreTake(lockMutex_, 10) == pdTRUE) {
        state = currentState_;
        xSemaphoreGive(lockMutex_);
    }
    return state;
}

ActionSource LockController::getLastActionSource() {
    ActionSource src = ActionSource::NONE;
    if (xSemaphoreTake(lockMutex_, 10) == pdTRUE) {
        src = lastSource_;
        xSemaphoreGive(lockMutex_);
    }
    return src;
}

unsigned long LockController::getBlockedTimeRemaining() {
    unsigned long remaining = 0;
    if (xSemaphoreTake(lockMutex_, 10) == pdTRUE) {
        if (currentState_ == LockSystemState::BLOCKED_TEMP) {
            unsigned long elapsed = millis() - stateTimerStart_;
            if (elapsed < BLOCK_DURATION) {
                remaining = BLOCK_DURATION - elapsed;
            }
        }
        xSemaphoreGive(lockMutex_);
    }
    return remaining;
}