#!/usr/bin/env bash

LOG_FILE="/opt/xcore/cron_jobs.log"
SWAP_USED=$(free -m | grep Swap | awk '{print $3}')

if [ "$SWAP_USED" -gt 300 ]; then
  systemctl restart warp-svc.service
  echo "$(date): warp-svc.service successfully restarted due to high swap usage" >> "$LOG_FILE"
fi
