#pragma once
#include <cstdint>
#include <string>
#include <vector>
#include <functional>

namespace BleDomain {

enum class FeatureState : uint8_t {
    DISABLE = 0,
    ENABLE  = 1
};

enum class BlePowerLevel : uint8_t {
    Minimum,   ///< -12 dBm
    Low,       ///< -6  dBm
    Optimum,   ///<  0  dBm
    High,      ///<  +6 dBm
    Maximum    ///< +9  dBm
};


enum class TxPowerDbm : uint8_t {
    N12 = 0,   ///< -12 dBm
    N9  = 1,   ///<  -9 dBm
    N6  = 2,   ///<  -6 dBm
    N3  = 3,   ///<  -3 dBm
    P0  = 4,   ///<   0 dBm
    P3  = 5,   ///<  +3 dBm
    P6  = 6,   ///<  +6 dBm
    P9  = 7    ///< +9  dBm
};

enum class TxPowerTarget : uint8_t {
    Default     = 0,   ///< ESP_BLE_PWR_TYPE_DEFAULT
    Advertising = 1,   ///< ESP_BLE_PWR_TYPE_ADV
    Scanning    = 2,   ///< ESP_BLE_PWR_TYPE_SCAN
    Connection  = 3    ///< ESP_BLE_PWR_TYPE_CONN_HDL0 (first connection handle)
};

enum class IoCapabilities : uint8_t {
    DisplayOnly     = 0x00,   ///< BLE_HS_IO_DISPLAY_ONLY
    DisplayYesNo    = 0x01,   ///< BLE_HS_IO_DISPLAY_YESNO
    KeyboardOnly    = 0x02,   ///< BLE_HS_IO_KEYBOARD_ONLY
    NoInputNoOutput = 0x03,   ///< BLE_HS_IO_NO_INPUT_OUTPUT
    KeyboardDisplay = 0x04    ///< BLE_HS_IO_KEYBOARD_DISPLAY
};

enum class SecurityLevel : uint8_t {
    Open           = 0,   ///< No security requirements
    JustWorks      = 1,   ///< Unauthenticated, no MITM protection
    PasskeyConfirm = 2,   ///< Numeric comparison (LESC)
    PasskeyEntry   = 3,   ///< Passkey entry (MITM protected)
    Lesc           = 4    ///< LE Secure Connections required
};

enum class CharacteristicProperty : uint32_t {
    READ            = 1 << 0,
    WRITE           = 1 << 1,
    NOTIFY          = 1 << 2,
    INDICATE        = 1 << 3,
    WRITE_NR        = 1 << 4,   ///< Write without response
    BROADCAST       = 1 << 5,
    READ_ENC        = 1 << 6,
    READ_AUTHEN     = 1 << 7,
    WRITE_ENC       = 1 << 8,
    WRITE_AUTHEN    = 1 << 9,
    NOTIFY_ENC      = 1 << 10,
    NOTIFY_AUTHEN   = 1 << 11,
    INDICATE_ENC    = 1 << 12,
    INDICATE_AUTHEN = 1 << 13
};

inline uint32_t operator|(CharacteristicProperty a, CharacteristicProperty b) {
    return static_cast<uint32_t>(a) | static_cast<uint32_t>(b);
}
inline uint32_t operator|(uint32_t a, CharacteristicProperty b) {
    return a | static_cast<uint32_t>(b);
}
inline uint32_t operator&(uint32_t a, CharacteristicProperty b) {
    return a & static_cast<uint32_t>(b);
}

enum class DescriptorProperty : uint32_t {
    READ         = 1 << 0,
    WRITE        = 1 << 1,
    READ_ENC     = 1 << 2,
    READ_AUTHEN  = 1 << 3,
    WRITE_ENC    = 1 << 4,
    WRITE_AUTHEN = 1 << 5
};

inline uint32_t operator|(DescriptorProperty a, DescriptorProperty b) {
    return static_cast<uint32_t>(a) | static_cast<uint32_t>(b);
}
inline uint32_t operator|(uint32_t a, DescriptorProperty b) {
    return a | static_cast<uint32_t>(b);
}

enum class AdvertisingType : uint8_t {
    ConnectableUndirected    = 0x00,   ///< ADV_IND   — standard connectable
    ConnectableDirectedHD    = 0x01,   ///< ADV_DIRECT_IND high-duty
    ScannableUndirected      = 0x02,   ///< ADV_SCAN_IND
    NonConnectableUndirected = 0x03,   ///< ADV_NONCONN_IND (beacons, sensors)
    ConnectableDirectedLD    = 0x04    ///< ADV_DIRECT_IND low-duty
};

enum class ScanFilterPolicy : uint8_t {
    AllDevices        = 0x00,   ///< No filtering
    WhitelistConnect  = 0x01,   ///< Connections from whitelist only
    WhitelistScan     = 0x02,   ///< Scan requests from whitelist only
    WhitelistAll      = 0x03    ///< Both from whitelist only
};

struct AdvertisingConfig {
    AdvertisingType  type         = AdvertisingType::ConnectableUndirected;
    uint16_t         minInterval  = 0x20;    ///< units of 0.625 ms  → 20 ms
    uint16_t         maxInterval  = 0x40;    ///< units of 0.625 ms  → 40 ms
    bool             scanResponse = true;
    uint16_t         appearance   = 0x0000;  ///< 0x0000 = Generic Unknown
    std::string      manufacturerData;
    ScanFilterPolicy filterPolicy = ScanFilterPolicy::AllDevices;
};

enum class AddressType : uint8_t {
    Public          = 0x00,
    RandomStatic    = 0x01,
    RandomPrivateR  = 0x02,   ///< Resolvable private address
    RandomPrivateNR = 0x03    ///< Non-resolvable private address
};

struct DeviceAddress {
    std::string address;   ///< Colon-separated hex, e.g. "aa:bb:cc:dd:ee:ff"
    AddressType type = AddressType::Public;
};

/**
 * Parameters used in updateConnectionParams().
 * All interval / timeout fields use the standard BLE units:
 *   interval  — 1.25 ms units  (range: 6 .. 3200)
 *   latency   — number of connection events slave may skip
 *   timeout   — 10 ms units    (range: 10 .. 3200)
 */
struct ConnectionParams {
    uint16_t minInterval        = 24;    ///< 30 ms
    uint16_t maxInterval        = 40;    ///< 50 ms
    uint16_t latency            = 0;
    uint16_t supervisionTimeout = 400;   ///< 4 s
    uint16_t minConnEventLen    = 0;
    uint16_t maxConnEventLen    = 0xFFFF;
};

struct ConnectionInfo {
    std::string address;
    uint16_t    handle          = 0;
    uint16_t    connInterval    = 0;
    uint16_t    connLatency     = 0;
    uint16_t    supTimeout      = 0;
    bool        encrypted       = false;
    bool        authenticated   = false;
    bool        bonded          = false;
    uint8_t     securityKeySize = 0;
    bool        isMaster        = false;
};

enum class PhyType : uint8_t {
    Phy1M    = 0x01,   ///< 1 Mbps  — maximum compatibility
    Phy2M    = 0x02,   ///< 2 Mbps  — higher throughput
    PhyCoded = 0x04    ///< Coded   — long range (LE Coded PHY)
};

inline uint8_t operator|(PhyType a, PhyType b) {
    return static_cast<uint8_t>(a) | static_cast<uint8_t>(b);
}

using ConnectCallback    = std::function<void(const ConnectionInfo&)>;
using DisconnectCallback = std::function<void(const ConnectionInfo&, int reason)>;
using AuthCallback       = std::function<void(const ConnectionInfo&, bool success)>;
using MtuChangedCallback = std::function<void(uint16_t connHandle, uint16_t newMtu)>;

} // namespace BleDomain
