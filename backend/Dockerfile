FROM python:3.10-slim

WORKDIR /opt/StarBurgerDockerizations

# Установка зависимостей для снижения размера образа
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Копирование и установка зависимостей
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копирование проекта
COPY . .

# Создание необходимых директорий
RUN mkdir -p /opt/StarBurgerDockerizations/staticfiles \
    /opt/StarBurgerDockerizations/media \
    /opt/StarBurgerDockerizations/bundles

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

EXPOSE 8000

CMD ["python", "-m", "gunicorn", "star_burger.wsgi:application", "--bind", "0.0.0.0:8000"] 