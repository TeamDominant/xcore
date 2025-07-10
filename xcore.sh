#!/usr/bin/env bash

# Copyright (c) 2025 xCore Authors
# This file is part of xCore.
# xCore is licensed under the xCore Software License. See the LICENSE file for details.

###################################
### GLOBAL CONSTANTS AND VARIABLES
###################################
VERSION_MANAGER='1.0.0'
VERSION_XRAY='v25.6.8'

DIR_XCORE="/opt/xcore"
DIR_XRAY="/usr/local/etc/xray"
DIR_HAPROXY="/etc/haproxy"

REPO_URL="https://github.com/cortez24rus/XCore/archive/refs/heads/main.tar.gz"

###################################
### INITIALIZATION AND DECLARATIONS
###################################
declare -A defaults
declare -A args
declare -A regex
declare -A generate

###################################
### REGEX PATTERNS FOR VALIDATION
###################################
regex[domain]="^([a-zA-Z0-9-]+)\.([a-zA-Z0-9-]+\.[a-zA-Z]{2,})$"
regex[port]="^[1-9][0-9]*$"
regex[username]="^[a-zA-Z0-9]+$"
regex[ipv4]="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
regex[tgbot_token]="^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$"
regex[tgbot_admins]="^[a-zA-Z][a-zA-Z0-9_]{4,31}(,[a-zA-Z][a-zA-Z0-9_]{4,31})*$"
regex[domain_port]="^[a-zA-Z0-9]+([-.][a-zA-Z0-9]+)*\.[a-zA-Z]{2,}(:[1-9][0-9]*)?$"
regex[file_path]="^[a-zA-Z0-9_/.-]+$"
regex[url]="^(http|https)://([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})(:[0-9]{1,5})?(/.*)?$"
generate[path]="tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30"

###################################
### OUTPUT FORMATTING FUNCTIONS
###################################
out_data()   { echo -e "\e[1;33m$1\033[0m \033[1;37m$2\033[0m"; }
tilda()      { echo -e "\033[31m\033[38;5;214m$*\033[0m"; }
warning()    { echo -e "\033[31m [!]\033[38;5;214m$*\033[0m"; }
error()      { echo -e "\033[31m\033[01m$*\033[0m"; exit 1; }
info()       { echo -e "\033[32m\033[01m$*\033[0m"; }
question()   { echo -e "\033[32m[?]\e[1;33m$*\033[0m"; }
hint()       { echo -e "\033[33m\033[01m$*\033[0m"; }
reading()    { read -rp " $(question "$1")" "$2"; }
text()       { eval echo "\${${LANGUAGE}[$*]}"; }
text_eval()  { eval echo "\$(eval echo "\${${LANGUAGE}[$*]}")"; }


###################################
### LANGUAGE STRINGS
###################################
EU[0]="Language:\n  1. English (default) \n  2. Русский"
RU[0]="Язык:\n  1. English (по умолчанию) \n  2. Русский"
EU[1]="Choose an action:"
RU[1]="Выбери действие:"
EU[2]="Error: this script requires superuser (root) privileges to run."
RU[2]="Ошибка: для выполнения этого скрипта необходимы права суперпользователя (root)."
EU[3]="Unable to determine IP address."
RU[3]="Не удалось определить IP-адрес."
EU[4]="Reinstalling script..."
RU[4]="Повторная установка скрипта..."
EU[5]="WARNING!"
RU[5]="ВНИМАНИЕ!"
EU[6]="It is recommended to perform the following actions before running the script"
RU[6]="Перед запуском скрипта рекомендуется выполнить следующие действия"
EU[7]="Annihilation of the system!"
RU[7]="Аннигиляция системы!"

EU[9]="CANCEL"
RU[9]="ОТМЕНА"
EU[10]="\n|--------------------------------------------------------------------------|\n"
RU[10]="\n|--------------------------------------------------------------------------|\n"
EU[11]="Enter username:"
RU[11]="Введите имя пользователя:"
EU[12]="Enter user password:"
RU[12]="Введите пароль пользователя:"
EU[13]="Enter your domain A record:"
RU[13]="Введите доменную запись типа A:"
EU[14]="Error: the entered address '$temp_value' is incorrectly formatted."
RU[14]="Ошибка: введённый адрес '$temp_value' имеет неверный формат."
EU[15]="Enter your email registered with Cloudflare:"
RU[15]="Введите вашу почту, зарегистрированную на Cloudflare:"
EU[16]="Enter your Cloudflare API token (Edit zone DNS) or global API key:"
RU[16]="Введите ваш API токен Cloudflare (Edit zone DNS) или Cloudflare global API key:"
EU[17]="Verifying domain, API token/key, and email..."
RU[17]="Проверка домена, API токена/ключа и почты..."
EU[18]="Error: invalid domain, API token/key, or email. Please try again."
RU[18]="Ошибка: неправильно введён домен, API токен/ключ или почта. Попробуйте снова."

EU[20]="Error: failed to connect to WARP. Manual acceptance of the terms of service is required."
RU[20]="Ошибка: не удалось подключиться к WARP. Требуется вручную согласиться с условиями использования."
EU[21]="Access link to node exporter:"
RU[21]="Доступ по ссылке к node exporter:"
EU[22]="Access link to shell in a box:"
RU[22]="Доступ по ссылке к shell in a box:"
EU[23]="Creating a backup and rotation."
RU[23]="Создание резевной копии и ротация."
EU[24]="Enter Node Exporter path:"
RU[24]="Введите путь к Node Exporter:"

EU[27]="Enter subscription path:"
RU[27]="Введите путь к подписке:"

EU[29]="Error: path cannot be empty, please re-enter."
RU[29]="Ошибка: путь не может быть пустым, повторите ввод."
EU[30]="Error: path must not contain characters {, }, /, $, \\, please re-enter."
RU[30]="Ошибка: путь не должен содержать символы {, }, /, $, \\, повторите ввод."

EU[33]="Error: invalid choice, please try again."
RU[33]="Ошибка: неверный выбор, попробуйте снова."

EU[36]="Updating system and installing necessary packages."
RU[36]="Обновление системы и установка необходимых пакетов."
EU[37]="Configuring Haproxy."
RU[37]="Настройка Haproxy."
EU[38]="Download failed, retrying..."
RU[38]="Скачивание не удалось, пробуем снова..."
EU[39]="Adding user."
RU[39]="Добавление пользователя."
EU[40]="Enabling automatic security updates."
RU[40]="Автоматическое обновление безопасности."
EU[41]="Enabling BBR."
RU[41]="Включение BBR."
EU[42]="Disabling IPv6."
RU[42]="Отключение IPv6."
EU[43]="Configuring WARP."
RU[43]="Настройка WARP."
EU[44]="Issuing certificates."
RU[44]="Выдача сертификатов."
EU[45]="Configuring NGINX."
RU[45]="Настройка NGINX."
EU[46]="Setting Xray."
RU[46]="Настройка Xray."
EU[47]="Configuring UFW."
RU[47]="Настройка UFW."
EU[48]="Configuring SSH."
RU[48]="Настройка SSH."
EU[49]="Generate a key for your OS (ssh-keygen)."
RU[49]="Сгенерируйте ключ для своей ОС (ssh-keygen)."
EU[50]="In Windows, install the openSSH package and enter the command in PowerShell (recommended to research key generation online)."
RU[50]="В Windows нужно установить пакет openSSH и ввести команду в PowerShell (рекомендуется изучить генерацию ключей в интернете)."
EU[51]="If you are on Linux, you probably know what to do C:"
RU[51]="Если у вас Linux, то вы сами все умеете C:"
EU[52]="Command for Windows:"
RU[52]="Команда для Windows:"
EU[53]="Command for Linux:"
RU[53]="Команда для Linux:"
EU[54]="Configure SSH (optional step)? [y/N]:"
RU[54]="Настроить SSH (необязательный шаг)? [y/N]:"
EU[55]="Error: Keys not found. Please add them to the server before retrying..."
RU[55]="Ошибка: ключи не найдены, добавьте его на сервер, прежде чем повторить..."
EU[56]="Key found, proceeding with SSH setup."
RU[56]="Ключ найден, настройка SSH."
EU[57]="Client-side configuration."
RU[57]="Настройка клиентской части."
EU[58]="SAVE THIS SCREEN!"
RU[58]="СОХРАНИ ЭТОТ ЭКРАН!"
EU[59]="Subscription page link:"
RU[59]="Ссылка на страницу подписки:"

EU[62]="SSH connection:"
RU[62]="Подключение по SSH:"
EU[63]="Username:"
RU[63]="Имя пользователя:"
EU[64]="Password:"
RU[64]="Пароль:"
EU[65]="Log file path:"
RU[65]="Путь к лог файлу:"
EU[66]="Prometheus monitor."
RU[66]="Мониторинг Prometheus."

EU[70]="Secret key:"
RU[70]="Секретный ключ:"
EU[71]="Current operating system is \$SYS.\\\n The system lower than \$SYSTEM \${MAJOR[int]} is not supported. Feedback: [https://github.com/cortez24rus/xcore/issues]"
RU[71]="Текущая операционная система: \$SYS.\\\n Система с версией ниже, чем \$SYSTEM \${MAJOR[int]}, не поддерживается. Обратная связь: [https://github.com/cortez24rus/xcore/issues]"
EU[72]="Install dependence-list:"
RU[72]="Список зависимостей для установки:"
EU[73]="All dependencies already exist and do not need to be installed additionally."
RU[73]="Все зависимости уже установлены и не требуют дополнительной установки."
EU[74]="OS - $SYS"
RU[74]="OS - $SYS"
EU[75]="Invalid option for --$key: $value. Use 'true' or 'false'."
RU[75]="Неверная опция для --$key: $value. Используйте 'true' или 'false'."
EU[76]="Unknown option: $1"
RU[76]="Неверная опция: $1"
EU[77]="List of dependencies for installation:"
RU[77]="Список зависимостей для установки:"
EU[78]="All dependencies are already installed and do not require additional installation."
RU[78]="Все зависимости уже установлены и не требуют дополнительной установки."
EU[79]="Configuring site template."
RU[79]="Настройка шаблона сайта."
EU[80]="Random template name:"
RU[80]="Случайное имя шаблона:"
EU[81]="Enter your domain CNAME record:"
RU[81]="Введите доменную запись типа CNAME:"
EU[82]="Enter Shell in a box path:"
RU[82]="Введите путь к Shell in a box:"
EU[83]="Terminal emulator Shell in a box."
RU[83]="Эмулятор терминала Shell in a box."

EU[84]="0. Previous menu"
RU[84]="0. Предыдущее меню"
EU[85]="Press Enter to return to the menu..."
RU[85]="Нажмите Enter, чтобы вернуться в меню..."
EU[86]="X Core $VERSION_MANAGER"
RU[86]="X Core $VERSION_MANAGER"
EU[87]="1. Perform standard installation"
RU[87]="1. Выполнить стандартную установку"
EU[88]="2. Restore from backup"
RU[88]="2. Восстановить из резервной копии"
EU[89]="3. Change proxy domain name"
RU[89]="3. Изменить доменное имя прокси"
EU[90]="4. Reissue SSL certificates"
RU[90]="4. Перевыпустить SSL-сертификаты"
EU[91]="5. Copy website to server"
RU[91]="5. Скопировать веб-сайт на сервер"
EU[92]="6. Show directory size"
RU[92]="6. Показать размер директории"
EU[93]="7. Show traffic statistics"
RU[93]="7. Показать статистику трафика"
EU[94]="8. Update Xray core"
RU[94]="8. Обновить ядро Xray"
EU[95]="X. Manage Xray core"
RU[95]="X. Управлять ядром Xray"
EU[96]="9. Change interface language"
RU[96]="9. Изменить язык интерфейса"
EU[97]="Client migration initiation (experimental feature)."
RU[97]="Начало миграции клиентов (экспериментальная функция)."
EU[98]="Client migration is complete."
RU[98]="Миграция клиентов завершена."
EU[99]="Settings custom JSON subscription."
RU[99]="Настройки пользовательской JSON-подписки."
EU[100]="Restore from backup."
RU[100]="Восстановление из резервной копии."
EU[101]="Backups:"
RU[101]="Резервные копии:"
EU[102]="Enter the number of the archive to restore:"
RU[102]="Введите номер архива для восстановления:"
EU[103]="Restoration is complete."
RU[103]="Восстановление завершено."
EU[104]="Selected archive:"
RU[104]="Выбран архив:"
EU[105]="Traffic statistics:\n  1. By years \n  2. By months \n  3. By days \n  4. By hours"
RU[105]="Статистика трафика:\n  1. По годам \n  2. По месяцам \n  3. По дням \n  4. По часам"

EU[107]="1. Clear DNS query statistics"
RU[107]="1. Очистить статистику DNS-запросов"
EU[108]="2. Reset inbound traffic statistics"
RU[108]="2. Сбросить статистику трафика инбаундов"
EU[109]="3. Reset client traffic statistics"
RU[109]="3. Сбросить статистику трафика клиентов"
EU[110]="4. Reset network traffic statistics."
RU[110]="4. Сбросить статистику трафика network"

EU[111]="Client traffic statistics cleared"
RU[111]="Статистика очищена"
EU[112]="Error clearing client traffic statistics"
RU[112]="Ошибка при очистке статистики"

EU[117]="1. Add server chain for routing"
RU[117]="1. Добавить цепочку серверов для маршрутизации"
EU[118]="2. Remove server chain from configuration"
RU[118]="2. Удалить цепочку серверов из конфигурации"
EU[119]="Error adding server chain. Configuration update skipped."
RU[119]="Ошибка при добавлении цепочки серверов. Обновление конфигурации пропущено."

