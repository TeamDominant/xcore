#!/usr/bin/env bash

# Указываем директории 
dirXray="/usr/local/etc/xray/"

# Глобальные переменные для хранения значений
previous_stats=""
current_stats=""
client_previous_stats=""
client_current_stats=""

extract_data() {
  local CONFIG_FILE_HAPROXY="/etc/haproxy/haproxy.cfg"
  SUB_JSON_PATH=$(grep -oP 'use_backend http-sub if \{ path /.*? \}' "$CONFIG_FILE_HAPROXY" | grep -oP '(?<=path /).*?(?= \})')
}

# Функция для настройки PostgreSQL
setup_postgres() {
  local dbName="reversedb"

  sudo -u postgres psql -c "CREATE DATABASE $dbName;"
  sudo -u postgres psql -d $dbName <<EOF
CREATE TABLE IF NOT EXISTS clients_stats (
  email TEXT PRIMARY KEY,
  level INTEGER,
  xray_uuid TEXT,
  activity_status TEXT,
  enabled TEXT,
  created TEXT,
  sub_end TEXT,
  sub_duration TEXT,
  ip_limit INTEGER DEFAULT 10,
  ip TEXT,
  uplink BIGINT DEFAULT 0,
  downlink BIGINT DEFAULT 0,
  sess_uplink BIGINT DEFAULT 0,
  sess_downlink BIGINT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS traffic_stats (
  source TEXT PRIMARY KEY,
  sess_uplink BIGINT DEFAULT 0,
  sess_downlink BIGINT DEFAULT 0,
  uplink BIGINT DEFAULT 0,
  downlink BIGINT DEFAULT 0
);
EOF
}

# Функция для извлечения пользователей с основного конфига серверного
extract_users_xray_server() {
  jq -r '.inbounds[] | select(.tag == "vless_raw") | .settings.clients[] | "\(.email) \(.level) \(.id)"' "${dirXray}config.json"
}

# Функция для удаления пользователей из базы данных, которых нет в конфиге Xray
delete_user_from_db() {
  # Подготовка SQL для выполнения запросов
  local queries=""
  
  # Получаем список email из конфига Xray
  mapfile -t users_xray < <(extract_users_xray_server)
  
  # Извлекаем email всех пользователей из базы данных
  mapfile -t users_db < <(sudo -u postgres psql -d reversedb -t -c "SELECT email FROM clients_stats;")
  
  for user in "${users_db[@]}"; do
    # Проверяем, есть ли email пользователя в списке из конфига Xray
    if [[ ! " ${users_xray[*]} " =~ " $user " ]]; then
      # Формируем запрос на удаление
      queries+="DELETE FROM clients_stats WHERE email = '$user'; "
    fi
  done

  # Выполнение всех запросов в одну команду, если они есть
  if [[ -n "$queries" ]]; then
    sudo -u postgres psql -d reversedb -q -c "BEGIN; $queries COMMIT;"
  fi
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

# Добавление пользователей в PostgreSQL без явных транзакций
add_user_to_db() {
  # Подготовка SQL для выполнения запросов
  local queries=""
  # Получаем список email из конфига Xray
  mapfile -t clients < <(extract_users_xray_server)
  # Строка для хранения запросов на добавление

  for client in "${clients[@]}"; do
    IFS=' ' read -r USERNAME LEVEL XRAY_UUID <<< "$client"
    # Получаем дату создания файла
    CREATED_CLIENT=$(get_file_creation_date)
    # Формируем запрос на обновление
    queries+="
    INSERT INTO clients_stats (email, level, xray_uuid, activity_status, enabled, created) 
    VALUES ('$USERNAME', $LEVEL, '$XRAY_UUID', '❌ offline', 'true', '$CREATED_CLIENT') 
    ON CONFLICT (email) DO NOTHING; "
  done

  # Выполнение всех запросов в одну команду, если они есть
  if [[ -n "$queries" ]]; then
    sudo -u postgres psql -d reversedb -q -c "BEGIN; $queries COMMIT;"
  fi
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
  local queries=""
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

  declare -A client_uplink_values client_downlink_values client_sess_uplink_values client_sess_downlink_values

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
      client_sess_uplink_values["$email"]=$client_current
    elif [[ "$client_direction" == "downlink" ]]; then
      client_downlink_values["$email"]=$client_diff
      client_sess_downlink_values["$email"]=$client_current
    fi
  done

  for email in "${!client_uplink_values[@]}"; do
    # Разница между текущими и предыдущими данными
    client_uplink_online=$((client_sess_uplink_values[$email] - client_previous_values["$email uplink"]))
    client_downlink_online=$((client_sess_downlink_values[$email] - client_previous_values["$email downlink"]))

    client_uplink=${client_uplink_values[$email]:-0}
    client_downlink=${client_downlink_values[$email]:-0}
    client_sess_uplink=${client_sess_uplink_values[$email]:-0}
    client_sess_downlink=${client_sess_downlink_values[$email]:-0}

    # Общая разница трафика
    client_diff_online=$((client_uplink_online + client_downlink_online))

    # Расчет статуса активности
    if [ "$client_diff_online" -lt 1 ]; then
      online_status="❌ offline"
    elif [ "$client_diff_online" -lt 25000 ]; then
      online_status="💤 idle"
    elif [ "$client_diff_online" -lt 12000000 ]; then
      online_status="🟢 online"
    else
      online_status="⚡ overload"
    fi

    # Формируем запрос для PostgreSQL
    queries+="
    INSERT INTO clients_stats (email, activity_status, uplink, downlink, sess_uplink, sess_downlink) 
    VALUES ('$email', '$online_status', $client_uplink, $client_downlink, $client_sess_uplink, $client_sess_downlink)
    ON CONFLICT(email) DO UPDATE 
    SET activity_status = '$online_status',
        uplink = clients_stats.uplink + $client_uplink,
        downlink = clients_stats.downlink + $client_downlink,
        sess_uplink = $client_sess_uplink,
        sess_downlink = $client_sess_downlink;
    "
  done

  # Выполнение всех запросов в одну команду, если они есть
  if [[ -n "$queries" ]]; then
    sudo -u postgres psql -d reversedb -q -c "BEGIN; $queries COMMIT;"
  fi

  # Обновляем предыдущие данные
  client_previous_stats="$client_current_stats"
}

update_proxy_stats() {
  # Подготовка SQL для выполнения одной транзакцией
  local queries=""
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

  declare -A uplink_values downlink_values sess_uplink_values sess_downlink_values

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
      sess_uplink_values["$source"]=$current
    elif [[ "$direction" == "downlink" ]]; then
      downlink_values["$source"]=$diff
      sess_downlink_values["$source"]=$current
    fi
  done

  for source in "${!uplink_values[@]}"; do
    uplink=${uplink_values[$source]:-0}
    downlink=${downlink_values[$source]:-0}
    sess_uplink=${sess_uplink_values[$source]:-0}
    sess_downlink=${sess_downlink_values[$source]:-0}

    queries+="INSERT INTO traffic_stats (source, uplink, downlink, sess_uplink, sess_downlink) 
                       VALUES ('$source', $uplink, $downlink, $sess_uplink, $sess_downlink)
                       ON CONFLICT(source) DO UPDATE 
                       SET uplink = traffic_stats.uplink + $uplink,
                           downlink = traffic_stats.downlink + $downlink,
                           sess_uplink = $sess_uplink,
                           sess_downlink = $sess_downlink; "
  done

  # Выполнение транзакции, если есть запросы
  if [[ -n "$queries" ]]; then
    sudo -u postgres psql -d reversedb -q -c "BEGIN; $queries COMMIT;"
  fi

  # Обновляем предыдущие данные
  previous_stats="$current_stats"
}

update_enable_status() {
  # Подготовка SQL для выполнения одной транзакцией
  local queries=""
  local lua_file="/etc/haproxy/.auth.lua"
  declare -A uuid_status

  while IFS= read -r line; do
    if [[ "$line" =~ \[\"([a-f0-9\-]{36})\"\]\ =\ (true|false) ]]; then
      uuid="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      uuid_status["$uuid"]="$value"
    fi
  done < "$lua_file"

  # Создание запросов на обновление для каждого UUID
  for uuid in "${!uuid_status[@]}"; do
    value=${uuid_status[$uuid]}
    queries+="UPDATE clients_stats SET enabled = '$value' WHERE xray_uuid = '$uuid'; "
  done

  # Выполнение транзакции, если есть запросы
  if [[ -n "$queries" ]]; then
    sudo -u postgres psql -d reversedb -q -c "BEGIN; $queries COMMIT;"
  fi
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
  local queries=""

  # Формирование запросов на обновление
  for email in "${!email_ips[@]}"; do
    local new_ips="[\"${email_ips[$email]//,/\"],[\"}\"]"
    queries+="UPDATE clients_stats SET ip = '$new_ips' WHERE email = '$email'; "
  done

  if [[ -n "$queries" ]]; then
    sudo -u postgres psql -d reversedb -q -c "BEGIN; $queries COMMIT;"
  fi
}

ip_limit() {
  # Время жизни IP в секундах (180 секунд)
  IP_LIFETIME=180

  # Ассоциативные массивы: email -> IP и email -> таймштампы
  declare -A email_ips
  declare -A email_ip_timestamps

  # Очистка данных по IP в базе данных
  sudo -u postgres psql -d reversedb -c "UPDATE clients_stats SET ip = '[]';"

  # Чтение логов и парсинг IP
  while IFS= read -r line; do
    parse_log_line "$line"
  done < "${dirXray}access.log"

  # Сохранение IP в базу данных
  save_ips_to_db

  # Очистка файла логов
  > "${dirXray}access.log"
}

display_stats() {
  echo "📊 Статистика клиентов:"
  sudo -u postgres psql -d reversedb --pset footer=off --pset border=2 -c "
SELECT
  email AS \"Email\",
  activity_status AS \"Status\",
  enabled AS \"Enabled\",
  created AS \"Created\",
  ip AS \"Ips\",
  ip_limit AS \"Lim_ip\",
  sess_uplink AS \"Sess Up\",
  sess_downlink AS \"Sess Down\",
  uplink AS \"Upload\",
  downlink AS \"Download\"
FROM clients_stats;
"

  echo
  echo "🌐 Статистика сервера:"
  sudo -u postgres psql -d reversedb --pset footer=off --pset border=2 -c "
SELECT
  source AS \"Source\",
  sess_uplink AS \"Sess Up\",
  sess_downlink AS \"Sess Down\",
  uplink AS \"Upload\",
  downlink AS \"Download\"
FROM traffic_stats;
"

  echo
}

task_10_sec() {
  while true; do
    # Проверка существования базы данных и вызов функции, если база не существует
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='reversedb'" | grep -q 1; then
      setup_postgres
    fi
    clear
    if [[ "$1" == "--stats" ]]; then
      display_stats
    fi
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
  task_10_sec "$1" &
  task_50_sec &
  wait
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
statistics_collection "$1"