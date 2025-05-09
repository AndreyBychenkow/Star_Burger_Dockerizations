#!/bin/bash

# Strict mode
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Variables
PROJECT_DIR="/opt/StarBurgerDockerizations"
MAX_RETRIES=3
RETRY_DELAY=10

# Functions
log_info() {
    echo -e "${GREEN}>>> $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}>>> Предупреждение: $1${NC}"
}

log_error() {
    echo -e "${RED}>>> Ошибка: $1${NC}"
}

wait_for_service() {
    local service=$1
    local max_attempts=$2
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if docker-compose ps $service | grep -q "Up"; then
            return 0
        fi
        log_warning "Ожидание запуска $service (попытка $attempt/$max_attempts)"
        sleep 5
        attempt=$((attempt + 1))
    done
    return 1
}

# Load environment variables if .env exists
if [ -f "$PROJECT_DIR/.env" ]; then
    set -o allexport
    source "$PROJECT_DIR/.env"
    set +o allexport
fi

log_info "Начинаем деплой StarBurger"

# 1. Обновляем код из Git
log_info "Получаем изменения из Git"
cd $PROJECT_DIR
git fetch
git reset --hard origin/master

# 2. Проверяем наличие Docker и Docker Compose
log_info "Проверяем Docker и Docker Compose"
if ! command -v docker &> /dev/null; then
    log_error "Docker не установлен"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose не установлен"
    exit 1
fi

# 3. Останавливаем старые контейнеры
log_info "Останавливаем старые контейнеры"
docker-compose down || true

# 4. Собираем новые образы
log_info "Собираем Docker образы"
docker-compose build --no-cache

# 5. Запускаем контейнеры
log_info "Запускаем контейнеры"
docker-compose up -d

# 6. Ждем запуска сервисов
log_info "Ожидаем запуска сервисов"
if ! wait_for_service "db" $MAX_RETRIES; then
    log_error "База данных не запустилась"
    exit 1
fi

if ! wait_for_service "backend" $MAX_RETRIES; then
    log_error "Backend не запустился"
    exit 1
fi

# 7. Применяем миграции
log_info "Применяем миграции БД"
if ! docker-compose exec -T backend python manage.py migrate --noinput; then
    log_error "Ошибка при применении миграций"
    exit 1
fi

# 8. Собираем статику Django
log_info "Собираем статику Django"
if ! docker-compose exec -T backend python manage.py collectstatic --noinput; then
    log_error "Ошибка при сборке статики"
    exit 1
fi

# 9. Проверяем статус контейнеров
log_info "Проверяем статус контейнеров"
docker-compose ps

# 10. Очищаем неиспользуемые образы и тома
log_info "Очищаем неиспользуемые Docker ресурсы"
docker system prune -f

# 12. Проверяем работоспособность сервисов
log_info "Проверяем работоспособность сервисов"
for service in backend frontend; do
    if ! docker-compose ps $service | grep -q "Up"; then
        log_error "Сервис $service не запущен"
        exit 1
    fi
done

# Уведомляем Rollbar о деплое
log_info "Уведомляем Rollbar о деплое"
ROLLBAR_ACCESS_TOKEN="${TOKEN_ROLLBAR_PROD:-}"
if [ -z "$ROLLBAR_ACCESS_TOKEN" ]; then
    log_warning "Rollbar access token не найден, пропускаем уведомление"
else
    LOCAL_USERNAME=$(whoami)
    CURRENT_COMMIT=$(git rev-parse HEAD)
    COMMENT="Deployed via deploy_star_burger.sh using Docker"
    ENVIRONMENT="production"

    log_info "Отправляем уведомление в Rollbar (коммит: ${CURRENT_COMMIT})"

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
        log_info "Rollbar успешно уведомлен о деплое"
    else
        log_warning "Не удалось уведомить Rollbar (HTTP $HTTP_STATUS)"
        log_warning "Ответ сервера: $BODY"
    fi
fi

log_info "Деплой успешно завершен!"