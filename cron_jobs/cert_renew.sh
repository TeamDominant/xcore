#!/usr/bin/env bash

CONFIG_FILE_HAPROXY="/etc/haproxy/haproxy.cfg"
CURR_DOMAIN=$(grep -oP 'crt /etc/haproxy/certs/\K[^.]+(?:\.[^.]+)+(?=\.pem)' "$CONFIG_FILE_HAPROXY")

LOG_FILE="/opt/xcore/cron_jobs.log"
CERT_DIR="/etc/letsencrypt/live/${CURR_DOMAIN}"
HAPROXY_CERT_DIR="/etc/haproxy/certs"
HAPROXY_CERT="$HAPROXY_CERT_DIR/${CURR_DOMAIN}.pem"

echo "$(date): Starting certificate renewal" >> "$LOG_FILE"

/usr/bin/certbot renew >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
  echo "$(date): certbot renew completed successfully" >> "$LOG_FILE"
else
  echo "$(date): Error: certbot renew failed" >> "$LOG_FILE"
  exit 1
fi

if cat "$CERT_DIR/fullchain.pem" "$CERT_DIR/privkey.pem" > "$HAPROXY_CERT" 2>> "$LOG_FILE"; then
  echo "$(date): Successfully created $HAPROXY_CERT" >> "$LOG_FILE"
else
  echo "$(date): Error: Failed to create $HAPROXY_CERT" >> "$LOG_FILE"
  exit 1
fi

if /usr/bin/systemctl restart haproxy >> "$LOG_FILE" 2>&1; then
  echo "$(date): haproxy service successfully restarted" >> "$LOG_FILE"
else
  echo "$(date): Error: Failed to restart haproxy service" >> "$LOG_FILE"
  exit 1
fi

echo "$(date): Completed certificate renewal" >> "$LOG_FILE"
echo >> "$LOG_FILE"
