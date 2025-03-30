package main

import (
	"bufio"
	"context"
	"database/sql"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

type Config struct {
	DatabasePath      string
	AccessLogPath     string
	DirXray           string
	ConfigFileHaproxy string
	LUAFilePath       string
	XIPLLogFile       string
	IP_TTL            time.Duration
}

var config = Config{
	DatabasePath:      "/usr/local/reverse_proxy/projectgo/reverse.db",
	AccessLogPath:     "/usr/local/etc/xray/access.log",
	DirXray:           "/usr/local/etc/xray/",
	ConfigFileHaproxy: "/etc/haproxy/haproxy.cfg",
	LUAFilePath:       "/etc/haproxy/.auth.lua",
	XIPLLogFile:       "/var/log/xipl.log",
	IP_TTL:            1 * time.Minute,
}

var (
	dnsEnabled          = flag.Bool("dns", false, "Enable DNS statistics collection") // Флаг для включения/отключения DNS
	uniqueEntries       = make(map[string]map[string]time.Time)                       // email -> {IP: время добавления}
	mutex               = &sync.Mutex{}
	re                  = regexp.MustCompile(`from tcp:([0-9\.]+).*?tcp:([\w\.\-]+):\d+.*?email: (\S+)`)
	rgx                 = regexp.MustCompile(`\["([a-f0-9-]+)"\] = (true|false)`)
	previousStats       string
	clientPreviousStats string
)

type Client struct {
	Email string `json:"email"`
	Level int    `json:"level"`
	ID    string `json:"id"`
}

type Inbound struct {
	Tag      string `json:"tag"`
	Settings struct {
		Clients []Client `json:"clients"`
	} `json:"settings"`
}

type ConfigXray struct {
	Inbounds []Inbound `json:"inbounds"`
}

type Stat struct {
	Name  string `json:"name"`
	Value int    `json:"value"`
}

type ApiResponse struct {
	Stat []Stat `json:"stat"`
}

func extractData() string {
	file, err := os.Open(config.ConfigFileHaproxy)
	if err != nil {
		log.Fatal("Ошибка при открытии файла:", err)
		return ""
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.Contains(line, "path ") {
			fields := strings.Fields(line)
			for i, field := range fields {
				if field == "path" && i+1 < len(fields) {
					subJsonPath := strings.TrimPrefix(fields[i+1], "/")
					return subJsonPath
				}
			}
		}
	}

	if err := scanner.Err(); err != nil {
		log.Fatal("Ошибка при чтении файла:", err)
	}

	return ""
}

// Функция для инициализации базы данных
func initDB(db *sql.DB) error {
	// Установка PRAGMA-настроек для оптимизации
	_, err := db.Exec(`
		PRAGMA cache_size = 10000;  -- Увеличивает кэш (10000 страниц ≈ 40 MB RAM)
		PRAGMA journal_mode = MEMORY; -- Хранит журнал транзакций в RAM
	`)
	if err != nil {
		return fmt.Errorf("ошибка установки PRAGMA: %v", err)
	}

	// SQL-запрос для создания таблиц
	query := `
	CREATE TABLE IF NOT EXISTS clients_stats (
	    email TEXT PRIMARY KEY,
	    level INTEGER,
	    uuid TEXT,
	    status TEXT,
	    enabled TEXT,
	    created TEXT,
	    sub_end TEXT,
	    sub_duration TEXT,
	    ip_limit INTEGER NOT NULL DEFAULT 10,
	    ip TEXT NOT NULL DEFAULT '',
	    uplink INTEGER DEFAULT 0,
	    downlink INTEGER DEFAULT 0,
	    sess_uplink INTEGER DEFAULT 0,
	    sess_downlink INTEGER DEFAULT 0
	);

    CREATE TABLE IF NOT EXISTS traffic_stats (
		source TEXT PRIMARY KEY,
		sess_uplink INTEGER DEFAULT 0,
		sess_downlink INTEGER DEFAULT 0,
		uplink INTEGER DEFAULT 0,
		downlink INTEGER DEFAULT 0
    );

	CREATE TABLE IF NOT EXISTS dns_stats (
		email TEXT NOT NULL,
		count INTEGER DEFAULT 1,
		domain TEXT NOT NULL,
		PRIMARY KEY (email, domain)
	);`

	// Выполнение запроса
	_, err = db.Exec(query)
	if err != nil {
		return fmt.Errorf("ошибка выполнения SQL-запроса: %v", err)
	}
	fmt.Println("База данных успешно инициализирована")
	// Успешная инициализация базы данных
	return nil
}

// Функция для выполнения резервного копирования между базами
func backupDB(srcDB, destDB *sql.DB) error {
	srcConn, err := srcDB.Conn(context.Background())
	if err != nil {
		return fmt.Errorf("ошибка получения соединения с исходной базой: %v", err)
	}
	defer srcConn.Close()

	destConn, err := destDB.Conn(context.Background())
	if err != nil {
		return fmt.Errorf("ошибка получения соединения с целевой базой: %v", err)
	}
	defer destConn.Close()

	_, err = destConn.ExecContext(context.Background(), fmt.Sprintf("ATTACH DATABASE '%s' AS src_db;", config.DatabasePath))
	if err != nil {
		return fmt.Errorf("ошибка при подключении исходной базы: %v", err)
	}

	// Создаём таблицы с правильной схемой, включая ограничения
	_, err = destConn.ExecContext(context.Background(), `
        CREATE TABLE clients_stats (
            email TEXT PRIMARY KEY,
            level INTEGER,
            uuid TEXT,
            status TEXT,
            enabled TEXT,
            created TEXT,
            sub_end TEXT,
            sub_duration TEXT,
            ip_limit INTEGER NOT NULL DEFAULT 10,
            ip TEXT NOT NULL DEFAULT '',
            uplink INTEGER DEFAULT 0,
            downlink INTEGER DEFAULT 0,
            sess_uplink INTEGER DEFAULT 0,
            sess_downlink INTEGER DEFAULT 0
        );
        CREATE TABLE traffic_stats (
            source TEXT PRIMARY KEY,
            sess_uplink INTEGER DEFAULT 0,
            sess_downlink INTEGER DEFAULT 0,
            uplink INTEGER DEFAULT 0,
            downlink INTEGER DEFAULT 0
        );
        CREATE TABLE dns_stats (
            email TEXT NOT NULL,
            count INTEGER DEFAULT 1,
            domain TEXT NOT NULL,
            PRIMARY KEY (email, domain)
        );
    `)
	if err != nil {
		return fmt.Errorf("ошибка при создании таблиц в memDB: %v", err)
	}

	// Копируем данные из src_db в memDB
	_, err = destConn.ExecContext(context.Background(), `
        INSERT OR REPLACE INTO clients_stats SELECT * FROM src_db.clients_stats;
        INSERT OR REPLACE INTO traffic_stats SELECT * FROM src_db.traffic_stats;
        INSERT OR REPLACE INTO dns_stats SELECT * FROM src_db.dns_stats;
    `)
	if err != nil {
		return fmt.Errorf("ошибка при копировании данных: %v", err)
	}

	_, err = destConn.ExecContext(context.Background(), "DETACH DATABASE src_db;")
	if err != nil {
		return fmt.Errorf("ошибка при отключении исходной базы: %v", err)
	}

	return nil
}

// Функция для копирования базы данных в память
func loadDBIntoMemory(fileDB *sql.DB) (*sql.DB, error) {
	// Создаем in-memory базу
	memDB, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		return nil, fmt.Errorf("ошибка при создании in-memory базы: %v", err)
	}

	// Выполняем резервное копирование из fileDB в memDB
	err = backupDB(fileDB, memDB)
	if err != nil {
		memDB.Close()
		return nil, fmt.Errorf("ошибка при копировании данных в in-memory базу: %v", err)
	}

	return memDB, nil
}

