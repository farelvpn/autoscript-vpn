#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: TROJAN management submenu
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
[[ -f /usr/local/sbin/lib/common.sh ]] && . /usr/local/sbin/lib/common.sh

menu_trojan() {
    clear
    ui_header "TROJAN MENU"
    echo -e " 1)  Create Account            5)  Check Login (live)"
    echo -e " 2)  Trial Account             6)  List Accounts"
    echo -e " 3)  Delete Account            7)  Check Config / Details"
    echo -e " 4)  Renew Account             8)  Recovery Account"
    ui_foot
    echo -e " 0)  Back to Main Menu"
    ui_foot
    read -rp " Select option : " opt
    case "$opt" in
        1) add-trojan ;;
        2) trial-trojan ;;
        3) delete-trojan ;;
        4) renew-trojan ;;
        5) cek-trojan ;;
        6) list-trojan ;;
        7) config-trojan ;;
        8) recovery-trojan ;;
        0|x|X) menu ;;
        *) err "Invalid option."; sleep 1; menu_trojan ;;
    esac
}

menu_trojan
