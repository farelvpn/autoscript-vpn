#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================

# --- Database library (SQLite) ---
[[ -f /usr/local/sbin/lib/db.sh ]] && . /usr/local/sbin/lib/db.sh && db_init 2>/dev/null

# --- Color Definitions ---
NC='\033[0m' # No Color
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BICyan='\033[1;96m'
BIWhite='\033[1;97m'

# --- Function: Delete All Recovery data ---
delall() {
    clear
    line
    echo -e "${WHITE}  PURGE ALL RECOVERY (deleted/expired) ACCOUNTS${NC}"
    line
    echo ""
    echo -e "${YELLOW}WARNING: This permanently removes all soft-deleted/expired${NC}"
    echo -e "${YELLOW}account records from the database. They cannot be recovered.${NC}"
    echo ""

    local total
    total=$(db_query "SELECT COUNT(*) FROM accounts WHERE status IN ('deleted','expired');" 2>/dev/null)
    total=${total:-0}

    if [[ "$total" -eq 0 ]]; then
        warn "No recoverable (deleted/expired) accounts found."
        line
        read -n 1 -s -r -p "Press any key to return to menu..."
        menu
        return 0
    fi

    echo -e "Recoverable records to purge: ${RED}${total}${NC}"
    db_query "SELECT protocol||'  '||username||'  ('||status||')'
              FROM accounts WHERE status IN ('deleted','expired') ORDER BY protocol;" \
      | while read -r row; do echo -e "  ${GREEN}-${NC} $row"; done
    line
    read -rp $'\e[1;31mPurge ALL these records permanently? (yes/NO): \e[0m' confirm
    case "$confirm" in
        yes|YES|Yes)
            db_exec "DELETE FROM accounts WHERE status IN ('deleted','expired');"
            db_audit "purge_recovery" "" "" "count=${total}"
            ok "Purged ${total} recovery records."
            ;;
        *) warn "Cancelled. Nothing was purged." ;;
    esac
    line
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
}

# --- Function: Clear RAM Cache ---
run_cc() {
    sync
    echo 1 > /proc/sys/vm/drop_caches
    sync
    echo 2 > /proc/sys/vm/drop_caches
    sync
    echo 3 > /proc/sys/vm/drop_caches
}

# --- Bandwidth Usage (vnstat) ---
read_vnstat_usage() {
  local interface=$1
  local today=$(vnstat -i "$interface" | grep "today" | awk '{print $8" "$9}')
  local yesterday=$(vnstat -i "$interface" | grep "yesterday" | awk '{print $8" "$9}')
  local this_month=$(vnstat -i "$interface" -m | grep "$(date +"%b '%y")" | awk '{print $9" "$10}')
  echo "$today;$yesterday;$this_month"
}

convert_to_mb() {
  local value=$1
  local unit=$2
  case $unit in
    B) echo "scale=6; $value / 1048576" | bc ;;
    KiB) echo "scale=6; $value / 1024" | bc ;;
    MiB) echo "$value" ;;
    GiB) echo "scale=6; $value * 1024" | bc ;;
    TiB) echo "scale=6; $value * 1048576" | bc ;;
    *) echo "0" ;;
  esac
}

all_interfaces=$(vnstat --iflist 2>/dev/null | sed 's/Available interfaces: //')
if [ -z "$all_interfaces" ]; then
  ttoday="N/A"
  tyest="N/A"
  tmon="N/A"
else
  total_today=0
  total_yesterday=0
  total_month=0

  for iface in $all_interfaces; do
    result=$(read_vnstat_usage "$iface")
    today=$(echo "$result" | awk -F';' '{print $1}')
    yesterday=$(echo "$result" | awk -F';' '{print $2}')
    month=$(echo "$result" | awk -F';' '{print $3}')
    
    today_value=$(echo "$today" | awk '{print $1}')
    today_unit=$(echo "$today" | awk '{print $2}')
    yesterday_value=$(echo "$yesterday" | awk '{print $1}')
    yesterday_unit=$(echo "$yesterday" | awk '{print $2}')
    month_value=$(echo "$month" | awk '{print $1}')
    month_unit=$(echo "$month" | awk '{print $2}')
    
    total_today=$(echo "$total_today + $(convert_to_mb $today_value $today_unit)" | bc)
    total_yesterday=$(echo "$total_yesterday + $(convert_to_mb $yesterday_value $yesterday_unit)" | bc)
    total_month=$(echo "$total_month + $(convert_to_mb $month_value $month_unit)" | bc)
  done

  format_usage() {
    local value=$1
    if (( $(echo "$value >= 1024" | bc -l) )); then
      echo "$(printf "%.2f" $(echo "$value / 1024" | bc)) GB"
    else
      echo "$(printf "%.2f" $value) MB"
    fi
  }

  ttoday=$(format_usage "$total_today")
  tyest=$(format_usage "$total_yesterday")
  tmon=$(format_usage "$total_month")
fi

