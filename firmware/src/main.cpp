#include <Arduino.h>
#include "setup.hpp"
#include "LedcSerwoManager.hpp"
#include "KeypadLockController.hpp"
#include "BleAppController.hpp"
#include "BleLockController.hpp"
#include "MqttManager.hpp"
#include "LockController.hpp"

LedcSerwoManager servo;
MqttManager* mqtt_manager;
KeypadLockController* keypad_controller;
BleAppController* ble_app_controller;
BleLockController* ble_lock_controller;

LockSystemState lastSystemState = LockSystemState::IDLE_LOCKED;

const String DEVICE_ID = "DzWord=CWord";

void resetLeds() {
    digitalWrite(RED_LED, LOW);
    digitalWrite(GREEN_LED, LOW);
    digitalWrite(BLUE_LED, LOW);
}

String sourceToString(ActionSource source) {
    switch (source) {
        case ActionSource::KEYPAD: return "KEYPAD";
        case ActionSource::BLUETOOTH: return "BLUETOOTH";
        case ActionSource::WIFI: return "WIFI";
        case ActionSource::SYSTEM: return "SYSTEM";
        default: return "NONE";
    }
}


String stateToString(LockSystemState state) {
    switch (state) {
        case LockSystemState::IDLE_LOCKED:   return "IDLE_LOCKED";
        case LockSystemState::ENTERING_PIN:  return "ENTERING_PIN";
        case LockSystemState::CHANGING_PIN:  return "CHANGING_PIN";
        case LockSystemState::UNLOCKED:      return "UNLOCKED";
        case LockSystemState::BLOCKED_TEMP:  return "BLOCKED_TEMP";
        default:                             return "UNKNOWN";
    }
}

void setup() {
    Serial.begin(115200);
    Serial.println("[System] Uruchamianie zamka...");
    configTime(3600, 3600, "pool.ntp.org", "time.nist.gov");
    
    pinMode(RED_LED, OUTPUT);
    pinMode(GREEN_LED, OUTPUT);
    pinMode(BLUE_LED, OUTPUT);
    pinMode(BUTTON, INPUT_PULLUP);
    resetLeds();

    servo.setChanel(SERVO_CHANNEL);
    servo.setFrequency(SERVO_FREQ);
    servo.setRes(SERVO_RES);
    servo.setBounds(500, 1500, 2500);
    servo.begin(SERVO_PIN);

    LockController::getInstance().init(&servo);

    keypad_controller = new KeypadLockController(keypad);

    mqtt_manager = new MqttManager();
    mqtt_manager->setupWiFi();

    ble_app_controller = new BleAppController();
    ble_app_controller->init();
    
    ble_lock_controller = new BleLockController();
    ble_lock_controller->init();

    Serial.println("[System] Inicjalizacja zakończona pomyślnie. System gotowy.");
}

void loop() {
    LockController::getInstance().update(); 
    
    keypad_controller->update(); 
    mqtt_manager->loop();
    ble_app_controller->loop(); 
    ble_lock_controller->update(); 

    LockSystemState currentState = LockController::getInstance().getCurrentState();
    ActionSource currentSource = LockController::getInstance().getLastActionSource();
    
    if (currentState != lastSystemState) {
        resetLeds(); 
        
        String sourceStr = sourceToString(currentSource);
        MqttMessage mqttMessage = MqttMessage(DEVICE_ID, stateToString(currentState), sourceStr);
        
        switch (currentState) {
            case LockSystemState::IDLE_LOCKED:
                mqtt_manager->publish("topicCinkus", mqttMessage);
                break;
                
            case LockSystemState::ENTERING_PIN:
                digitalWrite(BLUE_LED, HIGH);
                mqtt_manager->publish("topicCinkus", mqttMessage);
                break;
                
            case LockSystemState::CHANGING_PIN:
                digitalWrite(BLUE_LED, HIGH);
                mqtt_manager->publish("topicCinkus", mqttMessage);
                break;
                
            case LockSystemState::UNLOCKED:
                digitalWrite(GREEN_LED, HIGH);
                mqtt_manager->publish("topicCinkus", mqttMessage);
                break;
                
            case LockSystemState::BLOCKED_TEMP:
                digitalWrite(RED_LED, HIGH);
                mqtt_manager->publish("topicCinkus", mqttMessage);
                break;
        }
        lastSystemState = currentState;
    }

    if (digitalRead(BUTTON) == LOW) {
        delay(50);
        if (digitalRead(BUTTON) == LOW) {
            
            ble_app_controller->startPairingMode();
            
            resetLeds();
            digitalWrite(BLUE_LED, HIGH);
            delay(200);
            digitalWrite(BLUE_LED, LOW);
            delay(200);
            digitalWrite(BLUE_LED, HIGH);
            delay(200);
            digitalWrite(BLUE_LED, LOW);
            
            while(digitalRead(BUTTON) == LOW) { delay(10); } 
            
            lastSystemState = LockSystemState::BLOCKED_TEMP;
        }
    }
}