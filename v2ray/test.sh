#!/bin/bash

# ====================================================
# 将军阁下的专属 V2Ray 综合管理脚本 (兼容性增强版)
# ====================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONFIG_FILE="/usr/local/etc/v2ray/config.json"
CADDY_FILE="/etc/caddy/Caddyfile"

# 权限检查
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 必须使用 root 权限运行!${NC}" && exit 1

# 生成分享链接并显示
generate_output() {
    local uuid=$1
    local domain=$2
    local path=$3
    local proto=$4
    local safe_path=$(echo -n "$path" | sed 's/\//%2F/g')
    if [[ "$proto" == "vless" ]]; then
        URL="vless://$uuid@$domain:443?encryption=none&security=tls&type=ws&host=$domain&path=$safe_path#vpn-ws-$domain"
    else
        VMESS_JSON=$(cat <<EOF
{ "v": "2", "ps": "vpn-ws-$domain", "add": "$domain", "port": "443", "id": "$uuid", "aid": "0", "net": "ws", "type": "none", "host": "$domain", "path": "$path", "tls": "tls" }
EOF
        )
        URL="vmess://$(echo -n "$VMESS_JSON" | base64 -w 0)#$domain"
    fi
    echo -e "-------------------------------------------------------"
    echo -e "协议 (protocol) \t= ${BLUE}${proto}${NC}"
    echo -e "地址 (address) \t\t= ${BLUE}${domain}${NC}"
    echo -e "端口 (port) \t\t= ${BLUE}443${NC}"
    echo -e "用户ID (id) \t\t= ${BLUE}${uuid}${NC}"
    echo -e "传输协议 (network) \t= ${BLUE}ws${NC}"
    echo -e "伪装域名 (host) \t= ${BLUE}${domain}${NC}"
    echo -e "路径 (path) \t\t= ${BLUE}${path}${NC}"
    echo -e "传输层安全 (TLS) \t= ${BLUE}tls${NC}"
    echo -e "------------- 链接 (URL) -------------"
    echo -e "${RED}${URL}${NC}"
    echo -e "-------------------------------------------------------"
}

# 域名解析检测
check_dns() {
    local domain=$1
    echo -e "${YELLOW}正在检测域名解析状态...${NC}"
    local local_ipv4=$(curl -s4m 5 https://api64.ipify.org || echo "未检测到")
    apt update && apt install -y dnsutils > /dev/null 2>&1
    local resolved_ipv4=$(dig +short A "$domain" | tail -n1)
    echo -e "本机公网 IPv4: ${BLUE}$local_ipv4${NC}"
    echo -e "域名解析 IPv4: ${BLUE}${resolved_ipv4:-未检测到}${NC}"
    if [[ "$resolved_ipv4" != "$local_ipv4" ]]; then
        echo -e "${YELLOW}警告：解析与本机不匹配！${NC}"
        read -p "是否强制继续？(y/n): " force_continue
        [[ "${force_continue,,}" != "y" ]] && return 1
    fi
    return 0
}

# 安装功能
install_v2ray() {
    while true; do
        echo -e "${YELLOW}请选择协议：${NC}"
        echo -e "1) VLESS + WS + TLS (推荐)"
        echo -e "2) VMess + WS + TLS"
        read -p "选择 [1-2, 默认1]: " p_choice
        case $p_choice in
            2) PROTO="vmess" ; break ;;
            *) PROTO="vless" ; break ;;
        esac
    done
    
    read -p "请输入解析域名: " DOMAIN
    [[ -z "$DOMAIN" ]] && return
    check_dns "$DOMAIN" || return

    echo -e "${GREEN}正在安装核心与基础组件...${NC}"
    apt update && apt install -y curl wget jq uuid-runtime caddy vnstat

    # 修复：先强制创建目录，防止写入配置失败
    mkdir -p /usr/local/etc/v2ray
    mkdir -p /usr/local/bin

    # 修复：更换安装源，使用 frainzy1477 的脚本或官方备用链接
    bash <(curl -L https://raw.githubusercontent.com/v2fly/fscript/master/install-release.sh) || \
    bash <(curl -L https://multi.netlify.app/go.sh) # 备用备选安装方式

    UUID=$(uuidgen)
    WSPATH="/$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 10)"

    cat <<EOF > $CONFIG_FILE
{
  "inbounds": [{
    "port": 10000, "listen":"127.0.0.1", "protocol": "$PROTO",
    "settings": { "clients": [{"id": "$UUID" $( [[ "$PROTO" == "vless" ]] && echo ',"decryption": "none"' ) }] },
    "streamSettings": { "network": "ws", "wsSettings": {"path": "$WSPATH"} }
  }],
  "outbounds": [{"protocol": "freedom"}]
}
EOF

    cat <<EOF > $CADDY_FILE
$DOMAIN {
    bind 0.0.0.0
    reverse_proxy $WSPATH localhost:10000
    file_server { root /var/www/html }
}
EOF
    
    cat <<EOF > /etc/systemd/system/v2ray.service
[Unit]
Description=V2Ray Service
After=network.target
[Service]
User=root
ExecStart=/usr/local/bin/v2ray run -c $CONFIG_FILE
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload && systemctl enable v2ray caddy && systemctl restart v2ray caddy
    generate_output "$UUID" "$DOMAIN" "$WSPATH" "$PROTO"
}

# --- 主菜单 ---
while true; do
    echo -e "${YELLOW}=================================${NC}"
    echo -e "${GREEN}   将军阁下的 V2Ray 管理面板 (随机号: 111897) ${NC}"
    echo -e "${YELLOW}=================================${NC}"
    echo -e "1) 安装 V2Ray"
    echo -e "q) 退出"
    read -p "请选择: " opt
    case $opt in
        1) install_v2ray ;;
        q) exit 0 ;;
        *) echo -e "无效选项" ;;
    esac
done