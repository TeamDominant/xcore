#!/usr/bin/env bash

###################################
### Global values
###################################
VERSION_MANAGER='0.7.2'
VERSION_XRAY='25.1.30'

DIR_REVERSE_PROXY="/usr/local/reverse_proxy/"
DIR_XRAY="/usr/local/etc/xray/"
LUA_PATH="/etc/haproxy/.auth.lua"
DB_PATH="/usr/local/reverse_proxy/projectgo/reverse.db"

REPO_URL="https://github.com/cortez24rus/reverse_proxy/archive/refs/heads/main.tar.gz"

###################################
### Initialization and Declarations
###################################
declare -A defaults
declare -A args
declare -A regex
declare -A generate

###################################
### Regex Patterns for Validation
###################################
regex[domain]="^([a-zA-Z0-9-]+)\.([a-zA-Z0-9-]+\.[a-zA-Z]{2,})$"
regex[port]="^[1-9][0-9]*$"
regex[username]="^[a-zA-Z0-9]+$"
regex[ip]="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
regex[tgbot_token]="^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$"
regex[tgbot_admins]="^[a-zA-Z][a-zA-Z0-9_]{4,31}(,[a-zA-Z][a-zA-Z0-9_]{4,31})*$"
regex[domain_port]="^[a-zA-Z0-9]+([-.][a-zA-Z0-9]+)*\.[a-zA-Z]{2,}(:[1-9][0-9]*)?$"
regex[file_path]="^[a-zA-Z0-9_/.-]+$"
regex[url]="^(http|https)://([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})(:[0-9]{1,5})?(/.*)?$"
generate[path]="tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30"

###################################
### INFO
###################################
out_data()   { echo -e "\e[1;33m$1\033[0m \033[1;37m$2\033[0m"; }
tilda()      { echo -e "\033[31m\033[38;5;214m$*\033[0m"; }
warning()    { echo -e "\033[31m [!]\033[38;5;214m$*\033[0m"; }
error()      { echo -e "\033[31m\033[01m$*\033[0m"; exit 1; }
info()       { echo -e "\033[32m\033[01m$*\033[0m"; }
question()   { echo -e "\033[32m[?]\e[1;33m$*\033[0m"; }
hint()       { echo -e "\033[33m\033[01m$*\033[0m"; }
reading()    { read -rp " $(question "$1")" "$2"; }
text()       { eval echo "\${${L}[$*]}"; }
text_eval()  { eval echo "\$(eval echo "\${${L}[$*]}")"; }

###################################
### Languages
###################################
E[0]="Language:\n  1. English (default) \n  2. Русский"
R[0]="Язык:\n  1. English (по умолчанию) \n  2. Русский"
E[1]="Choose an action:"
R[1]="Выбери действие:"
E[2]="Error: this script requires superuser (root) privileges to run."
R[2]="Ошибка: для выполнения этого скрипта необходимы права суперпользователя (root)."
E[3]="Unable to determine IP address."
R[3]="Не удалось определить IP-адрес."
E[4]="Reinstalling script..."
R[4]="Повторная установка скрипта..."
E[5]="WARNING!"
R[5]="ВНИМАНИЕ!"
E[6]="It is recommended to perform the following actions before running the script"
R[6]="Перед запуском скрипта рекомендуется выполнить следующие действия"
E[7]="Annihilation of the system!"
R[7]="Аннигиляция системы!"
E[8]=""
R[8]=""
E[9]="CANCEL"
R[9]="ОТМЕНА"
E[10]="\n|--------------------------------------------------------------------------|\n"
R[10]="\n|--------------------------------------------------------------------------|\n"
E[11]="Enter username:"
R[11]="Введите имя пользователя:"
E[12]="Enter user password:"
R[12]="Введите пароль пользователя:"
E[13]="Enter your domain A record:"
R[13]="Введите доменную запись типа A:"
E[14]="Error: the entered address '$temp_value' is incorrectly formatted."
R[14]="Ошибка: введённый адрес '$temp_value' имеет неверный формат."
E[15]="Enter your email registered with Cloudflare:"
R[15]="Введите вашу почту, зарегистрированную на Cloudflare:"
E[16]="Enter your Cloudflare API token (Edit zone DNS) or global API key:"
R[16]="Введите ваш API токен Cloudflare (Edit zone DNS) или Cloudflare global API key:"
E[17]="Verifying domain, API token/key, and email..."
R[17]="Проверка домена, API токена/ключа и почты..."
E[18]="Error: invalid domain, API token/key, or email. Please try again."
R[18]="Ошибка: неправильно введён домен, API токен/ключ или почта. Попробуйте снова."
E[19]=""
R[19]=""
E[20]="Error: failed to connect to WARP. Manual acceptance of the terms of service is required."
R[20]="Ошибка: не удалось подключиться к WARP. Требуется вручную согласиться с условиями использования."
E[21]="Access link to node exporter:"
R[21]="Доступ по ссылке к node exporter:"
E[22]="Access link to shell in a box:"
R[22]="Доступ по ссылке к shell in a box:"
E[23]="Creating a backup and rotation."
R[23]="Создание резевной копии и ротация."
E[24]="Enter Node Exporter path:"
R[24]="Введите путь к Node Exporter:"
E[25]=""
R[25]=""
E[26]=""
R[26]=""
E[27]="Enter subscription path:"
R[27]="Введите путь к подписке:"
E[28]=""
R[28]=""
E[29]="Error: path cannot be empty, please re-enter."
R[29]="Ошибка: путь не может быть пустым, повторите ввод."
E[30]="Error: path must not contain characters {, }, /, $, \\, please re-enter."
R[30]="Ошибка: путь не должен содержать символы {, }, /, $, \\, повторите ввод."
E[31]=""
R[31]=""
E[32]=""
R[32]="."
E[33]="Error: invalid choice, please try again."
R[33]="Ошибка: неверный выбор, попробуйте снова."
E[34]=""
R[34]=""
E[35]=""
R[35]=""
E[36]="Updating system and installing necessary packages."
R[36]="Обновление системы и установка необходимых пакетов."
E[37]="Configuring Haproxy."
R[37]="Настройка Haproxy."
E[38]="Download failed, retrying..."
R[38]="Скачивание не удалось, пробуем снова..."
E[39]="Adding user."
R[39]="Добавление пользователя."
E[40]="Enabling automatic security updates."
R[40]="Автоматическое обновление безопасности."
E[41]="Enabling BBR."
R[41]="Включение BBR."
E[42]="Disabling IPv6."
R[42]="Отключение IPv6."
E[43]="Configuring WARP."
R[43]="Настройка WARP."
E[44]="Issuing certificates."
R[44]="Выдача сертификатов."
E[45]="Configuring NGINX."
R[45]="Настройка NGINX."
E[46]="Setting Xray."
R[46]="Настройка Xray."
E[47]="Configuring UFW."
R[47]="Настройка UFW."
E[48]="Configuring SSH."
R[48]="Настройка SSH."
E[49]="Generate a key for your OS (ssh-keygen)."
R[49]="Сгенерируйте ключ для своей ОС (ssh-keygen)."
E[50]="In Windows, install the openSSH package and enter the command in PowerShell (recommended to research key generation online)."
R[50]="В Windows нужно установить пакет openSSH и ввести команду в PowerShell (рекомендуется изучить генерацию ключей в интернете)."
E[51]="If you are on Linux, you probably know what to do C:"
R[51]="Если у вас Linux, то вы сами все умеете C:"
E[52]="Command for Windows:"
R[52]="Команда для Windows:"
E[53]="Command for Linux:"
R[53]="Команда для Linux:"
E[54]="Configure SSH (optional step)? [y/N]:"
R[54]="Настроить SSH (необязательный шаг)? [y/N]:"
E[55]="Error: Keys not found. Please add them to the server before retrying..."
R[55]="Ошибка: ключи не найдены, добавьте его на сервер, прежде чем повторить..."
E[56]="Key found, proceeding with SSH setup."
R[56]="Ключ найден, настройка SSH."
E[57]="Client-side configuration."
R[57]="Настройка клиентской части."
E[58]="SAVE THIS SCREEN!"
R[58]="СОХРАНИ ЭТОТ ЭКРАН!"
E[59]="Subscription page link:"
R[59]="Ссылка на страницу подписки:"
E[60]=""
R[60]=""
E[61]=""
R[61]=":"
E[62]="SSH connection:"
R[62]="Подключение по SSH:"
E[63]="Username:"
R[63]="Имя пользователя:"
E[64]="Password:"
R[64]="Пароль:"
E[65]="Log file path:"
R[65]="Путь к лог файлу:"
E[66]="Prometheus monitor."
R[66]="Мониторинг Prometheus."
E[67]=""
R[67]=""
E[68]=""
R[68]=""
E[69]=""
R[69]=""
E[70]="Secret key:"
R[70]="Секретный ключ:"
E[71]="Current operating system is \$SYS.\\\n The system lower than \$SYSTEM \${MAJOR[int]} is not supported. Feedback: [https://github.com/cortez24rus/xui-reverse-proxy/issues]"
R[71]="Текущая операционная система: \$SYS.\\\n Система с версией ниже, чем \$SYSTEM \${MAJOR[int]}, не поддерживается. Обратная связь: [https://github.com/cortez24rus/xui-reverse-proxy/issues]"
E[72]="Install dependence-list:"
R[72]="Список зависимостей для установки:"
E[73]="All dependencies already exist and do not need to be installed additionally."
R[73]="Все зависимости уже установлены и не требуют дополнительной установки."
E[74]="OS - $SYS"
R[74]="OS - $SYS"
E[75]="Invalid option for --$key: $value. Use 'true' or 'false'."
R[75]="Неверная опция для --$key: $value. Используйте 'true' или 'false'."
E[76]="Unknown option: $1"
R[76]="Неверная опция: $1"
E[77]="List of dependencies for installation:"
R[77]="Список зависимостей для установки:"
E[78]="All dependencies are already installed and do not require additional installation."
R[78]="Все зависимости уже установлены и не требуют дополнительной установки."
E[79]="Configuring site template."
R[79]="Настройка шаблона сайта."
E[80]="Random template name:"
R[80]="Случайное имя шаблона:"
E[81]="Enter your domain CNAME record:"
R[81]="Введите доменную запись типа CNAME:"
E[82]="Enter Shell in a box path:"
R[82]="Введите путь к Shell in a box:"
E[83]="Terminal emulator Shell in a box."
R[83]="Эмулятор терминала Shell in a box."
E[84]="0. Exit script"
R[84]="0. Выход из скрипта"
E[85]="Press Enter to return to the menu..."
R[85]="Нажмите Enter, чтобы вернуться в меню..."
E[86]="Reverse proxy manager $VERSION_MANAGER"
R[86]="Reverse proxy manager $VERSION_MANAGER"
E[87]="1. Standard installation"
R[87]="1. Стандартная установка"
E[88]="2. Restore from a rescue copy."
R[88]="2. Восстановление из резевной копии."
E[89]="3. Migration to a new version with client retention."
R[89]="3. Миграция на новую версию с сохранением клиентов."
E[90]="4. Change the domain name for the proxy."
R[90]="4. Изменить доменное имя для прокси."
E[91]="5. Forced reissue of certificates."
R[91]="5. Принудительный перевыпуск сертификатов."
E[92]="6. Integrate custom JSON subscription."
R[92]="6. Интеграция кастомной JSON подписки."
E[93]="7. Copy someone else's website to your server."
R[93]="7. Скопировать чужой сайт на ваш сервер."
E[94]="8. Disable IPv6."
R[94]="8. Отключение IPv6."
E[95]="9. Enable IPv6."
R[95]="9. Включение IPv6."
E[96]="10. Find out the size of the directory."
R[96]="10. Узнать размер директории."
E[97]="Client migration initiation (experimental feature)."
R[97]="Начало миграции клиентов (экспериментальная функция)."
E[98]="Client migration is complete."
R[98]="Миграция клиентов завершена."
E[99]="Settings custom JSON subscription."
R[99]="Настройки пользовательской JSON-подписки."
E[100]="Restore from backup."
R[100]="Восстановление из резервной копии."
E[101]="Backups:"
R[101]="Резервные копии:"
E[102]="Enter the number of the archive to restore:"
R[102]="Введите номер архива для восстановления:"
E[103]="Restoration is complete."
R[103]="Восстановление завершено."
E[104]="Restoration is complete."
R[104]="Выбран архив:"
E[105]="11. Traffic statistics."
R[105]="11. Статистика трафика."
E[106]="Traffic statistics:\n  1. By years \n  2. By months \n  3. By days \n  4. By hours"
R[106]="Статистика трафика:\n  1. По годам \n  2. По месяцам \n  3. По дням \n  4. По часам"
E[107]="12. Change language."
R[107]="12. Изменить язык."

