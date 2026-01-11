#!/bin/bash
echo -e "\033[32m---> [3/4] 安装 Sing-box 并写入 Gemini 分流配置 \033[0m"

# 1. 安装官方 Sing-box
bash <(curl -fsSL https://sing-box.app/sbo-install.sh)

# 2. 生成配置文件 (核心！)
# 注意：这里配置了 mixed-in (端口5555) 方便您测试。
# 您以后可以在这里把 mixed 改成 vless reality。

cat > /etc/sing-box/config.json <<EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "::",
      "listen_port": 5555
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "socks",
      "tag": "warp-socks",
      "server": "127.0.0.1",
      "server_port": 40000
    }
  ],
  "route": {
    "rules": [
      {
        "geosite": ["gemini", "google", "openai"], 
        "outbound": "warp-socks"
      }
    ],
    "final": "direct",
    "auto_detect_interface": true
  }
}
EOF

# 3. 重启生效
systemctl restart sing-box
echo "Sing-box 已安装并配置。Gemini -> WARP，其他 -> 直连。"
