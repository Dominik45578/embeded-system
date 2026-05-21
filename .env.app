
MOSQUITTO_VERSION=2.0.18

# ==========================================
# Porty zewnętrzne
# ==========================================
MQTT_PORT=1883
INFLUX_DB_PORT=8181
INFLUX_EXPLORER_PORT=8282

# ==========================================
# Konfiguracja sieci
# ==========================================
APP_NETWORK_NAME=iot_shared_net

# ==========================================
# Konfiguracja InfluxDB
# ==========================================
INFLUXDB_INIT_USERNAME=ADMIN_USERNAME
INFLUXDB_INIT_PASSWORD=ADMIN_PASSWORD
INFLUXDB_INIT_ORG=iot
INFLUXDB_INIT_BUCKET=espdb

BACKEND_PORT=12200

BACKEND_ISSUER_URI=https://your-auth-domain/realms/lockly
BACKEND_JWK_SET_URI=https://your-auth-domain/realms/lockly/protocol/openid-connect/certs

BACKEND_MQTT_HOST=tcp://broker.hivemq.com
BACKEND_MQTT_TOPIC=lockly/iot

BACKEND_INFLUX_HOST=http://influxdb:8086
BACKEND_INFLUX_TOKEN=Ojdp9UGN9O4092hnJsXcvnYarEh2COW_Ntg9UWHZb6aO7nRjT9cuP1Fs_k346xBSZOb92TEToIRe0l5-xoWSEQ==
BACKEND_INFLUX_BUCKET=iot
BACKEND_INFLUX_ORG=lockly

DATABASE_URL=jdbc:postgresql://postgres:5432/iot
DATABASE_PORT=5432
DATABASE_USERNAME=admin
DATABASE_PASSWORD=admin
DATABASE_NAME=iot

RABBITMQ_HOST=rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_USERNAME=guest
RABBITMQ_PASSWORD=guest

GRPC_FIREBASE_INTEG_ADRES=static://firebase-integration:9090
