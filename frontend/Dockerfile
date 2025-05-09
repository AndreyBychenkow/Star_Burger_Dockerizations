FROM node:16-alpine as build

WORKDIR /app

# Копируем файлы package.json и устанавливаем зависимости
COPY package*.json ./
RUN npm install

# Копируем исходники
COPY . .

# Создаем директории если их нет
RUN mkdir -p static
RUN touch static/icon.png

# Собираем приложение
RUN npm run build

# Второй этап - nginx сервер со статикой
FROM nginx:alpine

# Создаем директории
RUN mkdir -p /usr/share/nginx/html/static
RUN mkdir -p /usr/share/nginx/html/media
RUN mkdir -p /usr/share/nginx/html/bundles

# Копируем собранные файлы
COPY --from=build /app/bundles/ /usr/share/nginx/html/bundles/
COPY --from=build /app/index.html /usr/share/nginx/html/index.html
COPY --from=build /app/static/ /usr/share/nginx/html/static/

# Копируем конфигурацию nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

# Запускаем nginx
CMD ["nginx", "-g", "daemon off;"]