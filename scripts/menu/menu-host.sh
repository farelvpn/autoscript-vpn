#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================

# Warna
NC='\e[0m'
green='\033[0;92m'
red='\033[0;91m'
yellow='\033[0;93m'

function install_acme() {
    if [ ! -f ~/.acme.sh/acme.sh ]; then
        echo -e "[ ${yellow}INFO${NC} ] acme.sh not found, installing..."
        curl https://get.acme.sh | sh
        export PATH=~/.acme.sh:$PATH
    fi

    random_prefix=$(tr -dc a-z </dev/urandom | head -c5)
    random_number=$(shuf -i 1000-9999 -n 1)
    acme_email="${random_prefix}${random_number}@risqinf.biz.id"

    if [ ! -f ~/.acme.sh/account.conf ]; then
        echo -e "[ ${green}INFO${NC} ] Registering new account with email: $acme_email"
        ~/.acme.sh/acme.sh --register-account -m "$acme_email" --agree-tos > /dev/null 2>&1
    else
        echo -e "[ ${green}INFO${NC} ] ACME account already exists. Using existing."
    fi
}

cert() {
    clear
    install_acme

    echo -e "[ ${green}INFO${NC} ] Start "
    sleep 0.5
    systemctl stop nginx haproxy

    domain=$(cat /etc/xray/domain)
    rm -f /etc/xray/xray.crt /etc/xray/xray.key

    sleep 1
    echo -e "[ ${red}WARNING${NC} ] Detected port 80 used by Nginx/HAProxy "
    sleep 2
    echo -e "[ ${green}INFO${NC} ] Processing to stop Nginx and HAProxy "
    sleep 1

    clear
    echo -e "[ ${green}INFO${NC} ] Starting renew cert... "
    sleep 2
    clear

    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
    ~/.acme.sh/acme.sh --installcert -d $domain \
        --fullchainpath /etc/xray/xray.crt \
        --keypath /etc/xray/xray.key \
        --ecc
        
    # Update HAProxy combined certificate
    cat /etc/xray/xray.crt /etc/xray/xray.key | tee /etc/haproxy/haproxy.pem > /dev/null
    chmod 600 /etc/xray/xray.key /etc/haproxy/haproxy.pem 2>/dev/null

    sleep 2
    clear
    echo -e "[ ${green}INFO${NC} ] Renew cert done... "
    sleep 2
    clear
    echo -e "[ ${green}INFO${NC} ] Restarting services... "
    sleep 2

    systemctl restart nginx haproxy xray
    sleep 0.5
    clear
    echo -e "[ ${green}INFO${NC} ] All finished... "
    echo ""
    read -n 1 -s -r -p "Press any key to back on menu"
    menu
}

addhost() {
    clear
    echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "Domain anda saat ini:"
    echo -e "$(cat /etc/xray/domain)"
    echo ""
    read -rp "Domain/Host: " -e host
    echo ""
    if [ -z $host ]; then
        echo "DONE CHANGE DOMAIN"
        echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        read -n 1 -s -r -p "Press any key to back on menu"
        menu
    else
        cat /etc/xray/domain > /etc/xray/domain.bak
        echo "$host" > /etc/xray/domain
        old=$(cat /etc/xray/domain.bak)
        sed -i "s|server_name ${old};|server_name ${host};|" /etc/nginx/risqinf.conf
        rm -f /etc/xray/domain.bak
        echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo -e ""
        read -n 1 -s -r -p "Press any key to renew cert"
        cert
    fi
}

menu1() {
    clear
    echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e " 1. Change Hostname/Domain/Subdomain Server"
    echo -e " 2. Renew Certificate Your Domain"
    echo -e " 0. Back To Menu"
    echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    read -p " Input Option: " ope
    case $ope in
        1) addhost ;;
        2) cert ;;
        0) menu ;;
        *) clear ; menu1 ;;
    esac
}

menu1
