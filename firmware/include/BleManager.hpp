#pragma once

#include "NimBleCoreAdapter.hpp"
#include "BleDomain.hpp"
#include <string>
#include <functional>
#include <vector>


enum class BlePerformanceProfile {
    ECO,         // Minimalne zużycie energii 
    STANDARD,    // Standardowy kompromis
    OTA_UPDATE   // Zmaksymalizowana moc i paczki danych do szybkiego przesyłania
};

enum class BleAdvertisingMode {
    FAST,        // Szybkie rozgłaszanie (kiedy zamek "czeka" na telefon)
    SLOW,        // Powolne rozgłaszanie (tryb czuwania, aby odciążyć Wi-Fi)
    STOPPED      // Zatrzymanie rozgłaszania
};

class ServiceBuilder;
class BleManager;

class CharacteristicCallbackHandler : public NimBLECharacteristicCallbacks {
public:
    using WriteCallback = std::function<void(const std::string&)>;
    void onWrite(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo) override {
        if (writeCb_) {
            auto val = pChar->getValue();
            std::string strValue(val.begin(), val.end());
            writeCb_(strValue);
        }
    }

    void setWriteCallback(WriteCallback cb) { writeCb_ = cb; }

private:
    WriteCallback writeCb_ = nullptr;
};

class CharacteristicBuilder {
public:
    CharacteristicBuilder(const std::string& uuid, NimBLEService* pService, NimBleCoreAdapter* adapter, ServiceBuilder* parent);

    CharacteristicBuilder& readAccess();
    CharacteristicBuilder& writeAccess();
    CharacteristicBuilder& notifyAccess();

    CharacteristicBuilder& encryptedReadAccess();
    CharacteristicBuilder& encryptedWriteAccess();
    
    CharacteristicBuilder& onWrite(std::function<void(const std::string&)> callback);

    ServiceBuilder& buildCharacteristic();

private:
    std::string uuid_;
    NimBLEService* pService_;
    NimBleCoreAdapter* adapter_;
    ServiceBuilder* parent_;
    uint32_t properties_ = 0;
    CharacteristicCallbackHandler* callbackHandler_ = nullptr;
};

class ServiceBuilder {
public:
    ServiceBuilder(const std::string& uuid, NimBleCoreAdapter* adapter, BleManager* manager);

    CharacteristicBuilder addCharacteristic(const std::string& uuid);
    
    BleManager& buildService();

private:
    std::string uuid_;
    NimBLEService* pService_;
    NimBleCoreAdapter* adapter_;
    BleManager* manager_;
};

class BleManager {
public:
    static BleManager& getInstance() {
        static BleManager instance(&NimBleCoreAdapter::getInstance());
        return instance;
    }

    BleManager(const BleManager&) = delete;
    BleManager& operator=(const BleManager&) = delete;

    void init(const std::string& deviceName);

    ServiceBuilder createNewService(const std::string& uuid);

    void setPerformanceProfile(BlePerformanceProfile profile);
    void manageAdvertising(BleAdvertisingMode mode);

    int getActiveConnectionsCount() const;
    int getPairedCount() const;
    
    int getAverageRssi() const;
    
    bool updateAndNotify(const std::string& serviceUuid, const std::string& charUuid, const std::string& payload);

private:
    NimBleCoreAdapter* adapter_;
    BleManager(NimBleCoreAdapter* adapter);
};