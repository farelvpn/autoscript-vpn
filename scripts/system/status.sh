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
  "haproxy|HAProxy (entry)|80, 443"
  "nginx|Nginx (router)|81*"
  "xray|Xray Core|1,2,3*"
  "dropbear|Dropbear SSH|109"
  "ssh-ws|SSH WebSocket|8888"
  "sshd|OpenSSH|22, 3303"
  "openvpn-server@server-tcp-1194|OpenVPN TCP|1194"
  "openvpn-server@server-udp-2200|OpenVPN UDP|2200"
  "vnstat|vnStat (bandwidth)|-"
  "rsyslog|rsyslog (secure)|-"
  "crond|Cron scheduler|-"
  "firewalld|Firewall|-"
  "quota|VLESS quota loop|-"
  "limit-ip-vless|VLESS ip-limit|-"
  "quota-vmess|VMESS quota loop|-"
  "limit-ip-vmess|VMESS ip-limit|-"
  "quota-trojan|Trojan quota loop|-"
  "limit-ip-trojan|Trojan ip-limit|-"
)

clear
ui_header "SERVICE STATUS"
printf " ${BIWhite}%-20s %-9s %s${NC}\n" "SERVICE" "STATUS" "PORT"
ui_rule

up=0; down=0
for row in "${ROWS[@]}"; do
  IFS='|' read -r unit label port <<< "$row"
  # Hide optional loop units that were never installed (avoid noise).
  if ! systemctl list-unit-files "${unit}.service" 2>/dev/null | grep -q "${unit}"; then
    case "$unit" in
      quota*|limit-ip-*) continue ;;
    esac
  fi
  if systemctl is-active --quiet "$unit" 2>/dev/null; then
    badge="${GREEN}[ ON ]${NC} "; ((up++))
  else
    badge="${RED}[ OFF ]${NC}"; ((down++))
  fi
  # %-20s for label, fixed-width badge column, then port.
  printf " ${WHITE}%-20s${NC} %b  ${CYAN}%s${NC}\n" "$label" "$badge" "$port"
done

ui_rule
ui_status "SSH stack" "$(ssh_stack_badge)  ${CYAN}(dropbear + ssh-ws)${NC}"
ui_rule
echo -e " Active ${GREEN}${up}${NC}   Inactive ${RED}${down}${NC}    ${CYAN}* internal (127.0.0.1)${NC}"
ui_foot
ui_back
menu-system