###################################
### Help output
###################################
show_help() {
  echo
  echo "Usage: reverse_proxy [-u|--utils <true|false>] [-a|--addu <true|false>]"
  echo "         [-r|--autoupd <true|false>] [-b|--bbr <true|false>] [-i|--ipv6 <true|false>] [-w|--warp <true|false>]"
  echo "         [-c|--cert <true|false>] [-m|--mon <true|false>] [-l|--shell <true|false>] [-n|--nginx <true|false>]"
  echo "         [-p|--xcore <true|false>] [--custom <true|false>] [-f|--firewall <true|false>] [-s|--ssh <true|false>]"
  echo "         ] [-g|--generate <true|false>]"
  echo "         [--update] [-h|--help]"
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
  echo "  -p, --xcore <true|false>       Installing the Xray kernel                       (default: ${defaults[xcore]})"
  echo "                                 Установка ядра Xray"
  echo "      --custom <true|false>      Custom JSON subscription                         (default: ${defaults[custom]})"
  echo "                                 Кастомная JSON-подписка"  
  echo "  -f, --firewall <true|false>    Firewall configuration                           (default: ${defaults[firewall]})"
  echo "                                 Настройка файрвола"
  echo "  -s, --ssh <true|false>         SSH access                                       (default: ${defaults[ssh]})"
  echo "                                 SSH доступ"
  echo "  -g, --generate <true|false>    Generate a random string for configuration       (default: ${defaults[generate]})"
  echo "                                 Генерация случайных путей для конфигурации"
  echo "      --update                   Update version of Reverse-proxy manager (Version on github: ${VERSION_MANAGER})"
  echo "                                 Обновить версию Reverse-proxy manager (Версия на github: ${VERSION_MANAGER})"
  echo "  -h, --help                     Display this help message"
  echo "                                 Показать это сообщение помощи"
  echo
  exit 0
}

###################################
### Reverse_proxy manager
###################################
update_reverse_proxy() {
  info "Script update and integration."
  
  TOKEN="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"
  REPO_URL="https://api.github.com/repos/cortez24rus/reverse_proxy/tarball/main"
  
  mkdir -p "${DIR_REVERSE_PROXY}repo/"
  wget --header="Authorization: Bearer $TOKEN" -qO- $REPO_URL | tar xz --strip-components=1 -C "${DIR_REVERSE_PROXY}repo/"
  
  chmod +x "${DIR_REVERSE_PROXY}repo/reverse_proxy.sh"
  ln -sf "${DIR_REVERSE_PROXY}repo/reverse_proxy.sh" /usr/local/bin/reverse_proxy

  sleep 1

  CURRENT_VERSION=$(sed -n "s/^[[:space:]]*VERSION_MANAGER=[[:space:]]*'\([0-9\.]*\)'/\1/p" "${DIR_REVERSE_PROXY}repo/reverse_proxy.sh")
  warning "Script version: $CURRENT_VERSION"

  crontab -l | grep -v -- "--update" | crontab -
  add_cron_rule "0 0 * * * /usr/local/reverse_proxy/repo/reverse_proxy.sh --update"

  tilda "\n|-----------------------------------------------------------------------------|\n"
}

