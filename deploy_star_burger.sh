#!/bin/bash

# Strict mode
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Variables
PROJECT_DIR="/opt/StarBurger"
SERVICE_NAME="StarBurger.service"

# Load environment variables if .env exists
if [ -f "$PROJECT_DIR/.env" ]; then
    export $(grep -v '^#' $PROJECT_DIR/.env | xargs)
fi

echo -e "${GREEN}>>> Начинаем деплой StarBurger${NC}"

# 1. Обновляем код из Git
echo -e "${GREEN}>>> Получаем изменения из Git${NC}"
cd $PROJECT_DIR
git fetch
git reset --hard origin/master

# 2. Проверяем наличие Docker и Docker Compose
echo -e "${GREEN}>>> Проверяем Docker и Docker Compose${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}>>> Ошибка: Docker не установлен${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}>>> Ошибка: Docker Compose не установлен${NC}"
    exit 1
fi

# 3. Останавливаем старые контейнеры
echo -e "${GREEN}>>> Останавливаем старые контейнеры${NC}"
docker-compose down || true

# 4. Собираем новые образы
echo -e "${GREEN}>>> Собираем Docker образы${NC}"
docker-compose build --no-cache

# 5. Запускаем контейнеры
echo -e "${GREEN}>>> Запускаем контейнеры${NC}"
docker-compose up -d

# 6. Применяем миграции
echo -e "${GREEN}>>> Применяем миграции БД${NC}"
docker-compose exec -T backend python manage.py migrate --noinput

# 7. Собираем статику Django
echo -e "${GREEN}>>> Собираем статику Django${NC}"
docker-compose exec -T backend python manage.py collectstatic --noinput

# 8. Проверяем статус контейнеров
echo -e "${GREEN}>>> Проверяем статус контейнеров${NC}"
docker-compose ps

# 9. Очищаем неиспользуемые образы и тома
echo -e "${GREEN}>>> Очищаем неиспользуемые Docker ресурсы${NC}"
docker system prune -f

# 10. Перезапускаем nginx
echo -e "${GREEN}>>> Перезапускаем nginx${NC}"
systemctl reload nginx.service

echo -e "${GREEN}>>> Деплой успешно завершен!${NC}"

# Уведомляем Rollbar о деплое
echo -e "${GREEN}>>> Уведомляем Rollbar о деплое${NC}"
ROLLBAR_ACCESS_TOKEN="${TOKEN_ROLLBAR_PROD:-}"
if [ -z "$ROLLBAR_ACCESS_TOKEN" ]; then
    echo -e "${YELLOW}>>> Предупреждение: Rollbar access token не найден, пропускаем уведомление${NC}"
else
    LOCAL_USERNAME=$(whoami)
    CURRENT_COMMIT=$(git rev-parse HEAD)
    COMMENT="Deployed via deploy_star_burger.sh using Docker"
    ENVIRONMENT="production"

    echo -e "${GREEN}>>> Отправляем уведомление в Rollbar (коммит: ${CURRENT_COMMIT})${NC}"

    RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" https://api.rollbar.com/api/1/deploy/ \
        -F "access_token=$ROLLBAR_ACCESS_TOKEN" \
        -F "environment=$ENVIRONMENT" \
        -F "revision=$CURRENT_COMMIT" \
        -F "local_username=$LOCAL_USERNAME" \
        -F "comment=$COMMENT" \
        -F "status=succeeded" 2>&1)

    HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | sed 's/.*HTTP_STATUS://')
    BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')

    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo -e "${GREEN}>>> Rollbar успешно уведомлен о деплое${NC}"
    else
        echo -e "${YELLOW}>>> Предупреждение: Не удалось уведомить Rollbar (HTTP $HTTP_STATUS)${NC}"
        echo -e "${YELLOW}>>> Ответ сервера: $BODY${NC}"
    fi
fi

# Проверяем логи на наличие ошибок
echo -e "${GREEN}>>> Проверяем логи контейнеров${NC}"
docker-compose logs --tail=50 backend frontend nginx 
