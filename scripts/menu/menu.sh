#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================

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
    NC='\033[0m'
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BICyan='\033[1;96m'
    BIWhite='\033[1;97m'
    
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    echo -e "\e[0;41;36m              DELETE ALL RECOVERY ACCOUNTS                  \e[0m"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    echo ""
    echo -e "${YELLOW}WARNING: This action will permanently delete ALL recovery files${NC}"
    echo -e "${YELLOW}for both SSH and VLESS accounts that can be recovered later.${NC}"
    echo ""
    
    ssh_recovery_exists=false
    vless_recovery_exists=false
    
    if [[ -d "/etc/xray/recovery/ssh" ]] && [[ -n "$(ls -A /etc/xray/recovery/ssh/ 2>/dev/null)" ]]; then
        ssh_recovery_exists=true
    fi
    
    if [[ -d "/etc/xray/recovery/vless" ]] && [[ -n "$(ls -A /etc/xray/recovery/vless/ 2>/dev/null)" ]]; then
        vless_recovery_exists=true
    fi
    
    if [[ "$ssh_recovery_exists" == false && "$vless_recovery_exists" == false ]]; then
        echo -e "${YELLOW}No recovery files found in any recovery directories.${NC}"
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
        read -n 1 -s -r -p "Press any key to return to menu..."
        return 0
    fi
    
    echo -e "${BIWhite}Recovery files that will be deleted:${NC}"
    echo -e "\033[0;34m────────────────────────────────────────────────────────────────\e[037;1m"
    
    total_ssh=0
    total_vless=0
    
    if [[ "$ssh_recovery_exists" == true ]]; then
        echo -e "${BICyan}SSH Recovery Files:${NC}"
        ssh_files=$(ls /etc/xray/recovery/ssh/ 2>/dev/null)
        for file in $ssh_files; do
            if [[ -f "/etc/xray/recovery/ssh/$file" ]]; then
                echo -e "  ${GREEN}•${NC} $file"
                ((total_ssh++))
            fi
        done
        echo ""
    fi
    
    if [[ "$vless_recovery_exists" == true ]]; then
        echo -e "${BICyan}VLESS Recovery Files:${NC}"
        vless_files=$(ls /etc/xray/recovery/vless/ 2>/dev/null)
        for file in $vless_files; do
            if [[ -f "/etc/xray/recovery/vless/$file" ]]; then
                echo -e "  ${GREEN}•${NC} $file"
                ((total_vless++))
            fi
        done
    fi
    
    echo -e "\033[0;34m────────────────────────────────────────────────────────────────\e[037;1m"
    echo -e "${BIWhite}Total files to delete:${NC}"
    echo -e "  SSH: ${RED}$total_ssh${NC} files"
    echo -e "  VLESS: ${RED}$total_vless${NC} files"
    echo -e "  ${BIWhite}TOTAL:${NC} ${RED}$((total_ssh + total_vless))${NC} files"
    echo ""
    
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    echo -e "${YELLOW}IMPORTANT:${NC}"
    echo -e "${YELLOW}Once deleted, these recovery files cannot be restored!${NC}"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    echo ""
    
    read -rp $'\e[1;31mAre you absolutely sure you want to delete ALL recovery files? (yes/NO): \e[0m' confirm
    
    case "$confirm" in
        yes|YES|Yes|y|Y)
            echo ""
            echo -e "${YELLOW}Deleting recovery files...${NC}"
            echo ""
            
            deleted_count=0
            
            if [[ "$ssh_recovery_exists" == true ]]; then
                echo -e "${BICyan}Deleting SSH recovery files...${NC}"
                ssh_files=$(ls /etc/xray/recovery/ssh/ 2>/dev/null)
                for file in $ssh_files; do
                    if [[ -f "/etc/xray/recovery/ssh/$file" ]]; then
                        rm -f "/etc/xray/recovery/ssh/$file"
                        echo -e "  ${GREEN}✓${NC} Deleted: $file"
                        ((deleted_count++))
                    fi
                done
                echo ""
            fi
            
            if [[ "$vless_recovery_exists" == true ]]; then
                echo -e "${BICyan}Deleting VLESS recovery files...${NC}"
                vless_files=$(ls /etc/xray/recovery/vless/ 2>/dev/null)
                for file in $vless_files; do
                    if [[ -f "/etc/xray/recovery/vless/$file" ]]; then
                        rm -f "/etc/xray/recovery/vless/$file"
                        echo -e "  ${GREEN}✓${NC} Deleted: $file"
                        ((deleted_count++))
                    fi
                done
                echo ""
            fi
            
            echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
            echo -e "${GREEN}SUCCESS:${NC} ${BIWhite}Deleted ${RED}$deleted_count${NC} ${BIWhite}recovery files${NC}"
            echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
            ;;
        *)
            echo ""
            echo -e "${YELLOW}Operation cancelled. No files were deleted.${NC}"
            echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
            ;;
    esac
    
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
}

