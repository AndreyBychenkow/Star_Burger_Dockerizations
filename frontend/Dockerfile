FROM node:18-alpine

WORKDIR /app

# Установка настроек npm для повышения стабильности сети
RUN npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000 && \
    npm config set fetch-timeout 300000 && \
    npm config set fetch-retries 5

# Копирование и установка зависимостей
COPY package*.json ./
RUN npm install --verbose

# Копирование исходного кода
COPY . .

# Сборка проекта
RUN npm run build:simple

EXPOSE 1234

CMD ["npm", "start"]