#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================

menu_ssh() {
    clear
    echo -e "════════════════════════════════════════" 
    echo -e "           ═══[ SSH MENU ]═══"
    echo -e "════════════════════════════════════════" 
    echo -e " 1)  Create Account SSH"
    echo -e " 2)  Trial Account SSH"
    echo -e " 3)  Delete Account SSH"
    echo -e " 4)  Renew Account SSH"
    echo -e " 5)  Cek User Login SSH"
    echo -e " 6)  List All SSH Accounts"
    echo -e " 7)  Cek Config Account SSH"
    echo -e " 8)  Recovery Account SSH"
    echo -e " 9)  Change Version Dropbear"
    echo -e "════════════════════════════════════════" 
    echo -e " x)  MAIN MENU"
    echo -e "════════════════════════════════════════" 
    echo -e ""
    read -p " Please select an option [1-9 or x]: " menu
    echo -e ""
    
    case $menu in
        1) add-ssh ;;
        2) trial-ssh ;;
        3) delete-ssh ;;
        4) renew-ssh ;;
        5) cek-ssh ;;
        6) list-ssh ;;
        7) config-ssh ;;
        8) recovery-ssh ;;
        9) menu-dropbear ;;
        x) menu ;;
        *) 
            echo -e "\e[31mInvalid option! Please try again.\e[0m"
            sleep 1
            menu_ssh
            ;;
    esac
}

menu_ssh