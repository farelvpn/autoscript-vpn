#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================

menu_vless() {
    clear
    echo -e "════════════════════════════════════════" 
    echo -e "         ═══[ Vless MENU ]═══"
    echo -e "════════════════════════════════════════" 
    echo -e " 1)  Create Account Vless"
    echo -e " 2)  Trial Account Vless"
    echo -e " 3)  Delete Account Vless"
    echo -e " 4)  Renew Account Vless"
    echo -e " 5)  Cek User Login Vless"
    echo -e " 6)  List All Vless Accounts"
    echo -e " 7)  Cek Config Account Vless"
    echo -e " 8)  Recovery Account Vless"
    echo -e "════════════════════════════════════════" 
    echo -e " x)  MAIN MENU"
    echo -e "════════════════════════════════════════" 
    echo -e ""
    read -p " Please select an option [1-9 or x]: " menu
    echo -e ""
    
    case $menu in
        1) add-vless ;;
        2) trial-vless ;;
        3) delete-vless ;;
        4) renew-vless ;;
        5) cek-vless ;;
        6) list-vless ;;
        7) config-vless ;;
        8) recovery-vless ;;
        x) menu ;;
        *) 
            echo -e "\e[31mInvalid option! Please try again.\e[0m"
            sleep 1
            menu_vless
            ;;
    esac
}

menu_vless