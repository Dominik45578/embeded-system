#include "BleManager.hpp"
#include <Arduino.h>

// ==========================================
// CHARACTERISTIC BUILDER
// ==========================================

CharacteristicBuilder::CharacteristicBuilder(const std::string& uuid, NimBLEService* pService, NimBleCoreAdapter* adapter, ServiceBuilder* parent)
    : uuid_(uuid), pService_(pService), adapter_(adapter), parent_(parent) {}

CharacteristicBuilder& CharacteristicBuilder::readAccess() {
    using CP = BleDomain::CharacteristicProperty;
    properties_ |= static_cast<uint32_t>(CP::READ);
    return *this;
}

CharacteristicBuilder& CharacteristicBuilder::writeAccess() {
    using CP = BleDomain::CharacteristicProperty;
    properties_ |= static_cast<uint32_t>(CP::WRITE);
    return *this;
}

CharacteristicBuilder& CharacteristicBuilder::notifyAccess() {
    using CP = BleDomain::CharacteristicProperty;
    properties_ |= static_cast<uint32_t>(CP::NOTIFY);
    return *this;
}

CharacteristicBuilder& CharacteristicBuilder::onWrite(std::function<void(const std::string&)> callback) {
    if (!callbackHandler_) {
        callbackHandler_ = new CharacteristicCallbackHandler();
    }
    callbackHandler_->setWriteCallback(callback);
    return *this;
}

ServiceBuilder& CharacteristicBuilder::buildCharacteristic() {
    NimBLECharacteristic* pChar = adapter_->createCharacteristic(pService_, uuid_, properties_);
    
    if (callbackHandler_ && pChar) {
        adapter_->setCharacteristicCallbacks(pChar, callbackHandler_);
    }
    
    return *parent_;
}

// ==========================================
// SERVICE BUILDER
// ==========================================

ServiceBuilder::ServiceBuilder(const std::string& uuid, NimBleCoreAdapter* adapter, BleManager* manager)
    : uuid_(uuid), adapter_(adapter), manager_(manager) {
    // Od razu zlecamy adapterowi rezerwację miejsca na serwis
    pService_ = adapter_->createService(uuid_);
}

CharacteristicBuilder ServiceBuilder::addCharacteristic(const std::string& uuid) {
    return CharacteristicBuilder(uuid, pService_, adapter_, this);
}

BleManager& ServiceBuilder::buildService() {
    // Uruchamiamy serwis, aby był widoczny
    adapter_->startService(pService_);
    return *manager_;
}

// ==========================================
// BLE MANAGER
// ==========================================

BleManager::BleManager(NimBleCoreAdapter* adapter) : adapter_(adapter) {}

void BleManager::init(const std::string& deviceName) {
    adapter_->powerOn(deviceName);
    // Ustawiamy parowanie z domyślnymi parametrami na start
    adapter_->setPairingMode(BleDomain::FeatureState::ENABLE);
}

ServiceBuilder BleManager::createNewService(const std::string& uuid) {
    return ServiceBuilder(uuid, adapter_, this);
}

void BleManager::setPerformanceProfile(BlePerformanceProfile profile) {
    switch(profile) {
        case BlePerformanceProfile::OTA_UPDATE:
            // Maksymalna wydajność: indeks 7 w kPowerLevelToDbm w adapterze (9 dBm)
            adapter_->setTxPower(static_cast<BleDomain::BlePowerLevel>(7)); 
            adapter_->optimizeForDataTransfer(512); // Maksymalne MTU
            break;
            
        case BlePerformanceProfile::ECO:
            // Minimalna moc: indeks 0 w kPowerLevelToDbm w adapterze (-12 dBm)
            adapter_->setTxPower(static_cast<BleDomain::BlePowerLevel>(0));
            // standardowe MTU
            adapter_->optimizeForDataTransfer(23);
            break;

        case BlePerformanceProfile::STANDARD:
            // Zbalansowana moc: indeks 4 (0 dBm)
            adapter_->setTxPower(static_cast<BleDomain::BlePowerLevel>(4));
            adapter_->optimizeForDataTransfer(256);
            break;
    }
}

void BleManager::manageAdvertising(BleAdvertisingMode mode) {
    switch(mode) {
        case BleAdvertisingMode::FAST:
            adapter_->setAdvertisingIntervals(0x20, 0x40);
            adapter_->startAdvertising(0);
            break;
        case BleAdvertisingMode::SLOW:
            // Interwały rzędu setek milisekund
            adapter_->setAdvertisingIntervals(0x100, 0x200);
            adapter_->startAdvertising(0);
            break;
        case BleAdvertisingMode::STOPPED:
            adapter_->suspendAdvertising();
            break;
    }
}

int BleManager::getActiveConnectionsCount() const {
    return adapter_->getConnectedCount();
}

int BleManager::getPairedCount() const {
    return adapter_->getPairedDeviceCount();
}

int BleManager::getAverageRssi() const {
    std::vector<uint16_t> handles = adapter_->getConnectedHandles();
    if (handles.empty()) {
        return -100; // Brak połączonych klientów
    }
    
    int totalRssi = 0;
    for (uint16_t handle : handles) {
        totalRssi += adapter_->getPeerRssi(handle);
    }
    
    return totalRssi / handles.size(); // Uśredniamy sygnał dla wszystkich połączonych urządzeń
}

bool BleManager::updateAndNotify(const std::string& serviceUuid, const std::string& charUuid, const std::string& payload) {
    NimBLEService* pService = adapter_->getServiceByUUID(serviceUuid);
    if (!pService) {
        Serial.println("[BleManager] Błąd: Nie znaleziono serwisu " + String(serviceUuid.c_str()));
        return false;
    }
    
    NimBLECharacteristic* pChar = adapter_->getCharacteristicByUUID(pService, charUuid);
    if (!pChar) {
         Serial.println("[BleManager] Błąd: Nie znaleziono charakterystyki " + String(charUuid.c_str()));
         return false;
    }

    adapter_->setCharacteristicValue(pChar, payload);
    adapter_->notifyClients(pChar, 0); 
    
    return true;
}