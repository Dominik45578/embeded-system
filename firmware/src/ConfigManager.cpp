#include "ConfigManager.hpp"

namespace {
static const char FACTORY_DEFAULT_JSON[] = R"json(
{
  "wifi": {
    "ssid": "",
    "password": ""
  },
  "ble": {
    "service_uuid": "4fafc201-1fb5-459e-8fcc-c5c9c331914b",
    "char_uuid": "beb5483e-36e1-4688-b7f5-ea07361b26a8",
    "pin": 123456,
    "enabled": true
  },
  "servo": {
    "pin": 23,
    "channel": 1,
    "freq": 50,
    "res": 16,
    "bounds": { "min": 500, "mid": 1500, "max": 2500 }
  },
  "lock": {
    "pin": "123456",
    "blocked_ms": 30000,
    "auto_relock_ms": 5000
  },
  "log": {
    "enabled": true,
    "level": "INFO"
  }
}
)json";
}

// ==========================================
// AppConfig Implementation
// ==========================================

AppConfig::AppConfig() {
    loadFactoryDefaults();
}

void AppConfig::loadFactoryDefaults() {
    _doc.clear();
    deserializeJson(_doc, FACTORY_DEFAULT_JSON);
}

std::vector<String> AppConfig::splitPathByDot(const String& path) const {
    std::vector<String> tokens;
    int start = 0;
    int end = path.indexOf('.');
    while (end != -1) {
        tokens.push_back(path.substring(start, end));
        start = end + 1;
        end = path.indexOf('.', start);
    }
    tokens.push_back(path.substring(start));
    return tokens;
}

bool AppConfig::getVariantByPath(const String& path, JsonVariantConst& out) const {
    std::vector<String> tokens = splitPathByDot(path);
    JsonVariantConst current = _doc.as<JsonVariantConst>();
    
    for (const auto& token : tokens) {
        if (!current.is<JsonObjectConst>() || !current.as<JsonObjectConst>().containsKey(token)) {
            return false;
        }
        current = current[token];
    }
    out = current;
    return true;
}

bool AppConfig::ensureParentObject(const String& path, JsonObject& parent, String& leaf) {
    std::vector<String> tokens = splitPathByDot(path);
    if (tokens.empty()) return false;
    
    JsonObject current = _doc.as<JsonObject>();
    for (size_t i = 0; i < tokens.size() - 1; ++i) {
        String key = tokens[i];
        if (!current.containsKey(key)) {
            current.createNestedObject(key);
        }
        current = current[key];
    }
    parent = current;
    leaf = tokens.back();
    return true;
}

void AppConfig::mergeObjects(JsonObject dst, JsonObjectConst src) {
    for (JsonPairConst kv : src) {
        const char* key = kv.key().c_str();
        JsonVariantConst srcValue = kv.value();

        if (srcValue.is<JsonObjectConst>()) {
            if (!dst[key].is<JsonObject>()) dst[key].to<JsonObject>();
            mergeObjects(dst[key].as<JsonObject>(), srcValue.as<JsonObjectConst>());
        } else {
            dst[key] = srcValue;
        }
    }
}

ConfigStatus AppConfig::deserialize(const String& jsonPayload) {
    JsonDocument incoming;
    DeserializationError error = deserializeJson(incoming, jsonPayload);
    if (error) return ConfigStatus::PARSE_ERR;

    // Pobranie czystego drzewa domyślnego celem zachowania struktury
    JsonDocument candidate;
    deserializeJson(candidate, FACTORY_DEFAULT_JSON);

    mergeObjects(candidate.as<JsonObject>(), incoming.as<JsonObjectConst>());
    _doc = candidate;
    return ConfigStatus::OK;
}

String AppConfig::serialize() const {
    String out;
    serializeJson(_doc, out);
    return out;
}

bool AppConfig::operator==(const AppConfig& other) const {
    return this->serialize() == other.serialize();
}

bool AppConfig::has(const String& path) const {
    JsonVariantConst dummy;
    return getVariantByPath(path, dummy);
}

String AppConfig::getSubtree(const String& rootNode) const {
    JsonVariantConst node;
    if (getVariantByPath(rootNode, node)) {
        String out;
        serializeJson(node, out);
        return out;
    }
    return "{}";
}

// ==========================================
// ConfigOrchestrator Implementation
// ==========================================

ConfigOrchestrator::ConfigOrchestrator() {}

ConfigStatus ConfigOrchestrator::begin() {
    // Inicjalizacja partycji NVS w trybie odczytu/zapisu (false = nie tylko do odczytu)
    if (!_prefs.begin(_nvsNamespace, false)) {
        return factoryReset();
    }

    String mainPayload = _prefs.getString(_mainKey, "");
    
    if (!mainPayload.isEmpty() && _state.deserialize(mainPayload) == ConfigStatus::OK) {
        return ConfigStatus::OK;
    }

    // Mechanizm Failover: Odzyskiwanie z partycji NVS backupu
    String backupPayload = _prefs.getString(_backupKey, "");
    if (!backupPayload.isEmpty() && _state.deserialize(backupPayload) == ConfigStatus::OK) {
        _prefs.putString(_mainKey, backupPayload); 
        return ConfigStatus::RESTORED_BACKUP;
    }

    return factoryReset();
}

ConfigStatus ConfigOrchestrator::save() {
    String payload = _state.serialize();
    
    size_t bytesMain = _prefs.putString(_mainKey, payload);
    size_t bytesBak = _prefs.putString(_backupKey, payload);

    if (bytesMain == 0 || bytesBak == 0) {
        return ConfigStatus::STORAGE_ERR;
    }
    return ConfigStatus::OK;
}

ConfigStatus ConfigOrchestrator::factoryReset() {
    _state.loadFactoryDefaults();
    
    String defaultPayload = _state.serialize();
    _prefs.putString(_mainKey, defaultPayload);
    _prefs.putString(_backupKey, defaultPayload);
    
    return ConfigStatus::RESTORED_FACTORY;
}

const AppConfig& ConfigOrchestrator::getConfig() const {
    return _state;
}

ConfigStatus ConfigOrchestrator::updateConfig(const AppConfig& newConfig) {
    if (_state == newConfig) return ConfigStatus::OK;

    std::vector<String> targetSections = {"wifi", "ble", "servo", "lock", "log"};
    std::vector<String> changedSections;

    // Reaktywna detekcja różnic (Differential update)
    for (const auto& section : targetSections) {
        if (_state.getSubtree(section) != newConfig.getSubtree(section)) {
            changedSections.push_back(section);
        }
    }

    _state = newConfig;
    ConfigStatus status = save();
    if (status != ConfigStatus::OK) return status;

    // Publikacja zdarzeń wzdłuż zmodyfikowanych modułów logicznych
    for (const auto& section : changedSections) {
        notify(section);
    }

    return ConfigStatus::OK;
}

void ConfigOrchestrator::subscribe(const String& section, ConfigCallback callback) {
    if (callback) {
        _listeners[section].push_back(callback);
    }
}

void ConfigOrchestrator::notify(const String& section) {
    auto it = _listeners.find(section);
    if (it != _listeners.end()) {
        for (const auto& cb : it->second) {
            cb(_state);
        }
    }
}