EU[120]="1. Show Xray server statistics"
RU[120]="1. Показать статистику Xray сервера"
EU[121]="2. View client DNS queries"
RU[121]="2. Просмотреть DNS-запросы клиентов"
EU[122]="3. Reset Xray server statistics"
RU[122]="3. Сбросить статистику Xray сервера"
EU[123]="4. Add new client"
RU[123]="4. Добавить нового клиента"
EU[124]="5. Delete client"
RU[124]="5. Удалить клиента"
EU[125]="6. Enable or disable client"
RU[125]="6. Включить или отключить клиента"
EU[126]="7. Set client IP address limit"
RU[126]="7. Установить лимит IP-адресов для клиента"
EU[127]="8. Update subscription auto-renewal status"
RU[127]="8. Обновить статус автопродления подписки"
EU[128]="9. Change subscription end date"
RU[128]="9. Изменить дату окончания подписки"
EU[129]="10. Synchronize client subscription configurations"
RU[129]="10. Синхронизировать конфигурации клиентских подписок"
EU[130]="11. Configure server chain"
RU[130]="11. Настроить цепочку серверов"
EU[131]="Enter 0 to exit (updates every 10 seconds): "
RU[131]="Введите 0 для выхода (обновление каждые 10 секунд): "

###################################
### HELP MESSAGE DISPLAY
###################################
display_help_message() {
  echo
  echo "Usage: xcore [-u|--utils <true|false>] [-a|--addu <true|false>]"
  echo "         [-r|--autoupd <true|false>] [-b|--bbr <true|false>] [-i|--ipv6 <true|false>] [-w|--warp <true|false>]"
  echo "         [-c|--cert <true|false>] [-m|--mon <true|false>] [-l|--shell <true|false>] [-n|--nginx <true|false>]"
  echo "         [-p|--xray <true|false>] [--custom <true|false>] [-f|--firewall <true|false>] [-s|--ssh <true|false>]"
  echo "         [-g|--generate <true|false>] [--update] [-h|--help]"
  echo
  echo "  -u, --utils <true|false>       Additional utilities                             (default: ${defaults[utils]})"
  echo "                                 Дополнительные утилиты"
  echo "  -a, --addu <true|false>        User addition                                    (default: ${defaults[addu]})"
  echo "                                 Добавление пользователя"
  echo "  -r, --autoupd <true|false>     Automatic updates                                (default: ${defaults[autoupd]})"
  echo "                                 Автоматические обновления"
  echo "  -b, --bbr <true|false>         BBR (TCP Congestion Control)                     (default: ${defaults[bbr]})"
  echo "                                 BBR (управление перегрузкой TCP)"
  echo "  -i, --ipv6 <true|false>        Disable IPv6 support                             (default: ${defaults[ipv6]})"
  echo "                                 Отключить поддержку IPv6 "
  echo "  -w, --warp <true|false>        WARP setting                                     (default: ${defaults[warp]})"
  echo "                                 Настройка WARP"
  echo "  -c, --cert <true|false>        Certificate issuance for domain                  (default: ${defaults[cert]})"
  echo "                                 Выпуск сертификатов для домена"
  echo "  -m, --mon <true|false>         Monitoring services (node_exporter)              (default: ${defaults[mon]})"
  echo "                                 Сервисы мониторинга (node_exporter)"
  echo "  -l, --shell <true|false>       Shell In A Box installation                      (default: ${defaults[shell]})"
  echo "                                 Установка Shell In A Box"
  echo "  -n, --nginx <true|false>       NGINX installation                               (default: ${defaults[nginx]})"
  echo "                                 Установка NGINX"
  echo "  -p, --xcore <true|false>       Installing the Xray kernel                       (default: ${defaults[xray]})"
  echo "                                 Установка ядра Xray"
  echo "      --custom <true|false>      Custom JSON subscription                         (default: ${defaults[custom]})"
  echo "                                 Кастомная JSON-подписка"  
  echo "  -f, --firewall <true|false>    Firewall configuration                           (default: ${defaults[firewall]})"
  echo "                                 Настройка файрвола"
  echo "  -s, --ssh <true|false>         SSH access                                       (default: ${defaults[ssh]})"
  echo "                                 SSH доступ"
  echo "  -g, --generate <true|false>    Generate a random string for configuration       (default: ${defaults[generate]})"
  echo "                                 Генерация случайных путей для конфигурации"
  echo "      --update                   Update version of X Core manager (Version on github: ${VERSION_MANAGER})"
  echo "                                 Обновить версию X Core manager (Версия на github: ${VERSION_MANAGER})"
  echo "  -h, --help                     Display this help message"
  echo "                                 Показать это сообщение помощи"
  echo
  exit 0
}

###################################
### X CORE UPDATE MANAGER
###################################
update_xcore_manager() {
  info " Script update and integration."

  TOKEN="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"
  REPO_VER_URL="https://raw.githubusercontent.com/cortez24rus/XCore/main/xcore.sh"
  GITHUB_VERSION=$(curl -s -H "Authorization: Bearer $TOKEN" "$REPO_VER_URL" | sed -n "s/^[[:space:]]*VERSION_MANAGER=[[:space:]]*'\([0-9\.]*\)'/\1/p")

  echo " Current version: $VERSION_MANAGER"

  if [[ -z "$GITHUB_VERSION" ]]; then
    error "Failed to fetch latest version from GitHub"
    return 1
  fi
  echo " Github version: $GITHUB_VERSION"

  if [[ "$VERSION_MANAGER" == "$GITHUB_VERSION" ]]; then
    warning "Script is up-to-date: $VERSION_MANAGER"
    echo
    return
  else
    warning "Updating script from $VERSION_MANAGER to $GITHUB_VERSION"
  fi

  REPO_URL="https://api.github.com/repos/cortez24rus/XCore/tarball/main"
  mkdir -p "${DIR_XCORE}/repo/"
  wget --header="Authorization: Bearer $TOKEN" -qO- $REPO_URL | tar xz --strip-components=1 -C "${DIR_XCORE}/repo/"

  chmod +x "${DIR_XCORE}/repo/xcore.sh"
  ln -sf "${DIR_XCORE}/repo/xcore.sh" /usr/local/bin/xcore
  
  chmod +x ${DIR_XCORE}/repo/cron_jobs/*
  bash "${DIR_XCORE}/repo/cron_jobs/get_v2ray-stat.sh"

  systemctl daemon-reload
  sleep 1
  systemctl restart v2ray-stat

  # crontab -l | grep -v -- "--update" | crontab -
  # schedule_cron_job "15 5 * * * ${DIR_XCORE}/repo/xcore.sh --update"

  tilda "\n|-----------------------------------------------------------------------------|\n"
}

###################################
### LOAD DEFAULTS FROM CONFIG FILE
###################################
load_defaults_from_config() {
  if [[ -f "${DIR_XCORE}/default.conf" ]]; then
    # Чтение и выполнение строк из файла
    while IFS= read -r line; do
      # Пропускаем пустые строки и комментарии
      [[ -z "$line" || "$line" =~ ^# ]] && continue
      eval "$line"
    done < "${DIR_XCORE}/default.conf"
  else
    # Если файл не найден, используем значения по умолчанию
    defaults[utils]=true
    defaults[addu]=true
    defaults[autoupd]=true
    defaults[bbr]=true
    defaults[ipv6]=true
    defaults[warp]=false
    defaults[cert]=true
    defaults[mon]=true
    defaults[shell]=true
    defaults[nginx]=true
    defaults[xray]=true
    defaults[custom]=true
    defaults[firewall]=true
    defaults[ssh]=true
    defaults[generate]=true
  fi
}

###################################
### SAVE DEFAULTS TO CONFIG FILE
###################################
save_defaults_to_config() {
  cat > "${DIR_XCORE}/default.conf"<<EOF
defaults[utils]=false
defaults[addu]=false
defaults[autoupd]=false
defaults[bbr]=false
defaults[ipv6]=false
defaults[warp]=false
defaults[cert]=false
defaults[mon]=false
defaults[shell]=false
defaults[nginx]=true
defaults[xray]=true
defaults[custom]=true
defaults[firewall]=false
defaults[ssh]=false
defaults[generate]=true
EOF
}

###################################
### NORMALIZE CASE FOR ARGUMENTS
###################################
normalize_argument_case() {
  local key=$1
  args[$key]="${args[$key],,}"
}

###################################
### VALIDATE BOOLEAN VALUES
###################################
validate_boolean_value() {
  local key=$1
  local value=$2
  case ${value} in
    true)
      args[$key]=true
      ;;
    false)
      args[$key]=false
      ;;
    *)
      warning " $(text 75) "
      return 1
      ;;
  esac
}

###################################
### PARSE COMMAND-LINE ARGUMENTS
###################################
declare -A arg_map=(
  [-u]=utils      [--utils]=utils
  [-a]=addu       [--addu]=addu
  [-r]=autoupd    [--autoupd]=autoupd
  [-b]=bbr        [--bbr]=bbr
  [-i]=ipv6       [--ipv6]=ipv6
  [-w]=warp       [--warp]=warp
  [-c]=cert       [--cert]=cert
  [-m]=mon        [--mon]=mon
  [-l]=shell      [--shell]=shell
  [-n]=nginx      [--nginx]=nginx
  [-x]=xray       [--xray]=xray
                  [--custom]=custom
  [-f]=firewall   [--firewall]=firewall
  [-s]=ssh        [--ssh]=ssh
  [-g]=generate   [--generate]=generate
)

parse_command_line_args() {
  local opts
  opts=$(getopt -o hu:a:r:b:i:w:c:m:l:n:x:f:s:g --long utils:,addu:,autoupd:,bbr:,ipv6:,warp:,cert:,mon:,shell:,nginx:,xray:,custom:,firewall:,ssh:,generate:,update,help -- "$@")

  if [[ $? -ne 0 ]]; then
    return 1
  fi

  eval set -- "$opts"
  while true; do
    case $1 in
      --update)
        echo
        update_xcore_manager
        exit 0
        ;;
      -h|--help)
        return 1
        ;;
      --)
        shift
        break
        ;;
      *)
        if [[ -n "${arg_map[$1]}" ]]; then
          local key="${arg_map[$1]}"
          args[$key]="$2"
          normalize_argument_case "$key"
          validate_boolean_value "$key" "$2" || return 1
          shift 2
          continue
        fi
        warning " $(text 76) "
        return 1
        ;;
    esac
  done

  for key in "${!defaults[@]}"; do
    if [[ -z "${args[$key]}" ]]; then
      args[$key]=${defaults[$key]}
    fi
  done
}

###################################
### LOGGING SETUP
###################################
enable_logging() {
  mkdir -p ${DIR_XCORE}/
  LOGFILE="${DIR_XCORE}/xcore.log"
  exec > >(tee -a "$LOGFILE") 2>&1
}

disable_logging() {
  exec > /dev/tty 2>&1
}

###################################
### LANGUAGE SELECTION
###################################
configure_language() {
  CONF_FILE="${DIR_XCORE}/xcore.conf"

  hint " $(text 0) \n" 
  reading " $(text 1) " LANGUAGE_CHOISE

  case "$LANGUAGE_CHOISE" in
    1) NEW_LANGUAGE=EU ;;
    2) NEW_LANGUAGE=RU ;;
    *) NEW_LANGUAGE=$LANGUAGE ;; # Оставляем текущий язык, если выбор некорректен
  esac

  sed -i "s/^LANGUAGE=.*/LANGUAGE=$NEW_LANGUAGE/" "$CONF_FILE"

  source "$CONF_FILE"
}

