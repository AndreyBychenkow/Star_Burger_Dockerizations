FROM node:18-alpine as builder

WORKDIR /app

# Установка настроек npm для повышения стабильности сети
RUN npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000 && \
    npm config set fetch-timeout 300000 && \
    npm config set fetch-retries 5

# Копирование и установка зависимостей
COPY package*.json ./
RUN npm ci --verbose

# Копирование исходного кода
COPY . .

# Сборка для production напрямую через parcel 
RUN ./node_modules/.bin/parcel build bundles-src/index.js --dist-dir bundles --public-url="./"

# Финальный этап - только собранные файлы
FROM nginx:alpine

COPY --from=builder /app/bundles /usr/share/nginx/html/bundles

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]