// extractUsersXrayServer извлекает пользователей из config.json
func extractUsersXrayServer() []Client {
	configPath := config.DirXray + "config.json"
	data, err := os.ReadFile(configPath)
	if err != nil {
		log.Fatalf("Ошибка чтения config.json: %v", err)
	}

	var config ConfigXray
	if err := json.Unmarshal(data, &config); err != nil {
		log.Fatalf("Ошибка парсинга JSON: %v", err)
	}

	var clients []Client
	for _, inbound := range config.Inbounds {
		if inbound.Tag == "vless_raw" {
			clients = append(clients, inbound.Settings.Clients...)
		}
	}

	return clients
}

func getFileCreationTime() (string, error) {
	subJsonPath := extractData()
	if subJsonPath == "" {
		return "", fmt.Errorf("не удалось извлечь путь из конфигурационного файла")
	}

	subPath := fmt.Sprintf("/var/www/%s/vless_raw/cortez.json", subJsonPath)
	var stat syscall.Stat_t
	err := syscall.Stat(subPath, &stat)
	if err != nil {
		return "", err
	}

	// Получаем время создания файла
	creationTime := time.Unix(int64(stat.Ctim.Sec), int64(stat.Ctim.Nsec))

	// Форматируем время в нужный формат: yy-mm-dd-hh
	formattedTime := creationTime.Format("2006-01-02-15")

	return formattedTime, nil
}

func addUserToDB(db *sql.DB, clients []Client) error {
	tx, err := db.Begin()
	if err != nil {
		return fmt.Errorf("ошибка начала транзакции: %v", err)
	}
	stmt, err := tx.Prepare("INSERT OR IGNORE INTO clients_stats(email, level, uuid, status, enabled, created) VALUES (?, ?, ?, ?, ?, ?)")
	if err != nil {
		tx.Rollback()
		return fmt.Errorf("ошибка подготовки запроса: %v", err)
	}
	defer stmt.Close()

	for _, client := range clients {
		createdClient, err := getFileCreationTime()
		if err != nil {
			tx.Rollback()
			return fmt.Errorf("не удалось получить дату создания файла для клиента %s: %v", client.Email, err)
		}
		_, err = stmt.Exec(client.Email, client.Level, client.ID, "❌ offline", "true", createdClient)
		if err != nil {
			tx.Rollback()
			return fmt.Errorf("ошибка вставки клиента %s: %v", client.Email, err)
		}
	}
	return tx.Commit()
}

func delUserFromDB(db *sql.DB, clients []Client) error {
	rows, err := db.Query("SELECT email FROM clients_stats")
	if err != nil {
		return fmt.Errorf("ошибка выполнения запроса: %v", err)
	}
	defer rows.Close()

	var usersDB []string
	for rows.Next() {
		var email string
		if err := rows.Scan(&email); err != nil {
			return fmt.Errorf("ошибка сканирования строки: %v", err)
		}
		usersDB = append(usersDB, email)
	}

	var Queries string
	for _, user := range usersDB {
		found := false
		for _, xrayUser := range clients {
			if user == xrayUser.Email {
				found = true
				break
			}
		}
		if !found {
			Queries += fmt.Sprintf("DELETE FROM clients_stats WHERE email = '%s'; ", user)
		}
	}

	if Queries != "" {
		_, err := db.Exec(Queries)
		if err != nil {
			return fmt.Errorf("ошибка выполнения транзакции: %v", err)
		}
		fmt.Println("Пользователи успешно удалены из базы данных")
	}

	return nil
}

func getApiResponse() (*ApiResponse, error) {
	cmd := exec.Command(config.DirXray+"xray", "api", "statsquery")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("ошибка выполнения команды: %w", err)
	}

	var apiResponse ApiResponse
	if err := json.Unmarshal(output, &apiResponse); err != nil {
		return nil, fmt.Errorf("ошибка парсинга JSON: %w", err)
	}

	return &apiResponse, nil
}

func extractProxyTraffic(apiData *ApiResponse) []string {
	var result []string
	for _, stat := range apiData.Stat {
		// Пропускаем user, api и blocked
		if strings.Contains(stat.Name, "user") || strings.Contains(stat.Name, "api") || strings.Contains(stat.Name, "blocked") {
			continue
		}

		parts := splitAndCleanName(stat.Name)
		if len(parts) > 0 {
			result = append(result, fmt.Sprintf("%s %d", strings.Join(parts, " "), stat.Value))
		}
	}
	return result
}

// Фильтрация и возврат трафика пользователей
func extractUserTraffic(apiData *ApiResponse) []string {
	var result []string
	for _, stat := range apiData.Stat {
		if strings.Contains(stat.Name, "user") {
			parts := splitAndCleanName(stat.Name)
			if len(parts) > 0 {
				result = append(result, fmt.Sprintf("%s %d", strings.Join(parts, " "), stat.Value))
			}
		}
	}
	return result
}