# --- Function: DNS Changer ---
mdns() {
    P='\e[0;35m'
    B='\033[0;36m'
    G='\033[0;32m'
    NC='\e[0m'
    N='\e[0m'
    clear
    echo -e "\e[36m╒════════════════════════════════════════════╕\033[0m"
    echo -e " \E[0;41;36m                 DNS CHANGER                \E[0m"
    echo -e "\e[36m╘════════════════════════════════════════════╛\033[0m
\033[1;37mDNS Changer By risqinf\033[0m
\033[1;37mTelegram : https://t.me/risqinf      \033[0m"
    dnsfile="/root/.dns"
    if test -f "$dnsfile"; then
        udns=$(cat /root/.dns)
        echo -e ""
        echo -e "   Active DNS : \033[1;37m$udns\033[0m"
    fi
    echo -e "
 [\033[1;36m•1 \033[0m]  Temporary DNS
 [\033[1;36m•2 \033[0m]  Permanent DNS
 [\033[1;36m•3 \033[0m]  Reset DNS To Default
 [\033[1;36m•4 \033[0m]  Back To Main Menu"
    echo ""
    echo -e "\033[1;37mPress [ Ctrl+C ] • To-Exit-Script\033[0m"
    echo ""
    read -p "Select From Options [ 1 - 4 ] :  " dns
    echo -e ""
    case $dns in
    1)
        clear
        echo -e "\033[1;37mTemporary DNS - Back To Default DNS After Rebooting VPS\033[0m"
        echo ""
        read -p "Please Insert DNS : " dns1
        if [ -z "$dns1" ]; then
            echo ""
            echo "Please Insert DNS !"
            sleep 1
            clear
            mdns
        fi
        rm -f /etc/resolv.conf
        echo "nameserver $dns1" > /etc/resolv.conf
        echo "$dns1" > /root/.dns
        echo ""
        echo -e "\e[032;1mDNS $dns1 sucessfully insert in VPS\e[0m"
        echo ""
        cat /etc/resolv.conf
        sleep 1
        clear
        mdns
        ;;
    2)
        clear
        echo ""
        read -p "Please Insert DNS : " dns2
        if [ -z "$dns2" ]; then
            echo ""
            echo "Please Insert DNS !"
            sleep 1
            clear
            mdns
        fi
        rm -f /etc/resolv.conf
        echo "nameserver $dns2" > /etc/resolv.conf
        chattr +i /etc/resolv.conf 2>/dev/null
        echo "$dns2" > /root/.dns
        echo ""
        echo -e "\e[032;1mDNS $dns2 sucessfully insert in VPS\e[0m"
        echo ""
        cat /etc/resolv.conf
        sleep 1
        clear
        mdns
        ;;
    3)
        clear
        echo ""
        read -p "Reset To Default DNS [Y/N]: " -e answer
        if [ "$answer" = 'y' ] || [ "$answer" = 'Y' ]; then
            chattr -i /etc/resolv.conf 2>/dev/null
            rm -f /root/.dns
            echo "nameserver 8.8.8.8" > /etc/resolv.conf
            echo -e "[ ${G}INFO${NC} ] Reset to default DNS (8.8.8.8)"
        else
            echo -e "[ ${G}INFO${NC} ] Operation Cancelled By User"
        fi
        sleep 1
        clear
        mdns
        ;;
    4)
        clear
        menu
        ;;
    *)
        echo "Please enter an correct number"
        clear
        mdns
        ;;
    esac
}

# --- Function: Install Ads Block ---
ins_hel() {
    red='\e[1;31m'
    green='\e[0;32m'
    purple='\e[0;35m'
    orange='\e[0;33m'
    NC='\e[0m'
    clear
    if [[ -e /usr/local/sbin/helium ]]; then
         echo ""
         echo -e "${green}Ads Block Already Install${NC}"
         echo ""
         read -n1 -r -p "Press any key to continue..."
         menu
    else
        rm -rf /usr/local/sbin/helium
        wget -q -O /usr/local/sbin/helium https://raw.githubusercontent.com/risqinf/autoscript/main/scripts/system/helium.sh
        chmod +x /usr/local/sbin/helium
        helium
    fi
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

# --- TOTAL ACCOUNT COUNT (Diperbaiki) ---
ssh1=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | wc -l)
vls=$(grep -c '#÷' /etc/xray/config.json | sort | uniq)
vms=$(grep -c '###' /etc/xray/config.json | sort | uniq)
tro=$(grep -c '#@' /etc/xray/config.json | sort | uniq) 

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
echo -e " 1)  SSH Panel         7)  Xray Core          13) API Menu"
echo -e " 2)  VLESS Panel       8)  Clean Data         14) Auto Bulk"
echo -e " 3)  TROJAN Panel      9)  Stream Check       15) User Checker"
echo -e " 4)  VMESS Panel      10)  Speedtest          16) Change Domain"
echo -e " 5)  SSL & Cert       11)  Change DNS         17) Timezone"
echo -e " 6)  Backup/Restore   12)  Ads Block          18) Uninstall"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf "${LIGHT}XRAY Version : [ ${GREEN}%s ${LIGHT}]\n" "$xray_version"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# --- MENU SELECTION ---
read -p " Select Option [1-18]: " mm
case $mm in
1) clear ; run_cc ; menu-ssh ;;
2) clear ; run_cc ; menu-vless ;;
3) clear ; run_cc ; menu-trojan ;;
4) clear ; run_cc ; menu-vmess ;;
5) clear ; run_cc ; menu-host ;;
6) clear ; run_cc ; menu-backup ;;
7) clear ; run_cc ; versi-xray ;;
8) clear ; run_cc ; delall ;;
9) clear ; run_cc ; stream-check ;;
10) clear ; run_cc ; echo -e "YES" | speedtest ;;
11) clear ; run_cc ; mdns ;;
12) clear ; run_cc ; ins_hel ;;
13) clear ; run_cc ; menu-api ;;
14) clear ; run_cc ; add-bulk ;;
15) clear ; run_cc ; cek-user ;;
16) clear ; run_cc ; change-domain ;;
17) clear ; run_cc ; change-timezone ;;
18) clear ; run_cc ; uninstall ;;
00) clear ; run_cc ; nano /etc/issue.net ;;
*) echo "Invalid option, please try again." ; sleep 1 ; menu ;;
esac