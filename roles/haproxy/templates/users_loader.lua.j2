local M = {}

-- Оптимизация: предкомпиляция паттерна поиска (микро-оптимизация)
-- Формат: enabled(не запятая), username(не запятая), credential(все остальное)
local CSV_PATTERN = "^([^,]+),([^,]+),(.+)$"

function M.load_users_file(path)
    local users = {
        vless = {},   -- map: clean_uuid (32 chars) -> username
        trojan = {}   -- map: sha224 (56 chars) -> username
    }

    local f = io.open(path, "r")
    if not f then
        if core and core.Warning then
            core.Warning("Lua: cannot open users file: " .. path)
        end
        return users
    end

    -- BEST PRACTICE: Читаем файл построчно, чтобы не грузить RAM
    for line in f:lines() do
        -- Пропускаем пустые строки
        if line ~= "" then
            local enabled, username, cred = line:match(CSV_PATTERN)
            
            -- Используем строгое сравнение с "1"
            if enabled == "1" and username and cred then
                -- Эффективный trim (убираем пробелы по краям)
                cred = cred:match("^%s*(.-)%s*$")
                
                -- Быстрая проверка длины без создания лишних переменных
                local len = #cred
                
                if len == 56 then
                    -- SHA224 (Trojan)
                    users.trojan[cred] = username

                elseif len == 32 then
                    -- UUID (VLESS) - убираем дефисы только если длина похожа на UUID с дефисами (36) или без (32)
                    -- Но в твоем коде логика была на 32. Если в файле UUID без дефисов:
                    users.vless[cred] = username
                    
                elseif len == 36 then
                     -- Если в файле UUID с дефисами (стандарт), убираем их "на лету"
                    local clean = cred:gsub("-", "")
                    if #clean == 32 then
                        users.vless[clean] = username
                    end
                end
            end
        end
    end

    f:close()
    return users
end

return M