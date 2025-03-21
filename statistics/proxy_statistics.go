package main

import (
	"bufio"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

var (
	accessLogPath       = "/usr/local/etc/xray/access.log"
	re                  = regexp.MustCompile(`from tcp:([0-9\.]+).*?email: (\S+)`) // Регулярное выражение
	ipTTL               = 3 * time.Minute                                          // Время жизни IP (по умолчанию 5 минут)
	uniqueEntries       = make(map[string]map[string]time.Time)                    // email -> {IP: время добавления}
	mutex               = &sync.Mutex{}
	dataBasePath        = "/usr/local/reverse_proxy/projectgo/reverse.db"
	dirXray             = "/usr/local/etc/xray/"
	configFileHaproxy   = "/etc/haproxy/haproxy.cfg"
	previousStats       string
	clientPreviousStats string
	//luaFilePath         = "/etc/haproxy/.auth.lua"
)

func extractData() string {
	file, err := os.Open(configFileHaproxy)
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
      ip_limit INTEGER DEFAULT 10,
      ip TEXT,
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
    );`

	// Выполнение запроса
	_, err := db.Exec(query)
	if err != nil {
		return fmt.Errorf("ошибка выполнения SQL-запроса: %v", err)
	}
	// fmt.Println("База данных успешно инициализирована")
	// Успешная инициализация базы данных
	return nil
}

// Структуры для представления данных из конфигурации Xray
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

type Config struct {
	Inbounds []Inbound `json:"inbounds"`
}

// extractUsersXrayServer извлекает пользователей из config.json
func extractUsersXrayServer() []Client {
	configPath := dirXray + "config.json"
	data, err := os.ReadFile(configPath)
	if err != nil {
		log.Fatalf("Ошибка чтения config.json: %v", err)
	}

	var config Config
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
	var queries string

	for _, client := range clients {
		// Получаем дату создания файла
		createdClient, err := getFileCreationTime()
		if err != nil {
			return fmt.Errorf("не удалось получить дату создания файла для клиента %s: %v", client.Email, err)
		}

		query := fmt.Sprintf(
			"INSERT OR IGNORE INTO clients_stats(email, level, uuid, status, enabled, created) "+
				"VALUES ('%s', %d, '%s', '❌ offline', 'true', '%s'); ",
			client.Email, client.Level, client.ID, createdClient,
		)
		queries += query
	}

	if queries != "" {
		// Используем = для присваивания, так как переменная err уже была объявлена
		_, err := db.Exec(queries)
		if err != nil {
			return fmt.Errorf("ошибка выполнения транзакции: %v", err)
		}
		// fmt.Println("Пользователи успешно добавлены в базу данных")
	}

	return nil
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
		for _, xrayUser := range clients { // здесь заменяем usersXray на clients
			if user == xrayUser.Email { // сравниваем по Email
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

// Структура для парсинга JSON-ответа
type Stat struct {
	Name  string `json:"name"`
	Value int    `json:"value"`
}

type ApiResponse struct {
	Stat []Stat `json:"stat"`
}

func getApiResponse() (*ApiResponse, error) {
	cmd := exec.Command(dirXray+"xray", "api", "statsquery")
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
		case diffOnline < 25000:
			onlineStatus = "💤 idle"
		case diffOnline < 12000000:
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

// Функция обновления IP в базе данных
func updateIPInDB(email string, ipList []string) error {
	db, err := sql.Open("sqlite3", dataBasePath)
	if err != nil {
		return fmt.Errorf("ошибка при подключении к БД: %v", err)
	}
	defer db.Close()

	ipStr := strings.Join(ipList, ",")
	query := `UPDATE clients_stats SET ip = ? WHERE email = ?`
	_, err = db.Exec(query, ipStr, email)
	if err != nil {
		return fmt.Errorf("ошибка при обновлении данных: %v", err)
	}

	return nil
}

// Функция обработки строк из access.log
func processLogLine(line string) {
	matches := re.FindStringSubmatch(line)
	if len(matches) != 3 {
		return
	}

	ip := matches[1]
	email := matches[2]

	mutex.Lock()
	defer mutex.Unlock()

	if uniqueEntries[email] == nil {
		uniqueEntries[email] = make(map[string]time.Time)
	}

	uniqueEntries[email][ip] = time.Now()

	validIPs := []string{}
	for ip, timestamp := range uniqueEntries[email] {
		if time.Since(timestamp) <= ipTTL {
			validIPs = append(validIPs, ip)
		} else {
			delete(uniqueEntries[email], ip)
		}
	}

	updateIPInDB(email, validIPs)
	// err := updateIPInDB(email, validIPs)
	//
	//	if err != nil {
	//		fmt.Println("Ошибка обновления БД:", err)
	//	} else {
	//
	//		fmt.Printf("Обновлены IP для %s: %v\n", email, validIPs)
	//	}
}

// Функция чтения новых строк из access.log
func readNewLines(accessLog *os.File, offset *int64) {
	accessLog.Seek(*offset, 0)

	scanner := bufio.NewScanner(accessLog)
	for scanner.Scan() {
		processLogLine(scanner.Text())
	}

	if err := scanner.Err(); err != nil {
		fmt.Println("Ошибка чтения файла:", err)
	}

	pos, _ := accessLog.Seek(0, os.SEEK_CUR)
	*offset = pos
}

// Функция установки нового `ipTTL` через API
func setIPTTLHandler(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()
	ttlStr := query.Get("minutes")

	if ttlStr == "" {
		http.Error(w, "Параметр 'minutes' отсутствует", http.StatusBadRequest)
		return
	}

	ttl, err := strconv.Atoi(ttlStr)
	if err != nil || ttl <= 0 {
		http.Error(w, "Некорректное значение 'minutes'", http.StatusBadRequest)
		return
	}

	mutex.Lock()
	ipTTL = time.Duration(ttl) * time.Minute
	mutex.Unlock()

	response := fmt.Sprintf("Время жизни IP установлено на %d минут\n", ttl)
	fmt.Println(response)
	w.Write([]byte(response))
}

// Функция для получения статистики
func getStats() string {
	// Статистика сервера
	stats := "🌐 Статистика сервера:\n==========================\n"
	// Запрос для статистики сервера
	cmd := exec.Command(
		"sqlite3", dataBasePath,
		"-cmd", ".headers on",
		"-cmd", ".mode column",
		"SELECT source AS 'Source', "+
			"printf('%.2f MB', sess_uplink / 1024.0 / 1024.0) AS 'S Upload', "+
			"printf('%.2f MB', sess_downlink / 1024.0 / 1024.0) AS 'S Download', "+
			"printf('%.2f MB', uplink / 1024.0 / 1024.0) AS 'Upload', "+
			"printf('%.2f MB', downlink / 1024.0 / 1024.0) AS 'Download' "+
			"FROM traffic_stats;",
	)

	// Получаем результат запроса
	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("Ошибка выполнения SQL-запроса: %v\n%s", err, string(output))
	}
	stats += string(output)

	// Статистика клиентов
	stats += "\n📊 Статистика клиентов:\n==========================\n"
	// Запрос для статистики клиентов
	cmd = exec.Command(
		"sqlite3", dataBasePath,
		"-cmd", ".headers on",
		"-cmd", ".mode column",
		"SELECT email AS 'Email', "+
			"status AS 'Status', "+
			"enabled AS 'Enabled', "+
			"created AS 'Created', "+
			"ip AS 'Ips', "+
			"ip_limit AS 'Lim_ip', "+
			"printf('%.2f MB', sess_uplink / 1024.0 / 1024.0) AS 'S Upload', "+
			"printf('%.2f MB', sess_downlink / 1024.0 / 1024.0) AS 'S Download', "+
			"printf('%.2f MB', uplink / 1024.0 / 1024.0) AS 'Upload', "+
			"printf('%.2f MB', downlink / 1024.0 / 1024.0) AS 'Download' "+
			"FROM clients_stats;",
	)

	// Получаем результат запроса
	output, err = cmd.CombinedOutput()
	if err != nil {
		log.Printf("Ошибка выполнения SQL-запроса: %v\n%s", err, string(output))
	}
	stats += string(output)

	return stats
}

// Обработчик для API
func statsHandler(w http.ResponseWriter, r *http.Request) {
	// Получаем актуальную статистику
	stats := getStats()

	// Отправляем статистику в ответ
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	fmt.Fprintln(w, stats)
}

// Функция запуска HTTP-сервера
func startAPIServer() {
	http.HandleFunc("/set_ttl", setIPTTLHandler)
	http.HandleFunc("/stats", statsHandler) // Регистрируем обработчик для пути /stats
	log.Println("API сервер запущен на 127.0.0.1:9998")
	log.Fatal(http.ListenAndServe("127.0.0.1:9998", nil))
}

func main() {
	// Открываем соединение с базой данных
	db, err := sql.Open("sqlite3", dataBasePath)
	if err != nil {
		log.Fatal("Ошибка открытия базы данных:", err)
	}
	defer db.Close()

	// Открываем файл access.log
	accessLog, err := os.Open(accessLogPath)
	if err != nil {
		log.Fatalf("Ошибка при открытии access.log: %v", err)
	}
	defer accessLog.Close()

	var offset int64

	// Используем ticker для регулярного запуска каждые 10 секунд
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	// Запуск API в отдельной горутине
	go startAPIServer()

	// Запускаем горутину для чтения новых строк из access.log
	go func() {
		for {
			readNewLines(accessLog, &offset)
			<-ticker.C
		}
	}()

	// Запускаем бесконечный цикл, который будет выполняться каждую итерацию через 10 секунд
	for {
		starttime := time.Now()

		// Инициализация базы данных
		err = initDB(db)
		if err != nil {
			log.Fatal("Ошибка инициализации базы данных:", err)
		}

		clients := extractUsersXrayServer()

		err = addUserToDB(db, clients)
		if err != nil {
			log.Fatalf("Ошибка при добавлении пользователя: %v", err)
		}

		err = delUserFromDB(db, clients)
		if err != nil {
			log.Fatalf("Ошибка при удалении пользователей: %v", err)
		}

		// Получаем данные API
		apiData, err := getApiResponse()
		if err != nil {
			log.Fatalf("Ошибка получения данных из API: %v", err)
		}

		// Обновляем статистику
		updateProxyStats(db, apiData)
		updateClientStats(db, apiData)

		elapsed := time.Since(starttime)
		fmt.Printf("Время выполнения программы: %s\n", elapsed)

		// Ждем 10 секунд перед следующей итерацией
		<-ticker.C
	}
}
