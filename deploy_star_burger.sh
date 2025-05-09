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
DOMAIN="starburger.decebell.site"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Main script
log_info "Начинаем деплой Star Burger"

# Переходим в директорию проекта
cd $PROJECT_DIR

# Получаем последние изменения из Git
log_info "Обновляем код из Git"
git pull || log_warning "Не удалось получить обновления из Git"

# Получаем текущий коммит
CURRENT_COMMIT=$(git rev-parse HEAD)
log_info "Текущий коммит: $CURRENT_COMMIT"

# Проверяем наличие переменных окружения
if [ ! -f ".env" ]; then
    log_warning "Файл .env не найден. Убедитесь, что он существует и содержит необходимые переменные."
    log_info "Требуются следующие переменные окружения:"
    echo "SECRET_KEY"
    echo "YANDEX_GEOCODER_API_KEY"
    echo "ALLOWED_HOSTS (должен включать $DOMAIN)" 
    echo "DB_USER, DB_PASSWORD, DB_NAME"
    echo "POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB"
    echo "DATABASE_URL"
    exit 1
fi

# Останавливаем и удаляем старые контейнеры
log_info "Останавливаем старые контейнеры"
docker-compose down || true
docker rm -f star-burger-db star-burger-backend star-burger-frontend || true

# Очистка Docker-кэша
log_info "Очищаем Docker-кэш"
docker system prune -f || true

# Перезагрузка Docker (крайняя мера для решения проблем с запуском)
log_info "Перезагружаем Docker"
systemctl restart docker || log_warning "Не удалось перезагрузить Docker"
sleep 5

# Запуск всех контейнеров
log_info "Запускаем контейнеры"
docker-compose up -d

# Проверка статуса
log_info "Проверяем статус сервисов"
docker-compose ps

# Проверка логов БД при проблемах
if ! docker ps | grep -q star-burger-db; then
    log_error "PostgreSQL не запустился. Выводим логи:"
    docker logs star-burger-db || true
fi

log_info "Деплой завершен!"