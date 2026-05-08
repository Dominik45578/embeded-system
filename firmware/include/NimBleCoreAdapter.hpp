#pragma once
#include <string>
#include <vector>
#include <functional>
#include <NimBLEDevice.h>
#include "BleDomain.hpp"

class NimBleCoreAdapter {

    class ServerCallbackShim : public NimBLEServerCallbacks {
    public:
        explicit ServerCallbackShim(NimBleCoreAdapter* owner) : owner_(owner) {}

        void onConnect   (NimBLEServer* pServer, NimBLEConnInfo& connInfo) override;
        void onDisconnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo, int reason) override;
        void onAuthenticationComplete(NimBLEConnInfo& connInfo) override;
        void onMTUChange (uint16_t mtu, NimBLEConnInfo& connInfo) override;

    private:
        NimBleCoreAdapter* owner_;
    };

    NimBLEServer* pServer_;
    NimBLEAdvertising* pAdvertising_;
    ServerCallbackShim* pCallbackShim_;
    std::string         deviceName_;
    bool                initialized_;

    bool isBondingEnabled_;
    bool isMitmEnabled_;
    bool isSecureConnectionsEnabled_;

    std::vector<uint16_t> connectedHandles_;
    std::vector<NimBLEService*> createdServices_;

    BleDomain::ConnectCallback    onConnectCb_;
    BleDomain::DisconnectCallback onDisconnectCb_;
    BleDomain::AuthCallback       onAuthCb_;
    BleDomain::MtuChangedCallback onMtuChangedCb_;

    uint32_t translateCharProperties  (uint32_t domainProps)  const;
    uint32_t translateDescProperties  (uint32_t domainProps)  const;
    void applySecurityState();
    BleDomain::ConnectionInfo buildConnectionInfo(const NimBLEConnInfo& raw) const;
    NimBleCoreAdapter();

