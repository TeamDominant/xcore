{
  "remarks": "HAPROXY",
  "log": {
    "loglevel": "warning"
  },
  "dns": {
    "servers": [
      {
        "address": "https+local://1.1.1.1/dns-query",
        "domain": [
          "geosite:category-ru",
          "geosite:yandex",
          "geosite:vk",
          "geosite:mailru",
          "geosite:zoom",
          "geosite:reddit",
          "geosite:twitch",
          "geosite:tumblr",
          "geosite:4chan",
          "geosite:pinterest",
          "geosite:deviantart",
          "geosite:duckduckgo",
          "geosite:yahoo",
          "geosite:mozilla",
          "geosite:category-android-app-download",
          "geosite:aptoide",
          "geosite:samsung",
          "geosite:huawei",
          "geosite:apple",
          "geosite:microsoft",
          "geosite:nvidia",
          "geosite:xiaomi",
          "geosite:hp",
          "geosite:asus",
          "geosite:lenovo",
          "geosite:lg",
          "geosite:oracle",
          "geosite:adobe",
          "geosite:blender",
          "geosite:drweb",
          "geosite:gitlab",
          "geosite:debian",
          "geosite:canonical",
          "geosite:python",
          "geosite:doi",
          "geosite:elsevier",
          "geosite:sciencedirect",
          "geosite:clarivate",
          "geosite:sci-hub",
          "geosite:duolingo",
          "geosite:aljazeera",
          "keyword:xn--",
          "keyword:researchgate",
          "keyword:springer",
          "keyword:nextcloud",
          "keyword:skype",
          "keyword:wiki",
          "keyword:kaspersky",
          "keyword:stepik",
          "keyword:likee",
          "keyword:snapchat",
          "keyword:yappy",
          "keyword:pikabu",
          "keyword:okko",
          "keyword:wink",
          "keyword:kion",
          "keyword:viber",
          "keyword:roblox",
          "keyword:ozon",
          "keyword:wildberries",
          "keyword:aliexpress",
          "wikipedia.org",
          "ru.com",
          "ru.net",
          "keyword:browserleaks",
          "dnsleaktest.com"
        ],
        "skipFallback": false,
        "queryStrategy": "ForceIPv4"
      }
    ]
  },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "domainMatcher": "hybrid",
    "network": "tcp,udp",
    "rules": [
      {
        "domain": [
          "geosite:category-ads-all",
          "keyword:yandex",
          "keyword:dzen",
          "keyword:yastatic",
          "keyword:reklama"
        ],
        "outboundTag": "block"
      },
      {
        "protocol": [
          "bittorrent",
          "quic"
        ],
        "outboundTag": "direct"
      },
      {
        "ip": [
          "geoip:ru",
          "geoip:private"
        ],
        "outboundTag": "direct"
      },
      {
        "domain": [
          "geosite:category-ru",
          "geosite:yandex",
          "geosite:vk",
          "geosite:mailru",
          "geosite:zoom",
          "geosite:reddit",
          "geosite:twitch",
          "geosite:tumblr",
          "geosite:4chan",
          "geosite:pinterest",
          "geosite:deviantart",
          "geosite:duckduckgo",
          "geosite:yahoo",
          "geosite:mozilla",
          "geosite:category-android-app-download",
          "geosite:aptoide",
          "geosite:samsung",
          "geosite:huawei",
          "geosite:apple",
          "geosite:microsoft",
          "geosite:nvidia",
          "geosite:xiaomi",
          "geosite:hp",
          "geosite:asus",
          "geosite:lenovo",
          "geosite:lg",
          "geosite:oracle",
          "geosite:adobe",
          "geosite:blender",
          "geosite:drweb",
          "geosite:gitlab",
          "geosite:debian",
          "geosite:canonical",
          "geosite:python",
          "geosite:doi",
          "geosite:elsevier",
          "geosite:sciencedirect",
          "geosite:clarivate",
          "geosite:sci-hub",
          "geosite:duolingo",
          "geosite:aljazeera",
          "keyword:xn--",
          "keyword:researchgate",
          "keyword:springer",
          "keyword:nextcloud",
          "keyword:skype",
          "keyword:wiki",
          "keyword:kaspersky",
          "keyword:stepik",
          "keyword:likee",
          "keyword:snapchat",
          "keyword:yappy",
          "keyword:pikabu",
          "keyword:okko",
          "keyword:wink",
          "keyword:kion",
          "keyword:viber",
          "keyword:roblox",
          "keyword:ozon",
          "keyword:wildberries",
          "keyword:aliexpress",
          "wikipedia.org",
          "ru.com",
          "ru.net",
          "keyword:browserleaks",
          "dnsleaktest.com"
        ],
        "outboundTag": "direct"
      }
    ]
  },
  "inbounds": [
    {
      "tag": "socks",
      "port": 10808,
      "protocol": "socks",
      "settings": {
        "udp": true,
        "auth": "noauth",
        "userLevel": 8
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic",
          "fakedns"
        ]
      },
      "routeOnly": false,
      "metadataOnly": false
    },
    {
      "tag": "http",
      "port": 10809,
      "protocol": "http",
      "settings": {
        "userLevel": 8
      }
    }
  ],
  "outbounds": [
    {
      "tag": "vless_raw",
      "protocol": "vless",
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tcpSettings": {
          "header": {
            "type": "none"
          }
        },
        "tslSettings": {
          "utls": {
            "alpn": [
              "h2",
              "http/1.1"
            ],
            "fingerprint": "chrome"
          }
        }
      },
      "mux": {
        "enabled": true,
        "concurrency": 8,
        "xudpConcurrency": 16,
        "xudpProxyUDP443": "reject"
      },
      "settings": {
        "vnext": [
          {
            "address": "swe.theleetworld.ru",
            "port": 443,
            "users": [
              {
                "encryption": "none",
                "id": "uuid_templates",
                "level": 8
              }
            ]
          }
        ]
      }
    },
    {
      "tag": "direct",
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "ForceIPv4"
      },
      "sockopt": {
        "tcpMaxSeg": 1460,
        "tcpFastOpen": true
      }
    },
    {
      "tag": "block",
      "protocol": "blackhole",
      "settings": {
        "response": {
          "type": "none"
        }
      }
    }
  ],
  "stats": {}
}