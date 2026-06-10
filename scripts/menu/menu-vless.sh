#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: VLESS management submenu
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
[[ -f /usr/local/sbin/lib/common.sh ]] && . /usr/local/sbin/lib/common.sh

menu_vless() {
    clear
    ui_header "VLESS MENU"
    echo -e " 1)  Create Account            5)  Check Login (live)"
    echo -e " 2)  Trial Account             6)  List Accounts"
    echo -e " 3)  Delete Account            7)  Check Config / Details"
    echo -e " 4)  Renew Account             8)  Recovery Account"
    ui_foot
    echo -e " 0)  Back to Main Menu"
    ui_foot
    read -rp " Select option : " opt
    case "$opt" in
        1) add-vless ;;
        2) trial-vless ;;
        3) delete-vless ;;
        4) renew-vless ;;
        5) cek-vless ;;
        6) list-vless ;;
        7) config-vless ;;
        8) recovery-vless ;;
        0|x|X) menu ;;
        *) err "Invalid option."; sleep 1; menu_vless ;;
    esac
}

menu_vless
