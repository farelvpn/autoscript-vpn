#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: VMESS management submenu
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
[[ -f /usr/local/sbin/lib/common.sh ]] && . /usr/local/sbin/lib/common.sh

menu_vmess() {
    clear
    ui_header "VMESS MENU"
    echo -e " 1)  Create Account            5)  Check Login (live)"
    echo -e " 2)  Trial Account             6)  List Accounts"
    echo -e " 3)  Delete Account            7)  Check Config / Details"
    echo -e " 4)  Renew Account             8)  Recovery Account"
    ui_foot
    echo -e " 0)  Back to Main Menu"
    ui_foot
    read -rp " Select option : " opt
    case "$opt" in
        1) add-vmess ;;
        2) trial-vmess ;;
        3) delete-vmess ;;
        4) renew-vmess ;;
        5) cek-vmess ;;
        6) list-vmess ;;
        7) config-vmess ;;
        8) recovery-vmess ;;
        0|x|X) menu ;;
        *) err "Invalid option."; sleep 1; menu_vmess ;;
    esac
}

menu_vmess
