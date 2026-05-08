#include "setup.hpp"
#include "PinManager.hpp"
#include <Arduino.h>
#include "LedcSerwoManager.hpp"
#include <PubSubClient.h>
#include "MqttManager.hpp"

LedcSerwoManager servo;
MqttManager* mqtt_manager;
PinKeypadController * pin_controller = new PinKeypadController(keypad);

void resetLeds(){
  digitalWrite(BLUE_LED, LOW);
  digitalWrite(RED_LED, LOW);
  digitalWrite(GREEN_LED, LOW);
}

void attachServo() {
  servo.atachLedc();
}

void detachServo() {
  servo.detachLedc();
}

void openLock() {
  servo.openLock(100);
  delay(10000);
  servo.closeLock(100);
  delay(1000);
}

void setup(){
  Serial.begin(115200);
  pinMode(RED_LED,OUTPUT);
  pinMode(GREEN_LED,OUTPUT);
  pinMode(BLUE_LED,OUTPUT);
  pinMode(BUTTON, INPUT_PULLUP);

  servo.setChanel(SERVO_CHANNEL);
  servo.setFrequency(SERVO_FREQ);
  servo.setRes(SERVO_RES);
  servo.setBounds(500, 1500, 2500);
  servo.begin(SERVO_PIN);

  mqtt_manager = new MqttManager();
  mqtt_manager->setupWiFi();
}

PinState last_state = PinState::IDLE;
PinState new_state = PinState::IDLE;

void handleFlags(const PinState state){
    resetLeds();
   switch(state) {
    case PinState::VALID:
        Serial.println("Pin poprawny");
        digitalWrite(GREEN_LED, HIGH);
        attachServo();
        openLock();
        break;

    case PinState::ERROR:
         Serial.println("Błędny pin");
         digitalWrite(RED_LED,HIGH);
         detachServo();
         mqtt_manager->publish("topicCinkus", "BLOCKED");
        break;

    case PinState::SETTING_MODE:
        Serial.println("Ustawaim nowy pin..");
        digitalWrite(BLUE_LED,HIGH);
        break;
    case PinState::TIMEOUT:
      Serial.println("Przekroczono limit czasu");
      digitalWrite(RED_LED,HIGH);
      break;
    case PinState::ENTERING:
      Serial.println("Wpisywanie pinu...");
      digitalWrite(BLUE_LED,HIGH);
      break;
    case PinState::BLOCKED:
      Serial.println("Zamek zablokowany jeszcze na " + String(pin_controller->getBlockedTime()));
      break;
  }
}

void loop(){
  mqtt_manager->loop();
  
  pin_controller->update();
  new_state = pin_controller->getState();
  if(last_state!=new_state){
    last_state = new_state;
    handleFlags(new_state);
  }
  if(digitalRead(BUTTON) == LOW){
    handleFlags(new_state);
  }
  delay(200);
}

int main(){
  return 0;
}