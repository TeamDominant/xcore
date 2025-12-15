#!/usr/bin/env bash

LOG_FILE="/var/log/geolite2.log"
DEST_DIR="/etc/nginx/geolite2"

echo "$(date): Starting geo database update" >> $LOG_FILE
mkdir -p "$DEST_DIR" || { echo "$(date): Failed to create $DEST_DIR" >> $LOG_FILE; }

# Получаем URL для скачивания
DOWNLOAD_URLS=$(/usr/bin/curl -s https://api.github.com/repos/P3TERX/GeoLite.mmdb/releases/latest \
| grep "browser_download_url" \
| cut -d '"' -f 4 \
| grep '\.mmdb$')

if [ -z "$DOWNLOAD_URLS" ]; then
    echo "$(date): Error: Failed to fetch download URLs." >> $LOG_FILE
    exit 1
fi

for url in $DOWNLOAD_URLS; do
    fname=$(basename "$url")
    echo "$(date): Downloading $url to $DEST_DIR/$fname" >> $LOG_FILE
    
    # Скачиваем с помощью curl и сохраняем во временный файл
    /usr/bin/curl -sL -o "$DEST_DIR/$fname.tmp" "$url"
    
    if [ $? -eq 0 ]; then
        # Если скачивание успешно, перемещаем
        mv "$DEST_DIR/$fname.tmp" "$DEST_DIR/$fname"
    else
        echo "$(date): Failed to download $url" >> $LOG_FILE
        rm -f "$DEST_DIR/$fname.tmp"
    fi
done

# ПЕРЕЗАГРУЗКА NGINX:
if [ -f /run/nginx.pid ] && kill -0 $(cat /run/nginx.pid 2>/dev/null) 2>/dev/null; then
    nginx -s reload && echo "$(date): Nginx reloaded" >> $LOG_FILE
else
    echo "$(date): Nginx not running yet — normal on first start" >> $LOG_FILE
fi

echo "$(date): GeoLite2 update completed" >> $LOG_FILE
