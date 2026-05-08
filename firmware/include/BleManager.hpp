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

    void onWrite(NimBLECharacteristic* pChar) {
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

    // Uprawnienia (Fluent API)
    CharacteristicBuilder& readAccess();
    CharacteristicBuilder& writeAccess();
    CharacteristicBuilder& notifyAccess();
    
    // Obsługa zdarzeń z telefonu
    CharacteristicBuilder& onWrite(std::function<void(const std::string&)> callback);

    // Kończy budowę charakterystyki i wraca do budowy Serwisu
    ServiceBuilder& buildCharacteristic();

private:
    std::string uuid_;
    NimBLEService* pService_;
    NimBleCoreAdapter* adapter_;
    ServiceBuilder* parent_;
    uint32_t properties_ = 0;
    CharacteristicCallbackHandler* callbackHandler_ = nullptr;
};

// --- Budowniczy Serwisu (ServiceBuilder) ---
class ServiceBuilder {
public:
    ServiceBuilder(const std::string& uuid, NimBleCoreAdapter* adapter, BleManager* manager);

    CharacteristicBuilder addCharacteristic(const std::string& uuid);
    
    // Kończy budowę serwisu i go uruchamia, wraca do Menedżera
    BleManager& buildService();

private:
    std::string uuid_;
    NimBLEService* pService_;
    NimBleCoreAdapter* adapter_;
    BleManager* manager_;
};

// --- Główny Menedżer (BleManager) ---
class BleManager {
public:
    BleManager(NimBleCoreAdapter* adapter);

    void init(const std::string& deviceName);

    // Uruchamia łańcuch budowania serwisu
    ServiceBuilder createNewService(const std::string& uuid);

    // Ustawienia profilów
    void setPerformanceProfile(BlePerformanceProfile profile);
    void manageAdvertising(BleAdvertisingMode mode);

    int getActiveConnectionsCount() const;

private:
    NimBleCoreAdapter* adapter_;
};