// Разделение имени и удаление ненужных частей
func splitAndCleanName(name string) []string {
	parts := strings.Split(name, ">>>")
	if len(parts) == 4 {
		return []string{parts[1], parts[3]}
	}
	return nil
}

func updateProxyStats(db *sql.DB, apiData *ApiResponse) {
	// Получаем и фильтруем данные
	currentStats := extractProxyTraffic(apiData)

	// Выводим текущие данные для проверки
	// fmt.Println("Текущие статистические данные:", currentStats)

	if previousStats == "" {
		previousStats = strings.Join(currentStats, "\n")
	}

	currentValues := make(map[string]int)
	previousValues := make(map[string]int)

	// Преобразуем данные в мапу для текущих значений
	for _, line := range currentStats {
		parts := strings.Fields(line)
		// fmt.Println("Текущая строка для обработки:", line) // Добавляем вывод для каждой строки

		// Проверяем, что строка разделена на 3 части (source, direction, value)
		if len(parts) == 3 {
			currentValues[parts[0]+" "+parts[1]] = stringToInt(parts[2])
		} else {
			fmt.Println("Ошибка: некорректный формат строки:", line) // Выводим ошибку для строк с неправильным количеством частей
		}
	}

	// Выводим текущие значения для отладки
	// fmt.Println("Текущие значения (map):", currentValues)

	// Преобразуем предыдущие данные в мапу
	previousLines := strings.Split(previousStats, "\n")
	for _, line := range previousLines {
		parts := strings.Fields(line)
		if len(parts) == 3 {
			previousValues[parts[0]+" "+parts[1]] = stringToInt(parts[2])
		}
	}

	// Выводим предыдущие значения для отладки
	// fmt.Println("Предыдущие значения (map):", previousValues)

	// Создаем мапы для разницы трафика
	uplinkValues := make(map[string]int)
	downlinkValues := make(map[string]int)
	sessUplinkValues := make(map[string]int)
	sessDownlinkValues := make(map[string]int)

	// Сравниваем текущие и предыдущие значения
	for key, current := range currentValues {
		previous, exists := previousValues[key]
		if !exists {
			previous = 0
		}
		diff := current - previous
		if diff < 0 {
			diff = 0
		}

		// Разделяем ключи на источник и направление
		parts := strings.Fields(key)
		source := parts[0]
		direction := parts[1]

		// Выводим информацию о разнице трафика для каждой пары
		// fmt.Printf("Сравнение для %s %s: текущий %d, предыдущий %d, разница %d\n", source, direction, current, previous, diff)

		if direction == "uplink" {
			uplinkValues[source] = diff
			sessUplinkValues[source] = current
		} else if direction == "downlink" {
			downlinkValues[source] = diff
			sessDownlinkValues[source] = current
		}
	}

	// Выводим разницу трафика для uplink и downlink
	// fmt.Println("Значения uplink:", uplinkValues)
	//fmt.Println("Значения downlink:", downlinkValues)

	// Строим запросы для вставки или обновления данных в базе
	var queries string
	for source := range uplinkValues {
		uplink := uplinkValues[source]
		downlink := downlinkValues[source]
		sessUplink := sessUplinkValues[source]
		sessDownlink := sessDownlinkValues[source]

		// Строим SQL запрос
		queries += fmt.Sprintf("INSERT OR REPLACE INTO traffic_stats (source, uplink, downlink, sess_uplink, sess_downlink) "+
			"VALUES ('%s', %d, %d, %d, %d) ON CONFLICT(source) DO UPDATE SET uplink = uplink + %d, "+
			"downlink = downlink + %d, sess_uplink = %d, sess_downlink = %d;\n", source, uplink, downlink, sessUplink, sessDownlink, uplink, downlink, sessUplink, sessDownlink)
	}

	// Если есть запросы, выполняем их
	if queries != "" {
		_, err := db.Exec(queries)
		if err != nil {
			log.Fatalf("ошибка выполнения транзакции: %v", err)
		}
		// fmt.Println("Данные успешно добавлены или обновлены в базе данных")
	} else {
		fmt.Println("Нет новых данных для добавления или обновления.")
	}

	// Обновляем предыдущие значения
	previousStats = strings.Join(currentStats, "\n")
}

func updateClientStats(db *sql.DB, apiData *ApiResponse) {
	// Получаем и фильтруем данные
	clientCurrentStats := extractUserTraffic(apiData)

	if clientPreviousStats == "" {
		clientPreviousStats = strings.Join(clientCurrentStats, "\n")
		return
	}

	clientCurrentValues := make(map[string]int)
	clientPreviousValues := make(map[string]int)

	// Преобразуем текущие данные в мапу
	for _, line := range clientCurrentStats {
		parts := strings.Fields(line)
		if len(parts) == 3 {
			clientCurrentValues[parts[0]+" "+parts[1]] = stringToInt(parts[2])
		} else {
			fmt.Println("Ошибка: некорректный формат строки:", line)
		}
	}

	// Преобразуем предыдущие данные в мапу
	previousLines := strings.Split(clientPreviousStats, "\n")
	for _, line := range previousLines {
		parts := strings.Fields(line)
		if len(parts) == 3 {
			clientPreviousValues[parts[0]+" "+parts[1]] = stringToInt(parts[2])
		}
	}

	clientUplinkValues := make(map[string]int)
	clientDownlinkValues := make(map[string]int)
	clientSessUplinkValues := make(map[string]int)
	clientSessDownlinkValues := make(map[string]int)

	// Сравниваем текущие и предыдущие значения
	for key, current := range clientCurrentValues {
		previous, exists := clientPreviousValues[key]
		if !exists {
			previous = 0
		}
		diff := current - previous
		if diff < 0 {
			diff = 0
		}

		parts := strings.Fields(key)
		email := parts[0]
		direction := parts[1]

		if direction == "uplink" {
			clientUplinkValues[email] = diff
			clientSessUplinkValues[email] = current
		} else if direction == "downlink" {
			clientDownlinkValues[email] = diff
			clientSessDownlinkValues[email] = current
		}
	}

	// Обнуляем данные для отсутствующих email
	for key := range clientPreviousValues {
		parts := strings.Fields(key)
		if len(parts) != 2 {
			continue
		}
		email := parts[0]
		direction := parts[1]

		if direction == "uplink" {
			if _, exists := clientSessUplinkValues[email]; !exists {
				clientSessUplinkValues[email] = 0
				clientUplinkValues[email] = 0
			}
		} else if direction == "downlink" {
			if _, exists := clientSessDownlinkValues[email]; !exists {
				clientSessDownlinkValues[email] = 0
				clientDownlinkValues[email] = 0
			}
		}
	}

	// Строим SQL-запросы
	var queries string
	for email := range clientUplinkValues {
		uplink := clientUplinkValues[email]
		downlink := clientDownlinkValues[email]
		sessUplink := clientSessUplinkValues[email]
		sessDownlink := clientSessDownlinkValues[email]

		// Проверяем, есть ли предыдущие данные
		previousUplink, uplinkExists := clientPreviousValues[email+" uplink"]
		previousDownlink, downlinkExists := clientPreviousValues[email+" downlink"]

		if !uplinkExists {
			previousUplink = 0
		}
		if !downlinkExists {
			previousDownlink = 0
		}

		uplinkOnline := sessUplink - previousUplink
		downlinkOnline := sessDownlink - previousDownlink
		diffOnline := uplinkOnline + downlinkOnline

		// Определение статуса активности
		var onlineStatus string
		switch {
		case diffOnline < 1:
			onlineStatus = "❌ offline"
		case diffOnline < 24576:
			onlineStatus = "💤 idle"
		case diffOnline < 18874368:
			onlineStatus = "🟢 online"
		default:
			onlineStatus = "⚡ overload"
		}

		// SQL-запрос
		queries += fmt.Sprintf("INSERT OR REPLACE INTO clients_stats (email, status, uplink, downlink, sess_uplink, sess_downlink) "+
			"VALUES ('%s', '%s', %d, %d, %d, %d) ON CONFLICT(email) DO UPDATE SET "+
			"status = '%s', uplink = uplink + %d, downlink = downlink + %d, "+
			"sess_uplink = %d, sess_downlink = %d;\n",
			email, onlineStatus, uplink, downlink, sessUplink, sessDownlink,
			onlineStatus, uplink, downlink, sessUplink, sessDownlink)
	}

	if queries != "" {
		_, err := db.Exec(queries)
		if err != nil {
			log.Fatalf("ошибка выполнения транзакции: %v", err)
		}
	} else {
		fmt.Println("Нет новых данных для добавления или обновления.")
	}

	clientPreviousStats = strings.Join(clientCurrentStats, "\n")
}

