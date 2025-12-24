local M = {}

-- Функция для удаления дефисов из UUID
local function remove_hyphens(uuid)
    -- Убедимся, что это строка и что она не пуста, прежде чем пытаться заменить
    if type(uuid) == 'string' and uuid ~= "" then
        return uuid:gsub("-", "")
    end
    return nil
end

-- Функция для парсинга строк CSV
-- Ожидаемый формат: enabled,username,uuid
local function parse_csv_lines(lines)
    local users = {}
    -- Используем gmatch для итерации по строкам, учитывая разные разделители строк
    for line in lines:gmatch("[^\r\n]+") do
        -- Ищем шаблон: 1. значение до запятой (enabled), 2. значение до запятой (username), 3. оставшаяся часть (uuid)
        local enabled, username, uuid_dash = line:match("^([^,]+),([^,]+),(.+)$")
        
        -- Проверяем, что строка "enabled" - это "1" и что есть username и uuid
        if enabled == "1" and username and uuid_dash then
            local uuid_clean = remove_hyphens(uuid_dash)
            if uuid_clean and #uuid_clean == 32 then -- Проверяем, что UUID корректно очищен и имеет нужную длину (32 hex символа)
                -- Сохраняем и username, и clean-uuid для удобства
                table.insert(users, { user=username, uuid=uuid_clean })
            else
                -- Опционально: можно добавить логирование ошибки для некорректных UUID
                -- core.Warning("Invalid UUID for user " .. username .. ": " .. (uuid_dash or "nil"))
            end
        end
    end
    return users
end

-- Основная функция для загрузки из файла
function M.load_users_file(path)
    local f = io.open(path, "r")
    if not f then
        -- Используем core.Warning, если доступен (в HAProxy/Lua)
        if core and core.Warning then
            core.Warning("cannot open users file: " .. path)
        end
        return {}
    end
    local content = f:read("*a")
    f:close()
    return parse_csv_lines(content)
end

return M
