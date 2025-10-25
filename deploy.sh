#!/bin/bash
set -e

# --- Переменные ---
COMPOSE_FILE="docker-compose.prod.yml"
WEB_SERVICE="web"

# --- 1. Проверка docker compose ---
if ! command -v docker &>/dev/null; then
    echo "Docker не установлен. Устанавливаем..."
    sudo apt update
    sudo apt install ca-certificates curl gnupg -y
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
      https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
fi

# --- 2. Экспорт переменных для сборки ---
export DOCKER_BUILDKIT=0
export DOCKER_COMPOSE_TELEMETRY_DISABLED=1

# --- 3. Очистка старых контейнеров и томов ---
echo "Останавливаем и удаляем старые контейнеры..."
docker compose -f $COMPOSE_FILE down || true

# --- 4. Сборка и запуск контейнеров ---
echo "Собираем образы и запускаем контейнеры..."
docker compose -f $COMPOSE_FILE up -d --build

# --- 5. Сборка статики Django ---
echo "Собираем статику Django..."
docker compose -f $COMPOSE_FILE exec $WEB_SERVICE python manage.py collectstatic --noinput

# --- 6. Перезапуск Nginx (если используется) ---
if docker ps -a --format '{{.Names}}' | grep -q nginx; then
    echo "Перезапускаем Nginx..."
    docker compose -f $COMPOSE_FILE restart nginx
fi

echo "✅ Деплой завершён!"