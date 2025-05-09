# Сайт доставки еды Star Burger

Это сайт сети ресторанов Star Burger. Здесь можно заказать превосходные бургеры с доставкой на дом.

![скриншот сайта](https://dvmn.org/filer/canonical/1594651635/686/)

Сеть Star Burger объединяет несколько ресторанов, действующих под единой франшизой. У всех ресторанов одинаковое меню и одинаковые цены. Просто выберите блюдо из меню на сайте и укажите место доставки. Мы сами найдём ближайший к вам ресторан, всё приготовим и привезём.

На сайте есть три независимых интерфейса. Первый — это публичная часть, где можно выбрать блюда из меню, и быстро оформить заказ без регистрации и SMS.

Второй интерфейс предназначен для менеджера. Здесь происходит обработка заказов. Менеджер видит поступившие новые заказы и первым делом созванивается с клиентом, чтобы подтвердить заказ. После оператор выбирает ближайший ресторан и передаёт туда заказ на исполнение. Там всё приготовят и сами доставят еду клиенту.

Третий интерфейс — это админка. Преимущественно им пользуются программисты при разработке сайта. Также сюда заходит менеджер, чтобы обновить меню ресторанов Star Burger.



### Предварительные требования
- Docker (версия 20.10+)
- Docker Compose (версия 2.0+)
- Git

### Локальная разработка

#### 1. Клонируйте репозиторий
```bash
git clone https://github.com/AndreyBychenkow/Star_Burger_Dockerizations.git
cd Star_Burger_Dockerizations
```

#### 2. Создайте файл .env
```bash
cp .env.example .env
```

Отредактируйте `.env` файл, указав следующие параметры:
```
SECRET_KEY=your_secret_key
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1
YANDEX_GEOCODER_API_KEY=your_api_key
```

#### 3. Запустите контейнеры
```bash
docker-compose up -d
```

После запуска, сайт будет доступен по адресу [http://localhost](http://localhost), а административная панель по адресу [http://localhost/admin](http://localhost/admin).

#### 4. Остановка контейнеров
```bash
docker-compose down
```

#### 5. Просмотр логов
```bash
# Логи всех контейнеров
docker-compose logs

# Логи конкретного контейнера
docker-compose logs backend
docker-compose logs frontend
```

### Запуск на боевом сервере (продакшн)

#### 1. Подготовка сервера
Установите Docker и Docker Compose:
```bash
apt-get update
apt-get install -y docker.io docker-compose
```

#### 2. Клонируйте репозиторий
```bash
git clone https://github.com/AndreyBychenkow/Star_Burger_Dockerizations.git
cd /opt/StarBurgerDockerizations
```

#### 3. Настройка переменных окружения
Создайте `.env` файл с боевыми настройками:
```bash
SECRET_KEY=your_secure_production_key
DEBUG=False
ALLOWED_HOSTS=your-domain.com,www.your-domain.com
YANDEX_GEOCODER_API_KEY=your_api_key
TOKEN_ROLLBAR_PROD=your_token_rollbar
DATABASE_URL=postgres://starburger_user:0704@localhost:5432/starburger_dev
ROLLBAR_ENVIRONMENT=production
DB_PASSWORD=your password
DB_USER=your_db_user
DB_NAME=name_your_db
```

**Проект доступен по ссылке:** [Демо-версия](http://starburger.decebell.site)

#### 4. Настройка HTTPS с Certbot

Установите Certbot:
```bash
apt-get install -y certbot python3-certbot-nginx
```

Внесите изменения в docker-compose.yml:
```bash
# Изменить порт с 80:80 на 8081:80 для frontend
nano docker-compose.yml
```

Получите SSL-сертификат:
```bash
certbot --nginx -d your-domain.com
```

Создайте конфигурацию Nginx:
```bash
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Активируйте конфигурацию:
```bash
ln -sf /etc/nginx/sites-available/starburger.conf /etc/nginx/sites-enabled/
systemctl restart nginx
```

Настройте автоматическое обновление сертификатов:
```bash
echo "0 0 * * * certbot renew --quiet && systemctl reload nginx" | crontab -
```

#### 5. Запуск контейнеров
```bash
# Дайте права на запуск скрипта деплоя
chmod +x deploy_star_burger.sh

# Запустите скрипт деплоя
./deploy_star_burger.sh
```

#### 6. Обновление до последней версии
```bash
cd /opt/StarBurgerDockerizations
./deploy_star_burger.sh
```

## Цели проекта

Код написан в учебных целях — это урок в курсе по Python и веб-разработке на сайте [Devman](https://dvmn.org). За основу был взят код проекта [FoodCart](https://github.com/Saibharath79/FoodCart).

Где используется репозиторий:

- Второй и третий урок [учебного курса Django](https://dvmn.org/modules/django/)