func stringToInt(s string) int {
	var result int
	_, err := fmt.Sscanf(s, "%d", &result)
	if err != nil {
		log.Printf("ошибка преобразования строки в число: %v", err)
	}
	return result
}

func updateEnabledInDB(db *sql.DB, uuid string, enabled string) {
	_, err := db.Exec("UPDATE clients_stats SET enabled = ? WHERE uuid = ?", enabled, uuid)
	if err != nil {
		log.Printf("Ошибка обновления базы данных: %v", err)
	}
}

func parseAndUpdate(db *sql.DB, file *os.File) {
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		matches := rgx.FindStringSubmatch(line)
		if len(matches) == 3 {
			uuid := matches[1]
			enabled := matches[2]
			updateEnabledInDB(db, uuid, enabled)
		}
	}
}

func logExcessIPs(db *sql.DB) error {
	// Открытие лог-файла
	logFile, err := os.OpenFile(config.XIPLLogFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer logFile.Close()

	// Получение текущего времени в нужном формате
	currentTime := time.Now().Format("2006/01/02 15:04:05")

	// Запрос для получения email, ip_limit и ip из таблицы clients_stats
	rows, err := db.Query("SELECT email, ip_limit, ip FROM clients_stats")
	if err != nil {
		return err
	}
	defer rows.Close()

	// Обработка всех записей из таблицы
	for rows.Next() {
		var email string
		var ipLimit int
		var ipAddresses sql.NullString // Используем sql.NullString для обработки NULL

		err := rows.Scan(&email, &ipLimit, &ipAddresses)
		if err != nil {
			return err
		}

		// Если ipAddresses равно NULL, присваиваем пустую строку
		if !ipAddresses.Valid {
			ipAddresses.String = ""
		}

		// Убираем квадратные скобки и разбиваем IP-адреса по запятой
		ipAddresses.String = strings.Trim(ipAddresses.String, "[]")
		ipList := strings.Split(ipAddresses.String, ",")

		if len(ipList) > ipLimit {
			// Если IP-адресов больше, чем ipLimit, сохраняем избыточные в лог
			excessIPs := ipList[ipLimit:]
			for _, ip := range excessIPs {
				ip = strings.TrimSpace(ip)
				// Формируем строку в точном формате
				logData := fmt.Sprintf("%s [LIMIT_IP] Email = %s || SRC = %s\n", currentTime, email, ip)
				_, err := logFile.WriteString(logData)
				if err != nil {
					return err
				}
			}
		}
	}

	// Проверка на ошибки после обработки строк
	if err := rows.Err(); err != nil {
		return err
	}

	return nil
}

type DNSStat struct {
	Email  string
	Domain string
	Count  int
}

// Функция обновления IP в базе данных
func updateIPInDB(tx *sql.Tx, email string, ipList []string) error {
	ipStr := strings.Join(ipList, ",")
	query := `UPDATE clients_stats SET ip = ? WHERE email = ?`
	_, err := tx.Exec(query, ipStr, email)
	if err != nil {
		return fmt.Errorf("ошибка при обновлении данных: %v", err)
	}
	return nil
}

// Функция вставки или обновления записи в dns_stats
func upsertDNSRecord(tx *sql.Tx, email, domain string) error {
	_, err := tx.Exec(`
        INSERT INTO dns_stats (email, domain, count) 
        VALUES (?, ?, 1)
        ON CONFLICT(email, domain) 
        DO UPDATE SET count = count + 1`, email, domain)
	if err != nil {
		return fmt.Errorf("ошибка при обновлении dns_stats: %v", err)
	}
	return nil
}

// Обработка строк из access.log
func processLogLine(tx *sql.Tx, line string) {
	matches := re.FindStringSubmatch(line)
	if len(matches) != 4 {
		return
	}

	email := strings.TrimSpace(matches[3])
	domain := strings.TrimSpace(matches[2])
	ip := matches[1]

	mutex.Lock()
	if uniqueEntries[email] == nil {
		uniqueEntries[email] = make(map[string]time.Time)
	}
	uniqueEntries[email][ip] = time.Now()
	mutex.Unlock()

	validIPs := []string{}
	for ip, timestamp := range uniqueEntries[email] {
		if time.Since(timestamp) <= config.IP_TTL {
			validIPs = append(validIPs, ip)
		} else {
			delete(uniqueEntries[email], ip)
		}
	}

	if err := updateIPInDB(tx, email, validIPs); err != nil {
		log.Printf("Ошибка при обновлении IP в БД: %v", err)
	}

	if *dnsEnabled {
		if err := upsertDNSRecord(tx, email, domain); err != nil {
			log.Printf("Ошибка при обновлении DNS в БД: %v", err)
		}
	}
}

// Чтение новых строк из access.log
func readNewLines(db *sql.DB, file *os.File, offset *int64) {
	file.Seek(*offset, 0)
	scanner := bufio.NewScanner(file)

	// Начинаем транзакцию
	tx, err := db.Begin()
	if err != nil {
		log.Printf("Ошибка при создании транзакции: %v", err)
		return
	}

	for scanner.Scan() {
		processLogLine(tx, scanner.Text())
	}

	if err := scanner.Err(); err != nil {
		log.Printf("Ошибка чтения файла: %v", err)
		tx.Rollback()
		return
	}

	if err := tx.Commit(); err != nil {
		log.Printf("Ошибка при коммите транзакции: %v", err)
		tx.Rollback()
		return
	}

	pos, err := file.Seek(0, 1)
	if err != nil {
		log.Printf("Ошибка получения позиции файла: %v", err)
		return
	}
	*offset = pos
}

func checkExpiredSubscriptions(db *sql.DB) {
	now := time.Now()

	rows, err := db.Query("SELECT email, sub_end FROM clients_stats WHERE sub_end IS NOT NULL")
	if err != nil {
		log.Println("Ошибка при получении данных из БД:", err)
		return
	}
	defer rows.Close()

	for rows.Next() {
		var email string
		var subEndStr string

		err := rows.Scan(&email, &subEndStr)
		if err != nil {
			log.Println("Ошибка сканирования строки:", err)
			continue
		}

		subEnd, err := time.Parse("2006-01-02-15", subEndStr)
		if err != nil {
			log.Printf("Ошибка парсинга даты для %s, %v\n", email, err)
			continue
		}

		// Если подписка истекла
		if subEnd.Before(now) {
			log.Printf("❌ Подписка истекла для %s (sub_end: %s)\n", email, subEndStr)
		}
	}
}

// Функция для получения списка пользователей из базы в памяти
func usersHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json; charset=utf-8")

		if r.Method != http.MethodGet {
			http.Error(w, "Неверный метод. Используйте GET", http.StatusMethodNotAllowed)
			return
		}

		if db == nil {
			http.Error(w, "База данных не инициализирована", http.StatusInternalServerError)
			return
		}

		rows, err := db.Query("SELECT email FROM clients_stats")
		if err != nil {
			log.Printf("Ошибка выполнения SQL-запроса: %v", err)
			http.Error(w, "Ошибка выполнения запроса", http.StatusInternalServerError)
			return
		}
		defer rows.Close()

		var users []string
		for rows.Next() {
			var email string
			if err := rows.Scan(&email); err != nil {
				log.Printf("Ошибка чтения результата: %v", err)
				http.Error(w, "Ошибка обработки данных", http.StatusInternalServerError)
				return
			}
			users = append(users, email)
		}

		// Отправляем список пользователей в формате JSON
		if err := json.NewEncoder(w).Encode(users); err != nil {
			log.Printf("Ошибка кодирования JSON: %v", err)
			http.Error(w, "Ошибка формирования ответа", http.StatusInternalServerError)
			return
		}
	}
}

