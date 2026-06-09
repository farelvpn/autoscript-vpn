#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================

menu_trojan() {
    clear
    echo -e "════════════════════════════════════════" 
    echo -e "         ═══[ Trojan MENU ]═══"
    echo -e "════════════════════════════════════════" 
    echo -e " 1)  Create Account Trojan"
    echo -e " 2)  Trial Account Trojan"
    echo -e " 3)  Delete Account Trojan"
    echo -e " 4)  Renew Account Trojan"
    echo -e " 5)  Cek User Login Trojan"
    echo -e " 6)  List All Trojan Accounts"
    echo -e " 7)  Cek Config Account Trojan"
    echo -e " 8)  Recovery Account Trojan"
    echo -e "════════════════════════════════════════" 
    echo -e " x)  MAIN MENU"
    echo -e "════════════════════════════════════════" 
    echo -e ""
    read -p " Please select an option [1-9 or x]: " menu
    echo -e ""
    
    case $menu in
        1) add-trojan ;;
        2) trial-trojan ;;
        3) delete-trojan ;;
        4) renew-trojan ;;
        5) cek-trojan ;;
        6) list-trojan ;;
        7) config-trojan ;;
        8) recovery-trojan ;;
        x) menu ;;
        *) 
            echo -e "\e[31mInvalid option! Please try again.\e[0m"
            sleep 1
            menu_trojan
            ;;
    esac
}

menu_trojan