-- Убедитесь, что путь к вашему модулю включен
package.path = "/etc/haproxy/lua/?.lua;" .. package.path

local loader = require("users_loader")

local loaded = loader.load_users_file("/etc/haproxy/data/users.csv")

-- users: clean-uuid → username
local uuid_map = {}
for _, entry in ipairs(loaded) do
    uuid_map[entry.uuid] = entry.user
end

-- Ищем логин по чистому hash (UUID без дефисов)
local function find_user_by_clean_hash(clean_hash)
    return uuid_map[clean_hash] -- вернёт username или nil
end

-- Функция аутентификации для VLESS
function vless_auth(txn)
    local status, data = pcall(function() return txn.req:dup() end)
    if status and data and #data >= 17 then
        -- VLESS UUID/Password находится в байтах 2-17 (16 байт) ClientHello
        local sniffed_password = string.sub(data, 2, 17)

        -- Преобразуем 16 байт (raw binary) в 32-символьную hex-строку (clean-uuid)
        local hex_pass = (sniffed_password:gsub(".", function(c)
            return string.format("%02x", string.byte(c))
        end))
        
        -- core.Info("Sniffed password hex: " .. hex_pass)

        local found_login = find_user_by_clean_hash(hex_pass)
        
        if found_login then
            txn:Info("login: " .. found_login .. "; ip: " .. txn.sf:src()) 
            -- Возвращаем имя бэкенда для успешной аутентификации (например, "xray")
            return "xray" 
        end
    end
    
    -- Если не удалось аутентифицировать или возникла ошибка, 
    -- возвращаем имя бэкенда по умолчанию (например, "http" для перенаправления/заглушки)
    -- txn:Info("VLESS login failed or incomplete data; ip: " .. txn.sf:src())
    return "http"
end

core.register_fetches("vless_auth", vless_auth)
