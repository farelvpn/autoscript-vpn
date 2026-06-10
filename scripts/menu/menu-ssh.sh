#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: SSH / OpenVPN management submenu
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
[[ -f /usr/local/sbin/lib/common.sh ]] && . /usr/local/sbin/lib/common.sh

menu_ssh() {
    clear
    ui_header "SSH / OPENVPN MENU"
    echo -e " 1)  Create Account            6)  List Accounts"
    echo -e " 2)  Trial Account             7)  Check Config / Details"
    echo -e " 3)  Delete Account            8)  Recovery Account"
    echo -e " 4)  Renew Account             9)  Check Login (live)"
    echo -e " 5)  Change Dropbear Version"
    ui_foot
    echo -e " 0)  Back to Main Menu"
    ui_foot
    read -rp " Select option : " opt
    case "$opt" in
        1) add-ssh ;;
        2) trial-ssh ;;
        3) delete-ssh ;;
        4) renew-ssh ;;
        5) menu-dropbear ;;
        6) list-ssh ;;
        7) config-ssh ;;
        8) recovery-ssh ;;
        9) cek-ssh ;;
        0|x|X) menu ;;
        *) err "Invalid option."; sleep 1; menu_ssh ;;
    esac
}

menu_ssh
