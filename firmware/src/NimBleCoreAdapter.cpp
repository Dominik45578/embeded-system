#include "NimBleCoreAdapter.hpp"
#include <esp_bt.h>
#include <nimble/nimble/host/include/host/ble_gap.h>
#include <algorithm> 

static const int8_t kPowerLevelToDbm[] = { -12, -9, -6, -3, 0, 3, 6, 9 };
static constexpr uint8_t kPowerTableSize = sizeof(kPowerLevelToDbm) / sizeof(kPowerLevelToDbm[0]);

void NimBleCoreAdapter::ServerCallbackShim::onConnect(NimBLEServer* /*pServer*/, NimBLEConnInfo& connInfo) {
    uint16_t handle = connInfo.getConnHandle();
    owner_->connectedHandles_.push_back(handle);
    if (owner_->onConnectCb_) owner_->onConnectCb_(owner_->buildConnectionInfo(connInfo));
}

void NimBleCoreAdapter::ServerCallbackShim::onDisconnect(NimBLEServer* /*pServer*/, NimBLEConnInfo& connInfo, int reason) {
    uint16_t handle = connInfo.getConnHandle();
    auto& handles = owner_->connectedHandles_;
    handles.erase(std::remove(handles.begin(), handles.end(), handle), handles.end());
    if (owner_->onDisconnectCb_) owner_->onDisconnectCb_(owner_->buildConnectionInfo(connInfo), reason);
}

void NimBleCoreAdapter::ServerCallbackShim::onAuthenticationComplete(NimBLEConnInfo& connInfo) {
    if (owner_->onAuthCb_) owner_->onAuthCb_(owner_->buildConnectionInfo(connInfo), connInfo.isEncrypted());
}

void NimBleCoreAdapter::ServerCallbackShim::onMTUChange(uint16_t mtu, NimBLEConnInfo& connInfo) {
    if (owner_->onMtuChangedCb_) owner_->onMtuChangedCb_(connInfo.getConnHandle(), mtu);
}

NimBleCoreAdapter::NimBleCoreAdapter() : pServer_(nullptr), pAdvertising_(nullptr), pCallbackShim_(nullptr), initialized_(false),
    isBondingEnabled_(false), isMitmEnabled_(false), isSecureConnectionsEnabled_(true) {}

NimBleCoreAdapter::~NimBleCoreAdapter() {
    if (isPoweredOn()) powerOff();
}

void NimBleCoreAdapter::powerOn(const std::string& name) {
    deviceName_ = name;
    NimBLEDevice::init(deviceName_);
    initialized_ = true;
    pServer_ = NimBLEDevice::createServer();
    pCallbackShim_ = new ServerCallbackShim(this);
    pServer_->setCallbacks(pCallbackShim_, true);
    pAdvertising_ = NimBLEDevice::getAdvertising();
    applySecurityState();
}

void NimBleCoreAdapter::powerOff() {
    NimBLEDevice::deinit(true);
    initialized_ = false;
    pServer_ = nullptr;
    pAdvertising_ = nullptr;
    pCallbackShim_ = nullptr;
    connectedHandles_.clear();
    createdServices_.clear();
}

bool NimBleCoreAdapter::isPoweredOn() const {
    return initialized_;
}

uint32_t NimBleCoreAdapter::translateCharProperties(uint32_t dp) const {
    uint32_t np = 0;
    using CP = BleDomain::CharacteristicProperty;
    if (dp & static_cast<uint32_t>(CP::READ))            np |= NIMBLE_PROPERTY::READ;
    if (dp & static_cast<uint32_t>(CP::WRITE))           np |= NIMBLE_PROPERTY::WRITE;
    if (dp & static_cast<uint32_t>(CP::NOTIFY))          np |= NIMBLE_PROPERTY::NOTIFY;
    if (dp & static_cast<uint32_t>(CP::INDICATE))        np |= NIMBLE_PROPERTY::INDICATE;
    if (dp & static_cast<uint32_t>(CP::WRITE_NR))        np |= NIMBLE_PROPERTY::WRITE_NR;
    if (dp & static_cast<uint32_t>(CP::BROADCAST))       np |= NIMBLE_PROPERTY::BROADCAST;
    if (dp & static_cast<uint32_t>(CP::READ_ENC))        np |= NIMBLE_PROPERTY::READ_ENC;
    if (dp & static_cast<uint32_t>(CP::READ_AUTHEN))     np |= NIMBLE_PROPERTY::READ_AUTHEN;
    if (dp & static_cast<uint32_t>(CP::WRITE_ENC))       np |= NIMBLE_PROPERTY::WRITE_ENC;
    if (dp & static_cast<uint32_t>(CP::WRITE_AUTHEN))    np |= NIMBLE_PROPERTY::WRITE_AUTHEN;
    return np;
}

