#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: DNS changer (Rocky Linux 9)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
G='\033[0;32m'
NC='\e[0m'

mdns() {
    clear
    echo -e "\e[36m╒════════════════════════════════════════════╕\033[0m"
    echo -e " \E[0;41;36m                 DNS CHANGER                \E[0m"
    echo -e "\e[36m╘════════════════════════════════════════════╛\033[0m"
    dnsfile="/root/.dns"
    if test -f "$dnsfile"; then
        echo -e "   Active DNS : \033[1;37m$(cat /root/.dns)\033[0m"
    fi
    echo -e "
 [1]  Temporary DNS (reset on reboot)
 [2]  Permanent DNS (locked)
 [3]  Reset DNS to Default (8.8.8.8)
 [4]  Back"
    echo ""
    read -p "Select [1-4] : " dns
    case $dns in
    1)
        read -p "Insert DNS : " dns1
        [[ -z "$dns1" ]] && { echo "DNS required!"; sleep 1; mdns; return; }
        chattr -i /etc/resolv.conf 2>/dev/null
        echo "nameserver $dns1" > /etc/resolv.conf
        echo "$dns1" > /root/.dns
        echo -e "${G}DNS $dns1 applied (temporary).${NC}"
        sleep 1; mdns
        ;;
    2)
        read -p "Insert DNS : " dns2
        [[ -z "$dns2" ]] && { echo "DNS required!"; sleep 1; mdns; return; }
        chattr -i /etc/resolv.conf 2>/dev/null
        echo "nameserver $dns2" > /etc/resolv.conf
        chattr +i /etc/resolv.conf 2>/dev/null
        echo "$dns2" > /root/.dns
        echo -e "${G}DNS $dns2 applied (permanent/locked).${NC}"
        sleep 1; mdns
        ;;
    3)
        read -p "Reset to default DNS? [Y/N]: " -e ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            chattr -i /etc/resolv.conf 2>/dev/null
            rm -f /root/.dns
            echo "nameserver 8.8.8.8" > /etc/resolv.conf
            echo -e "[ ${G}INFO${NC} ] Reset to default DNS (8.8.8.8)"
        fi
        sleep 1; mdns
        ;;
    4) clear ; menu-system ;;
    *) mdns ;;
    esac
}

mdns
