#!/bin/bash

# Скрипт для запуска на сервере
# Исправляет конфликт локальных изменений и обновлений Git

# Сохраняем локальные изменения
cp deploy_star_burger.sh deploy_star_burger.sh.backup

# Принудительно применяем изменения из Git
git reset --hard HEAD
git pull

# Запускаем обновленный скрипт деплоя
bash deploy_star_burger.sh 