###################################
### OPERATING SYSTEM DETECTION
###################################
detect_operating_system() {
  if [ -s /etc/os-release ]; then
    SYS="$(grep -i pretty_name /etc/os-release | cut -d \" -f2)"
  elif [ -x "$(type -p hostnamectl)" ]; then
    SYS="$(hostnamectl | grep -i system | cut -d : -f2)"
  elif [ -x "$(type -p lsb_release)" ]; then
    SYS="$(lsb_release -sd)"
  elif [ -s /etc/lsb-release ]; then
    SYS="$(grep -i description /etc/lsb-release | cut -d \" -f2)"
  elif [ -s /etc/redhat-release ]; then
    SYS="$(grep . /etc/redhat-release)"
  elif [ -s /etc/issue ]; then
    SYS="$(grep . /etc/issue | cut -d '\' -f1 | sed '/^[ ]*$/d')"
  fi

  REGEX=("debian" "ubuntu" "centos|red hat|kernel|alma|rocky")
  RELEASE=("Debian" "Ubuntu" "CentOS")
  EXCLUDE=("---")
  MAJOR=("10" "20" "7")
  PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update --skip-broken")
  PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install")
  PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove")

  for int in "${!REGEX[@]}"; do
    [[ "${SYS,,}" =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && break
  done

  # Проверка на кастомизированные системы от различных производителей
  if [ -z "$SYSTEM" ]; then
    [ -x "$(type -p yum)" ] && int=2 && SYSTEM='CentOS' || error " $(text 5) "
  fi

  # Определение основной версии Linux
  MAJOR_VERSION=$(sed "s/[^0-9.]//g" <<< "$SYS" | cut -d. -f1)

  # Сначала исключаем системы, указанные в EXCLUDE, затем для оставшихся делаем сравнение по основной версии
  for ex in "${EXCLUDE[@]}"; do [[ ! "${SYS,,}" =~ $ex ]]; done &&
  [[ "$MAJOR_VERSION" -lt "${MAJOR[int]}" ]] && error " $(text 71) "
}

###################################
### DEPENDENCY CHECK AND INSTALLATION
###################################
install_dependencies() {
  # Зависимости, необходимые для трех основных систем
  [ "${SYSTEM}" = 'CentOS' ] && ${PACKAGE_INSTALL[int]} vim-common epel-release
  DEPS_CHECK=("ping" "wget" "curl" "systemctl" "ip" "sudo")
  DEPS_INSTALL=("iputils-ping" "wget" "curl" "systemctl" "iproute2" "sudo")

  for g in "${!DEPS_CHECK[@]}"; do
    [ ! -x "$(type -p ${DEPS_CHECK[g]})" ] && [[ ! "${DEPS[@]}" =~ "${DEPS_INSTALL[g]}" ]] && DEPS+=(${DEPS_INSTALL[g]})
  done

  if [ "${#DEPS[@]}" -ge 1 ]; then
    info "\n $(text 72) ${DEPS[@]} \n"
    ${PACKAGE_UPDATE[int]}
    ${PACKAGE_INSTALL[int]} ${DEPS[@]}
  else
    info "\n $(text 73) \n"
  fi
}

###################################
### ROOT PRIVILEGE CHECK
###################################
verify_root_privileges() {
  if [[ $EUID -ne 0 ]]; then
    error " $(text 8) "
  fi
}

###################################
### EXTERNAL IP ADDRESS DETECTION
###################################
detect_external_ip() {
  IP4=$(curl -s https://cloudflare.com/cdn-cgi/trace | grep "ip" | cut -d "=" -f 2)

  if [[ ! $IP4 =~ ${regex[ipv4]} ]]; then
    IP4=$(curl -s ipinfo.io/ip)
  fi

  if [[ ! $IP4 =~ ${regex[ipv4]} ]]; then
    IP4=$(curl -s 2ip.io)
  fi

  if [[ ! $IP4 =~ ${regex[ipv4]} ]]; then
    echo "Не удалось получить внешний IP."
    return 1
  fi
}

###################################
### BANNER DISPLAY
###################################
display_xcore_banner() {
  echo
  echo " █░█ ░░ █▀▀█ █▀▀█ █▀▀█ █▀▀ "
  echo " ▄▀▄    █░░  █░░█ █▄▄▀ █▀▀ "
  echo " ▀░▀ ░░ ▀▀▀▀ ▀▀▀▀ ▀░▀▀ ▀▀▀ $VERSION_MANAGER"
  echo
}

###################################
### PRE-INSTALLATION WARNING
###################################
display_pre_install_warning() {
  warning " $(text 5) "
  echo
  info " $(text 6) "
  warning " apt-get update && apt-get full-upgrade -y && reboot "
}

###################################
### CRON JOB MANAGEMENT
###################################
schedule_cron_job() {
  local logged_rule="$1"
  ( crontab -l | grep -Fxq "$logged_rule" ) || ( crontab -l 2>/dev/null; echo "$logged_rule" ) | crontab -
}

###################################
### CLOUDFLARE API TEST REQUEST
###################################
fetch_cloudflare_test_response() {
  testdomain=$(echo "${DOMAIN}" | rev | cut -d '.' -f 1-2 | rev)

  if [[ "$CFTOKEN" =~ [A-Z] ]]; then
    test_response=$(curl --silent --request GET --url https://api.cloudflare.com/client/v4/zones --header "Authorization: Bearer ${CFTOKEN}" --header "Content-Type: application/json")
  else
    test_response=$(curl --silent --request GET --url https://api.cloudflare.com/client/v4/zones --header "X-Auth-Key: ${CFTOKEN}" --header "X-Auth-Email: ${EMAIL}" --header "Content-Type: application/json")
  fi
}

###################################
### URL CLEANUP UTILITY
###################################
clean_url_string() {
  local INPUT_URL_L="$1"  # Входной URL, который нужно очистить от префикса, порта и пути.
  # Убираем префикс https:// или http:// и порт/путь
  local CLEANED_URL_L=$(echo "$INPUT_URL_L" | sed -E 's/^https?:\/\///' | sed -E 's/(:[0-9]+)?(\/[a-zA-Z0-9_\-\/]+)?$//')
  echo "$CLEANED_URL_L"  # Возвращаем очищенный URL (без префикса, порта и пути).
}

###################################
### DOMAIN CROPPING UTILITY
###################################
crop_domain_to_base() {
  local DOMAIN_L=$1  # Получаем домен как аргумент
  IFS='.' read -r -a parts <<< "$DOMAIN_L"  # Разбиваем домен на части по точкам.

  # Если в домене больше двух частей (например, для субдоменов), обрезаем до последних двух.
  if [ ${#parts[@]} -gt 2 ]; then
    DOMAIN_L="${parts[${#parts[@]}-2]}.${parts[${#parts[@]}-1]}"  # Берем последние две части домена.
  else
    DOMAIN_L="${parts[0]}.${parts[1]}"  # Если домен второго уровня, оставляем только его.
  fi

  echo "$DOMAIN_L"  # Возвращаем результат через echo.
}

###################################
### CLOUDFLARE TOKEN VALIDATION
###################################
validate_cloudflare_token() {
  while ! echo "$test_response" | grep -qE "\"${testdomain}\"|\"#dns_records:edit\"|\"#dns_records:read\"|\"#zone:read\""; do
    DOMAIN=""
    EMAIL=""
    CFTOKEN=""

    while [[ -z "$DOMAIN" ]]; do
      reading " $(text 13) " DOMAIN
      DOMAIN=$(clean_url_string "$DOMAIN")
    done
    echo
    while [[ -z $EMAIL ]]; do
      reading " $(text 15) " EMAIL
    done
    echo
    while [[ -z $CFTOKEN ]]; do
      reading " $(text 16) " CFTOKEN
    done

    fetch_cloudflare_test_response
    info " $(text 17) "
  done
}

###################################
### PATH VALIDATION AND PROCESSING
###################################
validate_and_process_path() {
  local VARIABLE_NAME="$1"
  local PATH_VALUE

  # Проверка на пустое значение
  while true; do
    case "$VARIABLE_NAME" in
      METRICS)
        reading " $(text 24) " PATH_VALUE
        ;;
      SHELLBOX)
        reading " $(text 24) " PATH_VALUE
        ;;
      SUB_JSON_PATH)
        reading " $(text 28) " PATH_VALUE
        ;;
    esac

    if [[ -z "$PATH_VALUE" ]]; then
      warning " $(text 29) "
      echo
    elif [[ $PATH_VALUE =~ ['{}\$/\\'] ]]; then
      warning " $(text 30) "
      echo
    else
      break
    fi
  done

  # Экранируем пробелы в пути
  local ESCAPED_PATH=$(echo "$PATH_VALUE" | sed 's/ /\\ /g')

  # Присваиваем значение переменной
  case "$VARIABLE_NAME" in
    METRICS)
      export METRICS="$ESCAPED_PATH"
      ;;
    SHELLBOX)
      export SHELLBOX="$ESCAPED_PATH"
      ;;
    SUB_JSON_PATH)
      export SUB_JSON_PATH="$ESCAPED_PATH"
      ;;
  esac
}

###################################
### USER DATA INPUT COLLECTION
###################################
collect_user_data() {
  tilda "$(text 10)"

  reading " $(text 11) " USERNAME
  echo
  reading " $(text 12) " PASSWORD
  [[ ${args[addu]} == "true" ]] && create_system_user

  tilda "$(text 10)"

  validate_cloudflare_token

  if [[ ${args[generate]} == "true" ]]; then
    SUB_JSON_PATH=$(eval ${generate[path]})
  else
    echo
    validate_and_process_path SUB_JSON_PATH
  fi
  if [[ ${args[mon]} == "true" ]]; then
    if [[ ${args[generate]} == "true" ]]; then
      METRICS=$(eval ${generate[path]})
    else
      echo
      validate_and_process_path METRICS
    fi
  fi
  if [[ ${args[shell]} == "true" ]]; then
    if [[ ${args[generate]} == "true" ]]; then
      SHELLBOX=$(eval ${generate[path]})
    else
      echo
      validate_and_process_path SHELLBOX
    fi
  fi

  if [[ ${args[ssh]} == "true" ]]; then
    tilda "$(text 10)"
    reading " $(text 54) " ANSWER_SSH
    if [[ "${ANSWER_SSH,,}" == "y" ]]; then
      info " $(text 48) "
      out_data " $(text 49) "
      echo
      out_data " $(text 50) "
      out_data " $(text 51) "
      echo
      out_data " $(text 52)" "type \$env:USERPROFILE\.ssh\id_rsa.pub | ssh -p 22 ${USERNAME}@${IP4} \"cat >> ~/.ssh/authorized_keys\""
      out_data " $(text 53)" "ssh-copy-id -p 22 ${USERNAME}@${IP4}"
      echo
      # Цикл проверки наличия ключей
      while true; do
        if [[ -s "/home/${USERNAME}/.ssh/authorized_keys" || -s "/root/.ssh/authorized_keys" ]]; then
          info " $(text 56) " # Ключи найдены
          SSH_OK=true
          break
        else
          warning " $(text 55) " # Ключи отсутствуют
          echo
          reading " $(text 54) " ANSWER_SSH
          if [[ "${ANSWER_SSH,,}" != "y" ]]; then
            warning " $(text 9) " # Настройка отменена
            SSH_OK=false
            break
          fi
        fi
      done
    else
      warning " $(text 9) " # Настройка пропущена
      SSH_OK=false
    fi
  fi

  tilda "$(text 10)"
}

###################################
### NGINX INSTALLATION
###################################
install_nginx() {
  case "$SYSTEM" in
    Debian|Ubuntu)
      DEPS_CHECK_BUILD=(
        gcc                     gcc
        make                    make
        mmdb-bin                mmdb-bin
        libgd-dev               libgd-dev
        zlib1g-dev              zlib1g-dev
        libssl-dev              libssl-dev
        libpcre2-dev            libpcre2-dev
        libxslt1-dev            libxslt1-dev
        libmaxminddb0           libmaxminddb0
        libmaxminddb-dev        libmaxminddb-dev
        build-essential         build-essential
      )
      USERNGINX="www-data"
      ;;

    CentOS|Fedora)
      DEPS_CHECK_BUILD=(
        gcc                     gcc
        make                    make
        gd-devel                gd-devel
        pcre-devel              pcre-devel
        zlib-devel              zlib-devel
        openssl-devel           openssl-devel
        libxslt-devel           libxslt-devel
        libmaxminddb-devel      libmaxminddb-devel
      )
      USERNGINX="nginx"
      ;;
  esac

  for ((i=0; i<${#DEPS_CHECK_BUILD[@]}; i+=2)); do
    bin="${DEPS_CHECK_BUILD[i]}"
    pkg="${DEPS_CHECK_BUILD[i+1]}"

    if command -v "$bin" >/dev/null 2>&1 || dpkg -s "$pkg" >/dev/null 2>&1; then
      continue
    fi
    DEPS_PACK_BUILD+=("$pkg")
  done

  if [ "${#DEPS_PACK_BUILD[@]}" -gt 0 ]; then
    info " $(text 77) ": ${DEPS_PACK_BUILD[@]}
    ${PACKAGE_UPDATE[int]}
    ${PACKAGE_INSTALL[int]} ${DEPS_PACK_BUILD[@]}
  else
    info " $(text 78) "
  fi

  NGINX_VERSION="1.27.5"
  wget https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz
  tar -xvf nginx-$NGINX_VERSION.tar.gz
  cd nginx-$NGINX_VERSION
  git clone https://github.com/leev/ngx_http_geoip2_module.git /tmp/ngx_http_geoip2_module

  ./configure \
    --prefix=/usr \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/run/nginx.pid \
    --lock-path=/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=$USERNGINX \
    --group=$USERNGINX \
    --with-compat \
    --with-file-aio \
    --with-threads \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-stream \
    --with-stream_realip_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --add-dynamic-module=/tmp/ngx_http_geoip2_module \
    --with-cc-opt="-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC" \
    --with-ld-opt="-Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie"

  make
  make install

  mkdir -p /var/cache/nginx/{client_temp,proxy_temp,fastcgi_temp,uwsgi_temp,scgi_temp}
  chown -R $USERNGINX:$USERNGINX /var/cache/nginx
  chmod -R 700 /var/cache/nginx

  cp "${DIR_XCORE}/repo/services/nginx.service" "/etc/systemd/system/nginx.service"

  systemctl daemon-reload
  systemctl start nginx
  systemctl enable nginx
  systemctl restart nginx
  systemctl status nginx --no-pager

  cd ..

  rm -rf nginx-$NGINX_VERSION.tar.gz nginx-$NGINX_VERSION /tmp/ngx_http_geoip2_module
}

###################################
### UTILITY PACKAGE INSTALLATION
###################################
install_utility_packages() {
  info " $(text 36) "
  case "$SYSTEM" in
    Debian|Ubuntu)
      DEPS_CHECK=(
        jq                      jq
        git                     git
        ufw                     ufw
        zip                     zip
        wget                    wget
        cron                    cron
        nano                    nano
        unzip                   unzip
        rsync                   rsync
        gpg                     gnupg2
        vnstat                  vnstat
        sqlite3                 sqlite3
        haproxy                 haproxy
        certbot                 certbot
        openssl                 openssl
        netstat                 net-tools
        htpasswd                apache2-utils
        update-ca-certificates  ca-certificates
        unattended-upgrades     unattended-upgrades
        add-apt-repository      software-properties-common
        certbot-dns-cloudflare  python3-certbot-dns-cloudflare
      )
      ;;

    CentOS|Fedora)
      DEPS_CHECK=(
        jq                      jq
        git                     git
        ufw                     ufw
        zip                     zip
        tar                     tar
        wget                    wget
        cron                    cron
        nano                    nano
        unzip                   unzip
        rsync                   rsync
        gpg                     gnupg2
        vnstat                  vnstat
        crontab                 cronie
        sqlite3                 sqlite3
        haproxy                 haproxy
        certbot                 certbot
        openssl                 openssl
        netstat                 net-tools
        nslookup                bind-utils
        htpasswd                httpd-tools
        update-ca-certificates  ca-certificates
        unattended-upgrades     unattended-upgrades
        add-apt-repository      software-properties-common
        certbot-dns-cloudflare  python3-certbot-dns-cloudflare
      )
      ;;
  esac

  for ((i=0; i<${#DEPS_CHECK[@]}; i+=2)); do
    bin="${DEPS_CHECK[i]}"
    pkg="${DEPS_CHECK[i+1]}"

    if command -v "$bin" >/dev/null 2>&1 || dpkg -s "$pkg" >/dev/null 2>&1; then
      continue
    fi

    DEPS_PACK+=("$pkg")
  done

  if [ "${#DEPS_PACK[@]}" -gt 0 ]; then
    info " $(text 77) ": ${DEPS_PACK[@]}
    ${PACKAGE_UPDATE[int]}
    ${PACKAGE_INSTALL[int]} ${DEPS_PACK[@]}
  else
    info " $(text 78) "
  fi

  install_nginx
  tilda "$(text 10)"
}

###################################
### SYSTEM USER CREATION
###################################
create_system_user() {
  info " $(text 39) "

  case "$SYSTEM" in
    Debian|Ubuntu)
      useradd -m -s $(which bash) -G sudo ${USERNAME}
      ;;

    CentOS|Fedora)
      useradd -m -s $(which bash) -G wheel ${USERNAME}
      ;;
  esac

  echo "${USERNAME}:${PASSWORD}" | chpasswd
  mkdir -p /home/${USERNAME}/.ssh/
  touch /home/${USERNAME}/.ssh/authorized_keys
  chown -R ${USERNAME}: /home/${USERNAME}/.ssh
  chmod -R 700 /home/${USERNAME}/.ssh
}

###################################
### AUTOMATIC UPDATES CONFIGURATION
###################################
configure_auto_updates() {
  info " $(text 40) "

  case "$SYSTEM" in
    Debian|Ubuntu)
      echo 'Unattended-Upgrade::Mail "root";' >> /etc/apt/apt.conf.d/50unattended-upgrades
      echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
      dpkg-reconfigure -f noninteractive unattended-upgrades
      systemctl restart unattended-upgrades
      ;;

    CentOS|Fedora)
      cat > /etc/dnf/automatic.conf <<EOF
