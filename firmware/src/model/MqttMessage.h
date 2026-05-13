#ifndef MQTT_MESSAGE_H
#define MQTT_MESSAGE_H

#include <string>
#include <WString.h>

class MqttMessage {
private:
    String deviceId;
    String lockState;
    String timeStamp;
    String source;

    String getCurrentTimestamp() const;

public:
    MqttMessage(const String& deviceId,
                const String& lockState,
                const String& source);

    // ===== GETTERY =====
    String getDeviceId() const;
    String getLockState() const;
    String getTimeStamp() const;
    String getSource() const;

    // ===== SETTERY =====
    void setDeviceId(const String& deviceId);
    void setLockState(const String& lockState);
    void setSource(const String& source);
};

#endif