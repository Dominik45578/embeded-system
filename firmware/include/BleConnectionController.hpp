#pragma once

#include <Arduino.h>
#include "BleManager.hpp"

class BleConnectionController {
public:
    explicit BleConnectionController(const String& deviceId);

    void init();

private:
    String deviceId_;
};