###################################
### Reading values ​​from file
################################### 
read_defaults_from_file() {
  if [[ -f "${DIR_REVERSE_PROXY}default.conf" ]]; then
    # Чтение и выполнение строк из файла
    while IFS= read -r line; do
      # Пропускаем пустые строки и комментарии
      [[ -z "$line" || "$line" =~ ^# ]] && continue
      eval "$line"
    done < "${DIR_REVERSE_PROXY}default.conf"
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
    defaults[xcore]=true
    defaults[custom]=true
    defaults[firewall]=true
    defaults[ssh]=true
    defaults[generate]=true
  fi
}

###################################
### Writing values ​​to a file
###################################
write_defaults_to_file() {
  cat > "${DIR_REVERSE_PROXY}default.conf"<<EOF
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
defaults[xcore]=true
defaults[custom]=true
defaults[firewall]=false
defaults[ssh]=false
defaults[generate]=true
EOF
}

###################################
### Lowercase characters
################################### 
normalize_case() {
  local key=$1
  args[$key]="${args[$key],,}"
}

###################################
### Validation of true/false value
###################################
validate_true_false() {
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
### Parse args
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
  [-x]=xcore      [--xcore]=xcore
                  [--custom]=custom
  [-f]=firewall   [--firewall]=firewall
  [-s]=ssh        [--ssh]=ssh
  [-g]=generate   [--generate]=generate
)

parse_args() {
  local opts
  opts=$(getopt -o hu:a:r:b:i:w:c:m:l:n:x:f:s:g --long utils:,addu:,autoupd:,bbr:,ipv6:,warp:,cert:,mon:,shell:,nginx:,xcore:,custom:,firewall:,ssh:,generate:,update,depers,help -- "$@")

  if [[ $? -ne 0 ]]; then
    return 1
  fi

  eval set -- "$opts"
  while true; do
    case $1 in
      --update)
        echo
        update_reverse_proxy
        exit 0
        ;;
      --depers)
        echo "Depersonalization database..."
        depersonalization_db
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
          normalize_case "$key"
          validate_true_false "$key" "$2" || return 1
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
### Logging
###################################
enable_logging() {
  mkdir -p ${DIR_REVERSE_PROXY}
  LOGFILE="${DIR_REVERSE_PROXY}reverse_proxy.log"
  exec > >(tee -a "$LOGFILE") 2>&1
}

disable_logging() {
  exec > /dev/tty 2>&1
}

###################################
### Language selection
###################################
select_language() {
  if [ ! -f "${DIR_REVERSE_PROXY}lang.conf" ]; then  # Если файла нет
    L=E
    hint " $(text 0) \n" 
    reading " $(text 1) " LANGUAGE

    case "$LANGUAGE" in
      1) L=E ;;   # Английский
      2) L=R ;;   # Русский
      *) L=E ;;   # По умолчанию — английский
    esac
    cat > "${DIR_REVERSE_PROXY}lang.conf" << EOF
$L
EOF
  else
    L=$(cat "${DIR_REVERSE_PROXY}lang.conf")  # Загружаем язык
  fi
}

###################################
### Checking the operating system
###################################
check_operating_system() {
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
### Checking and installing dependencies
###################################
check_dependencies() {
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
### Root check
###################################
check_root() {
  if [[ $EUID -ne 0 ]]; then
    error " $(text 8) "
  fi
}

###################################
### Obtaining your external IP address
###################################
check_ip() {
  IP4_REGEX="^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
  IP4=$(ip route get 8.8.8.8 2>/dev/null | grep -Po -- 'src \K\S*')

  if [[ ! $IP4 =~ $IP4_REGEX ]]; then
      IP4=$(curl -s --max-time 5 ipinfo.io/ip 2>/dev/null)
  fi

  if [[ ! $IP4 =~ $IP4_REGEX ]]; then
    echo "Не удалось получить внешний IP."
    return 1
  fi
}

###################################
### Banner
###################################
banner_xray() {
  echo
  echo " █░█ ░░ █▀▀█ █▀▀ ▀█░█▀ █▀▀ █▀▀█ █▀▀ █▀▀ ░░ █▀▀█ █▀▀█ █▀▀█ █░█ █░░█  "
  echo " ▄▀▄ ▀▀ █▄▄▀ █▀▀ ░█▄█░ █▀▀ █▄▄▀ ▀▀█ █▀▀ ▀▀ █░░█ █▄▄▀ █░░█ ▄▀▄ █▄▄█  "
  echo " ▀░▀ ░░ ▀░▀▀ ▀▀▀ ░░▀░░ ▀▀▀ ▀░▀▀ ▀▀▀ ▀▀▀ ░░ █▀▀▀ ▀░▀▀ ▀▀▀▀ ▀░▀ ▄▄▄█  "
  echo
}

###################################
### Installation request
###################################
warning_banner() {
  warning " $(text 5) "
  echo
  info " $(text 6) "
  warning " apt-get update && apt-get full-upgrade -y && reboot "
}

###################################
### Cron rules
###################################
add_cron_rule() {
  local rule="$1"
  local logged_rule="${rule} >> ${DIR_REVERSE_PROXY}cron_jobs.log 2>&1"

  ( crontab -l | grep -Fxq "$logged_rule" ) || ( crontab -l 2>/dev/null; echo "$logged_rule" ) | crontab -
}

###################################
### Request and response from Cloudflare API
###################################
get_test_response() {
  testdomain=$(echo "${DOMAIN}" | rev | cut -d '.' -f 1-2 | rev)

  if [[ "$CFTOKEN" =~ [A-Z] ]]; then
    test_response=$(curl --silent --request GET --url https://api.cloudflare.com/client/v4/zones --header "Authorization: Bearer ${CFTOKEN}" --header "Content-Type: application/json")
  else
    test_response=$(curl --silent --request GET --url https://api.cloudflare.com/client/v4/zones --header "X-Auth-Key: ${CFTOKEN}" --header "X-Auth-Email: ${EMAIL}" --header "Content-Type: application/json")
  fi
}

###################################
### Function to clean the URL (removes the protocol, port, and path)
###################################
clean_url() {
  local INPUT_URL_L="$1"  # Входной URL, который нужно очистить от префикса, порта и пути.
  # Убираем префикс https:// или http:// и порт/путь
  local CLEANED_URL_L=$(echo "$INPUT_URL_L" | sed -E 's/^https?:\/\///' | sed -E 's/(:[0-9]+)?(\/[a-zA-Z0-9_\-\/]+)?$//')
  echo "$CLEANED_URL_L"  # Возвращаем очищенный URL (без префикса, порта и пути).
}

###################################
### Function to crop the domain to the last two parts
###################################
crop_domain() {
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
### Domain validation in cloudflare
###################################
check_cf_token() {
  while ! echo "$test_response" | grep -qE "\"${testdomain}\"|\"#dns_records:edit\"|\"#dns_records:read\"|\"#zone:read\""; do
    DOMAIN=""
    EMAIL=""
    CFTOKEN=""

    while [[ -z "$DOMAIN" ]]; do
      reading " $(text 13) " DOMAIN
      DOMAIN=$(clean_url "$DOMAIN")
    done
    echo
    while [[ -z $EMAIL ]]; do
      reading " $(text 15) " EMAIL
    done
    echo
    while [[ -z $CFTOKEN ]]; do
      reading " $(text 16) " CFTOKEN
    done

    get_test_response
    info " $(text 17) "
  done
}

###################################
### Processing paths with a loop
###################################
validate_path() {
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
### Data entry
###################################
data_entry() {
  tilda "$(text 10)"

  reading " $(text 11) " USERNAME
  echo
  reading " $(text 12) " PASSWORD
  [[ ${args[addu]} == "true" ]] && add_user

  tilda "$(text 10)"

  check_cf_token

  if [[ ${args[generate]} == "true" ]]; then
    SUB_JSON_PATH=$(eval ${generate[path]})
  else
    echo
    validate_path SUB_JSON_PATH
  fi
  if [[ ${args[mon]} == "true" ]]; then
    if [[ ${args[generate]} == "true" ]]; then
      METRICS=$(eval ${generate[path]})
    else
      echo
      validate_path METRICS
    fi
  fi
  if [[ ${args[shell]} == "true" ]]; then
    if [[ ${args[generate]} == "true" ]]; then
      SHELLBOX=$(eval ${generate[path]})
    else
      echo
      validate_path SHELLBOX
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
### Install NGINX
###################################
nginx_gpg() {
  case "$SYSTEM" in
    Debian)
      ${PACKAGE_INSTALL[int]} debian-archive-keyring
      curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
        | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
      gpg --dry-run --quiet --no-keyring --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
      http://nginx.org/packages/debian `lsb_release -cs` nginx" \
        | tee /etc/apt/sources.list.d/nginx.list
      echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
        | tee /etc/apt/preferences.d/99nginx
      ;;

    Ubuntu)
      ${PACKAGE_INSTALL[int]} ubuntu-keyring
      curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
        | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
      gpg --dry-run --quiet --no-keyring --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
      http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" \
        | tee /etc/apt/sources.list.d/nginx.list
      echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
        | tee /etc/apt/preferences.d/99nginx
      ;;

    CentOS|Fedora)
      ${PACKAGE_INSTALL[int]} yum-utils
      cat <<EOL > /etc/yum.repos.d/nginx.repo
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOL
      ;;
  esac
  ${PACKAGE_UPDATE[int]}
  ${PACKAGE_INSTALL[int]} nginx
  systemctl daemon-reload
  systemctl start nginx
  systemctl enable nginx
  systemctl restart nginx
  systemctl status nginx --no-pager
}

###################################
### Installing packages
###################################
installation_of_utilities() {
  info " $(text 36) "
  case "$SYSTEM" in
    Debian|Ubuntu)
      DEPS_PACK_CHECK=("jq" "ufw" "zip" "wget" "gpg" "nano" "cron" "sqlite3" "haproxy" "certbot" "vnstat" "openssl" "netstat" "htpasswd" "update-ca-certificates" "add-apt-repository" "unattended-upgrades" "certbot-dns-cloudflare")
      DEPS_PACK_INSTALL=("jq" "ufw" "zip" "wget" "gnupg2" "nano" "cron" "sqlite3" "haproxy" "certbot" "vnstat" "openssl" "net-tools" "apache2-utils" "ca-certificates" "software-properties-common" "unattended-upgrades" "python3-certbot-dns-cloudflare")

      for g in "${!DEPS_PACK_CHECK[@]}"; do
        [ ! -x "$(type -p ${DEPS_PACK_CHECK[g]})" ] && [[ ! "${DEPS_PACK[@]}" =~ "${DEPS_PACK_INSTALL[g]}" ]] && DEPS_PACK+=(${DEPS_PACK_INSTALL[g]})
      done

      if [ "${#DEPS_PACK[@]}" -ge 1 ]; then
        info " $(text 77) ": ${DEPS_PACK[@]}
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} ${DEPS_PACK[@]}
      else
        info " $(text 78) "
      fi
      ;;

    CentOS|Fedora)
      DEPS_PACK_CHECK=("jq" "zip" "tar" "wget" "gpg" "nano" "sqlite3" "crontab" "haproxy" "openssl" "netstat" "nslookup" "htpasswd" "certbot" "update-ca-certificates" "certbot-dns-cloudflare")
      DEPS_PACK_INSTALL=("jq" "zip" "tar" "wget" "gnupg2" "nano" "sqlite3" "cronie" "haproxy" "openssl" "net-tools" "bind-utils" "httpd-tools" "certbot" "ca-certificates" "python3-certbot-dns-cloudflare")

      for g in "${!DEPS_PACK_CHECK[@]}"; do
        [ ! -x "$(type -p ${DEPS_PACK_CHECK[g]})" ] && [[ ! "${DEPS_PACK[@]}" =~ "${DEPS_PACK_INSTALL[g]}" ]] && DEPS_PACK+=(${DEPS_PACK_INSTALL[g]})
      done

      if [ "${#DEPS_PACK[@]}" -ge 1 ]; then
        info " $(text 77) ": ${DEPS_PACK[@]}
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} ${DEPS_PACK[@]}
      else
        info " $(text 78) "
      fi
      ;;
  esac

  nginx_gpg
  tilda "$(text 10)"
}

