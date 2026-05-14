#pragma once

#include <Arduino.h>

// Returns a stable, unique device id derived from ESP32 efuse MAC.
String getDeviceId();