// Функция для получения статистики из базы в памяти
func statsHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")

		if r.Method != http.MethodGet {
			http.Error(w, "Неверный метод. Используйте GET", http.StatusMethodNotAllowed)
			return
		}

		if db == nil {
			http.Error(w, "База данных не инициализирована", http.StatusInternalServerError)
			return
		}

		// Статистика сервера
		stats := " 🌐 Статистика сервера:\n============================\n"
		stats += fmt.Sprintf("%-10s %-10s %-10s %-10s %-10s\n", "Source", "Sess Up", "Sess Down", "Upload", "Download")
		stats += "-----------------------------------------------------\n"

		rows, err := db.Query(`
            SELECT source AS "Source",
                CASE
                    WHEN sess_uplink >= 1024 * 1024 * 1024 THEN printf('%.2f GB', sess_uplink / 1024.0 / 1024.0 / 1024.0)
                    WHEN sess_uplink >= 1024 * 1024 THEN printf('%.2f MB', sess_uplink / 1024.0 / 1024.0)
                    WHEN sess_uplink >= 1024 THEN printf('%.2f KB', sess_uplink / 1024.0)
                    ELSE printf('%d B', sess_uplink)
                END AS "Sess Up",
                CASE
                    WHEN sess_downlink >= 1024 * 1024 * 1024 THEN printf('%.2f GB', sess_downlink / 1024.0 / 1024.0 / 1024.0)
                    WHEN sess_downlink >= 1024 * 1024 THEN printf('%.2f MB', sess_downlink / 1024.0 / 1024.0)
                    WHEN sess_downlink >= 1024 THEN printf('%.2f KB', sess_downlink / 1024.0)
                    ELSE printf('%d B', sess_downlink)
                END AS "Sess Down",
                CASE
                    WHEN uplink >= 1024 * 1024 * 1024 THEN printf('%.2f GB', uplink / 1024.0 / 1024.0 / 1024.0)
                    WHEN uplink >= 1024 * 1024 THEN printf('%.2f MB', uplink / 1024.0 / 1024.0)
                    WHEN uplink >= 1024 THEN printf('%.2f KB', uplink / 1024.0)
                    ELSE printf('%d B', uplink)
                END AS "Upload",
                CASE
                    WHEN downlink >= 1024 * 1024 * 1024 THEN printf('%.2f GB', downlink / 1024.0 / 1024.0 / 1024.0)
                    WHEN downlink >= 1024 * 1024 THEN printf('%.2f MB', downlink / 1024.0 / 1024.0)
                    WHEN downlink >= 1024 THEN printf('%.2f KB', downlink / 1024.0)
                    ELSE printf('%d B', downlink)
                END AS "Download"
            FROM traffic_stats;
        `)
		if err != nil {
			log.Printf("Ошибка выполнения SQL-запроса: %v", err)
			http.Error(w, "Ошибка выполнения запроса", http.StatusInternalServerError)
			return
		}
		defer rows.Close()

		for rows.Next() {
			var source, sessUp, sessDown, upload, download string
			if err := rows.Scan(&source, &sessUp, &sessDown, &upload, &download); err != nil {
				log.Printf("Ошибка чтения результата: %v", err)
				http.Error(w, "Ошибка обработки данных", http.StatusInternalServerError)
				return
			}
			stats += fmt.Sprintf("%-10s %-10s %-10s %-10s %-10s\n", source, sessUp, sessDown, upload, download)
		}

		// Статистика клиентов
		stats += "\n 📊 Статистика клиентов:\n============================\n"
		stats += fmt.Sprintf("%-12s %-11s %-8s %-10s %-10s %-10s %-10s %-6s %s\n",
			"Email", "Status", "Enabled", "Sess Up", "Sess Down", "Uplink", "Downlink", "LimIP", "IP")
		stats += "----------------------------------------------------------------------------------------------------------\n"

		rows, err = db.Query(`
    SELECT email AS "Email",
        status AS "Status",
        enabled AS "Enabled",
        ip AS "Ips",
        ip_limit AS "Lim_ip",
        CASE
            WHEN sess_uplink >= 1024 * 1024 * 1024 THEN printf('%.2f GB', sess_uplink / 1024.0 / 1024.0 / 1024.0)
            WHEN sess_uplink >= 1024 * 1024 THEN printf('%.2f MB', sess_uplink / 1024.0 / 1024.0)
            WHEN sess_uplink >= 1024 THEN printf('%.2f KB', sess_uplink / 1024.0)
            ELSE printf('%d B', sess_uplink)
        END AS "Sess Up",
        CASE
            WHEN sess_downlink >= 1024 * 1024 * 1024 THEN printf('%.2f GB', sess_downlink / 1024.0 / 1024.0 / 1024.0)
            WHEN sess_downlink >= 1024 * 1024 THEN printf('%.2f MB', sess_downlink / 1024.0 / 1024.0)
            WHEN sess_downlink >= 1024 THEN printf('%.2f KB', sess_downlink / 1024.0)
            ELSE printf('%d B', sess_downlink)
        END AS "Sess Down",
        CASE
            WHEN uplink >= 1024 * 1024 * 1024 THEN printf('%.2f GB', uplink / 1024.0 / 1024.0 / 1024.0)
            WHEN uplink >= 1024 * 1024 THEN printf('%.2f MB', uplink / 1024.0 / 1024.0)
            WHEN uplink >= 1024 THEN printf('%.2f KB', uplink / 1024.0)
            ELSE printf('%d B', uplink)
        END AS "Uplink",
        CASE
            WHEN downlink >= 1024 * 1024 * 1024 THEN printf('%.2f GB', downlink / 1024.0 / 1024.0 / 1024.0)
            WHEN downlink >= 1024 * 1024 THEN printf('%.2f MB', downlink / 1024.0 / 1024.0)
            WHEN downlink >= 1024 THEN printf('%.2f KB', downlink / 1024.0)
            ELSE printf('%d B', downlink)
        END AS "Downlink"
    FROM clients_stats;
`)
		if err != nil {
			log.Printf("Ошибка выполнения SQL-запроса: %v", err)
			http.Error(w, "Ошибка выполнения запроса", http.StatusInternalServerError)
			return
		}
		defer rows.Close()

		for rows.Next() {
			var email, status, enabled, sessUp, sessDown, uplink, downlink, ipLimit string
			var ips sql.NullString // Используем sql.NullString для столбца ip
			if err := rows.Scan(&email, &status, &enabled, &ips, &ipLimit, &sessUp, &sessDown, &uplink, &downlink); err != nil {
				log.Printf("Ошибка чтения результата: %v", err)
				http.Error(w, "Ошибка обработки данных", http.StatusInternalServerError)
				return
			}

			// Обработка значения ips
			ipStr := "N/A" // Значение по умолчанию, если ip NULL
			if ips.Valid {
				ipStr = ips.String // Используем строковое значение, если оно есть
			}

			// Формируем строку клиента
			stats += fmt.Sprintf("%-12s %-10s %-8s %-10s %-10s %-10s %-10s %-6s %s\n",
				email, status, enabled, sessUp, sessDown, uplink, downlink, ipLimit, ipStr)
		}

		fmt.Fprintln(w, stats)
	}
}

