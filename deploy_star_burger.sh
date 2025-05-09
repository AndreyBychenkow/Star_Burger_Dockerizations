#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="/opt/StarBurger"
LOG_FILE="/var/log/starburger_deploy.log"

# Начать логирование
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${GREEN}>>> Начинаем деплой StarBurger${NC}"

# Проверка директории проекта
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}>>> Ошибка: Директория проекта $PROJECT_DIR не существует!${NC}"
    exit 1
fi

# Загрузка переменных окружения
if [ -f "$PROJECT_DIR/.env" ]; then
    export $(grep -v '^#' "$PROJECT_DIR/.env" | xargs)
fi

# 1. Обновление кода
echo -e "${GREEN}>>> Получаем изменения из Git${NC}"
cd "$PROJECT_DIR" || exit 1
git fetch
git reset --hard origin/master

# 2. Создаем необходимые директории
echo -e "${GREEN}>>> Создаем необходимые директории${NC}"
mkdir -p "$PROJECT_DIR/assets" \
         "$PROJECT_DIR/staticfiles" \
         "$PROJECT_DIR/media" \
         "$PROJECT_DIR/bundles"

# Устанавливаем правильные права
chmod 755 "$PROJECT_DIR/assets" \
          "$PROJECT_DIR/staticfiles" \
          "$PROJECT_DIR/media" \
          "$PROJECT_DIR/bundles"

# 3. Остановка старых контейнеров
echo -e "${GREEN}>>> Останавливаем старые контейнеры${NC}"
docker-compose down || true

# 4. Сборка образов
echo -e "${GREEN}>>> Собираем Docker образы${NC}"
docker-compose build --no-cache

# 5. Запуск контейнеров
echo -e "${GREEN}>>> Запускаем контейнеры${NC}"
docker-compose up -d

# 6. Миграции и статика
echo -e "${GREEN}>>> Применяем миграции БД${NC}"
docker-compose exec backend python manage.py migrate --noinput

echo -e "${GREEN}>>> Собираем статику Django${NC}"
docker-compose exec backend python manage.py collectstatic --noinput

# 7. Проверка контейнеров
echo -e "${GREEN}>>> Проверяем статус контейнеров${NC}"
docker-compose ps

# 8. Очистка Docker
echo -e "${GREEN}>>> Очищаем неиспользуемые Docker ресурсы${NC}"
docker system prune -f

# 9. Перезапуск nginx (если нужно)
echo -e "${GREEN}>>> Перезапускаем nginx (в Docker)${NC}"
docker-compose restart nginx

echo -e "${GREEN}>>> Деплой успешно завершен!${NC}"