uint32_t NimBleCoreAdapter::translateDescProperties(uint32_t dp) const {
    uint32_t np = 0;
    using DP = BleDomain::DescriptorProperty;
    if (dp & static_cast<uint32_t>(DP::READ))         np |= NIMBLE_PROPERTY::READ;
    if (dp & static_cast<uint32_t>(DP::WRITE))        np |= NIMBLE_PROPERTY::WRITE;
    if (dp & static_cast<uint32_t>(DP::READ_ENC))     np |= NIMBLE_PROPERTY::READ_ENC;
    if (dp & static_cast<uint32_t>(DP::READ_AUTHEN))  np |= NIMBLE_PROPERTY::READ_AUTHEN;
    if (dp & static_cast<uint32_t>(DP::WRITE_ENC))    np |= NIMBLE_PROPERTY::WRITE_ENC;
    if (dp & static_cast<uint32_t>(DP::WRITE_AUTHEN)) np |= NIMBLE_PROPERTY::WRITE_AUTHEN;
    return np;
}

void NimBleCoreAdapter::applySecurityState() {
    NimBLEDevice::setSecurityAuth(isBondingEnabled_, isMitmEnabled_, isSecureConnectionsEnabled_);
}

BleDomain::ConnectionInfo NimBleCoreAdapter::buildConnectionInfo(const NimBLEConnInfo& raw) const {
    BleDomain::ConnectionInfo info;
    info.address         = raw.getAddress().toString();
    info.handle          = raw.getConnHandle();
    info.connInterval    = raw.getConnInterval();
    info.connLatency     = raw.getConnLatency();
    info.supTimeout      = raw.getConnTimeout();
    info.encrypted       = raw.isEncrypted();
    info.authenticated   = raw.isAuthenticated();
    info.bonded          = raw.isBonded();
    info.securityKeySize = raw.getSecKeySize();
    info.isMaster        = raw.isMaster(); // Poprawka: powrót do isMaster()
    return info;
}

void NimBleCoreAdapter::setDeviceName(const std::string& name) { deviceName_ = name; NimBLEDevice::setDeviceName(name); }
std::string NimBleCoreAdapter::getDeviceName() const { return deviceName_; }

void NimBleCoreAdapter::setTxPower(BleDomain::BlePowerLevel level) {
    int idx = static_cast<int>(level);
    if (idx >= 0 && idx < kPowerTableSize) NimBLEDevice::setPower(kPowerLevelToDbm[idx]);
}

void NimBleCoreAdapter::setTxPowerGranular(BleDomain::TxPowerDbm level, BleDomain::TxPowerTarget target) {
    int idx = static_cast<int>(level);
    if (idx >= 0 && idx < kPowerTableSize) NimBLEDevice::setPower(kPowerLevelToDbm[idx]); 
}

int8_t NimBleCoreAdapter::getTxPower() const { return NimBLEDevice::getPower(); }

void NimBleCoreAdapter::optimizeForDataTransfer(uint16_t mtuSize) { NimBLEDevice::setMTU(mtuSize); }
uint16_t NimBleCoreAdapter::getMtu(uint16_t connHandle) const { return pServer_ ? pServer_->getPeerMTU(connHandle) : 0; }
uint16_t NimBleCoreAdapter::getPreferredMtu() const { return NimBLEDevice::getMTU(); }

