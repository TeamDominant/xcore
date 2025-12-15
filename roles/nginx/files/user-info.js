// user-info.js — модуль для загрузки и отображения данных пользователя
const UserInfoModule = (() => {
    const API_BASE = CONFIG.domain + CONFIG.path;
    const cache = {};
    function sanitizeText(text) {
        if (!text) return '';
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
    function formatBytes(bytes) {
        if (!bytes) return "0 Б";
        const sizes = ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ'];
        const i = Math.floor(Math.log(bytes) / Math.log(1024));
        return parseFloat((bytes / Math.pow(1024, i)).toFixed(2)) + ' ' + sizes[i];
    }
    function formatExpire(timestamp) {
        if (!timestamp || timestamp == 0) return "Бессрочно";
        const date = new Date(timestamp * 1000);
        const now = new Date();
        const diffDays = Math.ceil((date - now) / (1000 * 60 * 60 * 24));
        if (diffDays < 0) return "Истекла";
        if (diffDays === 0) return "Сегодня";
        if (diffDays <= 7) return `${diffDays} дн.`;
        return date.toLocaleDateString('ru-RU');
    }
    function parseUserInfo(header) {
        if (!header) return null;
        const params = {};
        header.split(';').forEach(part => {
            const [k, v] = part.trim().split('=');
            if (k) params[k.trim()] = v ? parseInt(v) || v.trim() : 0;
        });
        return {
            upload: parseInt(params.upload) || 0,
            download: parseInt(params.download) || 0,
            total: parseInt(params.total) || 0,
            expire: parseInt(params.expire) || 0
        };
    }
    async function fetchUserInfo(username) {
        if (!username || username.length < 2) return null;
        if (cache[username]) return cache[username];
        try {
            const url = `${API_BASE}?client=xray&user=${encodeURIComponent(username)}&mode=advanced`;
            const response = await fetch(url, { method: 'HEAD' });
            if (!response.ok) throw new Error('Network error');
            const userinfo = response.headers.get('subscription-userinfo');
            const profileTitle = response.headers.get('profile-title');
            if (!userinfo) {
                showNotification("Данные о подписке не найдены", "warning");
                return null;
            }
            const data = parseUserInfo(userinfo);
            if (data) {
                data.username = username;
                let decodedTitle = username;
                if (profileTitle?.includes('base64:')) {
                    try {
                        decodedTitle = atob(profileTitle.split(':')[1] || '');
                        decodedTitle = sanitizeText(decodedTitle);
                    } catch (e) {
                        console.error('Failed to decode profile title:', e);
                        decodedTitle = username;
                    }
                }
                data.profileTitle = decodedTitle;
                cache[username] = data;
            }
            return data;
        } catch (err) {
            console.error("Ошибка получения данных:", err);
            showNotification("Не удалось загрузить статистику", "error");
            return null;
        }
    }
    function render(data) {
        if (!data) {
            return;
        }
        const used = data.upload + data.download;
        const total = data.total || 0;
        const remaining = total > 0 ? total - used : 0;
        const percent = total > 0 ? Math.round((used / total) * 100) : 0;
        const trafficUsedSpan = document.getElementById("trafficUsed");
        const trafficRemainingSpan = document.getElementById("trafficRemaining");
        const trafficRemainingContainer = document.getElementById("trafficRemainingContainer");
        if (total > 0) {
            trafficUsedSpan.textContent = `${formatBytes(used)} из ${formatBytes(total)}`;
            trafficRemainingSpan.textContent = formatBytes(remaining);
            trafficRemainingContainer.style.display = "block";
        } else {
            trafficUsedSpan.textContent = formatBytes(used);
            trafficRemainingContainer.style.display = "none";
        }
        document.getElementById("expireDate").textContent = formatExpire(data.expire);
        const progressContainer = document.getElementById("trafficProgressContainer");
        const progressFill = document.getElementById("trafficProgress");
        const percentText = document.getElementById("trafficPercent");
        if (total > 0) {
            progressContainer.style.display = "block";
            progressFill.style.width = percent + "%";
            percentText.textContent = percent + "% использовано";
        } else {
            progressContainer.style.display = "none";
        }
    }
    return {
        async update(username) {
            if (!username?.trim()) {
                return;
            }
            const data = await fetchUserInfo(username.trim());
            render(data);
        }
    };
})();