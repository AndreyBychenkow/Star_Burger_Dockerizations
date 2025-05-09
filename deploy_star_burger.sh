#!/bin/bash

set -e  # Останавливаем выполнение скрипта при ошибке

echo "[INFO] Начинаем деплой Star Burger"

# Обновляем код из Git
echo "[INFO] Обновляем код из Git"
git pull

# Получаем текущий коммит
COMMIT=$(git rev-parse HEAD)
echo "[INFO] Текущий коммит: $COMMIT"

# Останавливаем старые контейнеры
echo "[INFO] Останавливаем старые контейнеры"
docker-compose down

# Очищаем Docker-кэш
echo "[INFO] Очищаем Docker-кэш"
docker system prune -f

# Собираем и запускаем контейнеры
echo "[INFO] Собираем и запускаем контейнеры"
docker-compose build
docker-compose up -d

# Проверяем статус сервисов
echo "[INFO] Проверяем статус сервисов"
docker ps

# Записываем информацию о деплое
echo "[INFO] Деплой успешно завершен!"
echo "Дата: $(date)" > deploy_info.txt
echo "Коммит: $COMMIT" >> deploy_info.txt
echo "Деплой завершен: $(date)" >> deploy_info.txt

# Отправляем уведомление в телеграм (если настроено)
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
  echo "[INFO] Отправляем уведомление о деплое"
  curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -d chat_id="$TELEGRAM_CHAT_ID" \
    -d text="Star Burger успешно обновлен до версии $COMMIT"
fi