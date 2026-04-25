#!/bin/bash

# ====================================================
# 将军阁下的专属 V2Ray 独立安装脚本 (多协议支持)
# ====================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 必须使用 root 权限运行!${NC}" && exit 1

# 1. 协议选择菜单
clear
echo -e "${YELLOW}请选择要部署的协议：${NC}"
echo -e "1) VLESS + WS + TLS (推荐，更轻量)"
echo -e "2) VMess + WS + TLS"
read -p "请输入数字 [1-2]: " PROTO_CHOICE

case $PROTO_CHOICE in
    2) PROTOCOL="vmess" ;;
    *) PROTOCOL="vless" ;;
esac

read -p "请输入您的解析域名 (例如: cc.myvpsworld.top): " DOMAIN
[[ -z "$DOMAIN" ]] && exit 1

echo -e "${GREEN}正在准备环境...${NC}"
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
apt update && apt install -y curl wget jq uuid-runtime debian-keyring debian-archive-keyring apt-transport-https vnstat

# 2. 安装官方核心与 Caddy
echo -e "${GREEN}正在下载官方核心...${NC}"
bash <(curl -L https://raw.githubusercontent.com/v2fly/fscript/master/install-release.sh)

echo -e "${GREEN}正在安装 Caddy 2...${NC}"
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update && apt install caddy -y

# 3. 生成配置参数
UUID=$(uuidgen)
WSPATH="/$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 10)"

# 4. 写入 V2Ray 配置文件
mkdir -p /usr/local/etc/v2ray
cat <<EOF > /usr/local/etc/v2ray/config.json
{
  "inbounds": [{
    "port": 10000,
    "listen":"127.0.0.1",
    "protocol": "$PROTOCOL",
    "settings": {
      "clients": [{"id": "$UUID" $( [[ "$PROTOCOL" == "vless" ]] && echo ',"decryption": "none"' ) }]
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {"path": "$WSPATH"}
    }
  }],
  "outbounds": [{"protocol": "freedom"}]
}
EOF

# 5. 写入 Caddyfile
cat <<EOF > /etc/caddy/Caddyfile
$DOMAIN {
    reverse_proxy $WSPATH localhost:10000
    file_server {
        root /var/www/html
    }
}
EOF

# 6. 服务自愈与启动
cat <<EOF > /etc/systemd/system/v2ray.service
[Unit]
Description=V2Ray Service
After=network.target nss-lookup.target
[Service]
User=root
ExecStart=/usr/local/bin/v2ray run -c /usr/local/etc/v2ray/config.json
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable v2ray caddy
systemctl restart v2ray caddy

# 7. 生成链接逻辑
SAFE_PATH=$(echo -n "$WSPATH" | sed 's/\//%2F/g')

if [[ "$PROTOCOL" == "vless" ]]; then
    SHARE_LINK="vless://$UUID@$DOMAIN:443?encryption=none&security=tls&type=ws&host=$DOMAIN&path=$SAFE_PATH#$DOMAIN-VLESS"
else
    # VMess 需要 Base64 编码
    VMESS_JSON=$(cat <<EOF
{
  "v": "2", "ps": "$DOMAIN-VMESS", "add": "$DOMAIN", "port": "443", "id": "$UUID",
  "aid": "0", "net": "ws", "type": "none", "host": "$DOMAIN", "path": "$WSPATH", "tls": "tls"
}
EOF
    )
    SHARE_LINK="vmess://$(echo -n "$VMESS_JSON" | base64 -w 0)"
fi

# 8. 结果展示
clear
echo -e "-------------------------------------------------------"
echo -e "${GREEN}部署完成！将军阁下，信息如下：${NC}"
echo -e "-------------------------------------------------------"
echo -e "协议类型: ${PROTOCOL}"
echo -e "解析域名: ${DOMAIN}"
echo -e "UUID: ${UUID}"
echo -e "路径: ${WSPATH}"
echo -e "-------------------------------------------------------"
echo -e "${GREEN}您的订阅链接：${NC}"
echo -e "${RED}${SHARE_LINK}${NC}"
echo -e "-------------------------------------------------------"