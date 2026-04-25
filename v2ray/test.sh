#!/bin/bash

# ====================================================
# 将军阁下的专属 V2Ray 安装脚本
# 环境要求：Debian / Ubuntu
# 功能：VLESS + WebSocket + TLS (Caddy 2 自动化)
# ====================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# 检查 root 权限
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 必须使用 root 权限运行!${NC}" && exit 1

read -p "请输入您的解析域名 (例如: v2.example.com): " DOMAIN
[[ -z "$DOMAIN" ]] && echo -e "${RED}域名不能为空!${NC}" && exit 1

echo -e "${GREEN}开始安装依赖...${NC}"
apt update && apt install -y curl wget jq uuid-runtime debian-keyring debian-archive-keyring apt-transport-https

# 1. 设置时区
echo -e "${GREEN}同步系统时区...${NC}"
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 2. 安装 V2Ray 官方核心
echo -e "${GREEN}从官方安装 V2Ray 核心...${NC}"
bash <(curl -L https://raw.githubusercontent.com/v2fly/fscript/master/install-release.sh)

# 3. 安装 Caddy 2 (负责 TLS 和 反向代理)
echo -e "${GREEN}安装 Caddy 2...${NC}"
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update && apt install caddy -y

# 4. 生成配置参数
UUID=$(uuidgen)
WSPATH="/$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 10)"

# 5. 写入 V2Ray 配置文件
cat <<EOF > /usr/local/etc/v2ray/config.json
{
  "inbounds": [{
    "port": 10000,
    "listen":"127.0.0.1",
    "protocol": "vless",
    "settings": {
      "clients": [{"id": "$UUID"}],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {"path": "$WSPATH"}
    }
  }],
  "outbounds": [{"protocol": "freedom"}]
}
EOF

# 6. 写入 Caddyfile (自动化证书与反向代理)
cat <<EOF > /etc/caddy/Caddyfile
$DOMAIN {
    reverse_proxy $WSPATH localhost:10000
    file_server {
        root /var/www/html
    }
}
EOF

# 7. 重启服务
echo -e "${GREEN}启动服务...${NC}"
systemctl restart v2ray
systemctl enable v2ray
systemctl restart caddy
systemctl enable caddy

# 8. 安装流量统计 (响应您的习惯)
apt-get install -y vnstat

# 输出结果
echo -e "-------------------------------------------------------"
echo -e "${GREEN}安装完成！将军阁下，以下是您的连接信息：${NC}"
echo -e "域名: ${DOMAIN}"
echo -e "协议: VLESS"
echo -e "端口: 443 (TLS)"
echo -e "UUID: ${UUID}"
echo -e "传输方式: WebSocket (ws)"
echo -e "路径: ${WSPATH}"
echo -e "TLS: 开启"
echo -e "-------------------------------------------------------"