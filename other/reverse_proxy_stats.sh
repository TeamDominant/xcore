#!/usr/bin/env bash

# Указываем директории 
dirXray="/usr/local/etc/xray/"
dataBasePath="/usr/local/reverse_proxy/reverse_proxy.db"
logFile="/var/log/xrp-ipl.log"

# Глобальные переменные для хранения значений
previous_stats=""
current_stats=""
client_previous_stats=""
client_current_stats=""

extract_data() {
  local CONFIG_FILE_HAPROXY="/etc/haproxy/haproxy.cfg"

  SUB_JSON_PATH=$(grep -oP 'use_backend http-sub if \{ path /.*? \}' "$CONFIG_FILE_HAPROXY" | grep -oP '(?<=path /).*?(?= \})')
  IP4=$(grep -oP 'acl host_ip hdr\(host\) -i \K[\d\.]+' "$CONFIG_FILE_HAPROXY")
  DOMAIN=$(grep -oP 'crt /etc/haproxy/certs/\K[^.]+(?:\.[^.]+)+(?=\.pem)' "$CONFIG_FILE_HAPROXY")
}

# Инициализация базы данных
init_db() {
  sqlite3 "$dataBasePath" <<EOF
    CREATE TABLE IF NOT EXISTS clients_stats (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE,
      level INTEGER,
      xray_uuid TEXT,
      activity_status TEXT,
      enabled TEXT,
      created TEXT,
      sub_end TEXT,
      sub_duration TEXT,
      ip_limit INTEGER DEFAULT 10,
      ip TEXT,
      uplink INTEGER DEFAULT 0,
      downlink INTEGER DEFAULT 0,
      session_uplink INTEGER DEFAULT 0,
      session_downlink INTEGER DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS traffic_stats (
      source TEXT PRIMARY KEY,
      session_uplink INTEGER DEFAULT 0,
      session_downlink INTEGER DEFAULT 0,
      uplink INTEGER DEFAULT 0,
      downlink INTEGER DEFAULT 0
    );
EOF
}

# Функция для извлечения пользователей с основного конфига серверного
extract_users_xray_server() {
  jq -r '.inbounds[] | select(.tag == "vless_raw") | .settings.clients[] | "\(.email) \(.level) \(.id)"' "${dirXray}config.json"
}

# Функция для выполнения транзакции
execute_transaction() {
  local queries="$1"
  sqlite3 "$dataBasePath" <<EOF
BEGIN TRANSACTION;
$queries
COMMIT;
EOF
}

# Функция для удаления пользователей из базы данных, которых нет в конфиге Xray
delete_user_from_db() {
  # Подготовка SQL для выполнения одной транзакцией
  local update_queries=""
  # Получаем список email из конфига Xray
  mapfile -t users_xray < <(extract_users_xray_server)
  # Извлекаем email всех пользователей из базы данных
  mapfile -t users_db < <(sqlite3 "$dataBasePath" "SELECT email FROM clients_stats;")

  for user in "${users_db[@]}"; do
    if [[ ! " ${users_xray[*]} " =~ " $user " ]]; then
      # Формируем запрос на обновление
      update_queries+="DELETE FROM clients_stats WHERE email = '$user'; "
    fi
  done

  # Выполнение транзакции, если есть запросы
  [[ -n "$update_queries" ]] && execute_transaction "$update_queries"
}

# Функция для получения даты создания файла в формате YYYY-MM-DD-HH
get_file_creation_date() {
  local USER_FILE_PATH="/var/www/${SUB_JSON_PATH}/vless_raw/${USERNAME}.json"
  
  # Получаем дату создания файла в секундах с эпохи UNIX
  file_creation_time=$(stat --format=%W "$USER_FILE_PATH" 2>/dev/null)

  # Если дата создания доступна (больше 0), преобразуем в формат YYYY-MM-DD-HH
  if [[ "$file_creation_time" -gt 0 ]]; then
    date -d @$file_creation_time "+%Y-%m-%d-%H"
  else
    echo "неизвестно"
  fi
}

# Добавление пользователей в базу данных
add_user_to_db() {
  # Подготовка SQL для выполнения одной транзакцией
  local update_queries=""
  # Получаем список email из конфига Xray
  mapfile -t clients < <(extract_users_xray_server)
  # Строка для хранения запросов на добавление

  for client in "${clients[@]}"; do
    IFS=' ' read -r USERNAME LEVEL XRAY_UUID <<< "$client"
    # Получаем дату создания файла
    CREATED_CLIENT=$(get_file_creation_date)
    # Формируем запрос на обновление
    update_queries+="INSERT OR IGNORE INTO clients_stats (email, level, xray_uuid, activity_status, enabled, created) 
    VALUES ('$USERNAME', $LEVEL, '$XRAY_UUID', '❌ offline', 'true', '$CREATED_CLIENT'); "
  done

  # Выполнение транзакции, если есть запросы
  [[ -n "$update_queries" ]] && execute_transaction "$update_queries"
}

# Функция для извлечения данных из API
api_response() {
  api_data=$(${dirXray}xray api statsquery)
}

# Функция для извлечения данных из API
extract_user_traffic() {
  echo "$api_data" | jq -r '
    .stat[] |
    select(.name | contains("user")) |
    "\(.name | split(">>>") | del(.[0, 2]) | join(" ")) \(.value // 0)"'
}

# Функция для извлечения данных из API
extract_proxy_traffic() {
  echo "$api_data" | jq -r '
    .stat[] | 
    select(.name | (contains ("user") or contains("api") or contains("blocked")) | not) |
    "\(.name | split(">>>") | del(.[0, 2]) | join(" ")) \(.value // 0)"'
}

update_client_stats() {
  # Подготовка SQL для выполнения одной транзакцией
  local update_queries=""
  # Извлекаем текущие данные
  client_current_stats=$(extract_user_traffic)

  # Если client_previous_stats пустая, это означает, что это первый запуск, пропускаем вычисление разницы
  if [ -z "$client_previous_stats" ]; then
    client_previous_stats="$client_current_stats"
    return
  fi

  # Преобразуем в массив
  declare -A client_current_values client_previous_values

  # Заполняем текущие данные
  while read -r first second value; do
    email="$first $second"
    client_current_values["$email"]=$value
  done <<< "$client_current_stats"

  # Заполняем предыдущие данные
  while read -r first second value; do
    email="$first $second"
    client_previous_values["$email"]=$value
  done <<< "$client_previous_stats"

  declare -A client_uplink_values client_downlink_values client_session_uplink_values client_session_downlink_values

  for key in "${!client_current_values[@]}"; do
    client_current=${client_current_values[$key]}
    client_previous=${client_previous_values[$key]:-0}

    if [ "$client_current" -gt "$client_previous" ]; then
      client_diff=$((client_current - client_previous))
    else
      client_diff=0
    fi

    email=$(echo "$key" | awk '{print $1}')
    client_direction=$(echo "$key" | awk '{print $2}')

    if [[ "$client_direction" == "uplink" ]]; then
      client_uplink_values["$email"]=$client_diff
      client_session_uplink_values["$email"]=$client_current
    elif [[ "$client_direction" == "downlink" ]]; then
      client_downlink_values["$email"]=$client_diff
      client_session_downlink_values["$email"]=$client_current
    fi
  done

  for email in "${!client_uplink_values[@]}"; do
    client_uplink=${client_uplink_values[$email]:-0}
    client_downlink=${client_downlink_values[$email]:-0}
    client_session_uplink=${client_session_uplink_values[$email]:-0}
    client_session_downlink=${client_session_downlink_values[$email]:-0}

    # Расчет статуса активности
    if [ "$client_diff" -lt 100 ]; then
      online_status="❌ offline"
    elif [ "$client_diff" -lt 25000 ]; then
      online_status="💤 idle"
    elif [ "$client_diff" -lt 12000000 ]; then
      online_status="🟢 online"
    else
      online_status="🔥 high activity"
    fi

    update_queries+="INSERT OR REPLACE INTO clients_stats (email, activity_status, uplink, downlink, session_uplink, session_downlink) 
                             VALUES ('$email', '$online_status', $client_uplink, $client_downlink, $client_session_uplink, $client_session_downlink)
                             ON CONFLICT(email) DO UPDATE 
                             SET activity_status = '$online_status',
                                 uplink = uplink + $client_uplink,
                                 downlink = downlink + $client_downlink,
                                 session_uplink = $client_session_uplink,
                                 session_downlink = $client_session_downlink; "
  done
  # Выполнение транзакции, если есть запросы
  [[ -n "$update_queries" ]] && execute_transaction "$update_queries"
  # Обновляем предыдущие данные
  client_previous_stats="$client_current_stats"
}

update_proxy_stats() {
  # Подготовка SQL для выполнения одной транзакцией
  local update_queries=""
  # Извлекаем текущие данные
  current_stats=$(extract_proxy_traffic)

  # Если previous_stats пустая, это означает, что это первый запуск, пропускаем вычисление разницы
  if [ -z "$previous_stats" ]; then
    previous_stats="$current_stats"
    return
  fi

  # Преобразуем в массив
  declare -A current_values previous_values

  # Заполняем текущие данные
  while read -r first second value; do
    source="$first $second"
    current_values["$source"]=$value
  done <<< "$current_stats"

  # Заполняем предыдущие данные
  while read -r first second value; do
    source="$first $second"
    previous_values["$source"]=$value
  done <<< "$previous_stats"

  declare -A uplink_values downlink_values session_uplink_values session_downlink_values

  for key in "${!current_values[@]}"; do
    current=${current_values[$key]}
    previous=${previous_values[$key]:-0}

    if [ "$current" -gt "$previous" ]; then
      diff=$((current - previous))
    else
      diff=0
    fi

    source=$(echo "$key" | awk '{print $1}')
    direction=$(echo "$key" | awk '{print $2}')

    if [[ "$direction" == "uplink" ]]; then
      uplink_values["$source"]=$diff
      session_uplink_values["$source"]=$current
    elif [[ "$direction" == "downlink" ]]; then
      downlink_values["$source"]=$diff
      session_downlink_values["$source"]=$current
    fi
  done

  for source in "${!uplink_values[@]}"; do
    uplink=${uplink_values[$source]:-0}
    downlink=${downlink_values[$source]:-0}
    session_uplink=${session_uplink_values[$source]:-0}
    session_downlink=${session_downlink_values[$source]:-0}

    update_queries+="INSERT OR REPLACE INTO traffic_stats (source, uplink, downlink, session_uplink, session_downlink) 
                       VALUES ('$source', $uplink, $downlink, $session_uplink, $session_downlink)
                       ON CONFLICT(source) DO UPDATE 
                       SET uplink = uplink + $uplink,
                           downlink = downlink + $downlink,
                           session_uplink = $session_uplink,
                           session_downlink = $session_downlink; "
  done
  # Выполнение транзакции, если есть запросы
  [[ -n "$update_queries" ]] && execute_transaction "$update_queries"
  # Обновляем предыдущие данные
  previous_stats="$current_stats"
}

update_enable_status() {
  # Подготовка SQL для выполнения одной транзакцией
  local update_queries=""
  local lua_file="/etc/haproxy/.auth.lua"
  declare -A uuid_status

  while IFS= read -r line; do
    if [[ "$line" =~ \[\"([a-f0-9\-]{36})\"\]\ =\ (true|false) ]]; then
      uuid="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      uuid_status["$uuid"]="$value"
    fi
  done < "$lua_file"

  # Обновление enabled для соответствующих UUID в базе данных
  for uuid in "${!uuid_status[@]}"; do
    value=${uuid_status[$uuid]}

    # Обновление поля enabled в базе данных
    update_queries+="UPDATE clients_stats SET enabled = '$value' WHERE xray_uuid = '$uuid'; "
  done

  # Выполнение транзакции, если есть запросы
  [[ -n "$update_queries" ]] && execute_transaction "$update_queries"
}

# Функция добавления IP с таймштампом
add_ip_to_array() {
  local email="$1"
  local ip="$2"
  local current_time=$(date +%s)

  # Если IP уже есть — обновляем его таймштамп
  if [[ -z "${email_ips[$email]}" ]]; then
    email_ips["$email"]="$ip"
    email_ip_timestamps["$email"]="$current_time"
  else
    IFS=',' read -ra existing_ips <<< "${email_ips[$email]}"
    IFS=',' read -ra existing_times <<< "${email_ip_timestamps[$email]}"

    local ip_found=0
    for i in "${!existing_ips[@]}"; do
      if [[ "${existing_ips[$i]}" == "$ip" ]]; then
        existing_times[$i]="$current_time"
        ip_found=1
        break
      fi
    done

    # Добавляем новый IP, если его нет в массиве
    if [[ $ip_found -eq 0 ]]; then
      existing_ips+=("$ip")
      existing_times+=("$current_time")
    fi

    # Обновляем массивы
    email_ips["$email"]=$(IFS=,; echo "${existing_ips[*]}")
    email_ip_timestamps["$email"]=$(IFS=,; echo "${existing_times[*]}")
  fi
}

# Функция очистки устаревших IP
remove_expired_ips() {
  local current_time=$(date +%s)

  for email in "${!email_ips[@]}"; do
    IFS=',' read -ra ips <<< "${email_ips[$email]}"
    IFS=',' read -ra timestamps <<< "${email_ip_timestamps[$email]}"

    local new_ips=()
    local new_times=()

    for i in "${!ips[@]}"; do
      local ip="${ips[$i]}"
      local timestamp="${timestamps[$i]}"
      local age=$((current_time - timestamp))

      if (( age <= IP_LIFETIME )); then
        new_ips+=("$ip")
        new_times+=("$timestamp")
      fi
    done

    email_ips["$email"]=$(IFS=,; echo "${new_ips[*]}")
    email_ip_timestamps["$email"]=$(IFS=,; echo "${new_times[*]}")
  done
}

# Функция для парсинга логов
parse_log_line() {
  local line="$1"
  if [[ "$line" =~ from\ tcp:([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+):[0-9]+\ accepted\ .*email:\ ([a-zA-Z0-9_]+) ]]; then
    add_ip_to_array "${BASH_REMATCH[2]}" "${BASH_REMATCH[1]}"
  fi
}

# Функция сохранения IP в базу данных
save_ips_to_db() {
  local update_queries=""

  for email in "${!email_ips[@]}"; do
    local new_ips="[\"${email_ips[$email]//,/\"],[\"}\"]"
    update_queries+="UPDATE clients_stats SET ip = '$new_ips' WHERE email = '$email'; "
  done

  [[ -n "$update_queries" ]] && execute_transaction "$update_queries"
}

ip_limit() {
  # Время жизни IP в секундах (180 секунд)
  IP_LIFETIME=180

  # Ассоциативные массивы: email -> IP и email -> таймштампы
  declare -A email_ips
  declare -A email_ip_timestamps

  sqlite3 "$dataBasePath" "UPDATE clients_stats SET ip = '[]';"
  
  while IFS= read -r line; do
    parse_log_line "$line"
  done < "${dirXray}access.log"

  save_ips_to_db
  > "${dirXray}access.log"
}

display_stats() {
  echo "  📊 Статистика клиентов:"
  sqlite3 "$dataBasePath" <<EOF
.headers on
.mode table
SELECT
  email AS "Email",
  activity_status AS "Status",
  enabled AS "Enabled",
  created AS "Created",
  ip AS "Ips",
  ip_limit AS "Lim_ip",
  printf("%.2f MB", session_uplink / 1024.0 / 1024.0) AS "S Upload",
  printf("%.2f MB", session_downlink / 1024.0 / 1024.0) AS "S Download",
  printf("%.2f MB", uplink / 1024.0 / 1024.0) AS "Upload",
  printf("%.2f MB", downlink / 1024.0 / 1024.0) AS "Download"
FROM clients_stats;
EOF

  echo
  echo "  🌐 Статистика сервера:"
  sqlite3 "$dataBasePath" <<EOF
.headers on
.mode table
SELECT
  source AS "Source",
  printf("%.2f MB", session_uplink / 1024.0 / 1024.0) AS "S Upload",
  printf("%.2f MB", session_downlink / 1024.0 / 1024.0) AS "S Download",
  printf("%.2f MB", uplink / 1024.0 / 1024.0) AS "Upload",
  printf("%.2f MB", downlink / 1024.0 / 1024.0) AS "Download"
FROM traffic_stats;
EOF
  echo
}

task_10_sec() {
  while true; do
    clear
    display_stats
    api_response
    update_client_stats
    update_proxy_stats
    sleep 10
  done
}

task_50_sec() {
  while true; do
    delete_user_from_db
    add_user_to_db
    update_enable_status
    ip_limit
    sleep 50
  done
}

statistics_collection() {
  extract_data
  if [ ! -f "$dataBasePath" ]; then
    init_db
  fi
  task_10_sec &  # Запуск задачи каждые 10 секунд
  task_50_sec &  # Запуск задачи каждые 60 секунд
}

cleanup() {
  echo "Завершаю фоновые процессы..."
  for job in $(jobs -p); do
    # Проверяем, существует ли процесс перед тем, как его убить
    if kill -0 "$job" 2>/dev/null; then
      kill "$job" || echo "Не удалось завершить процесс с ID $job"
    else
      echo "Процесс с ID $job уже завершен."
    fi
  done
}

trap cleanup SIGINT SIGTERM
statistics_collection
wait