public:
    static NimBleCoreAdapter& getInstance() {
        static NimBleCoreAdapter instance;
        return instance;
    }


    NimBleCoreAdapter(const NimBleCoreAdapter&) = delete;
    NimBleCoreAdapter& operator=(const NimBleCoreAdapter&) = delete;

    ~NimBleCoreAdapter();

    void powerOn(const std::string& name);
    void powerOff();
    [[nodiscard]] bool isPoweredOn() const;

    void setDeviceName(const std::string& name);
    [[nodiscard]] std::string getDeviceName() const;

    void setTxPower(BleDomain::BlePowerLevel level);
    void setTxPowerGranular(BleDomain::TxPowerDbm level, BleDomain::TxPowerTarget target = BleDomain::TxPowerTarget::Default);
    [[nodiscard]] int8_t getTxPower() const;

    void optimizeForDataTransfer(uint16_t mtuSize = 512);
    [[nodiscard]] uint16_t getMtu(uint16_t connHandle) const;
    [[nodiscard]] uint16_t getPreferredMtu() const;

    void setPairingMode      (BleDomain::FeatureState state);
    void setBonding          (BleDomain::FeatureState state);
    void setMitmProtection   (BleDomain::FeatureState state);
    void setSecureConnections(BleDomain::FeatureState state);
    void setIoCapabilities   (BleDomain::IoCapabilities ioCaps);
    void setStaticPasskey(uint32_t pin);
    bool initiateAuthentication(uint16_t connHandle);
    void setOwnAddressType(BleDomain::AddressType addrType, bool randomize = false);

    [[nodiscard]] std::vector<std::string> getPairedDevices()   const;
    [[nodiscard]] int                      getPairedDeviceCount() const;
    [[nodiscard]] bool                     isDevicePaired(const std::string& address) const;
    void unpairDevice   (const std::string& address);
    void unpairAllDevices();

    void addToWhitelist     (const std::string& address);
    void removeFromWhitelist(const std::string& address);
    void clearWhitelist     ();
    [[nodiscard]] std::vector<std::string> getWhitelist()      const;
    [[nodiscard]] int                      getWhitelistCount() const;

    void startServer();
    NimBLEService* createService(const std::string& uuid);
    bool startService (NimBLEService* service);
    bool stopService  (NimBLEService* service);
    void removeService(NimBLEService* service, bool deleteService = false);
    void addService(NimBLEService* service);
    [[nodiscard]] NimBLEService* getServiceByUUID(const std::string& uuid) const;
    [[nodiscard]] std::vector<NimBLEService*> getAllServices()      const;
    [[nodiscard]] std::vector<NimBLEService*> getActiveServices()   const;
    [[nodiscard]] std::vector<NimBLEService*> getInactiveServices() const;

    NimBLECharacteristic* createCharacteristic(NimBLEService* service, const std::string& uuid, uint32_t domainProperties);
    [[nodiscard]] NimBLECharacteristic* getCharacteristicByUUID(NimBLEService* service, const std::string& uuid) const;
    void setCharacteristicValue(NimBLECharacteristic* c, const uint8_t* data, size_t length);
    void setCharacteristicValue(NimBLECharacteristic* c, const std::string& value);
    [[nodiscard]] std::string          getCharacteristicValue   (NimBLECharacteristic* c) const;
    [[nodiscard]] std::vector<uint8_t> getCharacteristicRawValue(NimBLECharacteristic* c) const;
    bool notifyClients  (NimBLECharacteristic* c, uint16_t connHandle = 0xFFFF);
    bool indicateClients(NimBLECharacteristic* c, uint16_t connHandle = 0xFFFF);
    void setCharacteristicCallbacks(NimBLECharacteristic* c, NimBLECharacteristicCallbacks* callbacks);

    NimBLEDescriptor* createDescriptor(NimBLECharacteristic* c, const std::string& uuid, uint32_t domainDescProps, uint16_t maxLength = 100);
    [[nodiscard]] NimBLEDescriptor* getDescriptorByUUID(NimBLECharacteristic* c, const std::string& uuid) const;
    void setDescriptorValue(NimBLEDescriptor* descriptor, const uint8_t* data, size_t length);

    [[nodiscard]] int                                    getConnectedCount()  const;
    [[nodiscard]] std::vector<uint16_t>                  getConnectedHandles() const;
    [[nodiscard]] BleDomain::ConnectionInfo              getPeerInfo(uint16_t connHandle) const;
    [[nodiscard]] std::vector<BleDomain::ConnectionInfo> getAllPeersInfo()    const;

    bool disconnectPeer(uint16_t connHandle, uint8_t reason = 0x13);
    void disconnectAll (uint8_t  reason     = 0x13);
    bool updateConnectionParams(uint16_t connHandle, const BleDomain::ConnectionParams& params);

    void startAdvertising(uint32_t durationMs = 0);
    void suspendAdvertising();
    void resumeAdvertising();
    [[nodiscard]] bool isAdvertising() const;

    void setAdvertisingType     (BleDomain::AdvertisingType type);
    void setAppearance          (uint16_t appearance);
    void setManufacturerData    (const std::string&         data);
    void setManufacturerData    (const std::vector<uint8_t>& data);
    void setAdvertisingName     (const std::string&         name);
    void setAdvertisingIntervals(uint16_t minInterval, uint16_t maxInterval);
    void setPreferredConnIntervals(uint16_t minPreferred, uint16_t maxPreferred);
    void setServiceAdvertising(const std::string& serviceUuid, BleDomain::FeatureState state);
    void setScanResponse(bool enable);
    void setScanFilter(bool whitelistForScan, bool whitelistForConnect);

    void setPreferredPhy(BleDomain::PhyType txPhy, BleDomain::PhyType rxPhy);

    void setOnConnectCallback    (BleDomain::ConnectCallback    cb);
    void setOnDisconnectCallback (BleDomain::DisconnectCallback cb);
    void setOnAuthCompleteCallback(BleDomain::AuthCallback      cb);
    void setOnMtuChangedCallback (BleDomain::MtuChangedCallback cb);
    int getPeerRssi(uint16_t connHandle) const;

    [[nodiscard]] NimBLEServer* getRawServer()      const;
    [[nodiscard]] NimBLEAdvertising* getRawAdvertising() const;
};