[commands]
upgrade_type = security
random_sleep = 0
download_updates = yes
apply_updates = yes

[email]
email_from = root@localhost
email_to = root
email_host = localhost
EOF
      systemctl enable --now dnf-automatic.timer
      systemctl status dnf-automatic.timer
      ;;
  esac

  tilda "$(text 10)"
}

###################################
### BBR OPTIMIZATION
###################################
enable_bbr_optimization() {
  info " $(text 41) "

  if ! grep -q "net.core.default_qdisc = fq" /etc/sysctl.conf; then
      echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
  fi
  if ! grep -q "net.ipv4.tcp_congestion_control = bbr" /etc/sysctl.conf; then
      echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
  fi

  sysctl -p
}

###################################
### IPV6 DISABLING
###################################
disable_ipv6_support() {
  info " $(text 42) "
  interface_name=$(ifconfig -s | awk 'NR==2 {print $1}')

  if ! grep -q "net.ipv6.conf.all.disable_ipv6 = 1" /etc/sysctl.conf; then
      echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
  fi
  if ! grep -q "net.ipv6.conf.default.disable_ipv6 = 1" /etc/sysctl.conf; then
      echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
  fi
  if ! grep -q "net.ipv6.conf.lo.disable_ipv6 = 1" /etc/sysctl.conf; then
      echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
  fi
  if ! grep -q "net.ipv6.conf.$interface_name.disable_ipv6 = 1" /etc/sysctl.conf; then
      echo "net.ipv6.conf.$interface_name.disable_ipv6 = 1" >> /etc/sysctl.conf
  fi

  sysctl -p
  tilda "$(text 10)"
}

###################################
### Swapfile
###################################
swapfile() {
  echo
  echo "Setting up swapfile and restarting the WARP service if necessary"
  swapoff /swapfile*
  dd if=/dev/zero of=/swapfile bs=1M count=512
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  swapon --show
  
  chmod +x "${DIR_XCORE}/repo/cron_jobs/restart_warp.sh"
  # crontab -l | grep -v -- "restart_warp.sh" | crontab -
  schedule_cron_job "* * * * * ${DIR_XCORE}/repo/cron_jobs/restart_warp.sh"
}

###################################
### WARP CONFIGURATION
###################################
configure_warp() {
  info " $(text 43) "

  case "$SYSTEM" in
    Debian|Ubuntu)
      curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(grep "VERSION_CODENAME=" /etc/os-release | cut -d "=" -f 2) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
      ;;

    CentOS|Fedora)
      curl -fsSl https://pkg.cloudflareclient.com/cloudflare-warp-ascii.repo | tee /etc/yum.repos.d/cloudflare-warp.repo
      ;;
  esac

  ${PACKAGE_UPDATE[int]}
  ${PACKAGE_INSTALL[int]} cloudflare-warp

  warp-cli --accept-tos registration new
  warp-cli --accept-tos mode proxy
  warp-cli --accept-tos proxy port 40000
  warp-cli --accept-tos connect
  warp-cli debug qlog disable

  warp-cli tunnel stats
  if curl -x socks5h://localhost:40000 https://2ip.io; then
    echo "WARP is connected successfully."
  else
    warning " $(text 20) "
  fi

  swapfile
  tilda "$(text 10)"
}

###################################
### CERTIFICATE ISSUANCE
###################################
issue_certificates() {
  info " $(text 44) "

  CF_CREDENTIALS_PATH="/etc/letsencrypt/.cloudflare.credentials"
  touch ${CF_CREDENTIALS_PATH}
  chown root:root ${CF_CREDENTIALS_PATH}
  chmod 600 ${CF_CREDENTIALS_PATH}

  if [[ "$CFTOKEN" =~ [A-Z] ]]; then
    cat > ${CF_CREDENTIALS_PATH} <<EOF
dns_cloudflare_api_token = ${CFTOKEN}
EOF
  else
    cat > ${CF_CREDENTIALS_PATH} <<EOF
dns_cloudflare_email = ${EMAIL}
dns_cloudflare_api_key = ${CFTOKEN}
EOF
  fi

  attempt=0
  max_attempts=2
  while [ $attempt -lt $max_attempts ]; do
    certbot certonly --dns-cloudflare --dns-cloudflare-credentials ${CF_CREDENTIALS_PATH} --dns-cloudflare-propagation-seconds 30 --rsa-key-size 4096 -d ${DOMAIN},*.${DOMAIN} --agree-tos -m ${EMAIL} --cert-name ${DOMAIN} --no-eff-email --non-interactive
	  if [ $? -eq 0 ]; then
      break
    else
      attempt=$((attempt + 1))
      sleep 5
    fi
  done

  chmod +x "${DIR_XCORE}/repo/cron_jobs/cert_renew.sh"
  # crontab -l | grep -v -- "cert_renew.sh" | crontab -
  schedule_cron_job "20 5 */3 * * ${DIR_XCORE}/repo/cron_jobs/cert_renew.sh"

  tilda "$(text 10)"
}

###################################
### SETUP MONITORING WITH NODE EXPORTER
###################################
setup_node_exporter() {
  info " $(text 66) "
  mkdir -p /etc/nginx/locations/
  bash <(curl -Ls https://github.com/cortez24rus/grafana-prometheus/raw/refs/heads/main/prometheus_node_exporter.sh)

  cat > /etc/nginx/locations/monitoring.conf <<EOF
location /${METRICS}/ {
  proxy_pass http://127.0.0.1:9100/metrics;
  proxy_set_header Host \$host;
  proxy_set_header X-Real-IP \$remote_addr;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;

  auth_basic "Restricted Content";
  auth_basic_user_file /etc/nginx/.htpasswd;

  access_log off;
  break;
}
EOF

  tilda "$(text 10)"
}

###################################
### SETUP SHELL IN A BOX TERMINAL EMULATOR
###################################
setup_shell_in_a_box() {
  info " $(text 83) "
  apt-get install shellinabox
  mkdir -p /etc/nginx/locations/

  cat > /etc/default/shellinabox <<EOF
# Should shellinaboxd start automatically
SHELLINABOX_DAEMON_START=1
# TCP port that shellinboxds webserver listens on
SHELLINABOX_PORT=4200
# Parameters that are managed by the system and usually should not need
# changing:
# SHELLINABOX_DATADIR=/var/lib/shellinabox
# SHELLINABOX_USER=shellinabox
# SHELLINABOX_GROUP=shellinabox
# Any optional arguments (e.g. extra service definitions).  Make sure
# that that argument is quoted.
#   Beeps are disabled because of reports of the VLC plugin crashing
#   Firefox on Linux/x86_64.
SHELLINABOX_ARGS="--no-beep --localhost-only --disable-ssl"
EOF

  cat > /etc/nginx/locations/shellinabox.conf <<EOF
location /${SHELLBOX}/ {
  proxy_pass http://127.0.0.1:4200;
  proxy_set_header Host \$host;
  proxy_set_header X-Real-IP \$remote_addr;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;

  auth_basic "Restricted Content";
  auth_basic_user_file /etc/nginx/.htpasswd;

  access_log off;
  break;
}
EOF

  systemctl restart shellinabox
  tilda "$(text 10)"
}

###################################
### SELECT AND APPLY RANDOM WEBSITE TEMPLATE
###################################
apply_random_website_template() {
  info " $(text 79) "
  mkdir -p /var/www/html/ ${DIR_XCORE}/

  cd ${DIR_XCORE}/

  if [[ ! -d "simple-web-templates-main" ]]; then
      while ! wget -q --progress=dot:mega --timeout=30 --tries=10 --retry-connrefused "https://github.com/cortez24rus/simple-web-templates/archive/refs/heads/main.zip"; do
        warning " $(text 38) "
        sleep 3
      done
      unzip -q main.zip &>/dev/null && rm -f main.zip
  fi

  cd simple-web-templates-main
  rm -rf assets ".gitattributes" "README.md" "_config.yml"

  RandomHTML=$(ls -d */ | shuf -n1)  # Обновил для выбора случайного подкаталога
  info " $(text 80) ${RandomHTML}"

  # Если шаблон существует, копируем его в /var/www/html
  if [[ -d "${RandomHTML}" && -d "/var/www/html/" ]]; then
      echo "Копируем шаблон в /var/www/html/..."
      rm -rf /var/www/html/*  # Очищаем старую папку
      cp -a "${RandomHTML}/." /var/www/html/
  else
      echo "Ошибка при извлечении шаблона!"
  fi

  cd ~
  tilda "$(text 10)"
}

###################################
### CONFIGURE NGINX MAIN CONFIGURATION
###################################
configure_nginx_main() {
  cat > /etc/nginx/nginx.conf <<EOF
load_module /usr/lib/nginx/modules/ngx_http_geoip2_module.so;

# Global settings
user                                   ${USERNGINX};
pid                                    /run/nginx.pid;
worker_processes                       auto;
worker_rlimit_nofile                   65535;
error_log                              /var/log/nginx/error.log;
include                                /etc/nginx/modules-enabled/*.conf;

# Events
events {
  multi_accept                         on;
  worker_connections                   1024;
}

# HTTP settings
http {
  # GeoIP2: Determine geographical information from IP (Country)
  geoip2 /etc/nginx/geolite2/GeoLite2-Country.mmdb {
    auto_reload 12h;
    \$geoip2_country_code              country iso_code;
    \$geoip2_country_name              country names en;
  }

  # GeoIP2: Determine geographical information from IP (City)
  geoip2 /etc/nginx/geolite2/GeoLite2-City.mmdb {
    auto_reload                        12h;
    \$geoip2_city_name                  city names en;
  }

  # GeoIP2: Determine geographical information from IP (ASN)
  geoip2 /etc/nginx/geolite2/GeoLite2-ASN.mmdb {
    auto_reload 12h;
    \$geoip2_asn                        autonomous_system_number;
    \$geoip2_organization               autonomous_system_organization;
  }

  # Country access map
  map \$geoip2_country_code \$allow_country {
    default                            0;
    RU                                 1;
#    NL                                 1;
  }

  # Карта для блокировки по организации
  map \$geoip2_organization \$allow_organization {
    default                              1;
    "Chang Way Technologies Co. Limited" 0;
  }

  # Clean URI by removing ?x_padding parameter
  map \$request_uri \$cleaned_request_uri {
    default \$request_uri;
    "~^(.*?)(\?x_padding=[^ ]*)\$" \$1;
  }

  # Logging
  log_format json_analytics escape=json '{'
    '"local": "\$time_local",'
    '"addr": "\$remote_addr",'
    '"request": "\$request_method",'
    '"status": "\$status",'
    '"uri": "\$request_uri",'
    '"country": "\$geoip2_country_name",'
    '"country_code": "\$geoip2_country_code",'
    '"city": "\$geoip2_city_name",'
    '"asn": "\$geoip2_asn",'
    '"organization": "\$geoip2_organization"'
    '"agent": "\$http_user_agent",'
    '}';

  # Real IP
  set_real_ip_from                     127.0.0.1;
  real_ip_header                       X-Forwarded-For;
  real_ip_recursive                    on;

  # Performance
  sendfile                             on;
  tcp_nopush                           on;
  tcp_nodelay                          on;

  # Security
  server_tokens                        off;
  log_not_found                        off;

  # Hash sizes
  types_hash_max_size                  2048;
  types_hash_bucket_size               64;
  variables_hash_max_size              2048;
  variables_hash_bucket_size           128;

  # Client
  client_max_body_size                 16M;

  # Keepalive
  keepalive_timeout                    75s;
  keepalive_requests                   1000;

  # Timeouts
  reset_timedout_connection            on;

  # MIME types
  include                              /etc/nginx/mime.types;
  default_type                         application/octet-stream;

  # DNS resolver
  resolver                             127.0.0.1 valid=60s;
  resolver_timeout                     2s;

  # gzip
  gzip                                 on;
  gzip_vary                            on;
  gzip_proxied                         any;
  gzip_comp_level                      6;
  gzip_types                           text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;

  add_header X-XSS-Protection          "0" always;
  add_header X-Content-Type-Options    "nosniff" always;
  add_header Referrer-Policy           "no-referrer-when-downgrade" always;
  add_header Permissions-Policy        "interest-cohort=()" always;
  add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
  add_header X-Frame-Options           "SAMEORIGIN";
  proxy_hide_header                    X-Powered-By;

  # Include server
  include                              /etc/nginx/conf.d/*.conf;
}
EOF
}

###################################
### CONFIGURE NGINX SERVER BLOCK
###################################
configure_nginx_server() {
  cat > /etc/nginx/conf.d/local.conf <<EOF
server {
  listen                               36078;
  server_name                          _;

  # Access log
  access_log /var/log/nginx/access.log json_analytics;

  # Блокировка по стране
  if (\$allow_country = 0) {
    return 403;
  }

  # Блокировка по ASN
  if (\$allow_organization = 0) {
    return 403;
  }

  # Enable locations
  include /etc/nginx/locations/*.conf;
}
EOF
}

###################################
### CONFIGURE NGINX ROOT LOCATION
###################################
configure_nginx_root_location() {
  cat > /etc/nginx/locations/root.conf <<EOF
# Web site
location / {
  root /var/www/html;
  index index.html;
  autoindex off;
  try_files \$uri \$uri/ =404;
}
EOF
}

###################################
### CONFIGURE NGINX HIDDEN FILES PROTECTION
###################################
configure_nginx_hidden_files() {
  cat > /etc/nginx/locations/hidden_files.conf <<EOF
# . hidden_files.conf
location ~ /\.(?!well-known) {
  deny all;
}
EOF
}

###################################
### CONFIGURE NGINX SUBSCRIPTION PAGE
###################################
configure_nginx_sub_page() {
  cat > /etc/nginx/locations/sub_page.conf <<EOF
# Subsciption
location ~ ^/${SUB_JSON_PATH} {
  default_type application/json;
  root /var/www;
}
EOF
}

###################################
### CONFIGURE NGINX GEOIP CHECK ENDPOINT
###################################
configure_nginx_geoip_check() {
  cat > /etc/nginx/locations/geoip.conf <<EOF
# Geo check
location = /geoip-check {
  default_type text/plain;
  return 200 "Your IP: \$remote_addr\nCountry: \$geoip2_country_code - \$geoip2_country_name\nCity: \$geoip2_city_name\nASN: \$geoip2_asn\nOrg: \$geoip2_organization\n";
}
EOF
}

configure_nginx_v2ray() {
  cat > /etc/nginx/locations/v2ray-stat.conf <<EOF
location /statistics-v2ray-stat/ {
  access_log off;
  proxy_pass http://127.0.0.1:9952/;

  # Добавляем заголовок с IP клиента
  proxy_set_header X-Real-IP \$remote_addr;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header Host \$host;

  # Автообновление страницы каждые 10 секунд
  add_header Refresh "10; URL=\$scheme://\$http_host\$request_uri";
}
EOF
}

###################################
### DOWNLOAD AND SCHEDULE GEOLITE2 DATABASE UPDATES
###################################
schedule_geolite2_updates() {
  chmod +x "${DIR_XCORE}/repo/cron_jobs/geolite2_update.sh"
  # crontab -l | grep -v -- "geolite2_update.sh" | crontab -
  schedule_cron_job "20 5 */3 * * ${DIR_XCORE}/repo/cron_jobs/geolite2_update.sh"

  bash "${DIR_XCORE}/repo/cron_jobs/geolite2_update.sh"
}

###################################
### Nginx Logrotate
###################################
configure_nginx_logrotate() {
  cat > /etc/logrotate.d/nginx <<EOF
/var/log/nginx/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        [ -f /run/nginx.pid ] && kill -USR1 \$(cat /run/nginx.pid)
    endscript
}
EOF
}

