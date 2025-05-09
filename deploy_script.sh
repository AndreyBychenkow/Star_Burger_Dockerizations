#!/bin/bash

# Строгий режим
set -e

# Переменные
PROJECT_DIR="/opt/StarBurger"
REPO="https://github.com/AndreyBychenkow/StarBurgerDockerizations.git"
ENV_FILE="$PROJECT_DIR/.env"

echo "Начинаем деплой Star Burger"

# Проверка наличия директории проекта
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Создаем директорию проекта $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    git clone "$REPO" .
    if [ ! -d ".git" ]; then
        echo "Ошибка: Не удалось клонировать репозиторий"
        exit 1
    fi
else
    cd "$PROJECT_DIR"
    echo "Сохраняем текущий файл deploy_star_burger.sh перед обновлением"
    cp deploy_star_burger.sh deploy_star_burger.sh.backup || echo "Не удалось создать резервную копию"
    
    echo "Удаляем .git и клонируем репозиторий заново"
    rm -rf .git
    git init
    git remote add origin "$REPO"
    git fetch
    git reset --hard origin/master
    
    echo "Восстанавливаем права на скрипт"
    chmod +x deploy_star_burger.sh
    
    # Сравниваем текущий скрипт с бэкапом
    if [ -f deploy_star_burger.sh.backup ]; then
        echo "Проверяем отличия между текущим скриптом и резервной копией"
        diff -q deploy_star_burger.sh deploy_star_burger.sh.backup || echo "Файлы отличаются, используем новый скрипт"
    fi
fi

# Проверка наличия .env файла
if [ ! -f "$ENV_FILE" ]; then
    echo "Ошибка: Файл .env не найден"
    exit 1
fi

# Проверка и запуск Docker
echo "Проверяем Docker..."
if ! systemctl is-active --quiet docker; then
    sudo systemctl start docker || { echo "Не удалось запустить Docker"; exit 1; }
fi
sudo chmod 666 /var/run/docker.sock 2>/dev/null || true

# Создаем необходимые директории если их нет
echo "Создаем необходимые директории..."
mkdir -p "$PROJECT_DIR/frontend/assets" "$PROJECT_DIR/frontend/bundles" "$PROJECT_DIR/frontend/bundles-src"
mkdir -p "$PROJECT_DIR/backend/staticfiles" "$PROJECT_DIR/backend/media" "$PROJECT_DIR/backend/staticfiles/bundles"

# Создаем минимальные JS и CSS файлы
echo "Создаем минимальные JS и CSS файлы..."
cat > "$PROJECT_DIR/backend/staticfiles/index.min.js" << 'EOF'
// Minimal viable JS file
import React from 'react';
import ReactDOM from 'react-dom';
import './index.css';
import App from './App';

ReactDOM.render(<App />, document.getElementById('root'));
EOF

cat > "$PROJECT_DIR/backend/staticfiles/index.min.css" << 'EOF'
/* Minimal viable CSS file */
body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Roboto", "Oxygen",
    "Ubuntu", "Cantarell", "Fira Sans", "Droid Sans", "Helvetica Neue", sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
EOF

cat > "$PROJECT_DIR/backend/staticfiles/App.min.js" << 'EOF'
// Minimal App.js
import React from 'react';

function App() {
  return (
    <div className="App">
      <header className="App-header">
        <h1>Star Burger</h1>
        <p>
          Сайт в процессе загрузки...
        </p>
      </header>
    </div>
  );
}

export default App;
EOF

# Копируем исходные файлы, если они существуют
if [ -f "$PROJECT_DIR/frontend/bundles-src/index.js" ]; then
    cp -f "$PROJECT_DIR/frontend/bundles-src/index.js" "$PROJECT_DIR/backend/staticfiles/index.min.js"
    echo "Скопирован исходный index.js"
fi

if [ -f "$PROJECT_DIR/frontend/bundles-src/index.css" ]; then
    cp -f "$PROJECT_DIR/frontend/bundles-src/index.css" "$PROJECT_DIR/backend/staticfiles/index.min.css"
    echo "Скопирован исходный index.css"
fi

if [ -f "$PROJECT_DIR/frontend/bundles-src/App.js" ]; then
    cp -f "$PROJECT_DIR/frontend/bundles-src/App.js" "$PROJECT_DIR/backend/staticfiles/App.min.js"
    echo "Скопирован исходный App.js"
fi

# Определяем команду docker-compose
echo "Настраиваем Docker Compose..."
# Пробуем команду docker-compose
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
# Пробуем команду docker compose (новая версия)
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
# Если docker binary есть, но compose отдельно нет
else
    echo "Устанавливаем docker compose (если его нет)..."
    pip install docker-compose &>/dev/null || sudo apt-get install -y docker-compose &>/dev/null || true
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="docker-compose"
    else
        echo "Ошибка: Docker Compose не установлен и не может быть установлен автоматически"
        exit 1
    fi
fi

echo "Используем команду Docker Compose: $DOCKER_COMPOSE"

# Запуск контейнеров
echo "Запускаем сервисы через Docker Compose..."
$DOCKER_COMPOSE down || echo "Предупреждение: Не удалось остановить контейнеры, возможно они не были запущены"
$DOCKER_COMPOSE up -d --build || { 
    echo "Ошибка: Не удалось запустить контейнеры" 
    echo "Проверяем содержимое docker-compose.yml:"
    cat docker-compose.yml
    exit 1
}

# Ждем, пока контейнеры запустятся
echo "Ожидаем запуска контейнеров..."
sleep 15

# Проверяем, что контейнеры запущены
echo "Проверяем статус контейнеров..."
$DOCKER_COMPOSE ps

# Проверка наличия backend контейнера
if ! docker ps | grep -q "starburger.*backend\|star-burger.*backend"; then
    echo "Ошибка: Контейнер backend не запущен согласно docker ps"
    $DOCKER_COMPOSE logs backend
    exit 1
fi

# Определяем имя контейнера backend
BACKEND_CONTAINER=$(docker ps | grep -o "\w*\s*starburger.*backend\|\w*\s*star-burger.*backend" | awk '{print $1}')
echo "Backend контейнер: $BACKEND_CONTAINER"

# Применяем миграции
echo "Применяем миграции..."
docker exec -i $BACKEND_CONTAINER python manage.py migrate --noinput || { 
    echo "Ошибка при выполнении миграций через docker exec"; 
    echo "Пробуем альтернативный метод..."
    $DOCKER_COMPOSE exec -T backend python manage.py migrate --noinput || {
        echo "Ошибка при выполнении миграций"; 
        $DOCKER_COMPOSE logs backend;
        exit 1;
    }
}

# Устанавливаем права на статические файлы
echo "Устанавливаем права на файлы..."
chmod -R 755 "$PROJECT_DIR/backend/staticfiles/" || echo "Ошибка при установке прав"

# Проверяем наличие файлов
echo "Проверяем наличие файлов..."
ls -la "$PROJECT_DIR/backend/staticfiles/" || echo "Ошибка при просмотре файлов"

# Проверяем работоспособность сервисов
echo "Проверяем работоспособность сервисов..."
if curl -s --head --request GET http://localhost:80 | grep "200\|301\|302" > /dev/null; then 
    echo "Веб-сервер работает успешно."
else
    echo "Внимание: Веб-сервер не отвечает или возвращает ошибку."
    echo "Проверьте логи с помощью команды: $DOCKER_COMPOSE logs nginx"
fi

# Очистка
echo "Очищаем неиспользуемые образы..."
docker image prune -f

echo "Деплой завершен! Сайт доступен по адресу http://starburger.decebell.site"
 