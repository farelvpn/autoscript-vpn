#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================

menu_vmess() {
    clear
    echo -e "════════════════════════════════════════" 
    echo -e "         ═══[ Vmess MENU ]═══"
    echo -e "════════════════════════════════════════" 
    echo -e " 1)  Create Account Vmess"
    echo -e " 2)  Trial Account Vmess"
    echo -e " 3)  Delete Account Vmess"
    echo -e " 4)  Renew Account Vmess"
    echo -e " 5)  Cek User Login Vmess"
    echo -e " 6)  List All Vmess Accounts"
    echo -e " 7)  Cek Config Account Vmess"
    echo -e " 8)  Recovery Account Vmess"
    echo -e "════════════════════════════════════════" 
    echo -e " x)  MAIN MENU"
    echo -e "════════════════════════════════════════" 
    echo -e ""
    read -p " Please select an option [1-9 or x]: " menu
    echo -e ""
    
    case $menu in
        1) add-vmess ;;
        2) trial-vmess ;;
        3) delete-vmess ;;
        4) renew-vmess ;;
        5) cek-vmess ;;
        6) list-vmess ;;
        7) config-vmess ;;
        8) recovery-vmess ;;
        x) menu ;;
        *) 
            echo -e "\e[31mInvalid option! Please try again.\e[0m"
            sleep 1
            menu_vmess
            ;;
    esac
}

menu_vmess