void NimBleCoreAdapter::setPairingMode(BleDomain::FeatureState state) { isBondingEnabled_ = (state == BleDomain::FeatureState::ENABLE); applySecurityState(); }
void NimBleCoreAdapter::setBonding(BleDomain::FeatureState state) { isBondingEnabled_ = (state == BleDomain::FeatureState::ENABLE); applySecurityState(); }
void NimBleCoreAdapter::setMitmProtection(BleDomain::FeatureState state) { isMitmEnabled_ = (state == BleDomain::FeatureState::ENABLE); applySecurityState(); }
void NimBleCoreAdapter::setSecureConnections(BleDomain::FeatureState state) { isSecureConnectionsEnabled_ = (state == BleDomain::FeatureState::ENABLE); applySecurityState(); }
void NimBleCoreAdapter::setIoCapabilities(BleDomain::IoCapabilities ioCaps) { NimBLEDevice::setSecurityIOCap(static_cast<uint8_t>(ioCaps)); }
void NimBleCoreAdapter::setStaticPasskey(uint32_t pin) { NimBLEDevice::setSecurityPasskey(pin); }
bool NimBleCoreAdapter::initiateAuthentication(uint16_t connHandle) { return isPoweredOn() ? NimBLEDevice::startSecurity(connHandle) : false; }
void NimBleCoreAdapter::setOwnAddressType(BleDomain::AddressType addrType, bool) { NimBLEDevice::setOwnAddrType(static_cast<uint8_t>(addrType)); }

std::vector<std::string> NimBleCoreAdapter::getPairedDevices() const {
    std::vector<std::string> devices;
    int count = NimBLEDevice::getNumBonds();
    for (int i = 0; i < count; ++i) devices.push_back(NimBLEDevice::getBondedAddress(i).toString());
    return devices;
}
int NimBleCoreAdapter::getPairedDeviceCount() const { return NimBLEDevice::getNumBonds(); }
bool NimBleCoreAdapter::isDevicePaired(const std::string& address) const { return NimBLEDevice::isBonded(NimBLEAddress(address, 0)); }
void NimBleCoreAdapter::unpairDevice(const std::string& address) { NimBLEDevice::deleteBond(NimBLEAddress(address, 0)); }
void NimBleCoreAdapter::unpairAllDevices() { NimBLEDevice::deleteAllBonds(); }

void NimBleCoreAdapter::addToWhitelist(const std::string& address) { NimBLEDevice::whiteListAdd(NimBLEAddress(address, 0)); }
void NimBleCoreAdapter::removeFromWhitelist(const std::string& address) { NimBLEDevice::whiteListRemove(NimBLEAddress(address, 0)); }
void NimBleCoreAdapter::clearWhitelist() {
    std::vector<NimBLEAddress> addrs;
    for (size_t i = 0; i < NimBLEDevice::getWhiteListCount(); ++i) addrs.push_back(NimBLEDevice::getWhiteListAddress(i));
    for (auto& a : addrs) NimBLEDevice::whiteListRemove(a);
}
std::vector<std::string> NimBleCoreAdapter::getWhitelist() const {
    std::vector<std::string> res;
    for (size_t i = 0; i < NimBLEDevice::getWhiteListCount(); ++i) res.push_back(NimBLEDevice::getWhiteListAddress(i).toString());
    return res;
}
int NimBleCoreAdapter::getWhitelistCount() const { return NimBLEDevice::getWhiteListCount(); }

void NimBleCoreAdapter::startServer() {
    if (pServer_) pServer_->start();
    if (pAdvertising_) {
        NimBLEDevice::startAdvertising();
    }
}

NimBLEService* NimBleCoreAdapter::createService(const std::string& uuid) {
    if (!pServer_) return nullptr;
    auto* s = pServer_->createService(uuid);
    if (s) createdServices_.push_back(s);
    return s;
}

bool NimBleCoreAdapter::startService(NimBLEService* service) { return true; } 
bool NimBleCoreAdapter::stopService(NimBLEService* service) { return true; }  

void NimBleCoreAdapter::removeService(NimBLEService* service, bool deleteService) {
    if (!pServer_ || !service) return;
    pServer_->removeService(service, deleteService);
    createdServices_.erase(std::remove(createdServices_.begin(), createdServices_.end(), service), createdServices_.end());
}

