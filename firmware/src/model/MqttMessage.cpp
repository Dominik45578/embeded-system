#include "MqttMessage.h"
#include <time.h>
#include <Arduino.h>

MqttMessage::MqttMessage(const String& deviceId,
                         const String& lockState,
                         const String& source)
    : deviceId(deviceId),
      lockState(lockState),
      source(source)
{
    timeStamp = getCurrentTimestamp();
}

String MqttMessage::getDeviceId() const {
    return deviceId;
}

String MqttMessage::getLockState() const {
    return lockState;
}

String MqttMessage::getTimeStamp() const {
    return timeStamp;
}

String MqttMessage::getSource() const {
    return source;
}

void MqttMessage::setDeviceId(const String& deviceId) {
    this->deviceId = deviceId;
    timeStamp = getCurrentTimestamp();
}

void MqttMessage::setLockState(const String& lockState) {
    this->lockState = lockState;
    timeStamp = getCurrentTimestamp();
}

void MqttMessage::setSource(const String& source) {
    this->source = source;
    timeStamp = getCurrentTimestamp();
}

String MqttMessage::getCurrentTimestamp() const {
    time_t now;
    struct tm timeinfo;
    if (!getLocalTime(&timeinfo)) {
        return "Time not set";
    }
    char timeStringBuff[20];
    strftime(timeStringBuff, sizeof(timeStringBuff), "%Y-%m-%d %H:%M:%S", &timeinfo);
    return String(timeStringBuff);
}