###################################
### Creating a user
###################################
add_user() {
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
### Automatic system update
###################################
setup_auto_updates() {
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
### BBR
###################################
enable_bbr() {
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
### Disable IPv6
###################################
disable_ipv6() {
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
### Enable IPv6
###################################
enable_ipv6() {
  info " $(text 42) "
  interface_name=$(ifconfig -s | awk 'NR==2 {print $1}')

  sed -i "/net.ipv6.conf.all.disable_ipv6 = 1/d" /etc/sysctl.conf
  sed -i "/net.ipv6.conf.default.disable_ipv6 = 1/d" /etc/sysctl.conf
  sed -i "/net.ipv6.conf.lo.disable_ipv6 = 1/d" /etc/sysctl.conf
  sed -i "/net.ipv6.conf.$interface_name.disable_ipv6 = 1/d" /etc/sysctl.conf

  echo -e "IPv6 включен"
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

  cat > ${DIR_REVERSE_PROXY}restart_warp.sh <<EOF
#!/bin/bash
# Получаем количество занятого пространства в swap (в мегабайтах)
SWAP_USED=\$(free -m | grep Swap | awk '{print \$3}')
# Проверяем, больше ли оно 300 Мб
if [ "\$SWAP_USED" -gt 200 ]; then
    # Перезапускаем warp-svc.service
    systemctl restart warp-svc.service
    # Записываем дату и время в лог-файл
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - warp-svc.service перезапущен из-за превышения swap" >> ${DIR_REVERSE_PROXY}warp_restart_time
fi
EOF
  chmod +x ${DIR_REVERSE_PROXY}restart_warp.sh

  crontab -l | grep -v -- "restart_warp.sh" | crontab -
  add_cron_rule "* * * * * ${DIR_REVERSE_PROXY}restart_warp.sh"
}

###################################
### WARP
###################################
warp() {
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
### Certificates
###################################
issuance_of_certificates() {
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

  add_cron_rule "0 5 1 */2 * certbot -q renew"
  tilda "$(text 10)"
}

###################################
### Node exporter
###################################
monitoring() {
  info " $(text 66) "
  mkdir -p /etc/nginx/locations/
  bash <(curl -Ls https://github.com/cortez24rus/grafana-prometheus/raw/refs/heads/main/prometheus_node_exporter.sh)

  cat > /etc/nginx/locations/monitoring.conf <<EOF
location /${METRICS}/ {
  auth_basic "Restricted Content";
  auth_basic_user_file /etc/nginx/.htpasswd;
  proxy_pass http://127.0.0.1:9100/metrics;
  proxy_set_header Host \$host;
  proxy_set_header X-Real-IP \$remote_addr;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;
  break;
}
EOF

  tilda "$(text 10)"
}

###################################
### Shell In A Box
###################################
shellinabox() {
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
  auth_basic "Restricted Content";
  auth_basic_user_file /etc/nginx/.htpasswd;
  proxy_pass http://127.0.0.1:4200;
  proxy_set_header Host \$host;
  proxy_set_header X-Real-IP \$remote_addr;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;
  break;
}
EOF

  systemctl restart shellinabox
  tilda "$(text 10)"
}

###################################
### Selecting a random site
###################################
random_site() {
  info " $(text 79) "
  mkdir -p /var/www/html/ ${DIR_REVERSE_PROXY}

  cd ${DIR_REVERSE_PROXY}

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
### http conf
###################################
nginx_conf() {
  cat > /etc/nginx/nginx.conf <<EOF
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
  # Request mapping
  map \$request_uri \$cleaned_request_uri {
    default \$request_uri;
    "~^(.*?)(\?x_padding=[^ ]*)\$" \$1;
  }

  # Logging
  log_format json_analytics escape=json '{'
    '\$time_local, '
    '\$http_x_forwarded_for, '
    '\$proxy_protocol_addr, '
    '\$request_method '
    '\$status, '
    '\$http_user_agent, '
    '\$cleaned_request_uri, '
    '\$http_referer, '
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
### Server conf
###################################
local_conf() {
  cat > /etc/nginx/conf.d/local.conf <<EOF
server {
  listen                               36078;
  server_name                          _;

  # Enable locations
  include /etc/nginx/locations/*.conf;
}
EOF
}

###################################
### Web site
###################################
location_root() {
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
### Hidden_files
###################################
location_hidden_files() {
  cat > /etc/nginx/locations/hidden_files.conf <<EOF
# . hidden_files.conf
location ~ /\.(?!well-known) {
  deny all;
}
EOF
}

###################################
### Sub page
###################################
location_sub_page() {
  cat > /etc/nginx/locations/sub_page.conf <<EOF
# Subsciption
location ~ ^/${SUB_JSON_PATH} {
  default_type application/json;
  root /var/www;
}
EOF
}

###################################
### NGINX
###################################
nginx_setup() {
  info " $(text 45) "

  mkdir -p /etc/nginx/locations/
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

  nginx_conf
  local_conf
  location_root
  location_hidden_files
  location_sub_page  

  systemctl daemon-reload
  systemctl restart nginx
  nginx -s reload

  tilda "$(text 10)"
}

###################################
### Функция для генерации UUID
###################################
generate_uuids() {
    local XRAY_UUID=$(cat /proc/sys/kernel/random/uuid)
    echo "$XRAY_UUID"
}

###################################
### AUTH LUA
###################################
auth_lua() {
  read XRAY_UUID < <(generate_uuids)
  read PLACEBO_XRAY_UUID < <(generate_uuids)
  
  cat > ${LUA_PATH} <<EOF
local passwords = {
  ["${XRAY_UUID}"] = true,
  ["${PLACEBO_XRAY_UUID}"] = false		-- Заглушка, не удаляй, а то убьет
}

local function remove_hyphens(uuid)
  return uuid:gsub("-", "")
end

local clean_passwords = {}
for uuid, value in pairs(passwords) do
  if value then
    clean_passwords[remove_hyphens(uuid)] = true
  end
end

function vless_auth(txn)
  local status, data = pcall(function() return txn.req:dup() end)
  if status and data then
    -- Uncomment to enable logging of all received data
    core.Info("Received data from client: " .. data)
    local sniffed_password = string.sub(data, 2, 17)

    local hex = (sniffed_password:gsub(".", function(c)
      return string.format("%02x", string.byte(c))
    end))

    -- Uncomment to enable logging of sniffed password hashes
    core.Info("Sniffed password: " .. hex)
    if clean_passwords[hex] then
      return "vless"
    end
  end
  return "http"
end

core.register_fetches("vless_auth", vless_auth)
EOF
}

###################################
### HAPROXY
###################################
haproxy_setup() {
  info " $(text 37) "
  mkdir -p /etc/haproxy/certs
  auth_lua

  openssl dhparam -out /etc/haproxy/dhparam.pem 2048
  cat /etc/letsencrypt/live/${DOMAIN}/fullchain.pem /etc/letsencrypt/live/${DOMAIN}/privkey.pem > /etc/haproxy/certs/${DOMAIN}.pem

  cat > /etc/haproxy/haproxy.cfg <<EOF
global
  # Uncomment to enable system logging
  # log /dev/log local0
  # log /dev/log local1 notice
  log /dev/log local2 warning
  lua-load ${LUA_PATH}
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
  mode http
  log global
  option tcplog
  option  dontlognull
  timeout connect 5000
  timeout client  50000
  timeout server  50000

frontend haproxy-tls
  mode tcp
  timeout client 1h
  bind :::443 v4v6 ssl crt /etc/haproxy/certs/${DOMAIN}.pem alpn h2,http/1.1
  acl host_ip hdr(host) -i ${IP4}
  tcp-request content reject if host_ip
  tcp-request inspect-delay 5s
  tcp-request content accept if { req_ssl_hello_type 1 }
  use_backend http-sub if { path /${SUB_JSON_PATH} } || { path_beg /${SUB_JSON_PATH}/ }
  use_backend %[lua.vless_auth]
  default_backend main

backend vless
  mode tcp
  timeout server 1h
  server xray 127.0.0.1:10550 send-proxy-v2

backend main
  mode http
  timeout server 1h
  server nginx 127.0.0.1:36078

backend http-sub
  mode http
  timeout server 1h
  server nginx 127.0.0.1:36078

EOF

  systemctl enable haproxy.service
  haproxy -f /etc/haproxy/haproxy.cfg -c
  systemctl restart haproxy.service

  tilda "$(text 10)"
}

###################################
### Xray installation
###################################
xray_setup() {
  mkdir -p "${DIR_XRAY}"

  while ! wget -q --progress=dot:mega --timeout=30 --tries=10 --retry-connrefused -P "${DIR_REVERSE_PROXY}" "https://github.com/XTLS/Xray-core/releases/download/v${VERSION_XRAY}/Xray-linux-64.zip"; do
    warning " $(text 38) "
    sleep 3
  done

  unzip -o "${DIR_REVERSE_PROXY}Xray-linux-64.*" -d "${DIR_XRAY}"
  rm -f ${DIR_REVERSE_PROXY}Xray-linux-64.*
}

###################################
### Xray config
###################################
xray_config() {
  cp -f ${DIR_REVERSE_PROXY}repo/conf_template/server_raw.json ${DIR_XRAY}config.json
        
  sed -i \
    -e "s/USERNAME_TEMP/${USERNAME}/g" \
    -e "s/UUID_TEMP/${XRAY_UUID}/g" \
    "${DIR_XRAY}config.json"
}

###################################
### Xray service
###################################
xray_service() {
  mv -f ${DIR_REVERSE_PROXY}/repo/services/xray.service /etc/systemd/system/xray.service

  systemctl daemon-reload
  systemctl enable xray.service
  systemctl start xray.service
  systemctl restart xray.service
}

###################################
### Xray server settings
###################################
xray_server_conf() {
  info " $(text 46) "

  xray_setup
  xray_config
  xray_service

  tilda "$(text 10)"
}

###################################
### Web sub page
###################################
web_sub_page() {
  mkdir -p /var/www/${SUB_JSON_PATH}/vless_raw/
  cp -r ${DIR_REVERSE_PROXY}repo/sub_page/* /var/www/${SUB_JSON_PATH}/

  sed -i \
    -e "s/DOMAIN_TEMP/${DOMAIN}/g" \
    -e "s/SUB_JSON_PATH_TEMP/${SUB_JSON_PATH}/g" \
    "/var/www/${SUB_JSON_PATH}/sub.html"
}

###################################
### Client configuration setup
###################################
client_conf() {
  cp -r ${DIR_REVERSE_PROXY}repo/conf_template/client_raw.json /var/www/${SUB_JSON_PATH}/vless_raw/${USERNAME}.json

  sed -i \
    -e "s/DOMAIN_TEMP/${DOMAIN}/g" \
    -e "s/UUID_TEMP/${XRAY_UUID}/g" \
    "/var/www/${SUB_JSON_PATH}/vless_raw/${USERNAME}.json"
}

###################################
### Xray client settings
###################################
xray_client_conf() {
  info " $(text 57) "

  web_sub_page
  client_conf

  tilda "$(text 10)"
}

xreverse_service() {
  chmod +x ${DIR_REVERSE_PROXY}repo/services/xreverse.service
  mv -f "${DIR_REVERSE_PROXY}repo/services/xreverse.service" "/etc/systemd/system/xreverse.service"

  systemctl daemon-reload
  systemctl enable xreverse.service
  systemctl start xreverse.service
  systemctl restart xreverse.service
}

###################################
### BACKUP DIRECTORIES
###################################
backup_dir() {
  cat > ${DIR_REVERSE_PROXY}backup_dir.sh <<EOF
#!/bin/bash

# Путь к директории резервного копирования
DIR_REVERSE_PROXY="/usr/local/reverse_proxy/"
BACKUP_DIR="\${DIR_REVERSE_PROXY}backup"
CURRENT_DATE=\$(date +"%y-%m-%d")
ARCHIVE_NAME="\${BACKUP_DIR}/backup_\${CURRENT_DATE}.7z"

# Создаем директорию для резервных копий, если её нет
mkdir -p "\$BACKUP_DIR"

# Архивируем все три директории в один архив
7za a -mx9 "\$ARCHIVE_NAME" "/etc/nginx" "/etc/x-ui" "/etc/letsencrypt" || echo "Ошибка при создании архива"

# Проверка успешного создания архива
if [[ -f "\$ARCHIVE_NAME" ]]; then
  echo "Архив успешно создан: \$ARCHIVE_NAME"
else
  echo "Ошибка при создании архива"
fi

EOF
  chmod +x ${DIR_REVERSE_PROXY}backup_dir.sh
  bash "${DIR_REVERSE_PROXY}backup_dir.sh"

  crontab -l | grep -v -- "backup_dir.sh" | crontab -
  add_cron_rule "0 0 * * * ${DIR_REVERSE_PROXY}backup_dir.sh"
}

###################################
### ROTATE BACKUPS
###################################
rotation_backup() {
  cat > ${DIR_REVERSE_PROXY}rotation_backup.sh <<EOF
#!/bin/bash

DIR_REVERSE_PROXY="/usr/local/reverse_proxy/"
BACKUP_DIR="${DIR_REVERSE_PROXY}backup"
DAY_TO_KEEP=6

find "\$BACKUP_DIR" -type f -name "backup_*.7z" -mtime +\$DAY_TO_KEEP -exec rm -f {} \;
EOF
  chmod +x ${DIR_REVERSE_PROXY}rotation_backup.sh
  bash "${DIR_REVERSE_PROXY}rotation_backup.sh"

  crontab -l | grep -v -- "rotation_backup.sh" | crontab -
  add_cron_rule "5 0 * * * ${DIR_REVERSE_PROXY}rotation_backup.sh"
}

###################################
### BACKUP & ROTATION SCHEDULER
###################################
rotation_and_archiving() {
  info " $(text 23) "
  ${PACKAGE_UPDATE[int]}
  ${PACKAGE_INSTALL[int]} p7zip-full
  backup_dir
  rotation_backup
  journalctl --vacuum-time=7days
  tilda "$(text 10)"
}

###################################
### Firewall
###################################
enabling_security() {
  info " $(text 47) "
  BLOCK_ZONE_IP=$(echo ${IP4} | cut -d '.' -f 1-3).0/22

  case "$SYSTEM" in
    Debian|Ubuntu)
      ufw --force reset
      ufw limit 22/tcp comment 'SSH'
      ufw allow 443/tcp comment 'WEB'
      ufw insert 1 deny from "$BLOCK_ZONE_IP" comment 'Protection from my own subnet (reality of degenerates)'
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
### SSH
###################################
ssh_setup() {
  if [[ "${ANSWER_SSH,,}" == "y" ]]; then
    info " $(text 48) "
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

    bash <(curl -Ls https://raw.githubusercontent.com/cortez24rus/motd/refs/heads/X/install.sh)
    systemctl restart ssh
    tilda "$(text 10)"
  fi
}

###################################
### Information output
###################################
data_output() {
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
  echo
  out_data " $(text 65) " "$LOGFILE"
  tilda "$(text 10)"
}

###################################
### Downloadr webiste
###################################
download_website() {
  reading " $(text 13) " sitelink
  local NGINX_CONFIG_L="/etc/nginx/conf.d/local.conf"
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

  NEW_ROOT=" root /var/www/${sitedir};"
  NEW_INDEX=" index ${index};"

  sed -i '/^\s*root\s.*/c\ '"$NEW_ROOT" $NGINX_CONFIG_L
  sed -i '/^\s*index\s.*/c\ '"$NEW_INDEX" $NGINX_CONFIG_L

  systemctl restart nginx
}

###################################
### Change domain name
###################################
change_domain() {


  tilda "$(text 10)"
}

###################################
### Reissue of certificates
###################################
renew_cert() {
  # Получение домена из конфигурации Nginx
  NGINX_DOMAIN=$(grep "ssl_certificate" /etc/nginx/conf.d/local.conf | head -n 1)
  NGINX_DOMAIN=${NGINX_DOMAIN#*"/live/"}
  NGINX_DOMAIN=${NGINX_DOMAIN%"/"*}

  # Проверка наличия сертификатов
  if [ ! -d /etc/letsencrypt/live/${NGINX_DOMAIN} ]; then
    check_cf_token
    issuance_of_certificates
  else
    certbot renew --force-renewal
    if [ $? -ne 0 ]; then
      return 1
    fi
  fi
  # Перезапуск Nginx
  systemctl restart nginx
}

###################################
### Depersonalization of the database
###################################
depersonalization_db() {
  echo ""
}

###################################
### Directory size
###################################
directory_size() {
  read -e -p "Enter a directory: " DIRECTORY
  echo
  free -h
  echo
  du -ah ${DIRECTORY} --max-depth=1 | grep -v '/$' | sort -rh | head -10
  echo
}

###################################
### Migration to a new version
###################################
migration(){
  info " $(text 97) "

  info " $(text 98) "
}

###################################
### Unzips the selected backup
###################################
unzip_backup() {
  BACKUP_DIR="${DIR_REVERSE_PROXY}backup"

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
### Migrates backup files to the system directories
###################################
backup_migration() {
  echo
  x-ui stop
  
  rm -rf /etc/x-ui/
  rm -rf /etc/nginx/
  rm -rf /etc/letsencrypt/

  mv /tmp/restore/x-ui/ /etc/
  mv /tmp/restore/nginx/ /etc/
  mv /tmp/restore/letsencrypt/ /etc/

  systemctl restart nginx
  x-ui restart
  echo
}

###################################
### Restores the backup by first unzipping and then migrating
###################################
restore_backup() {
  info " $(text 100) "

  RESTORE_DIR="/tmp/restore"
  unzip_backup
  backup_migration

  info " $(text 103) "
}

###################################
### Displays traffic statistics
###################################
traffic_stats() {
  ${PACKAGE_UPDATE[int]} >/dev/null 2>&1
  ${PACKAGE_INSTALL[int]} vnstat >/dev/null 2>&1

  hint " $(text 106) \n"  # Показывает информацию о доступных языках
  reading " $(text 1) " CHOICE_STATS  # Запрашивает выбор языка

  case $CHOICE_STATS in
    1)
      vnstat -y
      ;;
    2)
      vnstat -m
      ;;
    3)
      vnstat -d
      ;;
    4)
      vnstat -h
      ;;
    *)
      vnstat -d
      ;;
  esac
  echo
}

display_stats() {
  clear
  echo -e " 🖥️  Состояние сервера:\n============================"
  bash /etc/update-motd.d/02-uptime
  bash /etc/update-motd.d/03-load-average
  bash /etc/update-motd.d/04-memory
  bash /etc/update-motd.d/05-disk-usage
  bash /etc/update-motd.d/09-status
  echo
  curl -X GET http://localhost:9952/stats
}

###################################
### Extracting data from haproxy.cfg
###################################
extract_data() {
  local CONFIG_FILE_HAPROXY="/etc/haproxy/haproxy.cfg"

  SUB_JSON_PATH=$(grep -oP 'use_backend http-sub if \{ path /.*? \}' "$CONFIG_FILE_HAPROXY" | grep -oP '(?<=path /).*?(?= \})')
  IP4=$(grep -oP 'acl host_ip hdr\(host\) -i \K[\d\.]+' "$CONFIG_FILE_HAPROXY")
  DOMAIN=$(grep -oP 'crt /etc/haproxy/certs/\K[^.]+(?:\.[^.]+)+(?=\.pem)' "$CONFIG_FILE_HAPROXY")
}

add_user_to_xray_config() {
  inboundnum=$(jq '[.inbounds[].tag] | index("vless_raw")' ${DIR_XRAY}config.json)
  jq ".inbounds[${inboundnum}].settings.clients += [{\"email\":\"${USERNAME}\",\"level\":0,\"id\":\"${XRAY_UUID}\"}]" "${DIR_XRAY}config.json" > "${DIR_XRAY}config.json.tmp" && mv "${DIR_XRAY}config.json.tmp" "${DIR_XRAY}config.json"
}

###################################
### Adding user configuration
###################################
add_user_config() {
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
        if [[ -f /var/www/${SUB_JSON_PATH}/vless_raw/${USERNAME}.json ]]; then
          echo "Пользователь $USERNAME уже добавлен. Попробуйте другое имя."
          echo
          continue  # Повтор запроса имени
        fi

        read XRAY_UUID < <(generate_uuids)
        
        # Добавление пользователя
        client_conf

        # Добавление в файл /etc/haproxy/.auth.lua
        sed -i "/local passwords = {/a \  [\"$XRAY_UUID\"] = true," ${LUA_PATH}
    
        # Добавляем нового пользователя
        add_user_to_xray_config

        systemctl reload nginx && systemctl reload haproxy && systemctl restart xray

        echo "Пользователь $USERNAME добавлен."
        echo
        ;;
    esac
  done
}

del_sub_client_config() {
  if [[ -f /var/www/${SUB_JSON_PATH}/vless_raw/${USERNAME}.json ]]; then
    rm -rf /var/www/${SUB_JSON_PATH}/vless_raw/${USERNAME}.json
  fi
}

del_lua_uuid_config() {
  sed -i "/\[\"${XRAY_UUID}\"\] = .*/d" ${LUA_PATH}
}

del_xray_server_config() {
  inboundnum=$(jq '[.inbounds[].tag] | index("vless_raw")' ${DIR_XRAY}config.json)
  jq "del(.inbounds[${inboundnum}].settings.clients[] | select(.email==\"${USERNAME}\"))" "${DIR_XRAY}config.json" > "${DIR_XRAY}config.json.tmp" && mv "${DIR_XRAY}config.json.tmp" "${DIR_XRAY}config.json"
}

# Функция для извлечения пользователей
extract_users() {
  jq -r '.inbounds[] | select(.tag == "vless_raw") | .settings.clients[] | "\(.email) \(.id)"' "${DIR_XRAY}config.json"
}

# Функция для форматирования и выбора пользователя
delete_user_config() {
  while true; do
    mapfile -t clients < <(extract_users)
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
            del_sub_client_config
            del_lua_uuid_config
            del_xray_server_config
          else
            echo "Некорректный номер: $choice"
          fi
          ;;
      esac
    done
  echo
  echo "|--------------------------------------------------------------------------|"
  echo
  done
}

toggle_user_status() {
  local API_URL="http://localhost:9952/users"
  local TOGGLE_URL="http://localhost:9952/set-enabled"

  while true; do
    clear

    # Получаем JSON от API
    response=$(curl -s -X GET "$API_URL")
    if [ $? -ne 0 ]; then
      warning "Ошибка: Не удалось подключиться к API"
      return 1
    fi

    # Парсим JSON и извлекаем email и enabled
    mapfile -t users < <(echo "$response" | jq -r '.[] | [.email, .enabled] | join(" ")')

    # Проверяем, есть ли пользователи
    if [ ${#users[@]} -eq 0 ]; then
      info "Нет пользователей для отображения"
      return 1
    fi

    # Выводим список
    info " Список пользователей:"
    for i in "${!users[@]}"; do
      IFS=' ' read -r email enabled <<< "${users[$i]}"
      printf " %d. %s (%s)\n" "$((i+1))" "$email" "$enabled"
    done
    echo " 0. Выйти"

    # Запрашиваем выбор
    reading "Введите номера пользователей (через пробел или запятую): " USER_CHOICE

    if [[ "$USER_CHOICE" == "0" ]]; then
      return 0
    fi

    # Преобразуем ввод в массив чисел
    USER_CHOICE="${USER_CHOICE//,/ }"   # заменяем запятые на пробелы
    read -ra CHOICES <<< "$USER_CHOICE" # массив номеров

    echo
    for choice in "${CHOICES[@]}"; do
      if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#users[@]}" ]; then
        IFS=' ' read -r selected_email current_enabled <<< "${users[$((choice-1))]}"

        # Определяем новый статус
        new_enabled="false"
        if [ "$current_enabled" = "false" ]; then
          new_enabled="true"
        fi

        # Выполняем PATCH-запрос
        response=$(curl -s -X PATCH -d "email=$selected_email&enabled=$new_enabled" "$TOGGLE_URL")
        if [ $? -eq 0 ]; then
          info "Статус пользователя $selected_email изменяется на $new_enabled"
        else
          warning "Ошибка при изменении статуса пользователя $selected_email"
        fi
      else
        warning "Неверный выбор: $choice"
      fi
    done

    sleep 10
  done
}

sync_client_configs() {
  SUB_DIR="/var/www/${SUB_JSON_PATH}/vless_raw/"

  for FILE_PATH in ${SUB_DIR}*.json; do
    FILENAME=$(basename "$FILE_PATH")

    OUT_VL_NUM=$(jq '[.outbounds[].tag] | index("vless_raw")' $FILE_PATH)
    CLIENT=$(jq ".outbounds[${OUT_VL_NUM}].settings.vnext[].users[]" $FILE_PATH)
  
    rm -rf ${FILE_PATH}
    cp -r ${DIR_REVERSE_PROXY}repo/conf_template/client_raw.json ${FILE_PATH}
  
    echo "$(jq ".outbounds[${OUT_VL_NUM}].settings.vnext[].users[] = ${CLIENT}" ${FILE_PATH})" > $FILE_PATH
    sed -i -e "s/DOMAIN_TEMP/${DOMAIN}/g" ${FILE_PATH}

    echo "Файл $FILENAME успешно обновлен."
  done
}

get_dns_stats() {
  declare -A user_map
  local counter=0
  local last_choice=""

  # Запрос количества строк
  read -p "Введите количество строк для вывода статистики: " count
  clear

  # Получаем список пользователей через API
  response=$(curl -s -X GET "http://127.0.0.1:9952/users")
  if [ $? -ne 0 ]; then
    echo "Ошибка подключения к API."
    return 1
  fi

  # Парсим JSON в массив
  mapfile -t users < <(echo "$response" | jq -r '.[] | .email')

  # Проверяем, есть ли пользователи
  if [ ${#users[@]} -eq 0 ]; then
    echo "Нет пользователей в базе данных."
    return 1
  fi

  # Заполняем user_map и выводим список пользователей
  while true; do
    counter=0
    info " Список пользователей:"
    for user in "${users[@]}"; do
      user_map[$counter]="$user"
      echo "$((counter+1)). $user"
      ((counter++))
    done
    echo
    if [[ -n "$last_choice" ]]; then
      echo "(Enter - обновить статистику для ${user_map[$((last_choice-1))]})"
    fi
    read -p "Введите номер пользователя (0 - выход, \"reset\" - сброс статистики): " choice

    if [[ "$choice" == "0" ]]; then
      echo "Выход..."
      return
    fi

    if [[ "$choice" == "reset" ]]; then
      echo "Очищаю статистику..."
      curl -X POST http://127.0.0.1:9952/delete_dns_stats
      echo "Статистика удалена."
      echo
      continue
    fi

    if [[ -z "$choice" && -n "$last_choice" ]]; then
      choice="$last_choice"  # Используем предыдущий выбор
    fi

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > counter )); then
      echo "Некорректный ввод. Попробуйте снова."
      continue
    fi

    selected_email="${user_map[$((choice-1))]}"
    last_choice="$choice"  # Сохраняем текущий выбор

    # Выполняем запрос к API
    clear
    curl -X GET "http://127.0.0.1:9952/dns_stats?email=${selected_email}&count=${count}"
  done
}

set_lim_ip() {
  declare -A user_map
  local counter=0

  # Запрос лимита IP
  read -p "Введите новый лимит IP: " lim_ip
  clear

  while true; do
    # Получаем список пользователей через API
    response=$(curl -s -X GET "http://127.0.0.1:9952/users")
    if [ $? -ne 0 ]; then
      echo "Ошибка подключения к API."
      return 1
    fi

    # Парсим пользователей
    mapfile -t users < <(echo "$response" | jq -r '.[] | "\(.email)|\(.lim_ip)"')
    if [ ${#users[@]} -eq 0 ]; then
      echo "Нет пользователей в ответе API."
      return 1
    fi

    counter=0
    info " Список пользователей:"
    for user in "${users[@]}"; do
      IFS='|' read -r email lim_ip_value <<< "$user"
      user_map[$counter]="$email"
      echo " $((counter+1)). $email (текущий лимит ${lim_ip_value:-не задан})"
      ((counter++))
    done
    echo
    echo " (Выбран лимит $lim_ip)"
    read -p " Введите номер пользователя (0 - выход, \"reset\" - изменить лимит IP): " choice

    if [[ "$choice" == "0" ]]; then
      echo "Выход..."
      return
    fi

    if [[ "$choice" == "reset" ]]; then
      clear
      read -p "Введите новый лимит IP: " lim_ip
      continue
    fi

    # Разбиваем ввод на массив номеров
    choices=($(echo "$choice" | tr ',' ' ' | tr -s ' ' | tr ' ' '\n'))

    # Проверяем каждый номер
    for num in "${choices[@]}"; do
      if [[ ! "$num" =~ ^[0-9]+$ ]] || (( num < 1 || num > counter )); then
        echo "Некорректный номер пользователя: $num. Попробуйте снова."
        continue 2
      fi
    done

    clear
    # Обновляем лимит для выбранных пользователей
    for num in "${choices[@]}"; do
      selected_email="${user_map[$((num-1))]}"
      curl -X PATCH -d "username=${selected_email}&lim_ip=${lim_ip}" "http://127.0.0.1:9952/update_lim_ip"
    done
    echo
  done
}

###################################
### Removing all escape sequences
###################################
log_clear() {
  sed -i -e 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$LOGFILE"
}

###################################
### Конфигурирование Xray core
###################################
reverse_proxy_xray_menu() {
  while true; do
    clear
    banner_xray
    tilda "|--------------------------------------------------------------------------|"
    info " $(text 86) "                      # MENU
    tilda "|--------------------------------------------------------------------------|"
    info " 1. Вывод статистики."
    info " 2. Вывод статистики dns запросов клиентов." 
    echo    
    info " 3. Добавление пользователей."
    info " 4. Удаление пользователей."
    info " 5. Включение/Отключение клиента."
    echo
    info " 6. Синхронизация клиентских конфигураций."
    info " 7. Смена лимита ip адресов для пользователя."
    echo
    info " 0. Назад в основное меню."         # 0. Return
    tilda "|--------------------------------------------------------------------------|"
    echo
    reading " $(text 1) " CHOICE_MENU        # Choise
    tilda "$(text 10)"
    extract_data
    case $CHOICE_MENU in
      1)
        while true; do
          display_stats
          echo -n "Введите 0 для выхода (обновление каждые 10 секунд): "
          read -t 10 -r STATS_CHOICE
          [[ "$STATS_CHOICE" == "0" ]] && break
        done
        ;;
      2)
        get_dns_stats
        ;;
      3)
        add_user_config
        ;;
      4)
        delete_user_config
        ;;
      5)
        toggle_user_status
        ;;
      6)
        sync_client_configs
        ;;
      7)
        set_lim_ip
        ;;
      0)
        reverse_proxy_main_menu
        ;;
      *)
        warning " $(text 76) "
        ;;
    esac
  done
}

