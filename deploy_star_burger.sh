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
    exit 1
fi

# Настройка и запуск PostgreSQL на хосте
log_info "Проверяем PostgreSQL на хосте"
if ! command -v psql &> /dev/null; then
    log_info "PostgreSQL не установлен. Устанавливаем..."
    apt-get update
    apt-get install -y postgresql postgresql-contrib
fi

# Создание БД и пользователя, если они не существуют
log_info "Настраиваем PostgreSQL"
if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw starburger_prod; then
    log_info "Создаем базу данных и пользователя"
    sudo -u postgres psql -c "CREATE USER starburger_user WITH PASSWORD '0704';" || true
    sudo -u postgres psql -c "CREATE DATABASE starburger_prod OWNER starburger_user;" || true
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE starburger_prod TO starburger_user;" || true
fi

# Запуск PostgreSQL
log_info "Запускаем PostgreSQL на хосте"
systemctl restart postgresql
systemctl status postgresql --no-pager

# Останавливаем и удаляем старые контейнеры
log_info "Останавливаем старые контейнеры"
docker-compose down || true
docker rm -f star-burger-backend star-burger-frontend || true

# Очистка Docker-кэша
log_info "Очищаем Docker-кэш"
docker system prune -f || true

# Запуск контейнеров
log_info "Запускаем контейнеры"
docker-compose up -d

# Проверка статуса
log_info "Проверяем статус сервисов"
docker-compose ps

log_info "Деплой завершен!"