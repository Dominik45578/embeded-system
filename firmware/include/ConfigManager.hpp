#pragma once

#include <Arduino.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <vector>
#include <map>
#include <functional>

enum class ConfigStatus {
    OK,
    STORAGE_ERR,
    PARSE_ERR,
    RESTORED_BACKUP,
    RESTORED_FACTORY
};

class AppConfig {
private:
    JsonDocument _doc;

    std::vector<String> splitPathByDot(const String& path) const;
    bool getVariantByPath(const String& path, JsonVariantConst& out) const;
    bool ensureParentObject(const String& path, JsonObject& parent, String& leaf);
    void mergeObjects(JsonObject dst, JsonObjectConst src);

public:
    AppConfig();

    void loadFactoryDefaults();
    ConfigStatus deserialize(const String& jsonPayload);
    String serialize() const;
    
    bool operator==(const AppConfig& other) const;

    // Szablonowy dostęp do danych o wysokiej elastyczności (np. config.get<int>("servo.pin"))
    template <typename T>
    T get(const String& path, T defaultValue = T()) const {
        JsonVariantConst node;
        if (getVariantByPath(path, node) && node.is<T>()) {
            return node.as<T>();
        }
        return defaultValue;
    }

    // Szablonowy zapis danych, automatycznie tworzący brakujące gałęzie drzewa
    template <typename T>
    bool set(const String& path, const T& value) {
        JsonObject parent;
        String leaf;
        if (!ensureParentObject(path, parent, leaf)) return false;
        parent[leaf] = value;
        return true;
    }

    bool has(const String& path) const;
    String getSubtree(const String& rootNode) const;
};

class ConfigOrchestrator {
public:
    using ConfigCallback = std::function<void(const AppConfig&)>;

    static ConfigOrchestrator& getInstance() {
        static ConfigOrchestrator instance;
        return instance;
    }

    ConfigOrchestrator(const ConfigOrchestrator&) = delete;
    ConfigOrchestrator& operator=(const ConfigOrchestrator&) = delete;

    ConfigStatus begin();
    ConfigStatus save();
    ConfigStatus factoryReset();

    const AppConfig& getConfig() const;
    ConfigStatus updateConfig(const AppConfig& newConfig);

    void subscribe(const String& section, ConfigCallback callback);

private:
    ConfigOrchestrator();
    void notify(const String& section);

    AppConfig _state;
    Preferences _prefs;

    std::map<String, std::vector<ConfigCallback>> _listeners;

    const char* _nvsNamespace = "sys_config";
    const char* _mainKey = "cfg_main";
    const char* _backupKey = "cfg_bak";
};