reverse_proxy_main_menu() {
  while true; do
    clear
    banner_xray
    tilda "|--------------------------------------------------------------------------|"
    info " $(text 86) "                      # MENU
    tilda "|--------------------------------------------------------------------------|"
    info " $(text 87) "                      # 1. Install
    echo
    info " $(text 88) "                      # 2. Restore backup
    info " $(text 89) "                      # 3. Migration
    info " $(text 90) "                      # 4. Change domain
    info " $(text 91) "                      # 5. Renew cert
    echo
    info " $(text 93) "                      # 7. Steal web site
    info " $(text 94) "                      # 8. Disable IPv6
    info " $(text 95) "                      # 9. Enable IPv6
    echo
    info " $(text 96) "                      # 10. Directory size
    info " $(text 105) "                     # 11. Traffic statistics
    info " $(text 107) "                     # 12. Change language
    echo
    info " 13. Конфигурирование Xray "       # 13. Конфигурирование Xray
    echo
    info " $(text 84) "                      # Exit
    tilda "|--------------------------------------------------------------------------|"
    echo
    reading " $(text 1) " CHOICE_MENU        # Choise
    tilda "$(text 10)"

    case $CHOICE_MENU in
      1)
        enable_logging
        clear
        check_dependencies
        banner_xray
        warning_banner
        data_entry
        [[ ${args[utils]} == "true" ]] && installation_of_utilities
        [[ ${args[autoupd]} == "true" ]] && setup_auto_updates
        [[ ${args[bbr]} == "true" ]] && enable_bbr
        [[ ${args[ipv6]} == "true" ]] && disable_ipv6
      	[[ ${args[warp]} == "true" ]] && warp
        [[ ${args[cert]} == "true" ]] && issuance_of_certificates
        [[ ${args[mon]} == "true" ]] && monitoring
        [[ ${args[shell]} == "true" ]] && shellinabox
        update_reverse_proxy
        random_site
        [[ ${args[nginx]} == "true" ]] && nginx_setup
        haproxy_setup
        [[ ${args[xcore]} == "true" ]] && xray_server_conf
        [[ ${args[xcore]} == "true" ]] && xray_client_conf
        xreverse_service
        write_defaults_to_file
#        rotation_and_archiving
        [[ ${args[firewall]} == "true" ]] && enabling_security
        [[ ${args[ssh]} == "true" ]] && ssh_setup
        data_output
        disable_logging
        log_clear
        ;;
      2)
        if [ ! -d "/usr/local/reverse_proxy/backup" ]; then
          rotation_and_archiving
        fi
        restore_backup
        ;;
      3)
        migration
        ;;
      4)
        change_domain
        ;;
      5)
        renew_cert
        ;;
      7)
        download_website
        ;;
      8)
        enable_ipv6
        ;;
      9)
        disable_ipv6
        ;;
      10)
        directory_size
        ;;
      11)
        traffic_stats
        ;;
      12)
        rm -rf ${DIR_REVERSE_PROXY}lang.conf
        select_language
        ;;
      13)
        reverse_proxy_xray_menu
        ;;
      0)
        clear
        exit 0
        ;;
      *)
        warning " $(text 76) "
        ;;
    esac

    info " $(text 85) "
    read -r dummy
  done
  log_clear
}

###################################
### Main function
###################################
main() {
  read_defaults_from_file
  parse_args "$@" || show_help
  check_root
  check_ip
  check_operating_system
  echo
  select_language
  reverse_proxy_main_menu
}

main "$@"