###################################
### FULL NGINX SETUP AND CONFIGURATION
###################################
setup_nginx() {
  info " $(text 45) "

  mkdir -p /etc/nginx/conf.d/
  mkdir -p /etc/nginx/locations/
  mkdir -p /etc/nginx/geolite2/
  rm -rf /etc/nginx/conf.d/default.conf
  touch /etc/nginx/.htpasswd
  htpasswd -nb "$USERNAME" "$PASSWORD" > /etc/nginx/.htpasswd

  case "$SYSTEM" in
    Debian|Ubuntu)
      USERNGINX="www-data"
      ;;

    CentOS|Fedora)
      USERNGINX="nginx"
      ;;
  esac

  configure_nginx_main
  configure_nginx_server
  configure_nginx_root_location
  configure_nginx_hidden_files
  configure_nginx_sub_page
  # configure_nginx_geoip_check
  configure_nginx_v2ray
  schedule_geolite2_updates
  configure_nginx_logrotate

  systemctl daemon-reload
  systemctl restart nginx
  nginx -s reload

  tilda "$(text 10)"
}

###################################
### GENERATE UUID FOR XRAY CONFIGURATION
###################################
generate_uuid() {
  local XRAY_UUID=$(cat /proc/sys/kernel/random/uuid)
  echo "$XRAY_UUID"
}

###################################
### CREATE LUA AUTHENTICATION SCRIPT FOR HAPROXY
###################################
create_haproxy_auth_lua() {
  read XRAY_UUID < <(generate_uuid)
  read PLACEBO_XRAY_UUID < <(generate_uuid)

  cat > ${DIR_HAPROXY}/.auth.lua <<EOF
local users = {
  ["${USERNAME}"] = "${XRAY_UUID}",
  ["dummy"] = "${PLACEBO_XRAY_UUID}"  -- заглушка
}

-- Убираем дефисы из UUID
local function remove_hyphens(uuid)
  return uuid:gsub("-", "")
end

-- Строим map: clean-uuid -> username
local uuid_map = {}
for username, uuid_dash in pairs(users) do
  local uuid_clean = remove_hyphens(uuid_dash)
  uuid_map[uuid_clean] = username
end

-- Ищем логин по чистому hash (UUID без дефисов)
local function find_user_by_clean_hash(clean_hash)
  return uuid_map[clean_hash]  -- вернёт username или nil
end

-- Функция аутентификации для VLESS
function vless_auth(txn)
  local status, data = pcall(function() return txn.req:dup() end)
  if status and data then
    -- Берём 16 байт пароля из ClientHello
    local sniffed_password = string.sub(data, 2, 17)
    -- core.Info("Received data from client: " .. data)
    -- core.Info("Sniffed raw password: " .. sniffed_password)

    local hex_pass = (sniffed_password:gsub(".", function(c)
      return string.format("%02x", string.byte(c))
    end))
    -- core.Info("Sniffed password hex: " .. hex_pass)

    local found_login = find_user_by_clean_hash(hex_pass)
    if found_login then
      -- txn:Info("login: " .. found_login .. "; ip: " .. txn.sf:src()) 
    return "xray"
    end
  end
  return "http"
end

core.register_fetches("vless_auth", vless_auth)
EOF
}

###################################
### CONFIGURE HAPROXY WITH SSL AND VLESS SUPPORT
###################################
configure_haproxy() {
  info " $(text 37) "
  mkdir -p /etc/haproxy/certs
  create_haproxy_auth_lua

  openssl dhparam -out /etc/haproxy/dhparam.pem 2048
  cat /etc/letsencrypt/live/${DOMAIN}/fullchain.pem /etc/letsencrypt/live/${DOMAIN}/privkey.pem > /etc/haproxy/certs/${DOMAIN}.pem

  cat > /etc/haproxy/haproxy.cfg <<EOF
global
  # Uncomment to enable system logging
  # log /dev/log local0
  # log /dev/log local1 notice
  log /dev/log local2 warning
  lua-load ${DIR_HAPROXY}/.auth.lua
  chroot /var/lib/haproxy
  stats socket /run/haproxy/admin.sock mode 660 level admin
  stats timeout 30s
  user haproxy
  group haproxy
  daemon

  # Mozilla Modern
  ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
  ssl-default-bind-options prefer-client-ciphers no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets
  ssl-default-server-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
  ssl-default-server-options no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets

  # You must first generate DH parameters - [ openssl dhparam -out /etc/haproxy/dhparam.pem 2048 ]
  ssl-dh-param-file /etc/haproxy/dhparam.pem

defaults
  mode tcp
  log global
  option tcplog
  option dontlognull
  timeout connect 5s
  timeout client  1h
  timeout server  1h

frontend haproxy-tls
  mode tcp
  timeout client 1h
  bind 0.0.0.0:443 ssl crt /etc/haproxy/certs/${DOMAIN}.pem alpn h2,http/1.1

  tcp-request inspect-delay 5s
  tcp-request content accept if { req_ssl_hello_type 1 }

  use_backend forbidden if !{ ssl_fc_sni -i ${DOMAIN} } !{ ssl_fc_sni -m end .${DOMAIN} }
  use_backend %[lua.vless_auth]
  default_backend nginx

backend xray
  mode tcp
  server vless 127.0.0.1:10550 send-proxy-v2

backend nginx
  mode http
  option forwardfor
  server web 127.0.0.1:36078

backend forbidden
  mode http
  timeout server 1h
  http-request deny deny_status 403

EOF

  systemctl enable haproxy.service
  haproxy -f /etc/haproxy/haproxy.cfg -c
  systemctl restart haproxy.service

  tilda "$(text 10)"
}

###################################
### DOWNLOAD AND INSTALL XRAY CORE
###################################
install_xray() {
  mkdir -p "${DIR_XRAY}"

  while ! wget -q --progress=dot:mega --timeout=30 --tries=10 --retry-connrefused -P "${DIR_XCORE}/" "https://github.com/XTLS/Xray-core/releases/download/${VERSION_XRAY}/Xray-linux-64.zip"; do
    warning " $(text 38) "
    sleep 3
  done

  unzip -o "${DIR_XCORE}/Xray-linux-64.*" -d "${DIR_XRAY}"
  rm -f ${DIR_XCORE}/Xray-linux-64.*
}

###################################
### CONFIGURE XRAY SERVER SETTINGS
###################################
configure_xray_server() {
  cp -f ${DIR_XCORE}/repo/conf_template/server-vless-raw.json ${DIR_XRAY}/config.json

  sed -i \
    -e "s/USERNAME_TEMP/${USERNAME}/g" \
    -e "s/UUID_TEMP/${XRAY_UUID}/g" \
    "${DIR_XRAY}/config.json"
}

###################################
### SETUP XRAY SYSTEMD SERVICE
###################################
setup_xray_service() {
  cp ${DIR_XCORE}/repo/services/xray.service /etc/systemd/system/xray.service

  systemctl daemon-reload
  systemctl enable xray.service
  systemctl start xray.service
  systemctl restart xray.service
}

###################################
### FULL XRAY SERVER CONFIGURATION
###################################
setup_xray_server() {
  info " $(text 46) "

  install_xray
  configure_xray_server
  setup_xray_service

  tilda "$(text 10)"
}

