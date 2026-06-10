#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Full service status overview (all installed components)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/common.sh

# unit|label|listen-port (port shown for quick reference; "-" if none/internal)
ROWS=(
  "haproxy|HAProxy (entry 80/443)|80,443"
  "nginx|Nginx (router)|81,444*"
  "xray|Xray Core|1,2,3*"
  "dropbear|Dropbear SSH|109"
  "ssh-ws|SSH WebSocket|8888"
  "sshd|OpenSSH|22,3303"
  "openvpn-server@server-tcp-1194|OpenVPN TCP|1194"
  "openvpn-server@server-udp-2200|OpenVPN UDP|2200"
  "vnstat|vnStat (bandwidth)|-"
  "rsyslog|rsyslog (secure log)|-"
  "crond|Cron scheduler|-"
  "firewalld|Firewall|-"
  "quota|VLESS quota loop|-"
  "limit-ip-vless|VLESS ip-limit loop|-"
  "quota-vmess|VMESS quota loop|-"
  "limit-ip-vmess|VMESS ip-limit loop|-"
  "quota-trojan|Trojan quota loop|-"
  "limit-ip-trojan|Trojan ip-limit loop|-"
)

clear
ui_header "SERVICE STATUS"
printf " ${WHITE}%-26s %-7s %s${NC}\n" "Service" "Status" "Port"
ui_sep

up=0; down=0
for row in "${ROWS[@]}"; do
  IFS='|' read -r unit label port <<< "$row"
  # Skip units that were never installed (no unit file) to avoid noise.
  if ! systemctl list-unit-files "${unit}.service" >/dev/null 2>&1 \
       || [[ -z "$(systemctl list-unit-files "${unit}.service" 2>/dev/null | grep "${unit}")" ]]; then
    # still show core ones as N/A, hide optional loops if absent
    case "$unit" in
      quota*|limit-ip-*) continue ;;
    esac
  fi
  if systemctl is-active --quiet "$unit" 2>/dev/null; then
    badge="${GREEN}ON${NC}"; ((up++))
  else
    badge="${RED}OFF${NC}"; ((down++))
  fi
  printf " %-26s " "$label"
  printf "${badge}"
  # pad after colored badge (badge text is 2-3 chars)
  printf "%*s %s\n" 5 "" "$port"
done

ui_sep
echo -e " ${WHITE}SSH tunnel stack${NC} : $(ssh_stack_badge)  ${CYAN}(dropbear + ssh-ws)${NC}"
ui_sep
echo -e " Active: ${GREEN}${up}${NC}   Inactive: ${RED}${down}${NC}"
echo -e " ${CYAN}* internal (bound to 127.0.0.1)${NC}"
ui_foot
ui_back
menu-system