// Функция для получения статистики
func dnsStatsHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")

		if r.Method != http.MethodGet {
			http.Error(w, "Неверный метод. Используйте GET", http.StatusMethodNotAllowed)
			return
		}

		if db == nil {
			http.Error(w, "База данных не инициализирована", http.StatusInternalServerError)
			return
		}

		email := r.URL.Query().Get("email")
		count := r.URL.Query().Get("count")

		if email == "" {
			http.Error(w, "Missing email parameter", http.StatusBadRequest)
			return
		}

		if count == "" {
			count = "20"
		}

		if _, err := strconv.Atoi(count); err != nil {
			http.Error(w, "Invalid count parameter", http.StatusBadRequest)
			return
		}

		stats := " 📊 Статистика dns запросов:\n============================\n"
		stats += fmt.Sprintf("%-12s %-6s %-s\n", "Email", "Count", "Domain")
		stats += "-------------------------------------------------------------\n"
		rows, err := db.Query(`
			SELECT email AS "Email", count AS "Count", domain AS "Domain"
			FROM dns_stats
			WHERE email = ?
			ORDER BY count DESC
			LIMIT ?`, email, count)
		if err != nil {
			log.Printf("Ошибка выполнения SQL-запроса: %v", err)
			http.Error(w, "Ошибка выполнения запроса", http.StatusInternalServerError)
			return
		}
		defer rows.Close()

		for rows.Next() {
			var email, domain string
			var count int
			if err := rows.Scan(&email, &count, &domain); err != nil {
				log.Printf("Ошибка чтения результата: %v", err)
				http.Error(w, "Ошибка обработки данных", http.StatusInternalServerError)
				return
			}
			stats += fmt.Sprintf("%-12s %-6d %-s\n", email, count, domain)
		}

		fmt.Fprintln(w, stats)
	}
}

func updateIPLimitHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")

		// Проверяем, что метод запроса - PATCH
		if r.Method != http.MethodPatch {
			http.Error(w, "Неверный метод. Используйте PATCH", http.StatusMethodNotAllowed)
			return
		}

		// Проверка инициализации базы данных
		if db == nil {
			http.Error(w, "База данных не инициализирована", http.StatusInternalServerError)
			return
		}

		// Читаем параметры из формы (POST или PATCH тело запроса)
		err := r.ParseForm()
		if err != nil {
			http.Error(w, "Ошибка парсинга формы", http.StatusBadRequest)
			return
		}

		// Извлекаем параметры
		username := r.FormValue("username")
		ipLimit := r.FormValue("ip_limit")

		// Проверяем, что параметры не пустые
		if username == "" || ipLimit == "" {
			http.Error(w, "Неверные параметры. Используйте username и ip_limit", http.StatusBadRequest)
			return
		}

		// Проверяем, что ip_limit - это число в пределах от 1 до 100
		ipLimitInt, err := strconv.Atoi(ipLimit)
		if err != nil {
			http.Error(w, "ip_limit должен быть числом", http.StatusBadRequest)
			return
		}

		if ipLimitInt < 1 || ipLimitInt > 100 {
			http.Error(w, "ip_limit должен быть в пределах от 1 до 100", http.StatusBadRequest)
			return
		}

		// Выполняем обновление в базе данных
		query := "UPDATE clients_stats SET ip_limit = ? WHERE email = ?"
		result, err := db.Exec(query, ipLimit, username)
		if err != nil {
			http.Error(w, "Ошибка обновления ip_limit", http.StatusInternalServerError)
			return
		}

		rowsAffected, _ := result.RowsAffected()
		if rowsAffected == 0 {
			http.Error(w, fmt.Sprintf("Пользователь '%s' не найден", username), http.StatusNotFound)
			return
		}

		// Ответ о успешном обновлении
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, "ip_limit для '%s' обновлен до '%s'\n", username, ipLimit)
	}
}

func deleteDNSStatsHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Неверный метод. Используйте POST", http.StatusMethodNotAllowed)
			return
		}

		if db == nil {
			http.Error(w, "База данных не инициализирована", http.StatusInternalServerError)
			return
		}

		_, err := db.Exec("DELETE FROM dns_stats")
		if err != nil {
			http.Error(w, "Не удалось удалить записи из dns_stats", http.StatusInternalServerError)
			return
		}

		log.Printf("Received request to delete dns_stats from %s", r.RemoteAddr)
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "dns_stats deleted successfully")
	}
}

// Разбирает строку и корректирует дату
func parseAndAdjustDate(offset string, baseDate time.Time) (time.Time, error) {
	// Регулярка для разбора формата (+/-)число(:число)?
	re := regexp.MustCompile(`^([+-]?)(\d+)(?::(\d+))?$`)
	matches := re.FindStringSubmatch(offset)

	if matches == nil {
		return time.Time{}, fmt.Errorf("неверный формат: %s", offset)
	}

	sign := matches[1] // + или -
	daysStr := matches[2]
	hoursStr := matches[3]

	// Конвертируем в числа
	days, _ := strconv.Atoi(daysStr)
	hours := 0
	if hoursStr != "" {
		hours, _ = strconv.Atoi(hoursStr)
	}

	// Определяем направление (прибавлять или убавлять)
	if sign == "-" {
		days = -days
		hours = -hours
	}

	// Корректируем дату
	newDate := baseDate.AddDate(0, 0, days).Add(time.Duration(hours) * time.Hour)
	return newDate, nil
}

func adjustDateOffsetHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPatch {
			http.Error(w, "Неверный метод. Используйте PATCH", http.StatusMethodNotAllowed)
			return
		}

		if db == nil {
			http.Error(w, "База данных не инициализирована", http.StatusInternalServerError)
			return
		}

		if err := r.ParseForm(); err != nil {
			http.Error(w, "Ошибка парсинга данных", http.StatusBadRequest)
			return
		}

		email := r.FormValue("email")
		offset := r.FormValue("offset")

		if email == "" || offset == "" {
			http.Error(w, "email и offset обязательны", http.StatusBadRequest)
			return
		}
		offset = strings.TrimSpace(offset)

		var subEndStr sql.NullString
		err := db.QueryRow("SELECT sub_end FROM clients_stats WHERE email = ?", email).Scan(&subEndStr)
		if err != nil {
			if err == sql.ErrNoRows {
				http.Error(w, "Пользователь не найден", http.StatusNotFound)
				return
			}
			http.Error(w, "Ошибка запроса к БД", http.StatusInternalServerError)
			return
		}

		var baseDate time.Time
		if subEndStr.Valid && subEndStr.String != "" {
			baseDate, err = time.Parse("2006-01-02-15", subEndStr.String)
			if err != nil {
				http.Error(w, "Ошибка парсинга sub_end", http.StatusInternalServerError)
				return
			}
		} else {
			baseDate = time.Now().UTC()
		}

		newDate, err := parseAndAdjustDate(offset, baseDate)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		_, err = db.Exec("UPDATE clients_stats SET sub_end = ? WHERE email = ?", newDate.Format("2006-01-02-15"), email)
		if err != nil {
			http.Error(w, "Ошибка обновления БД", http.StatusInternalServerError)
			return
		}

		fmt.Fprintf(w, "Email: %s (смещение %s)\n%s >>> %s\n",
			email, offset, baseDate.Format("2006-01-02-15"), newDate.Format("2006-01-02-15"))
	}
}

// Функция запуска HTTP-сервера с graceful shutdown
func startAPIServer(ctx context.Context, memDB *sql.DB, wg *sync.WaitGroup) {
	defer wg.Done()

	server := &http.Server{
		Addr:    "127.0.0.1:9952",
		Handler: nil, // Используем стандартный маршрутизатор
	}

	// Регистрируем маршруты
	http.HandleFunc("/users", usersHandler(memDB))
	http.HandleFunc("/stats", statsHandler(memDB))
	http.HandleFunc("/dns_stats", dnsStatsHandler(memDB))
	http.HandleFunc("/update_ip_limit", updateIPLimitHandler(memDB))
	http.HandleFunc("/delete_dns_stats", deleteDNSStatsHandler(memDB))
	http.HandleFunc("/adjust-date", adjustDateOffsetHandler(memDB))

	// Запускаем сервер в отдельной горутине
	go func() {
		log.Println("API сервер запущен на 127.0.0.1:9952")
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Ошибка запуска сервера: %v", err)
		}
	}()

	// Ожидаем сигнала завершения
	<-ctx.Done()
	log.Println("Остановка API-сервера...")
	if err := server.Shutdown(context.Background()); err != nil {
		log.Printf("Ошибка при остановке сервера: %v", err)
	}
}

