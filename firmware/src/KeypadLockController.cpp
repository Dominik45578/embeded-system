#include "KeypadLockController.hpp"

KeypadLockController::KeypadLockController(Keypad& keypad) : keypad_(keypad) {
    resetInternal();
}

void KeypadLockController::resetInternal() {
    internalState_ = KeypadInternalState::IDLE;
    inputBuffer_ = "";
    oldPinBuffer_ = "";
}

void KeypadLockController::update() {
    LockSystemState centralState = LockController::getInstance().getCurrentState();
    if (centralState == LockSystemState::IDLE_LOCKED || centralState == LockSystemState::BLOCKED_TEMP) {
        if (internalState_ != KeypadInternalState::IDLE) {
            resetInternal();
        }
    }

    char key = keypad_.getKey();
    if (!key) return;

    if (centralState == LockSystemState::BLOCKED_TEMP) return;

    if (key == '*') {
        resetInternal();
        internalState_ = KeypadInternalState::ENTERING_PIN;
        LockController::getInstance().notifyActivity(LockSystemState::ENTERING_PIN, ActionSource::KEYPAD);
        return;
    }

    if (key == 'A') {
        resetInternal();
        internalState_ = KeypadInternalState::CHANGING_PIN_OLD;
        LockController::getInstance().notifyActivity(LockSystemState::CHANGING_PIN, ActionSource::KEYPAD);
        return;
    }

    if (key == '#') {
        if (internalState_ == KeypadInternalState::ENTERING_PIN) {
            LockController::getInstance().attemptUnlock(inputBuffer_, ActionSource::KEYPAD);
            resetInternal();
        } 
        else if (internalState_ == KeypadInternalState::CHANGING_PIN_OLD) {
            oldPinBuffer_ = inputBuffer_;
            inputBuffer_ = "";
            internalState_ = KeypadInternalState::CHANGING_PIN_NEW;
            LockController::getInstance().notifyActivity(LockSystemState::CHANGING_PIN, ActionSource::KEYPAD);
        } 
        else if (internalState_ == KeypadInternalState::CHANGING_PIN_NEW) {
            LockController::getInstance().changePin(oldPinBuffer_, inputBuffer_, ActionSource::KEYPAD);
            resetInternal();
        }
        return;
    }

    if (isDigit(key)) {
        if (internalState_ == KeypadInternalState::IDLE) {
            internalState_ = KeypadInternalState::ENTERING_PIN;
            LockController::getInstance().notifyActivity(LockSystemState::ENTERING_PIN, ActionSource::KEYPAD);
        }
        
        inputBuffer_ += key;
        
        LockController::getInstance().notifyActivity(
            (internalState_ == KeypadInternalState::ENTERING_PIN) ? LockSystemState::ENTERING_PIN : LockSystemState::CHANGING_PIN, 
            ActionSource::KEYPAD
        );
    }
}