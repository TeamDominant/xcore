#!/usr/bin/env bash

LOG_FILE="/opt/xcore/cron_jobs.log"
DEST_DIR="/etc/nginx/geolite2"
echo "$(date): Starting geo database update" >> $LOG_FILE
mkdir -p "$DEST_DIR" || { echo "$(date): Failed to create $DEST_DIR" >> $LOG_FILE; exit 1; }

/usr/bin/curl -s https://api.github.com/repos/P3TERX/GeoLite.mmdb/releases/latest \
| grep "browser_download_url" \
| cut -d '"' -f 4 \
| grep '\.mmdb$' \
| while read -r url; do
  fname=$(basename "$url")
  echo "$(date): Downloading $url to $DEST_DIR/$fname" >> $LOG_FILE
  /usr/bin/wget -qO "$DEST_DIR/$fname" "$url" || { echo "$(date): Failed to download $url" >> $LOG_FILE; exit 1; }
done

/usr/sbin/nginx -s reload || { echo "$(date): Failed to reload nginx" >> $LOG_FILE; exit 1; }

echo "$(date): Completed geo database update" >> $LOG_FILE
echo >> "$LOG_FILE"
