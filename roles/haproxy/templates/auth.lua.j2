-- auth.lua
package.path = "/etc/haproxy/lua/?.lua;" .. package.path

local loader = require("users_loader")

-- КОНСТАНТЫ (читаемость + защита от опечаток)
local PATH_USERS = "/etc/haproxy/data/users.csv"
local TROJAN_MIN_LEN = 66    -- 56 (hash) + 2 (CRLF) + что-то еще
local TROJAN_HASH_LEN = 56
local VLESS_MIN_LEN = 17
local MUX_PATTERN = "sp%.mux"
local MUX_OFFSET = 59        -- Где начинать искать MUX (после 56 байт хеша + 2 байт CRLF)

-- Загружаем пользователей
local users_db = loader.load_users_file(PATH_USERS)

-- ОПТИМИЗАЦИЯ: Таблица для быстрого перевода байта в hex
-- Это работает быстрее, чем string.format или gsub на каждом вызове
local hex_table = {}
for i = 0, 255 do
    hex_table[i] = string.format("%02x", i)
end

-- Быстрая функция tohex без callback-ов и регулярок
local function tohex(str)
    local result = {}
    for i = 1, #str do
        -- table.insert медленнее прямого присваивания по индексу
        result[i] = hex_table[string.byte(str, i)]
    end
    return table.concat(result)
end

-- Проверка на Trojan MUX (smux)
-- Используем string.find с начальной позицией, чтобы не делать sub (не копировать строку)
local function check_trojan_mux(data)
    -- Ищем паттерн начиная с 59-го байта.
    -- Если true, значит паттерн найден.
    if data:find(MUX_PATTERN, MUX_OFFSET) then
        return true
    end
    return false
end

-- Основная функция (делаем её local, так как она передается в register_fetches)
local function identify_protocol(txn)
    -- Получаем копию буфера. pcall тут оправдан, так как req:dup() может сбоить
    local status, data = pcall(function() return txn.req:dup() end)
    
    if not status or not data then
        return "http"
    end
    
    local data_len = #data

    -- 1. Проверка TROJAN
    if data_len >= TROJAN_MIN_LEN then
        -- Тут sub оправдан, нам нужен ключ для поиска в map
        local text_hash = data:sub(1, TROJAN_HASH_LEN)
        
        local user = users_db.trojan[text_hash]
        
        if user then
            local is_mux = check_trojan_mux(data)
            local isMultiplex = is_mux and "trojan" or "trojan-nomux"
            
            -- Логирование через string.format (чище и быстрее конкатенации)
            -- txn:Info(string.format("Multiplex: %s", isMultiplex))
            txn:Info(string.format("Trojan login: %s; ip: %s", user, txn.sf:src()))
            
            return isMultiplex
        end
    end

    -- 2. Проверка VLESS
    -- Нам нужны байты со 2-го по 17-й (всего 16 байт)
    if data_len >= VLESS_MIN_LEN then
        local raw_uuid = data:sub(2, 17)
        local uuid_hex = tohex(raw_uuid)
        
        local user = users_db.vless[uuid_hex]

        if user then
            txn:Info(string.format("VLESS login: %s; ip: %s", user, txn.sf:src()))
            return "vless"
        end
    end

    -- Если ни один протокол не подошел
    return "http"
end

-- Регистрируем fetch
core.register_fetches("identify_protocol", identify_protocol)