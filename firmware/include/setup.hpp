#include <Keypad.h>
#include <Arduino.h>
#include "ConfigManager.hpp"


#ifndef SETUP_HPP
#define SETUP_HPP

#define BLUE_LED 27
#define GREEN_LED 12
#define RED_LED 13
#define BUTTON 0
#define SERVO_PIN 23
#define SERVO_CHANNEL 1
#define SERVO_FREQ 50
#define SERVO_RES 16


const byte ROWS = 4; //four rows
const byte COLS = 4; //four columns
//define the cymbols on the buttons of the keypads
char hexaKeys[ROWS][COLS] = {
  {'1','2','3','A'},
  {'4','5','6','B'},
  {'7','8','9','C'},
  {'*','0','#','D'}
};
byte rowPins[ROWS] = {19, 18,5, 17}; 
byte colPins[COLS] = {16,4,0,15}; 



Keypad keypad = Keypad( makeKeymap(hexaKeys), rowPins, colPins, ROWS, COLS); 
ConfigOrchestrator& config = ConfigOrchestrator::getInstance();


void load() {
    ConfigStatus status = config.begin();
    
    switch(status) {
        case ConfigStatus::OK:
            Serial.println("Konfiguracja zaladowana poprawnie.");
            break;
        case ConfigStatus::RESTORED_BACKUP:
            Serial.println("Odtworzono konfiguracje z backupu NVS.");
            break;
        case ConfigStatus::RESTORED_FACTORY:
            Serial.println("Zaladowano ustawienia fabryczne.");
            break;
        case ConfigStatus::PARSE_ERR:
            Serial.println("Blad parsowania JSON.");
            break;
        case ConfigStatus::STORAGE_ERR:
            Serial.println("Krytyczny blad dostepu do pamieci NVS.");
            break;
    }
}
#endif //SETUP_HPP