# --- TOTAL ACCOUNT COUNT (DB-driven) ---
ssh1=$(db_query "SELECT COUNT(*) FROM accounts WHERE protocol='ssh' AND status!='deleted';" 2>/dev/null); ssh1=${ssh1:-0}
vls=$(db_query "SELECT COUNT(*) FROM accounts WHERE protocol='vless' AND status!='deleted';" 2>/dev/null); vls=${vls:-0}
vms=$(db_query "SELECT COUNT(*) FROM accounts WHERE protocol='vmess' AND status!='deleted';" 2>/dev/null); vms=${vms:-0}
tro=$(db_query "SELECT COUNT(*) FROM accounts WHERE protocol='trojan' AND status!='deleted';" 2>/dev/null); tro=${tro:-0}

# --- SERVICE STATUS ---
ressh="${RED}OFF${NC}"
[[ $(systemctl is-active dropbear 2>/dev/null) == "active" ]] && ressh="${GREEN}ON${NC}"

resngx="${RED}OFF${NC}"
[[ $(systemctl is-active nginx 2>/dev/null) == "active" ]] && resngx="${GREEN}ON${NC}"

resv2r="${RED}OFF${NC}"
[[ $(systemctl is-active xray 2>/dev/null) == "active" ]] && resv2r="${GREEN}ON${NC}"

reshap="${RED}OFF${NC}"
[[ $(systemctl is-active haproxy 2>/dev/null) == "active" ]] && reshap="${GREEN}ON${NC}"

resovpn="${RED}OFF${NC}"
[[ $(systemctl is-active openvpn-server@server-tcp-1194 2>/dev/null) == "active" ]] && resovpn="${GREEN}ON${NC}"

# --- SYSTEM INFO ---
DOMAIN=$(cat /etc/xray/domain 2>/dev/null || echo "Not Set")
cname=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
cores=$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo)
freq=$(awk -F: ' /cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
tram=$(free -m | awk 'NR==2 {print $2}')
up=$(uptime -p | sed 's/up //')
OS1=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || echo "Unknown OS")
f1=$(. /etc/os-release 2>/dev/null && echo "$VERSION_ID" || echo "N/A")
frem=$(free -h | grep "Mem:" | awk '{print $3 "/" $2}')
freswp=$(free -h | grep "Swap:" | awk '{print $3 "/" $2}')
cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 "% user, " $4 "% sys, " $6 "% nice, " $8 "% idle"}')
xray_version=$(xray version 2>/dev/null | awk 'NR==1 {print $1, $2}' || echo "Not Installed")
IPVPS=$(curl -s ifconfig.me 2>/dev/null || echo "N/A")

# --- MAIN MENU ---
clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${PURPLE}                ◎ ENTERPRISE VPN MANAGER ◎                  ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf "${LIGHT}%-12s :${GREEN} %-30s${NC}\n" "OS" "$OS1"
printf "${LIGHT}%-12s :${GREEN} %-30s${NC}\n" "IP VPS" "$IPVPS"
printf "${LIGHT}%-12s :${GREEN} %-30s${NC}\n" "Uptime" "$up"
printf "${LIGHT}%-12s :${GREEN} %-30s${NC}\n" "Domain" "$DOMAIN"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf "${LIGHT}%-12s :${GREEN} %-15s ${LIGHT}%-15s :${GREEN} %-10s${NC}\n" "RAM Usage" "$frem" "Total RAM" "$tram MB"
printf "${LIGHT}%-12s :${GREEN} %-30s${NC}\n" "CPU Usage" "$cpu"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf "${LIGHT}%-12s :${BICyan} ${RED}%s${NC} | ${RED}%s${NC} | ${RED}%s${NC}\n" "Bandwidth" "$ttoday" "$tyest" "$tmon"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf "${LIGHT}%-12s : SSH(${GREEN}%s${NC}) | VLESS(${GREEN}%s${NC}) | VMESS(${GREEN}%s${NC}) | TROJAN(${GREEN}%s${NC})\n" "Accounts" "$ssh1" "$vls" "$vms" "$tro"
printf "${LIGHT}%-12s : DBear ($ressh) | OVPN ($resovpn) | Nginx ($resngx) | Xray ($resv2r)\n" "Services"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}  ACCOUNT PANELS${NC}"
echo -e " 1)  SSH / OpenVPN Panel        3)  VMESS Panel"
echo -e " 2)  VLESS Panel                4)  TROJAN Panel"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}  TOOLS${NC}"
echo -e " 5)  Auto Bulk Create           7)  User Checker"
echo -e " 6)  Account Cleaner            8)  API Menu"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}  SERVER${NC}"
echo -e " 9)  System Menu                10) Backup / Restore"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " x)  Exit"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf "${LIGHT}XRAY Version : [ ${GREEN}%s ${LIGHT}]\n" "$xray_version"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# --- MENU SELECTION ---
read -p " Select Option : " mm
case $mm in
1) clear ; run_cc ; menu-ssh ;;
2) clear ; run_cc ; menu-vless ;;
3) clear ; run_cc ; menu-vmess ;;
4) clear ; run_cc ; menu-trojan ;;
5) clear ; run_cc ; add-bulk ;;
6) clear ; run_cc ; delall ;;
7) clear ; run_cc ; cek-user ;;
8) clear ; run_cc ; menu-api ;;
9) clear ; run_cc ; menu-system ;;
10) clear ; run_cc ; menu-backup ;;
x|X) clear ; exit 0 ;;
00) clear ; run_cc ; nano /etc/issue.net ;;
*) echo "Invalid option, please try again." ; sleep 1 ; menu ;;
esac