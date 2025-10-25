#!/bin/bash
set -e

# --- Переменные ---
COMPOSE_FILE="docker-compose.yml"
WEB_SERVICE="web"

# Проверка, запущен ли скрипт от root
if [ "$EUID" -ne 0 ]; then
    SUDO='sudo'
else
    SUDO=''
fi

# --- 1. Проверка docker compose ---
if ! command -v docker &>/dev/null; then
    echo "Docker не установлен. Устанавливаем..."
    $SUDO apt update
    $SUDO apt install ca-certificates curl gnupg -y
    $SUDO install -m 0755 -d /etc/apt/keyrings
    $SUDO curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    $SUDO chmod a+r /etc/apt/keyrings/docker.asc
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
      https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
    $SUDO apt update
    $SUDO apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
fi

echo "Проверяем, запущен ли Docker..."

if ! systemctl is-active --quiet docker; then
    echo "Docker не запущен. Запускаем..."
    $SUDO systemctl start docker

    # проверим ещё раз через 3 секунды
    sleep 3

    if ! systemctl is-active --quiet docker; then
        echo "❌ Не удалось запустить Docker. Проверьте установку или логи: sudo journalctl -u docker -xe"
        exit 1
    fi

    echo "✅ Docker успешно запущен."
else
    echo "✅ Docker уже работает."
fi

# --- 2. Экспорт переменных для сборки ---
export DOCKER_BUILDKIT=0
export DOCKER_COMPOSE_TELEMETRY_DISABLED=1

# --- 3. Очистка старых контейнеров и томов ---
echo "Останавливаем и удаляем старые контейнеры..."
$SUDO docker compose -f $COMPOSE_FILE down || true

# --- 4. Сборка и запуск контейнеров ---
echo "Собираем образы и запускаем контейнеры..."
$SUDO docker compose -f $COMPOSE_FILE up -d --build

echo "✅ Деплой завершён!"