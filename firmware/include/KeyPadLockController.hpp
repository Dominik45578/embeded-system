#pragma once
#include <Keypad.h>
#include "LockController.hpp"

class KeypadLockController {
public:
    KeypadLockController(Keypad& keypad);
    void update();

private:
    enum class KeypadInternalState {
        IDLE,
        ENTERING_PIN,
        CHANGING_PIN_OLD,
        CHANGING_PIN_NEW
    };

    Keypad& keypad_;
    KeypadInternalState internalState_;
    
    String inputBuffer_;
    String oldPinBuffer_;

    void resetInternal();
};