update_xray() {
  local releases_json
  local lines
  local i

  releases_json=$(curl -s \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/XTLS/Xray-core/releases")

  mapfile -t lines < <(
    echo "$releases_json" \
    | jq -r '
        .[] 
      | "\(.tag_name) \(
          if   .prerelease then "(prerelease)"
          elif .draft      then "(draft)"
          else "(release)" end
        )"
      ' \
    | head -n 15
  )

  echo "Available Xray versions:"
  for i in "${!lines[@]}"; do
    printf "%2d) %s\n" $((i+1)) "${lines[i]}"
  done

  local choice
  while true; do
    read -rp $'\nEnter a version number (0 to cancel): ' choice
    [[ "$choice" =~ ^[0-9]+$ ]] || { echo "Please enter a number."; continue; }
    (( choice == 0 )) && echo "Cancelled." && return 1
    (( choice >= 1 && choice <= ${#lines[@]} )) || { echo "Out of range."; continue; }
    break
  done

  VERSION_XRAY="${lines[choice-1]%% *}"  # отсекаем описание после пробела
  echo "Selected version: $VERSION_XRAY"
  echo
  install_xray
  systemctl restart xray
  sleep 2
  systemctl status xray --no-pager
}

###################################
### SETUP XRAY SUBSCRIPTION PAGE
###################################
setup_xray_subscription_page() {
  mkdir -p /var/www/${SUB_JSON_PATH}/vless_raw/
  cp -r ${DIR_XCORE}/repo/sub_page/* /var/www/${SUB_JSON_PATH}/

  sed -i \
    -e "s/IP_TEMP/${IP4}/g" \
    -e "s/DOMAIN_TEMP/${DOMAIN}/g" \
    -e "s/SUB_JSON_PATH_TEMP/${SUB_JSON_PATH}/g" \
    "/var/www/${SUB_JSON_PATH}/sub.html"
}

###################################
### CONFIGURE XRAY CLIENT SETTINGS
###################################
configure_xray_client() {
  # Устанавливаем TEMPLATE_FILE в зависимости от значения CHAIN
  if [ "$CHAIN" = "false" ]; then
    TEMPLATE_FILE="${DIR_XCORE}/repo/conf_template/client-vless-raw.json"
  else
    TEMPLATE_FILE="${DIR_XCORE}/repo/conf_template/client-vless-raw-chain.json"
  fi

  cp -r "$TEMPLATE_FILE" "/var/www/${SUB_JSON_PATH}/vless_raw/${USERNAME}.json"

  sed -i \
    -e "s/IP_TEMP/${IP4}/g" \
    -e "s/DOMAIN_TEMP/${DOMAIN}/g" \
    -e "s/UUID_TEMP/${XRAY_UUID}/g" \
    "/var/www/${SUB_JSON_PATH}/vless_raw/${USERNAME}.json"
}

###################################
### FULL XRAY CLIENT CONFIGURATION
###################################
setup_xray_client() {
  info " $(text 57) "

  setup_xray_subscription_page
  configure_xray_client

  tilda "$(text 10)"
}

###################################
### SETUP XCORE SYSTEMD SERVICE
###################################
setup_xcore_service() {
  chmod +x "${DIR_XCORE}/repo/cron_jobs/get_v2ray-stat.sh"
  # crontab -l | grep -v -- "get_v2ray-stat.sh" | crontab -
  schedule_cron_job "0 5 * * 1 ${DIR_XCORE}/repo/cron_jobs/get_v2ray-stat.sh"

  bash "${DIR_XCORE}/repo/cron_jobs/get_v2ray-stat.sh"
}

###################################
### CONFIGURE FIREWALL FOR SECURITY
###################################
configure_firewall() {
  info " $(text 47) "

  chmod +x "${DIR_XCORE}/repo/security/f2b.sh"
  bash ${DIR_XCORE}/repo/security/f2b.sh

  BLOCK_ZONE_IP=$(echo ${IP4} | cut -d '.' -f 1-3).0/22

  case "$SYSTEM" in
    Debian|Ubuntu)
      ufw --force reset
      ufw deny from "$BLOCK_ZONE_IP" comment 'Protection from my own subnet (reality of degenerates)'
      ufw deny from 95.161.76.0/24 comment 'TGBOT NL'
      ufw deny from 149.154.161.0/24 comment 'TGBOT NL'
      ufw limit 22/tcp comment 'SSH'
      # ufw allow 80/tcp comment 'WEB over HTTP'
      ufw allow 443/tcp comment 'WEB over HTTPS'
      ufw --force enable
      ;;

    CentOS|Fedora)
      systemctl enable --now firewalld
      firewall-cmd --permanent --zone=public --add-port=22/tcp
      firewall-cmd --permanent --zone=public --add-port=443/tcp
      firewall-cmd --permanent --zone=public --add-rich-rule="rule family='ipv4' source address='$BLOCK_ZONE_IP' reject"
      firewall-cmd --reload
      ;;
  esac

  tilda "$(text 10)"
}

###################################
### CONFIGURE SSH SECURITY SETTINGS
###################################
configure_ssh_security() {
  if [[ "${ANSWER_SSH,,}" == "y" ]]; then
    info " $(text 48) "
    bash <(curl -Ls https://raw.githubusercontent.com/cortez24rus/motd/refs/heads/X/install.sh)

    sed -i -e "
      s/#Port/Port/g;
      s/Port 22/Port 22/g;
      s/#PermitRootLogin/PermitRootLogin/g;
      s/PermitRootLogin yes/PermitRootLogin prohibit-password/g;
      s/#PubkeyAuthentication/PubkeyAuthentication/g;
      s/PubkeyAuthentication no/PubkeyAuthentication yes/g;
      s/#PasswordAuthentication/PasswordAuthentication/g;
      s/PasswordAuthentication yes/PasswordAuthentication no/g;
      s/#PermitEmptyPasswords/PermitEmptyPasswords/g;
      s/PermitEmptyPasswords yes/PermitEmptyPasswords no/g;
    " /etc/ssh/sshd_config

    systemctl restart ssh
    tilda "$(text 10)"
  fi
}

###################################
### DISPLAY FINAL CONFIGURATION OUTPUT
###################################
display_configuration_output() {
  info " $(text 58) "
  echo
  out_data " $(text 59) " "https://${DOMAIN}/${SUB_JSON_PATH}/sub.html?name=${USERNAME}"
  echo
  if [[ ${args[mon]} == "true" ]]; then
    out_data " $(text 21) " "https://${DOMAIN}/${METRICS}/"
    echo
  fi
  if [[ ${args[shell]} == "true" ]]; then
    out_data " $(text 22) " "https://${DOMAIN}/${SHELLBOX}/"
    echo
  fi
  out_data " $(text 62) " "ssh -p 22 ${USERNAME}@${IP4}"
  echo
  out_data " $(text 63) " "$USERNAME"
  out_data " $(text 64) " "$PASSWORD"
  tilda "$(text 10)"
}

###################################
### DOWNLOAD AND MIRROR WEBSITE
###################################
mirror_website() {
  reading " $(text 13) " sitelink
  local NGINX_CONFIG_L="/etc/nginx/locations/root.conf"
  wget -P /var/www --mirror --convert-links --adjust-extension --page-requisites --no-parent https://${sitelink}

  mkdir -p ./testdir
  wget -q -P ./testdir https://${sitelink}
  index=$(ls ./testdir)
  rm -rf ./testdir

  if [[ "$sitelink" =~ "/" ]]
  then
    sitedir=$(echo "${sitelink}" | cut -d "/" -f 1)
  else
    sitedir="${sitelink}"
  fi

  chmod -R 755 /var/www/${sitedir}
  filelist=$(find /var/www/${sitedir} -name ${index})
  slashnum=1000

  for k in $(seq 1 $(echo "$filelist" | wc -l))
  do
    testfile=$(echo "$filelist" | sed -n "${k}p")
    if [ $(echo "${testfile}" | tr -cd '/' | wc -c) -lt ${slashnum} ]
    then
      resultfile="${testfile}"
      slashnum=$(echo "${testfile}" | tr -cd '/' | wc -c)
    fi
  done

  sitedir=${resultfile#"/var/www/"}
  sitedir=${sitedir%"/${index}"}

  NEW_ROOT="  root /var/www/${sitedir};"
  NEW_INDEX="  index ${index};"

  sed -i '/^\s*root\s.*/c\ '"$NEW_ROOT" $NGINX_CONFIG_L
  sed -i '/^\s*index\s.*/c\ '"$NEW_INDEX" $NGINX_CONFIG_L

  systemctl restart nginx.service
}

###################################
### CHANGE DOMAIN NAME AND UPDATE CONFIGS
###################################
change_domain_name() {
  extract_data

  validate_cloudflare_token
  issue_certificates
  cat /etc/letsencrypt/live/${DOMAIN}/fullchain.pem /etc/letsencrypt/live/${DOMAIN}/privkey.pem > /etc/haproxy/certs/${DOMAIN}.pem
  sed -i -e "s/${CURR_DOMAIN}/${DOMAIN}/g" ${DIR_HAPROXY}/haproxy.cfg

  nginx -s reload
  haproxy -c -f ${DIR_HAPROXY}/haproxy.cfg && systemctl restart haproxy
  tilda "$(text 10)"
}

###################################
### REISSUE SSL CERTIFICATES
###################################
reissue_certificates() {
  # Получение домена
  extract_data

  # Проверка наличия сертификатов
  if [ ! -d /etc/letsencrypt/live/${CURR_DOMAIN} ]; then
    validate_cloudflare_token
    issue_certificates
  else
    bash "${DIR_XCORE}/repo/cron_jobs/cert_renew.sh"
    if [ $? -ne 0 ]; then
      return 1
    fi
  fi

  nginx -s reload
  haproxy -c -f ${DIR_HAPROXY}/haproxy.cfg && systemctl restart haproxy
}

###################################
### DISPLAY DIRECTORY SIZE AND SYSTEM STORAGE
###################################
show_directory_size() {
  while true; do
    read -e -p "Enter a directory (press Enter to exit): " DIRECTORY
    if [ -z "$DIRECTORY" ]; then
      echo "Exiting directory size view."
      break
    fi
    if [ ! -d "$DIRECTORY" ]; then
      echo "Error: '$DIRECTORY' is not a valid directory."
      continue
    fi
    echo
    du -ah "${DIRECTORY}" --max-depth=1 | grep -v '/$' | sort -rh | head -20
    echo
  done
}

###################################
### CREATE BACKUP SCRIPT FOR DIRECTORIES
###################################
create_backup_script() {
  chmod +x "${DIR_XCORE}/repo/cron_jobs/backup_dir.sh"
  # crontab -l | grep -v -- "backup_dir.sh" | crontab -
  schedule_cron_job "5 5 * * * ${DIR_XCORE}/repo/cron_jobs/backup_dir.sh"

  bash "${DIR_XCORE}/repo/cron_jobs/backup_dir.sh"
}

###################################
### CREATE BACKUP ROTATION SCRIPT
###################################
create_rotation_script() {
  chmod +x "${DIR_XCORE}/repo/cron_jobs/rotation_backup.sh"
  # crontab -l | grep -v -- "rotation_backup.sh" | crontab -
  schedule_cron_job "10 5 * * * ${DIR_XCORE}/repo/cron_jobs/rotation_backup.sh"

  bash "${DIR_XCORE}/repo/cron_jobs/rotation_backup.sh"
}

###################################
### SCHEDULE BACKUP AND ROTATION
###################################
rotation_and_archiving() {
  info " $(text 23) "

  ${PACKAGE_UPDATE[int]}
  ${PACKAGE_INSTALL[int]} p7zip-full
  mkdir -p "/opt/xcore/backup"
  create_backup_script
  create_rotation_script
  journalctl --vacuum-time=7days

  tilda "$(text 10)"
}

###################################
### UNZIP SELECTED BACKUP ARCHIVE
###################################
unzip_selected_backup() {
  RESTORE_DIR="/tmp/restore"
  BACKUP_DIR="${DIR_XCORE}/backup"

  if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "Ошибка: Директория $BACKUP_DIR не существует."
    exit 1
  fi

  echo
  hint " $(text 101) "

  mapfile -t backups < <(ls "$BACKUP_DIR"/backup_*.7z 2>/dev/null)
  if [[ ${#backups[@]} -eq 0 ]]; then
    echo "Нет доступных резервных копий."
    exit 1
  fi

  for i in "${!backups[@]}"; do
    hint " $((i + 1))) $(basename "${backups[i]}")"
  done

  echo
  reading " $(text 102) " CHOICE_BACKUP

  if [[ ! "$CHOICE_BACKUP" =~ ^[0-9]+$ ]] || (( CHOICE_BACKUP < 1 || CHOICE_BACKUP > ${#backups[@]} )); then
    echo "Ошибка: Неверный ввод."
    exit 1
  fi

  SELECTED_ARCHIVE="${backups[CHOICE_BACKUP - 1]}"
  info " $(text 104) $(basename "$SELECTED_ARCHIVE")"

  mkdir -p "$RESTORE_DIR"
  7za x "$SELECTED_ARCHIVE" -o"$RESTORE_DIR" -y > /dev/null 2>&1 || { echo "Ошибка при разархивировании!"; exit 1; }
}

###################################
### MIGRATE BACKUP FILES TO SYSTEM DIRECTORIES
###################################
migrate_backup_files() {
  DYN_DIR=$(find $RESTORE_DIR -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | awk 'length == 30')

  # Проверяем, что разархивированные данные существуют
  for dir in "$RESTORE_DIR/nginx" "$RESTORE_DIR/haproxy" "$RESTORE_DIR/letsencrypt" "$RESTORE_DIR/v2ray-stat" "$RESTORE_DIR/xray" "$RESTORE_DIR/$DYN_DIR"; do
    if [[ ! -d "$dir" ]]; then
      echo "Ошибка: директория $dir не найдена в разархивированных данных"
      exit 1
    fi
  done

  rsync -a --delete "/tmp/restore/nginx/" "/etc/nginx/"
  rsync -a --delete "/tmp/restore/haproxy/" "/etc/haproxy/"
  rsync -a --delete "/tmp/restore/letsencrypt/" "/etc/letsencrypt/"
  rsync -a --delete "/tmp/restore/xray/" "/usr/local/etc/xray/"
  rsync -a --delete "/tmp/restore/v2ray-stat/" "/usr/local/etc/v2ray-stat/"
  rsync -a --delete "/tmp/restore/$DYN_DIR/" "/var/www/$DYN_DIR/"

  # Перезапускаем службы с проверкой
  for service in nginx haproxy xray v2ray-stat; do
    if systemctl is-active --quiet "$service.service"; then
      systemctl restart "$service.service"
      if ! systemctl is-active --quiet "$service.service"; then
        echo "Ошибка: не удалось перезапустить службу $service"
      fi
    else
      echo "Предупреждение: служба $service не активна или не установлена"
    fi
  done
}

###################################
### RESTORE FROM BACKUP
###################################
restore_from_backup() {
  info " $(text 100) "

  RESTORE_DIR="/tmp/restore"
  unzip_selected_backup
  migrate_backup_files
  rm -rf "$RESTORE_DIR"

  info " $(text 103) "
}

###################################
### DISPLAY TRAFFIC STATISTICS
###################################
show_traffic_statistics() {
  hint " $(text 105) \n"  # Показывает информацию о доступных языках
  reading " $(text 1) " CHOICE_STATS  # Запрашивает выбор языка
  case $CHOICE_STATS in
    1) vnstat -y ;;  # По годам
    2) vnstat -m ;;  # По месяцам
    3) vnstat -d ;;  # По дням
    4) vnstat -h ;;  # По часам
    *) vnstat -d ;;  # По умолчанию - по дням
  esac
  echo
}

###################################
### DISPLAY SERVER STATISTICS
###################################
display_server_stats() {
  clear
  curl -X GET "http://127.0.0.1:9952/api/v1/stats?mode=standard&sort_by=last_seen&sort_order=DESC"
  echo -n "$(text 131) "
}

###################################
### EXTRACT DATA FROM HAPROXY CONFIG
###################################
extract_data() {
  SUB_JSON_PATH=""
  for dir in /var/www/*/ ; do
      dir_name=$(basename "$dir")
      [ ${#dir_name} -eq 30 ] && SUB_JSON_PATH="$dir_name" && break
  done
  if [[ -z "$SUB_JSON_PATH" ]]; then
    error "Ошибка: директория с длиной имени 30 символов не найдена в /var/www/"
  fi

  local CONFIG_FILE_HAPROXY="${DIR_HAPROXY}/haproxy.cfg"
  detect_external_ip
  CURR_DOMAIN=$(grep -oP 'crt /etc/haproxy/certs/\K[^.]+(?:\.[^.]+)+(?=\.pem)' "$CONFIG_FILE_HAPROXY")
  if [[ -z "$CURR_DOMAIN" ]]; then
    error "Ошибка: не удалось извлечь домен из haproxy.cfg"
  fi

#  echo $SUB_JSON_PATH
#  echo $CURR_DOMAIN
#  echo $CONFIG_FILE_HAPROXY
#  echo $IP4
}

###################################
### ADD USER TO XRAY CONFIGURATION
###################################
add_user_to_xray() {
  curl -s -X POST http://127.0.0.1:9952/api/v1/add_user -d "user=${USERNAME}&credential=${XRAY_UUID}&inboundTag=vless-in"
}

###################################
### ADD NEW USER CONFIGURATION
###################################
add_new_user() {
  while true; do
    echo -n "Введите имя пользователя (или '0' для возврата в меню): "
    read USERNAME

    case "$USERNAME" in
      0)
        echo "Возврат в меню..."
        return  # Возврат в меню, завершая функцию
        ;;
      "")
        echo "Имя пользователя не может быть пустым. Попробуйте снова."
        ;;
      *)
        if jq -e ".inbounds[] | select(.tag == \"vless-in\") | .settings.clients[] | select(.email == \"$USERNAME\")" "${DIR_XRAY}/config.json" > /dev/null; then
          echo "Пользователь $USERNAME уже добавлен в Xray. Попробуйте другое имя."
          echo
          continue
        fi

        if [[ -f /var/www/${SUB_JSON_PATH}/vless_raw/${USERNAME}.json ]]; then
          echo "Файл конфигурации для $USERNAME уже существует. Удалите его или выберите другое имя."
          echo
          continue
        fi

        read XRAY_UUID < <(generate_uuid)

        add_user_to_xray
        if [[ $? -ne 0 ]]; then
          echo "Не удалось добавить пользователя через API. Пробуем обновить config.json напрямую..."
          inboundnum=$(jq '[.inbounds[].tag] | index("vless-in")' ${DIR_XRAY}/config.json)
          jq ".inbounds[${inboundnum}].settings.clients += [{\"email\":\"${USERNAME}\",\"id\":\"${XRAY_UUID}\"}]" "${DIR_XRAY}/config.json" > "${DIR_XRAY}/config.json.tmp" && mv "${DIR_XRAY}/config.json.tmp" "${DIR_XRAY}/config.json"

          sed -i "/local users = {/,/}/ s/}/  [\"${USERNAME}\"] = \"${XRAY_UUID}\",\n}/" "${DIR_HAPROXY}/.auth.lua"
        fi
        DOMAIN=$CURR_DOMAIN
        configure_xray_client

        systemctl reload haproxy && systemctl restart xray

        echo "Пользователь $USERNAME добавлен с UUID: $XRAY_UUID"
        echo
        ;;
    esac
  done
}

###################################
### DELETE USER SUBSCRIPTION CONFIG
###################################
delete_subscription_config() {
  if [[ -f /var/www/${SUB_JSON_PATH}/vless_raw/${USERNAME}.json ]]; then
    rm -rf /var/www/${SUB_JSON_PATH}/vless_raw/${USERNAME}.json
  fi
}

##################################
### DELETE USER FROM XRAY SERVER CONFIG
###################################
delete_from_xray_server() {
  curl -X DELETE "http://127.0.0.1:9952/api/v1/delete_user?user=${USERNAME}&inboundTag=vless-in"
}

###################################
### EXTRACT USERS FROM XRAY CONFIG
###################################
extract_xray_users() {
  jq -r '.inbounds[] | select(.tag == "vless-in") | .settings.clients[] | "\(.email) \(.id)"' "${DIR_XRAY}/config.json"
}

###################################
### DELETE USER CONFIGURATION
###################################
delete_user() {
  while true; do
    mapfile -t clients < <(extract_xray_users)
    if [ ${#clients[@]} -eq 0 ]; then
      echo "Нет пользователей для отображения."
      return
    fi

    info " Список пользователей:"
    local count=1
    declare -A user_map

    for client in "${clients[@]}"; do
      IFS=' ' read -r email id <<< "$client"
      echo "$count. $email (ID: $id)"
      user_map[$count]="$email $id"
      ((count++))
    done
    echo "0. Выйти"

    # Запрос на выбор пользователей
    read -p "Введите номера пользователей через запятую: " choices
    echo

    # Разбиение введенных номеров на массив
    IFS=', ' read -r -a selected_users <<< "$choices"
    for choice in "${selected_users[@]}"; do
      case "$choice" in
        0)
          echo "Выход..."
          return
          ;;
        ''|*[!0-9]*)
          echo "Ошибка: введите корректный номер."
          ;;
        *)
          if [[ -n "${user_map[$choice]}" ]]; then
            IFS=' ' read -r USERNAME XRAY_UUID <<< "${user_map[$choice]}"
            echo "Вы выбрали: $USERNAME (ID: $XRAY_UUID)"
            
            delete_from_xray_server
            if [[ $? -ne 0 ]]; then
              echo "Не удалось удалить пользователя через API. Пробуем обновить config.json напрямую..."
              inboundnum=$(jq '[.inbounds[].tag] | index("vless-in")' ${DIR_XRAY}/config.json)
              jq "del(.inbounds[${inboundnum}].settings.clients[] | select(.email==\"${USERNAME}\"))" "${DIR_XRAY}/config.json" > "${DIR_XRAY}/config.json.tmp" && mv "${DIR_XRAY}/config.json.tmp" "${DIR_XRAY}/config.json"

              sed -i "/\[\"${USERNAME//\"/\\\"}\"\] = \".*\",/d" "${DIR_HAPROXY}/.auth.lua"
            fi
            delete_subscription_config
          else
            echo "Некорректный номер: $choice"
          fi
          ;;
      esac
    done
  systemctl reload nginx && systemctl reload haproxy && systemctl restart xray
  echo
  echo "|--------------------------------------------------------------------------|"
  echo
  done
}

###################################
### SYNCHRONIZE CLIENT CONFIGURATIONS
###################################
sync_client_configs() {
  SUB_DIR="/var/www/${SUB_JSON_PATH}/vless_raw/"

  # Устанавливаем TEMPLATE_FILE в зависимости от значения CHAIN
  if [ "$CHAIN" = "false" ]; then
    TEMPLATE_FILE="${DIR_XCORE}/repo/conf_template/client-vless-raw.json"
  else
    TEMPLATE_FILE="${DIR_XCORE}/repo/conf_template/client-vless-raw-chain.json"
  fi

  # Проверка, является ли шаблон валидным JSON
  jq . "$TEMPLATE_FILE" >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Ошибка: Файл шаблона $TEMPLATE_FILE содержит невалидный JSON"
    sleep 3
    return 1
  fi

  for FILE_PATH in ${SUB_DIR}*.json; do
    FILENAME=$(basename "$FILE_PATH")

    # Получаем индекс исходящего подключения с тегом "vless-out"
    OUT_VL_NUM=$(jq '[.outbounds[].tag] | index("vless-out")' "$FILE_PATH")
    if [ -z "$OUT_VL_NUM" ]; then
      echo "Ошибка: в файле $FILENAME"
      continue
    fi

    CLIENT=$(jq -c '.outbounds['"$OUT_VL_NUM"'].settings.vnext[].users | if type=="object" then [.] else . end' "$FILE_PATH")

    # Проверяем, что CLIENT не пустой и является валидным JSON  
    echo "$CLIENT" | jq . >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo "Ошибка: Некорректный JSON в CLIENT для файла $FILENAME: $CLIENT"
      continue
    fi
    if [ -z "$CLIENT" ] || [ "$CLIENT" = "[]" ]; then
      echo "Ошибка: Пустой или отсутствующий массив users для файла $FILENAME"
      continue
    fi

    # Удаляем старый файл и копируем шаблон
    rm -rf ${FILE_PATH}
    cp -r "$TEMPLATE_FILE" "${FILE_PATH}"

    # Обновляем массив users в новом файле
    echo "$(jq ".outbounds[${OUT_VL_NUM}].settings.vnext[].users = ${CLIENT}" ${FILE_PATH})" > $FILE_PATH

    # Заменяем заполнители DOMAIN_TEMP и IP_TEMP
    sed -i \
      -e "s/DOMAIN_TEMP/${CURR_DOMAIN}/g" \
      -e "s/IP_TEMP/${IP4}/g" \
      "${FILE_PATH}"

    echo "Файл $FILENAME успешно обновлен."
  done
  sleep 3
}

###################################
### ADD XRAY CHAIN
###################################
add_xray_config_chain() {
  read -rp "Введи ссылку на подписку: " link

  resp=$(curl -s -w '%{http_code}' "$link")
  http_code="${resp: -3}"
  body="${resp::-3}"

  if [[ "$http_code" != 2* ]]; then
    echo "Ошибка HTTP: код $http_code" >&2
    return 1
  fi

  # Проверяем JSON синтаксис
  if ! jq -e . >/dev/null 2>&1 <<<"$body"; then
    echo "Невалидный JSON по ссылке $link" >&2
    return 1
  fi

  # Извлекаем нужный outbound
  remote_outbound=$(jq -c '.outbounds[] | select(.tag=="vless-out") | .tag="vless-out-chain"' <<<"$body")
  if [ -z "$remote_outbound" ]; then
    echo "Тег vless-out не найден в JSON по ссылке $link" >&2
    sleep 3
    return 1
  fi

  # Извлекаем массив clients из inbound с тегом "vless-in" из config.json
  clients=$(jq -c '.inbounds[] | select(.tag=="vless-in") | .settings.clients' "${DIR_XRAY}/config.json")
  if [ -z "$clients" ] || [ "$clients" = "[]" ]; then
    echo "Ошибка: Не найден или пустой массив clients в inbound с тегом 'vless-in' в файле ${DIR_XRAY}/config.json"
    sleep 3
    return 1
  fi

  # Копируем шаблон конфигурации
  cp "${DIR_XCORE}/repo/conf_template/server-vless-raw-chain.json" "${DIR_XRAY}/config.json"

  # Обновляем массив users в outbound с тегом "vless-out-chain"
  jq --argjson new_outbound "$remote_outbound" \
    '.outbounds |= map(if .tag == "vless-out-chain" then $new_outbound else . end)' \
    "${DIR_XRAY}/config.json" > "${DIR_XRAY}/config.json.tmp" \
    && mv "${DIR_XRAY}/config.json.tmp" "${DIR_XRAY}/config.json"
  if [ $? -ne 0 ]; then
    echo "Ошибка: Не удалось обновить outbound с тегом 'vless-out-chain' в ${DIR_XRAY}/config.json"
    sleep 3
    return 1
  fi

  # Обновляем массив clients в inbound с тегом "vless-in"
  jq --argjson new_clients "$clients" \
    '.inbounds |= map(if .tag == "vless-in" then .settings.clients = $new_clients else . end)' \
    "${DIR_XRAY}/config.json" > "${DIR_XRAY}/config.json.tmp" \
    && mv "${DIR_XRAY}/config.json.tmp" "${DIR_XRAY}/config.json"
  if [ $? -ne 0 ]; then
    echo "Ошибка: Не удалось обновить массив clients в ${DIR_XRAY}/config.json"
    sleep 3
    return 1
  fi

  # Заменяем заполнители в config.json
  sed -i \
    -e "s/IP_TEMP/${IP4}/g" \
    -e "s/DOMAIN_TEMP/${CURR_DOMAIN}/g" \
    "${DIR_XRAY}/config.json"
}


###################################
### REMOVE XRAY CHAIN
###################################
remove_xray_config_chain() {
  # Извлекаем массив clients из inbound с тегом "vless-in" из config.json
  clients=$(jq -c '.inbounds[] | select(.tag=="vless-in") | .settings.clients' "${DIR_XRAY}/config.json")
  if [ -z "$clients" ] || [ "$clients" = "[]" ]; then
    echo "Ошибка: Не найден или пустой массив clients в inbound с тегом 'vless-in' в файле ${DIR_XRAY}/config.json"
    sleep 3
    return 1
  fi

  # Копируем шаблон конфигурации
  cp "${DIR_XCORE}/repo/conf_template/server-vless-raw.json" "${DIR_XRAY}/config.json"

  # Обновляем массив clients в inbound с тегом "vless-in"
  jq --argjson new_clients "$clients" \
    '.inbounds |= map(if .tag == "vless-in" then .settings.clients = $new_clients else . end)' \
    "${DIR_XRAY}/config.json" > "${DIR_XRAY}/config.json.tmp" \
    && mv "${DIR_XRAY}/config.json.tmp" "${DIR_XRAY}/config.json"
  if [ $? -ne 0 ]; then
    echo "Ошибка: Не удалось обновить массив clients в ${DIR_XRAY}/config.json"
    sleep 3
    return 1
  fi

  # Заменяем заполнители в config.json
  sed -i \
    -e "s/IP_TEMP/${IP4}/g" \
    -e "s/DOMAIN_TEMP/${CURR_DOMAIN}/g" \
    "${DIR_XRAY}/config.json"
}

###################################
### DISPLAY USER LIST FROM API
###################################
display_user_list() {
  local API_URL="http://127.0.0.1:9952/api/v1/users"
  local field="$1"  # Поле для извлечения, например "enabled", "lim_ip", "renew", "sub_end"

  declare -gA user_map
  local counter=0

  # Получаем данные от API
  response=$(curl -s -X GET "$API_URL")
  if [ $? -ne 0 ]; then
    warning "Ошибка: Не удалось подключиться к API"
    return 1
  fi

  # Парсим JSON, извлекая email и указанное поле
  mapfile -t users < <(echo "$response" | jq -r --arg field "$field" '.[] | [.user, .[$field]] | join("|")')

  if [ ${#users[@]} -eq 0 ]; then
    info "Нет пользователей для отображения"
    return 1
  fi

  info " Список пользователей:"
  for user in "${users[@]}"; do
    IFS='|' read -r email value <<< "$user"
    user_map[$counter]="$email"
    echo " $((counter+1)). $email ($field: ${value:-не задано})"
    ((counter++))
  done

  # Сохраняем user_map и users для использования в вызывающей функции
  export user_map
  export users
  return 0
}

###################################
### UPDATE USER PARAMETER VIA API
###################################
update_user_parameter_get() {
  local param_name="$1"
  local api_url="$2"
  local prompt="$3"

  local param_value

  # Запрос нового значения
  read -p "$prompt: " param_value
  clear

  while true; do
    # Получаем и отображаем список пользователей
    display_user_list "$param_name"
    if [ $? -ne 0 ]; then
      return 1
    fi

    info " (Выбрано значение $param_name: $param_value)"
    read -p " Введите номера пользователей (0 - выход, \"reset\" - изменить $param_name): " choice

    if [[ "$choice" == "0" ]]; then
      info "Выход..."
      return
    fi

    if [[ "$choice" == "reset" ]]; then
      clear
      read -p "$prompt: " param_value
      continue
    fi

    # Разбиваем ввод на массив номеров
    choices=($(echo "$choice" | tr ',' ' ' | tr -s ' ' | tr ' ' '\n'))

    # Проверяем каждый номер
    for num in "${choices[@]}"; do
      if [[ ! "$num" =~ ^[0-9]+$ ]] || (( num < 1 || num > ${#users[@]} )); then
        warning "Некорректный номер пользователя: $num. Попробуйте снова."
        continue 2
      fi
    done

    clear
    # Обновляем параметр для выбранных пользователей
    for num in "${choices[@]}"; do
      selected_email="${user_map[$((num-1))]}"
      curl -s -X GET "${api_url}?user=${selected_email}&$param_name=${param_value}"
    done
  done
}

###################################
### UPDATE USER PARAMETER VIA API
###################################
update_user_parameter_patch() {
  local param_name="$1"  # Название параметра, например "lim_ip", "renew", "offset", "count"
  local api_url="$2"     # URL для GET-запроса
  local prompt="$3"      # Текст для запроса нового значения

  last_selected_num=""
  local param_value

  # Запрос нового значения
  read -p "$prompt: " param_value
  clear

  while true; do
    # Получаем и отображаем список пользователей
    display_user_list "$param_name"
    if [ $? -ne 0 ]; then
      return 1
    fi

    info " (Выбрано значение $param_name: $param_value)"
    # Если последний выбранный номер существует, предлагаем его по умолчанию
    if [ -n "$last_selected_num" ]; then
      read -p " Введите номера пользователей (0 - выход, 'reset' - изменить $param_name): " choice
    else
      read -p " Введите номера пользователей (0 - выход, 'reset' - изменить $param_name): " choice
    fi

    # Если нажат Enter и есть последний выбор, используем его
    if [ -z "$choice" ] && [ -n "$last_selected_num" ]; then
      choice="$last_selected_num"
    fi

    if [[ "$choice" == "0" ]]; then
      info "Выход..."
      return
    fi

    if [[ "$choice" == "reset" ]]; then
      clear
      read -p "$prompt: " param_value
      continue
    fi

    # Разбиваем ввод на массив номеров
    choices=($(echo "$choice" | tr ',' ' ' | tr -s ' ' | tr ' ' '\n'))

    # Проверяем каждый номер
    for num in "${choices[@]}"; do
      if [[ ! "$num" =~ ^[0-9]+$ ]] || (( num < 1 || num > ${#users[@]} )); then
        warning "Некорректный номер пользователя: $num. Попробуйте снова."
        continue 2
      fi
    done

    clear
    # Обновляем параметр для выбранных пользователей и запоминаем последний номер
    for num in "${choices[@]}"; do
      selected_email="${user_map[$((num-1))]}"
      curl -s -X PATCH "${api_url}?user=${selected_email}&$param_name=${param_value}"
      # Запоминаем последний выбранный номер
      last_selected_num="$num"
    done
  done
}

###################################
### DNS
###################################
fetch_dns_stats() {
  update_user_parameter_get "count" "http://127.0.0.1:9952/api/v1/dns_stats" "Введите значение для вывода строк DNS запросов"
}

###################################
### TOGGLE USER STATUS VIA API
###################################
toggle_user_status() {
  update_user_parameter_patch "enabled" "http://127.0.0.1:9952/api/v1/set_enabled" "Введите true для включения и false отключения клиента"
}

###################################
### SET IP LIMIT FOR USER
###################################
set_user_lim_ip() {
  update_user_parameter_patch "lim_ip" "http://127.0.0.1:9952/api/v1/update_lim_ip" "Введите лимит IP"
}

###################################
### UPDATE USER RENEWAL STATUS
###################################
update_user_renewal() {
  update_user_parameter_patch "renew" "http://127.0.0.1:9952/api/v1/update_renew" "Введите значение для продления подписки"
}

###################################
### ADJUST USER SUBSCRIPTION END DATE
###################################
adjust_subscription_date() {
  update_user_parameter_patch "sub_end" "http://127.0.0.1:9952/api/v1/adjust_date" "Введите значение sub_end (например, +1, -1:3, 0)"
}

###################################
### REMOVE ESCAPE SEQUENCES FROM LOG FILE
###################################
clean_log_file() {
  sed -i -e 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$LOGFILE"
}

###################################
### RESET STATISTICS SUBMENU
###################################
reset_stats_menu() {
  while true; do
    clear
    display_xcore_banner
    tilda "|--------------------------------------------------------------------------|"
    info " $(text 107) "    # 1. Clear DNS query statistics
    info " $(text 108) "    # 2. Reset inbound traffic statistics
    info " $(text 109) "    # 3. Reset client traffic statistics
    info " $(text 110) "    # 4. Сброс трафика network
    echo
    warning " $(text 84) "  # 0. Previous menu
    tilda "|--------------------------------------------------------------------------|"
    echo
    reading " $(text 1) " CHOICE_MENU
    case $CHOICE_MENU in
      1)
        curl -s -X POST http://127.0.0.1:9952/api/v1/delete_dns_stats && info " $(text 111) " || warning " $(text 112) "
        sleep 2
        ;;
      2)
        curl -s -X POST http://127.0.0.1:9952/api/v1/reset_traffic_stats && info " $(text 111) " || warning " $(text 112) "
        sleep 2
        ;;
      3)
        curl -s -X POST http://127.0.0.1:9952/api/v1/reset_clients_stats && info " $(text 111) " || warning " $(text 112) "
        sleep 2
        ;;
      4)
        curl -s -X POST http://127.0.0.1:9952/api/v1/reset_traffic && info " $(text 111) " || warning " $(text 112) "
        sleep 2
        ;;
      0) break ;;
      *) warning " $(text 76) " ;;
    esac
  done
}

###################################
### MANAGE XRAY CHAIN MENU
###################################
manage_xray_chain_menu() {
  while true; do
    clear
    display_xcore_banner
    tilda "|--------------------------------------------------------------------------|"
    info " $(text 117) "    # 1. Add server chain for routing
    info " $(text 118) "    # 2. Remove server chain from configuration
    echo
    warning " $(text 84) "  # 0. Previous menu
    tilda "|--------------------------------------------------------------------------|"
    echo
    reading " $(text 1) " CHOICE_MENU
    tilda "$(text 10)"
    case $CHOICE_MENU in
      1)
        add_xray_config_chain
        if [[ $? -eq 0 ]]; then
          systemctl restart xray
          sed -i "s/^CHAIN=.*/CHAIN=true/" "${DIR_XCORE}/xcore.conf"
          source "${DIR_XCORE}/xcore.conf"
          sync_client_configs
        else
          warning " $(text 119) "
          sleep 3
        fi
        ;;
      2) 
        remove_xray_config_chain
        if [[ $? -eq 0 ]]; then
          systemctl restart xray
          sed -i "s/^CHAIN=.*/CHAIN=false/" "${DIR_XCORE}/xcore.conf"
          source "${DIR_XCORE}/xcore.conf"
          sync_client_configs
        else
          warning " $(text 119) "
          sleep 3
        fi
        ;;
      0) manage_xray_core ;;
      *) warning " $(text 76) " ;;
    esac
  done
}

###################################
### XRAY CORE MANAGEMENT MENU
###################################
manage_xray_core() {
  while true; do
    clear
    extract_data
    display_xcore_banner
    tilda "|--------------------------------------------------------------------------|"
    info " $(text 120) "    # 1. Show Xray server statistics
    info " $(text 121) "    # 2. View client DNS queries
    info " $(text 122) "    # 3. Reset Xray server statistics
    echo
    info " $(text 123) "    # 4. Add new client
    info " $(text 124) "    # 5. Delete client
    info " $(text 125) "    # 6. Enable or disable client
    echo
    info " $(text 126) "    # 7. Set client IP address limit
    info " $(text 127) "    # 8. Update subscription auto-renewal status
    info " $(text 128) "    # 9. Change subscription end date
    echo
    info " $(text 129) "    # 10. Synchronize client subscription configurations
    info " $(text 130) "    # 11. Configure server chain
    echo
    warning " $(text 84) "  # 0. Previous menu
    tilda "|--------------------------------------------------------------------------|"
    echo
    reading " $(text 1) " CHOICE_MENU
    tilda "$(text 10)"
    case $CHOICE_MENU in
      1)
        while true; do
          display_server_stats
          read -t 10 -r STATS_CHOICE
          [[ "$STATS_CHOICE" == "0" ]] && break
        done
        ;;
      2) fetch_dns_stats ;;
      3) reset_stats_menu ;;
      4) add_new_user ;;
      5) delete_user ;;
      6) toggle_user_status ;;
      7) set_user_lim_ip ;;
      8) update_user_renewal ;;
      9) adjust_subscription_date ;;
      10) sync_client_configs ;;
      11) manage_xray_chain_menu ;;
      0) manage_xcore ;;
      *) warning " $(text 76) " ;;
    esac
  done
}