// Функция для синхронизации данных из memDB в fileDB
func syncToFileDB(memDB, fileDB *sql.DB) error {
	// Список таблиц для синхронизации
	tables := []string{"clients_stats", "traffic_stats", "dns_stats"}

	// Начинаем транзакцию в fileDB
	tx, err := fileDB.Begin()
	if err != nil {
		return fmt.Errorf("ошибка начала транзакции в fileDB: %v", err)
	}

	// Проходим по каждой таблице
	for _, table := range tables {
		// Очищаем таблицу в fileDB перед вставкой (опционально, можно заменить на INSERT OR REPLACE)
		_, err = tx.Exec(fmt.Sprintf("DELETE FROM %s", table))
		if err != nil {
			tx.Rollback()
			return fmt.Errorf("ошибка очистки таблицы %s в fileDB: %v", table, err)
		}

		// Получаем все строки из memDB
		rows, err := memDB.Query(fmt.Sprintf("SELECT * FROM %s", table))
		if err != nil {
			tx.Rollback()
			return fmt.Errorf("ошибка получения данных из таблицы %s в memDB: %v", table, err)
		}
		defer rows.Close()

		// Получаем информацию о столбцах
		columns, err := rows.Columns()
		if err != nil {
			tx.Rollback()
			return fmt.Errorf("ошибка получения столбцов таблицы %s: %v", table, err)
		}

		// Подготовка запроса для вставки
		placeholders := strings.Repeat("?,", len(columns)-1) + "?"
		insertQuery := fmt.Sprintf("INSERT INTO %s (%s) VALUES (%s)", table, strings.Join(columns, ","), placeholders)
		stmt, err := tx.Prepare(insertQuery)
		if err != nil {
			tx.Rollback()
			return fmt.Errorf("ошибка подготовки запроса для таблицы %s: %v", table, err)
		}
		defer stmt.Close()

		// Копируем строки
		values := make([]interface{}, len(columns))
		valuePtrs := make([]interface{}, len(columns))
		for i := range values {
			valuePtrs[i] = &values[i]
		}

		for rows.Next() {
			if err := rows.Scan(valuePtrs...); err != nil {
				tx.Rollback()
				return fmt.Errorf("ошибка сканирования строки таблицы %s: %v", table, err)
			}
			_, err = stmt.Exec(values...)
			if err != nil {
				tx.Rollback()
				return fmt.Errorf("ошибка вставки строки в таблицу %s: %v", table, err)
			}
		}
	}

	// Завершаем транзакцию
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("ошибка коммита транзакции в fileDB: %v", err)
	}

	return nil
}

func main() {
	// Парсим флаги перед началом работы программы
	flag.Parse()

	// Открываем соединение с базой данных на диске
	fileDB, err := sql.Open("sqlite3", config.DatabasePath)
	if err != nil {
		log.Fatal("Ошибка открытия базы данных:", err)
	}
	defer fileDB.Close()

	// Инициализация базы данных на диске
	err = initDB(fileDB)
	if err != nil {
		log.Fatal("Ошибка инициализации базы данных:", err)
	}

	// Копируем базу в память
	memDB, err := loadDBIntoMemory(fileDB)
	if err != nil {
		log.Fatal(err)
	}
	defer memDB.Close()

	// Очищаем содержимое файла перед чтением
	err = os.Truncate(config.AccessLogPath, 0)
	if err != nil {
		fmt.Println("Ошибка очистки файла:", err)
		return
	}

	// Открываем файл access.log
	accessLog, err := os.Open(config.AccessLogPath)
	if err != nil {
		log.Fatalf("Ошибка при открытии access.log: %v", err)
	}
	defer accessLog.Close()

	// Создаём контекст для graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Канал для получения сигналов завершения
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	var wg sync.WaitGroup

	// Запуск API-сервера
	wg.Add(1)
	go startAPIServer(ctx, memDB, &wg)

	// Логирование лишних IP
	wg.Add(1)
	go func() {
		defer wg.Done()
		ticker := time.NewTicker(1 * time.Minute)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				err := logExcessIPs(memDB)
				if err != nil {
					log.Printf("Ошибка логирования IP: %v", err)
				}
			case <-ctx.Done():
				return
			}
		}
	}()

	// Проверка подписок
	wg.Add(1)
	go func() {
		defer wg.Done()
		ticker := time.NewTicker(1 * time.Minute)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				checkExpiredSubscriptions(memDB)
			case <-ctx.Done():
				return
			}
		}
	}()

	// Основной цикл обновления данных
	wg.Add(1)
	go func() {
		defer wg.Done()
		ticker := time.NewTicker(10 * time.Second)
		defer ticker.Stop()
		var offset int64 = 0
		for {
			select {
			case <-ticker.C:
				starttime := time.Now()
				clients := extractUsersXrayServer()
				if err := addUserToDB(memDB, clients); err != nil {
					log.Printf("Ошибка при добавлении пользователя: %v", err)
				}
				if err := delUserFromDB(memDB, clients); err != nil {
					log.Printf("Ошибка при удалении пользователей: %v", err)
				}
				luaConf, err := os.Open(config.LUAFilePath)
				if err != nil {
					fmt.Println("Ошибка открытия файла:", err)
				} else {
					parseAndUpdate(memDB, luaConf)
					luaConf.Close()
				}
				apiData, err := getApiResponse()
				if err != nil {
					log.Printf("Ошибка получения данных из API: %v", err)
				} else {
					updateProxyStats(memDB, apiData)
					updateClientStats(memDB, apiData)
				}
				readNewLines(memDB, accessLog, &offset)
				elapsed := time.Since(starttime)
				fmt.Printf("Время выполнения программы: %s\n", elapsed)
			case <-ctx.Done():
				return
			}
		}
	}()

	// Ожидание сигнала завершения
	<-sigChan
	log.Println("Получен сигнал завершения, сохраняем данные...")
	cancel() // Останавливаем все горутины

	// Синхронизация данных в fileDB перед завершением
	if err := syncToFileDB(memDB, fileDB); err != nil {
		log.Printf("Ошибка синхронизации данных в fileDB: %v", err)
	} else {
		log.Println("Данные успешно сохранены в файл базы данных")
	}

	wg.Wait()
	log.Println("Программа завершена")
}
