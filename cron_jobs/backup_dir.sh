#!/bin/bash

LOG_FILE="/opt/xcore/cron_jobs.log"
BACKUP_DIR="/opt/xcore/backup"
CURRENT_DATE=$(date +"%y-%m-%d")
ARCHIVE_NAME="${BACKUP_DIR}/backup_${CURRENT_DATE}.7z"

echo "$(date): Starting backup creation" >> "$LOG_FILE"

# Создаем директорию для резервных копий, если её нет
mkdir -p "$BACKUP_DIR" || { echo "$(date): Failed to create $BACKUP_DIR" >> "$LOG_FILE"; exit 1; }

# Ищем в /var/www директорию с именем длиной 30 символов
DYN_DIR=$(find /var/www -maxdepth 1 -type d -name '??????????????????????????????' -exec basename {} \;)
if [ -z "$DYN_DIR" ]; then
  echo "$(date): No directory with 30 characters found in /var/www" >> "$LOG_FILE"
  exit 1
fi

# Проверяем, существуют ли все директории для архивации
DIRECTORIES=("/etc/nginx" "/etc/haproxy" "/etc/letsencrypt" "/usr/local/etc/v2ray-stat" "/usr/local/etc/xray" "/var/www/$DYN_DIR")
for dir in "${DIRECTORIES[@]}"; do
  if [ ! -d "$dir" ]; then
    echo "$(date): Directory $dir does not exist" >> "$LOG_FILE"
    exit 1
  fi
done

# Архивируем все директории в один архив
echo "$(date): Creating archive $ARCHIVE_NAME" >> "$LOG_FILE"
if /usr/bin/7za a -mx9 "$ARCHIVE_NAME" "${DIRECTORIES[@]}" >> "$LOG_FILE" 2>&1; then
  echo "$(date): Completed backup creation: $ARCHIVE_NAME" >> "$LOG_FILE"
else
  echo "$(date): Failed to create archive $ARCHIVE_NAME" >> "$LOG_FILE"
  exit 1
fi
echo >> "$LOG_FILE"