void NimBleCoreAdapter::addService(NimBLEService* service) { if (pServer_) pServer_->addService(service); }
NimBLEService* NimBleCoreAdapter::getServiceByUUID(const std::string& uuid) const { return pServer_ ? pServer_->getServiceByUUID(uuid) : nullptr; }
std::vector<NimBLEService*> NimBleCoreAdapter::getAllServices() const { return createdServices_; }
std::vector<NimBLEService*> NimBleCoreAdapter::getActiveServices() const { return createdServices_; }
std::vector<NimBLEService*> NimBleCoreAdapter::getInactiveServices() const { return {}; }

NimBLECharacteristic* NimBleCoreAdapter::createCharacteristic(NimBLEService* s, const std::string& uuid, uint32_t props) {
    return s ? s->createCharacteristic(uuid, translateCharProperties(props)) : nullptr;
}
NimBLECharacteristic* NimBleCoreAdapter::getCharacteristicByUUID(NimBLEService* s, const std::string& uuid) const { return s ? s->getCharacteristic(uuid) : nullptr; }
void NimBleCoreAdapter::setCharacteristicValue(NimBLECharacteristic* c, const uint8_t* data, size_t length) { if (c) c->setValue(data, length); }
void NimBleCoreAdapter::setCharacteristicValue(NimBLECharacteristic* c, const std::string& value) { if (c) c->setValue(value); }
std::string NimBleCoreAdapter::getCharacteristicValue(NimBLECharacteristic* c) const { return c ? c->getValue().c_str() : ""; }

std::vector<uint8_t> NimBleCoreAdapter::getCharacteristicRawValue(NimBLECharacteristic* c) const {
    if (!c) return {};
    // Poprawka: W NimBLE 2.5 wartością zwracaną jest klasa NimBLEAttValue
    NimBLEAttValue v = c->getValue();
    return std::vector<uint8_t>(v.begin(), v.end());
}

bool NimBleCoreAdapter::notifyClients(NimBLECharacteristic* c, uint16_t) { if (!c) return false; c->notify(); return true; }
bool NimBleCoreAdapter::indicateClients(NimBLECharacteristic* c, uint16_t) { if (!c) return false; c->indicate(); return true; }
void NimBleCoreAdapter::setCharacteristicCallbacks(NimBLECharacteristic* c, NimBLECharacteristicCallbacks* callbacks) { if (c) c->setCallbacks(callbacks); }

NimBLEDescriptor* NimBleCoreAdapter::createDescriptor(NimBLECharacteristic* c, const std::string& uuid, uint32_t props, uint16_t maxL) {
    return c ? c->createDescriptor(uuid, translateDescProperties(props), maxL) : nullptr;
}
NimBLEDescriptor* NimBleCoreAdapter::getDescriptorByUUID(NimBLECharacteristic* c, const std::string& uuid) const { return c ? c->getDescriptorByUUID(uuid) : nullptr; }
void NimBleCoreAdapter::setDescriptorValue(NimBLEDescriptor* d, const uint8_t* data, size_t len) { if (d) d->setValue(data, len); }

int NimBleCoreAdapter::getConnectedCount() const { return pServer_ ? pServer_->getConnectedCount() : 0; }
std::vector<uint16_t> NimBleCoreAdapter::getConnectedHandles() const { return connectedHandles_; }

BleDomain::ConnectionInfo NimBleCoreAdapter::getPeerInfo(uint16_t connHandle) const {
    if (!pServer_) return {};
    return buildConnectionInfo(pServer_->getPeerInfo(connHandle));
}

std::vector<BleDomain::ConnectionInfo> NimBleCoreAdapter::getAllPeersInfo() const {
    std::vector<BleDomain::ConnectionInfo> result;
    for (uint16_t handle : connectedHandles_) result.push_back(getPeerInfo(handle));
    return result;
}

