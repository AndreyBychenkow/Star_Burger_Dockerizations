FROM node:16-alpine as builder

WORKDIR /opt/StarBurgerDockerizations

# Установка зависимостей
COPY package*.json ./
RUN npm install --no-audit --prefer-offline
RUN npm install regenerator-runtime --save

# Копирование исходного кода
COPY . .

# Сборка для production
RUN ./node_modules/.bin/parcel build bundles-src/index.js --dist-dir bundles --public-url="./"

# Финальный этап - только собранные файлы
FROM nginx:alpine

COPY --from=builder /opt/StarBurgerDockerizations/bundles /usr/share/nginx/html/bundles
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]