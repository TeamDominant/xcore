#!/usr/bin/env bash

REPO="cortez24rus/v2ray-stat"
FILE="v2ray-stat_linux_amd64"
DEST_DIR="/usr/local/v2ray-stat"
LOG_FILE="/opt/xcore/cron_jobs.log"

echo "$(date): Starting download of $FILE" >> "$LOG_FILE"
mkdir -p "$DEST_DIR"

# Get download URL from latest release
URL=$(curl -s https://api.github.com/repos/$REPO/releases/latest | grep -o "https.*$FILE" | head -1)

if [ -z "$URL" ]; then
  echo "$(date): Error: File $FILE not found in latest release" >> "$LOG_FILE"
  exit 1
fi

# Download and make executable
echo "$(date): Downloading $FILE to $DEST_DIR..." >> "$LOG_FILE"
curl -L -o "$DEST_DIR/$FILE" "$URL" && chmod +x "$DEST_DIR/$FILE" || { echo "$(date): Error: Failed to download or set executable permissions for $FILE" >> "$LOG_FILE"; exit 1; }

echo "$(date): Done! $FILE downloaded to $DEST_DIR and set as executable" >> "$LOG_FILE"
echo >> "$LOG_FILE"