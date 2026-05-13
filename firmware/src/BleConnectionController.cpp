#include "BleConnectionController.hpp"

namespace {
constexpr const char* kConnectionServiceUuid = "FF30";
constexpr const char* kDeviceIdCharacteristicUuid = "FF31";
}

BleConnectionController::BleConnectionController(const String& deviceId)
    : deviceId_(deviceId) {}

void BleConnectionController::init() {
    Serial.println("[BleConnectionController] Inicjalizacja serwisu identyfikacji urzadzenia...");

    BleManager::getInstance().createNewService(kConnectionServiceUuid)
        .addCharacteristic(kDeviceIdCharacteristicUuid)
            .readAccess()
            .buildCharacteristic()
        .buildService();

    BleManager::getInstance().updateAndNotify(kConnectionServiceUuid, kDeviceIdCharacteristicUuid, deviceId_.c_str());

    Serial.println("[BleConnectionController] Serwis deviceId gotowy.");
}