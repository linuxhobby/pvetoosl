#!/bin/bash
# ==============================================================
#  Debian 13 一键初始化脚本
#  功能：时区、locale、常用工具、IPv4/IPv6转发、BBR
#
#
#1、修改时区，Shanghai。
#2、设置显示英文提示，支持中文。
#3、安装curl、vim、net-tools
#4、设置ipv4、ipv6转发，启用BBR。
# ==============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# 检查 root 权限
[[ $EUID -ne 0 ]] && error "请使用 root 权限运行此脚本：sudo bash $0"

echo ""
echo "======================================================"
echo "   Debian 13 初始化脚本"
echo "======================================================"
echo ""

# -------------------------------------------------------
# 1. 修改时区为 Asia/Shanghai
# -------------------------------------------------------
info "设置时区为 Asia/Shanghai ..."
timedatectl set-timezone Asia/Shanghai
success "时区已设置为：$(timedatectl | grep 'Time zone' | awk '{print $3}')"

# -------------------------------------------------------
# 2. Locale：显示英文提示，支持中文
# -------------------------------------------------------
info "配置 Locale（英文界面 + 中文支持）..."

apt-get update -qq

apt-get install -y -qq locales

# 启用 en_US.UTF-8 和 zh_CN.UTF-8
sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen

# 若行不存在则追加
grep -q "^en_US.UTF-8" /etc/locale.gen || echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
grep -q "^zh_CN.UTF-8" /etc/locale.gen || echo "zh_CN.UTF-8 UTF-8" >> /etc/locale.gen

locale-gen > /dev/null 2>&1

# 系统语言设为英文，同时保留中文字符支持
update-locale LANG=en_US.UTF-8 LC_CTYPE=zh_CN.UTF-8

# 写入 /etc/default/locale
cat > /etc/default/locale <<EOF
LANG=en_US.UTF-8
LC_CTYPE=zh_CN.UTF-8
EOF

success "Locale 配置完成（系统提示英文，支持中文字符）"

# -------------------------------------------------------
# 3. 安装 curl、vim、net-tools
# -------------------------------------------------------
info "安装常用工具：curl vim net-tools ..."
apt-get install -y -qq curl vim net-tools wget
success "curl、vim、net-tools wget安装完成"

# -------------------------------------------------------
# 4. 开启 IPv4/IPv6 转发 + BBR
# -------------------------------------------------------
info "配置 IPv4/IPv6 转发 + BBR ..."

SYSCTL_CONF="/etc/sysctl.d/99-debian-init.conf"

cat > "$SYSCTL_CONF" <<EOF
# ---- IPv4/IPv6 转发 ----
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# ---- BBR 拥塞控制 ----
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

sysctl --system > /dev/null 2>&1

# 验证 BBR 是否生效
BBR_STATUS=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
IPV4_FWD=$(sysctl net.ipv4.ip_forward 2>/dev/null | awk '{print $3}')
IPV6_FWD=$(sysctl net.ipv6.conf.all.forwarding 2>/dev/null | awk '{print $3}')

[[ "$IPV4_FWD" == "1" ]] && success "IPv4 转发已启用" || warn "IPv4 转发启用失败，请手动检查"
[[ "$IPV6_FWD" == "1" ]] && success "IPv6 转发已启用" || warn "IPv6 转发启用失败，请手动检查"
[[ "$BBR_STATUS" == "bbr" ]] && success "BBR 拥塞控制已启用" || warn "BBR 启用失败（内核版本需 >= 4.9），当前：$BBR_STATUS"

# -------------------------------------------------------
# 汇总
# -------------------------------------------------------
echo ""
echo "======================================================"
echo -e "${GREEN}  初始化完成！汇总如下：${NC}"
echo "======================================================"
echo -e "  时区        : $(timedatectl | grep 'Time zone' | awk '{print $3}')"
echo -e "  系统语言    : $(grep ^LANG /etc/default/locale | cut -d= -f2)"
echo -e "  中文支持    : $(grep ^LC_CTYPE /etc/default/locale | cut -d= -f2)"
echo -e "  IPv4 转发   : $IPV4_FWD"
echo -e "  IPv6 转发   : $IPV6_FWD"
echo -e "  TCP 拥塞控制: $BBR_STATUS"
echo -e "  安装工具    : curl vim net-tools wget"
echo "======================================================"
echo ""
warn "建议重新登录终端（或执行 source /etc/default/locale）使 locale 完全生效"
echo ""