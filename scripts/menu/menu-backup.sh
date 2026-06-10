#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Backup & Restore submenu
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
[[ -f /usr/local/sbin/lib/common.sh ]] && . /usr/local/sbin/lib/common.sh

menu_backup() {
    clear
    ui_header "BACKUP & RESTORE"
    echo -e " 1)  Backup now (encrypted -> Telegram)"
    echo -e " 2)  Restore from backup"
    ui_foot
    echo -e " 0)  Back to Main Menu"
    ui_foot
    read -rp " Select option : " opt
    case "$opt" in
        1) clear ; backup ; ui_back ; menu_backup ;;
        2) clear ; restore ; ui_back ; menu_backup ;;
        0|x|X) clear ; menu ;;
        *) err "Invalid option."; sleep 1; menu_backup ;;
    esac
}

menu_backup
