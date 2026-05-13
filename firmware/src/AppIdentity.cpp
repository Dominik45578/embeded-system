#include "AppIdentity.hpp"
#include <esp_system.h>

String getDeviceId() {
    uint64_t mac = ESP.getEfuseMac();
    char buf[13];
    for (int i = 0; i < 6; ++i) {
        uint8_t b = (mac >> ((5 - i) * 8)) & 0xFF;
        sprintf(buf + i * 2, "%02X", b);
    }
    buf[12] = '\0';
    return String(buf);
}