bool NimBleCoreAdapter::disconnectPeer(uint16_t connHandle, uint8_t reason) { return pServer_ ? pServer_->disconnect(connHandle, reason) == 0 : false; }
void NimBleCoreAdapter::disconnectAll(uint8_t reason) {
    std::vector<uint16_t> copy = connectedHandles_;
    for (uint16_t handle : copy) disconnectPeer(handle, reason);
}
bool NimBleCoreAdapter::updateConnectionParams(uint16_t connHandle, const BleDomain::ConnectionParams& params) {
    if (!pServer_) return false;
    pServer_->updateConnParams(connHandle, params.minInterval, params.maxInterval, params.latency, params.supervisionTimeout);
    return true;
}

void NimBleCoreAdapter::startAdvertising(uint32_t durationMs) {
    if (!pAdvertising_) return;
    if (durationMs > 0) NimBLEDevice::startAdvertising(durationMs);
    else NimBLEDevice::startAdvertising();
}
void NimBleCoreAdapter::suspendAdvertising() { if (pAdvertising_ && pAdvertising_->isAdvertising()) NimBLEDevice::stopAdvertising(); }
void NimBleCoreAdapter::resumeAdvertising() { if (pAdvertising_ && !pAdvertising_->isAdvertising()) NimBLEDevice::startAdvertising(); }
bool NimBleCoreAdapter::isAdvertising() const { return pAdvertising_ && pAdvertising_->isAdvertising(); }

void NimBleCoreAdapter::setAdvertisingType(BleDomain::AdvertisingType) {} 
void NimBleCoreAdapter::setAppearance(uint16_t appearance) { if (pAdvertising_) pAdvertising_->setAppearance(appearance); }
void NimBleCoreAdapter::setManufacturerData(const std::string& data) { if (pAdvertising_) pAdvertising_->setManufacturerData(data); }
void NimBleCoreAdapter::setManufacturerData(const std::vector<uint8_t>& data) {
    if (pAdvertising_) pAdvertising_->setManufacturerData(std::string(data.begin(), data.end()));
}
void NimBleCoreAdapter::setAdvertisingName(const std::string& name) { if (pAdvertising_) pAdvertising_->setName(name); }
void NimBleCoreAdapter::setAdvertisingIntervals(uint16_t minInterval, uint16_t maxInterval) {
    if (pAdvertising_) { pAdvertising_->setMinInterval(minInterval); pAdvertising_->setMaxInterval(maxInterval); }
}
void NimBleCoreAdapter::setPreferredConnIntervals(uint16_t, uint16_t) {} 
void NimBleCoreAdapter::setServiceAdvertising(const std::string& serviceUuid, BleDomain::FeatureState state) {
    if (!pAdvertising_) return;
    if (state == BleDomain::FeatureState::ENABLE) pAdvertising_->addServiceUUID(serviceUuid);
    else pAdvertising_->removeServiceUUID(serviceUuid);
    if (pAdvertising_->isAdvertising()) { NimBLEDevice::stopAdvertising(); NimBLEDevice::startAdvertising(); }
}
void NimBleCoreAdapter::setScanResponse(bool enable) {} 
void NimBleCoreAdapter::setScanFilter(bool whitelistForScan, bool whitelistForConnect) { if (pAdvertising_) pAdvertising_->setScanFilter(whitelistForScan, whitelistForConnect); }

void NimBleCoreAdapter::setPreferredPhy(BleDomain::PhyType txPhy, BleDomain::PhyType rxPhy) {
    ble_gap_set_prefered_default_le_phy(static_cast<uint8_t>(txPhy), static_cast<uint8_t>(rxPhy));
}

void NimBleCoreAdapter::setOnConnectCallback(BleDomain::ConnectCallback cb) { onConnectCb_ = std::move(cb); }
void NimBleCoreAdapter::setOnDisconnectCallback(BleDomain::DisconnectCallback cb) { onDisconnectCb_ = std::move(cb); }
void NimBleCoreAdapter::setOnAuthCompleteCallback(BleDomain::AuthCallback cb) { onAuthCb_ = std::move(cb); }
void NimBleCoreAdapter::setOnMtuChangedCallback(BleDomain::MtuChangedCallback cb) { onMtuChangedCb_ = std::move(cb); }

NimBLEServer* NimBleCoreAdapter::getRawServer() const { return pServer_; }
NimBLEAdvertising* NimBleCoreAdapter::getRawAdvertising() const { return pAdvertising_; }