#!/bin/bash

# ====================================================
# 将军阁下，这是彻底解决语法转义冲突的 V3.3 脚本
# 针对：Debian 12 纯净版环境、URL 编码、DNS 报错优化
# ====================================================

CONFIG_FILE="/etc/v2ray/config.json"

# 1. 环境准备函数
prepare_env() {
    echo "正在安装基础依赖..."
    apt update && apt install -y curl jq gawk grep base64 python3-minimal
    if ! command -v v2ray &> /dev/null; then
        echo "核心缺失，正在执行安装程序..."
        bash <(curl -s -L https://git.io/v2ray.sh)
    fi
}

# 2. 写入 JSON 配置函数
apply_config() {
    local PROTO=$1
    local UUID=$2
    local PATH_STR=$3

    cat > $CONFIG_FILE <<EOF
{
  "log": { "loglevel": "warning" },
  "dns": { "servers": ["localhost"], "queryStrategy": "UseIPv4" },
  "policy": { "levels": { "0": { "handshake": 5, "connIdle": 300 } } },
  "inbounds": [{
    "port": 12345,
    "listen": "127.0.0.1",
    "protocol": "$PROTO",
    "settings": { "clients": [ { "id": "$UUID", "level": 0 } ], "decryption": "none" },
    "streamSettings": { "network": "ws", "wsSettings": { "path": "$PATH_STR" } }
  }],
  "outbounds": [{ "protocol": "freedom", "settings": { "domainStrategy": "UseIPv4" } }]
}
EOF
    systemctl restart v2ray
}

# 3. 链接生成与报告输出
output_links() {
    if [ ! -f "$CONFIG_FILE" ]; then 
        echo "尚未检测到配置，请先选择协议安装。"
        return
    fi
    
    local PROTO=$(jq -r '.inbounds[0].protocol' $CONFIG_FILE)
    local ID=$(jq -r '.inbounds[0].settings.clients[0].id' $CONFIG_FILE)
    local PR=$(jq -r '.inbounds[0].streamSettings.wsSettings.path' $CONFIG_FILE)
    local ADDR=$(hostname -f)
    # 使用 Python3 进行 URL 安全编码
    local P_ENC=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$PR', safe=''))")
    
    echo "-----------------------------------------------"
    if [ "$PROTO" == "vless" ]; then
        echo "VLESS 分享链接:"
        echo "vless://${ID}@${ADDR}:443?encryption=none&security=tls&type=ws&host=${ADDR}&path=${P_ENC}#Racknerd_V3"
    else
        local VM_JSON=$(cat <<EOF
{ "v": "2", "ps": "Racknerd_V3", "add": "${ADDR}", "port": "443", "id": "${ID}", "aid": "0", "net": "ws", "type": "none", "host": "${ADDR}", "path": "${PR}", "tls": "tls" }
EOF
)
        echo "VMess 分享链接:"
        echo "vmess://$(echo -n "$VM_JSON" | base64 -w 0)"
    fi
    echo "-----------------------------------------------"
}

# 4. 指挥菜单主逻辑
while true; do
    clear
    echo "==============================================="
    echo "      V2Ray 战略指挥面板 V3.3 (Debian 12)     "
    echo "==============================================="
    echo " 1) 部署 VLESS-WS-TLS (推荐)"
    echo " 2) 部署 VMess-WS-TLS"
    echo " 3) 查看报告与链接"
    echo " 4) 彻底退出脚本"
    echo "-----------------------------------------------"
    read -p "请将军下令 [1-4]: " choice

    case $choice in
        1)
            prepare_env
            UUID=$(cat /proc/sys/kernel/random/uuid)
            WPATH="/ray$(cat /proc/sys/kernel/random/uuid | cut -c1-4)"
            apply_config "vless" "$UUID" "$WPATH"
            output_links
            read -p "按回车返回..."
            ;;
        2)
            prepare_env
            UUID=$(cat /proc/sys/kernel/random/uuid)
            WPATH="/ray$(cat /proc/sys/kernel/random/uuid | cut -c1-4)"
            apply_config "vmess" "$UUID" "$WPATH"
            output_links
            read -p "按回车返回..."
            ;;
        3)
            output_links
            read -p "按回车返回..."
            ;;
        4)
            echo "正在退出指挥面板..."
            exit 0
            ;;
        *)
            echo "未知指令，请重新输入"
            sleep 1
            ;;
    esac
done