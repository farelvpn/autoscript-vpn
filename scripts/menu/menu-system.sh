#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: System & maintenance submenu
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
[[ -f /usr/local/sbin/lib/common.sh ]] && . /usr/local/sbin/lib/common.sh

menu_system() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}                      SYSTEM MENU                         ${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  DOMAIN & TLS${NC}"
    echo -e " 1)  Change Domain / Renew SSL Certificate"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  NETWORK${NC}"
    echo -e " 2)  Change DNS                 4)  Speedtest"
    echo -e " 3)  Stream / Media Check"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  CORE & SYSTEM${NC}"
    echo -e " 5)  Xray Core Version          7)  Timezone"
    echo -e " 6)  Dropbear Version           8)  Uninstall Script"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " x)  Back to Main Menu"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -rp " Select Option : " opt
    case "$opt" in
        1) clear ; menu-host ;;
        2) clear ; change-dns ;;
        3) clear ; stream-check ;;
        4) clear ; echo -e "YES" | speedtest ;;
        5) clear ; versi-xray ;;
        6) clear ; menu-dropbear ;;
        7) clear ; change-timezone ;;
        8) clear ; uninstall ;;
        x|X) clear ; menu ;;
        *) menu_system ;;
    esac
}

menu_system
