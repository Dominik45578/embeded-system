FROM nodered/node-red:3.1.9-18

# Kopiowanie plików konfiguracyjnych i przepływów (flows) do katalogu roboczego Node-RED
COPY --chown=node-red:node-red . /data

# Zainstaluj dodatkowe palety (wtyczki) dla obsługi dashboardu i InfluxDB
RUN npm install @flowfuse/node-red-dashboard node-red-contrib-influxdb

