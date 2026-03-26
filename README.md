# Microservices Music Streaming Platform on Kubernetes

Итоговый проект: Клиент-серверная платформа для стриминга музыки с использованием микросервисной архитектуры и оркестрации Kubernetes.

## 🚀 Архитектура проекта
*   **Backend:** Go (Golang) — сервис стриминга, работающий с S3 и SQL.
*   **Database:** PostgreSQL — хранение метаданных треков (название, автор, ключи файлов).
*   **Storage:** MinIO (S3-compatible) — хранилище аудиофайлов (.mp3).
*   **Orchestration:** Kubernetes (Minikube) — управление контейнерами и сетью.
*   **Frontend:** Flutter (Web/Mobile) — кроссплатформенный плеер.

---

## 🛠 Инфраструктура и запуск

### 1. Подготовка окружения
Проект разработан для запуска в среде: **Windows + Hyper-V + Ubuntu 24.04**.
Необходимые инструменты: `minikube`, `kubectl`, `docker`, `flutter`.

### 2. Развертывание хранилища и БД
Перейдите в папку с манифестами и примените их:

kubectl apply -f k8s/postgres-manifest.yaml
kubectl apply -f k8s/minio.yaml

Наполнение базы:
Зайдите в под Postgres и создайте таблицу:

kubectl exec -it <postgres-pod-name> -- psql -U admin -d music_db
# Выполните SQL:
CREATE TABLE tracks (id SERIAL PRIMARY KEY, title TEXT, artist TEXT, minio_key TEXT);
INSERT INTO tracks (title, artist, minio_key) VALUES ('Test Song', 'Go Gopher', 'test.mp3');

Настройка MinIO:

Пробросьте порт консоли: kubectl port-forward service/minio-service 9001:9001
Зайдите на localhost:9001, создайте бакет music и загрузите файл test.mp3.

3. Сборка и деплой Бэкенда
Подключите терминал к Docker внутри Minikube:

eval $(minikube docker-env)
cd services/streaming-service
CGO_ENABLED=0 GOOS=linux go build -o main main.go
docker build -t streaming-service:v1 .
kubectl apply -f ../../k8s/backend-deployment.yaml

4. Запуск мобильного приложения (Flutter)
Перейдите в папку приложения и запустите веб-версию:

cd mobile_app
flutter pub get
flutter run -d chrome --web-hostname 0.0.0.0 --web-port 5000
Приложение будет доступно по адресу http://<IP_UBUNTU>:5000.

📡 API Endpoints (Backend)
GET /tracks — Получение списка всех песен в формате JSON.
GET /stream?key=filename.mp3 — Потоковая передача аудиофайла.
🛠 Технический стек
Go 1.22/1.23 (minio-go, lib/pq)
Kubernetes (Deployments, Services, NodePort, LoadBalancer)
PostgreSQL 15
MinIO S3
Flutter 3.x (just_audio, http)
