
.PHONY: build-up down-all build-nodered push-nodered build-fi push-fi build-ms push-ms pushms build-u up

build-up:
	@echo "==> Budowanie projektu backendowego (Maven)..."
	mvn -f backend/pom.xml clean package -DskipTests
	@echo "==> Uruchamianie kontenerów aplikacji..."
	docker compose -f docker-compose.app.yml --profile app --env-file .env.app up -d --build
	@echo "==> Uruchamianie kontenerów monitorowania (Observability)..."
	docker compose -f docker-compose.obs.yml --env-file .env.observability up -d --build
	@echo "==> Wszystkie usługi zostały pomyślnie uruchomione!"

up:
	@echo "==> Uruchamianie kontenerów aplikacji..."
	docker compose -f docker-compose.app.yml --profile app --env-file .env.app up -d
	@echo "==> Uruchamianie kontenerów monitorowania (Observability)..."
	docker compose -f docker-compose.obs.yml --env-file .env.observability up -d
	@echo "==> Wszystkie usługi zostały pomyślnie uruchomione!"

down-all:
	@echo "==> Zatrzymywanie kontenerów aplikacji..."
	docker compose -f docker-compose.app.yml --profile app --env-file .env.app down
	@echo "==> Zatrzymywanie kontenerów monitorowania..."
	docker compose -f docker-compose.obs.yml --env-file .env.observability down
	@echo "==> Wszystkie usługi zostały zatrzymane."

build-nodered:
	@echo "==> Budowanie obrazu Node-RED..."
	docker build -t kowalolo/nodered:1.0.0 ./nodeRed

push-nodered:
	@echo "==> Wypychanie obrazu Node-RED na Docker Hub..."
	docker push kowalolo/nodered:1.0.0

build-fi:
	@echo "==> Budowanie jar dla firebase-integration..."
	mvn -f backend/pom.xml clean package -pl firebase-integration -am -DskipTests
	@echo "==> Budowanie obrazu firebase-integration..."
	docker build -t kowalolo/firebase-integration:1.0 ./backend/firebase-integration

push-fi:
	@echo "==> Wypychanie obrazu firebase-integration na Docker Hub..."
	docker push kowalolo/firebase-integration:1.0

build-ms:
	@echo "==> Budowanie jar dla mqtt-scaner..."
	mvn -f backend/pom.xml clean package -pl mqtt-scaner -am -DskipTests
	@echo "==> Budowanie obrazu mqtt-scaner..."
	docker build -t kowalolo/mqtt-scaner:1.0 ./backend/mqtt-scaner

push-ms:
	@echo "==> Wypychanie obrazu mqtt-scaner na Docker Hub..."
	docker push kowalolo/mqtt-scaner:1.0


