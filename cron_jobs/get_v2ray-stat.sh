#!/usr/bin/env bash

REPO="Adam-Sizzler/v2ray-stat"
FILE="v2ray-stat-linux-amd64"
DEST_DIR="/usr/local/etc/v2ray-stat"
LOG_FILE="/opt/xcore/cron_jobs.log"
DIR_XCORE="/opt/xcore"

echo "$(date): Starting download of $FILE" >> "$LOG_FILE"
mkdir -p "$DEST_DIR"

# Get download URL from latest release
URL=$(curl -s https://api.github.com/repos/$REPO/releases/latest | grep -o "https.*$FILE" | head -1)

if [ -z "$URL" ]; then
  echo "$(date): Error: File $FILE not found in latest release" >> "$LOG_FILE"
  echo >> "$LOG_FILE"
  exit 1
fi

echo "$(date): Stopping v2ray-stat service..." >> "$LOG_FILE"
systemctl stop v2ray-stat.service || echo "$(date): Warning: Failed to stop v2ray-stat service" >> "$LOG_FILE"

# Download and make executable
echo "$(date): Downloading $FILE to $DEST_DIR..." >> "$LOG_FILE"
curl -L -o "$DEST_DIR/v2ray-stat" "$URL" && chmod +x "$DEST_DIR/v2ray-stat" || { echo "$(date): Error: Failed to download or set executable permissions for $FILE" >> "$LOG_FILE"; exit 1; }

cp "${DIR_XCORE}/repo/services/v2ray-stat.service" "/etc/systemd/system/v2ray-stat.service"
[ ! -f ${DEST_DIR}/.env ] && wget -O ${DEST_DIR}/.env https://raw.githubusercontent.com/Adam-Sizzler/v2ray-stat/refs/heads/main/.env

systemctl daemon-reload
systemctl enable v2ray-stat.service
systemctl restart v2ray-stat.service

echo "$(date): Done! $FILE downloaded to $DEST_DIR and set as executable" >> "$LOG_FILE"
echo >> "$LOG_FILE"
