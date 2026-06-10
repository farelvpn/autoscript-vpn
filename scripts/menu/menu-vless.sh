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
    ui_header "VLESS PANEL"
    ui_opt 1 "Create Account"
    ui_opt 2 "Trial Account"
    ui_opt 3 "Delete Account"
    ui_opt 4 "Renew Account"
    ui_opt 5 "List Accounts"
    ui_opt 6 "Check Config / Details"
    ui_opt 7 "Recovery Account"
    ui_opt 8 "Check Login (live)"
    ui_rule
    ui_opt 0 "Back to Main Menu"
    ui_foot
    read -rp " Select option : " opt
    case "$opt" in
        1) add-vless ;;
        2) trial-vless ;;
        3) delete-vless ;;
        4) renew-vless ;;
        5) list-vless ;;
        6) config-vless ;;
        7) recovery-vless ;;
        8) cek-vless ;;
        0|x|X) menu ;;
        *) err "Invalid option."; sleep 1; menu_vless ;;
    esac
}

menu_vless
