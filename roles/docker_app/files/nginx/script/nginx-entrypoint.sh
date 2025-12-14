#!/bin/sh
set -e

# Проверяем, что CMD - это Nginx (как в официальном образе)
if [ "$1" = "nginx" ]; then
    echo "Starting cron daemon..."
    # Запускаем cron в фоне
    cron -L 15
    
    echo "Starting Nginx..."
    # Запускаем Nginx (используем exec, чтобы Nginx заменил этот скрипт как основной процесс)
    exec "$@"
else
    # Если команда не Nginx (например, bash), просто выполняем ее
    exec "$@"
fi
