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
    ui_header "TROJAN PANEL"
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
        1) add-trojan ;;
        2) trial-trojan ;;
        3) delete-trojan ;;
        4) renew-trojan ;;
        5) list-trojan ;;
        6) config-trojan ;;
        7) recovery-trojan ;;
        8) cek-trojan ;;
        0|x|X) menu ;;
        *) err "Invalid option."; sleep 1; menu_trojan ;;
    esac
}

menu_trojan
