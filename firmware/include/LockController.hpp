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

// Abstrakcyjne stany systemu (sterują diodami i blokadami)
enum class LockSystemState {
    IDLE_LOCKED,       // Zamek zamknięty (Diody wyłączone)
    ENTERING_PIN,      // Interakcja: Ktoś podaje PIN (Niebieski LED)
    CHANGING_PIN,      // Interakcja: Tryb zmiany PIN (Niebieski LED)
    UNLOCKED,          // Zamek otwarty (Zielony LED)
    BLOCKED_TEMP       // Zablokowany za karę (Czerwony LED)
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

    
    // Natychmiastowa próba autoryzacji (z gotowym kodem)
    ActionResult attemptUnlock(const String& pinAttempt, ActionSource source);
    
    // Bezpieczna zmiana PIN-u z weryfikacją starego
    ActionResult changePin(const String& oldPin, const String& newPin, ActionSource source);
    
    // Ręczne zablokowanie zamka
    ActionResult attemptLock(ActionSource source);

    // Flaga dla urządzeń peryferyjnych: "Hej, zacząłem coś robić, zmień stan i resetuj timeout!"
    void notifyActivity(LockSystemState state, ActionSource source);

    // --- GETTERY ---
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

    // Zmienne czasowe i kary
    int failedAttempts_;
    const int MAX_FAILED_ATTEMPTS = 3;
    unsigned long stateTimerStart_;
    
    const unsigned long UNLOCK_DURATION = 10000;    // 10s otwarcia
    const unsigned long BLOCK_DURATION = 30000;     // 30s kary
    const unsigned long INTERACTION_TIMEOUT = 10000; // 10s na bezczynność (np. wpisywanie PINu i odejście)

    void executePhysicalUnlock();
    void executePhysicalLock();
};