###################################
### XCORE MANAGEMENT MENU
###################################
manage_xcore() {
  while true; do
    clear
    display_xcore_banner
    tilda "|--------------------------------------------------------------------------|"
    info " $(text 87) "    # 1. Perform standard installation
    echo
    info " $(text 88) "    # 2. Restore from backup
    info " $(text 89) "    # 3. Change proxy domain name
    info " $(text 90) "    # 4. Reissue SSL certificates
    echo
    info " $(text 91) "    # 5. Copy website to server
    info " $(text 92) "    # 6. Show directory size
    info " $(text 93) "    # 7. Show traffic statistics
    echo
    info " $(text 94) "    # 8. Update Xray core
    info " $(text 95) "    # X. Manage Xray core
    echo
    info " $(text 96) "    # 9. Change interface language
    echo
    warning " $(text 84) " # 0. Previous menu
    tilda "|--------------------------------------------------------------------------|"
    echo
    reading " $(text 1) " CHOICE_MENU        # Choise
    tilda "$(text 10)"
    case $CHOICE_MENU in
      1)
        enable_logging
        clear
        install_dependencies
        display_xcore_banner
        display_pre_install_warning
        collect_user_data
        [[ ${args[utils]} == "true" ]] && install_utility_packages
        [[ ${args[autoupd]} == "true" ]] && configure_auto_updates
        [[ ${args[bbr]} == "true" ]] && enable_bbr_optimization
        [[ ${args[ipv6]} == "true" ]] && disable_ipv6_support
      	[[ ${args[warp]} == "true" ]] && configure_warp
        [[ ${args[cert]} == "true" ]] && issue_certificates
        [[ ${args[mon]} == "true" ]] && setup_node_exporter
        [[ ${args[shell]} == "true" ]] && setup_shell_in_a_box
        update_xcore_manager
        apply_random_website_template
        [[ ${args[nginx]} == "true" ]] && setup_nginx
        configure_haproxy
        [[ ${args[xray]} == "true" ]] && setup_xray_server
        [[ ${args[xray]} == "true" ]] && setup_xray_client
        setup_xcore_service
        save_defaults_to_config
        rotation_and_archiving
        [[ ${args[firewall]} == "true" ]] && configure_firewall
        [[ ${args[ssh]} == "true" ]] && configure_ssh_security
        display_configuration_output
        disable_logging
        clean_log_file
        ;;
      2)
        if [ ! -d "/opt/xcore/backup" ]; then
          rotation_and_archiving
        fi
        restore_from_backup
        ;;
      3) change_domain_name ;;
      4) reissue_certificates ;;
      5) mirror_website ;;
      6) 
        free -h
        echo
        show_directory_size ;;
      7) show_traffic_statistics ;;
      8) update_xray ;;
      9)
        configure_language
        ;;
      x|X) manage_xray_core ;;
      0)
        clear
        exit 0
        ;;
      *) warning " $(text 76) " ;;
    esac
    info " $(text 85) "
    read -r dummy
  done
  clean_log_file
}

###################################
### FUNCTION INITIALIZE CONFIG
###################################
init_file() {
  if [ ! -f "${DIR_XCORE}/xcore.conf" ]; then
    mkdir -p ${DIR_XCORE}
    cat > "${DIR_XCORE}/xcore.conf" << EOF
LANGUAGE=EU
CHAIN=false
EOF
  fi
}

###################################
### MAIN FUNCTION
###################################
main() {
  init_file
  source "${DIR_XCORE}/xcore.conf"
  load_defaults_from_config
  parse_command_line_args "$@" || display_help_message
  verify_root_privileges
  detect_external_ip
  detect_operating_system
  echo
  manage_xcore
}

main "$@"
