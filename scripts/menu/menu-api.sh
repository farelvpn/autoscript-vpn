#!/bin/bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# UI Color Codes
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
CYAN='\e[1;36m'
NC='\033[0m'
BOLD='\e[1m'

# Loading animation
loading() {
  local msg="$1"
  echo -ne "${CYAN}$msg"
  for i in {1..3}; do
    echo -ne "."
    sleep 0.5
  done
  echo -e "${NC}"
}

menu-api() {
clear
generate() {
  clear
  loading "${YELLOW}Generating New Key"
  # Generate a 32-character random alphanumeric API key dengan prefix risqinf_
  newkey="risqinf_$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)"
  # Hindari duplikat, tambahkan hanya jika belum ada
  grep -qxF "$newkey" /etc/api/key 2>/dev/null || echo "$newkey" >> /etc/api/key
  systemctl daemon-reload
  systemctl enable server.service
  systemctl start server.service
  systemctl restart server.service
  mds=$(cat /etc/api/key)
  clear
  echo -e "${GREEN}${BOLD}[OK] Success Generate New Key${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}Your API Token:${NC}"
  echo -e "${BOLD}$newkey${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  read -n 1 -s -r -p "Press any key to return to menu..."
}

manual() {
  clear
  echo -e "${YELLOW}Add New Token API${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  read -p "Input Token: " token
  loading "${YELLOW}Adding Token"
  echo $token >> /etc/api/key
  systemctl daemon-reload
  systemctl enable server.service
  systemctl start server.service
  systemctl restart server.service
  mds=$(cat /etc/api/key)
  clear
  echo -e "${GREEN}${BOLD}[OK] Success Add New Key API${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}Your API Token:${NC}"
  echo -e "${BOLD}$mds${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  read -n 1 -s -r -p "Press any key to return to menu..."
}

manual31() {
  nano /etc/api/key
}

enable() {
  clear
  loading "${YELLOW}Enabling API"
  systemctl daemon-reload
  systemctl enable server.service
  systemctl start server.service
  systemctl restart server.service
  clear
  echo -e "${GREEN}${BOLD}[OK] Done Enable API${NC}"
  read -n 1 -s -r -p "Press any key to return to menu..."
}

restart() {
  loading "${YELLOW}Restarting API"
  systemctl daemon-reload
  systemctl enable server.service
  systemctl start server.service
  systemctl restart server.service
  clear
  echo -e "${GREEN}${BOLD}[OK] Done Restarting API${NC}"
  read -n 1 -s -r -p "Press any key to return to menu..."
}

disable() {
  loading "${RED}Disabling API"
  systemctl stop server.service
  systemctl disable server.service
  clear
  echo -e "${RED}${BOLD}[X] Success Disable API${NC}"
  read -n 1 -s -r -p "Press any key to return to menu..."
}

detail() {
  mkdir -p /etc/api
  domain=$(cat /etc/xray/domain)

  while true; do
    clear
    edust_service=$(systemctl is-active server.service 2>/dev/null)
    if [[ $edust_service == "active" ]]; then
      proxy1="${GREEN}● ONLINE${NC}"
    else
      proxy1="${RED}● OFFLINE${NC}"
    fi

    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║           ${CYAN}<= Menu Web API =>               ${BLUE}║${NC}"
    echo -e "${BOLD}${BLUE}╠════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}${BLUE}║${NC}  ${YELLOW}Status: $proxy1${NC}"   
    echo -e "${BOLD}${BLUE}║${NC}  ${CYAN}Domain: ${BOLD}$domain${NC}"
    echo -e "${BOLD}${BLUE}╠════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}${BLUE}║${NC}  ${YELLOW}With Port:${NC}"
    echo -e "${BOLD}${BLUE}║${NC}    - http://${domain}:9000/api/path"
    echo -e "${BOLD}${BLUE}║${NC}    - http://${domain}:9000/vps/path"
    echo -e "${BOLD}${BLUE}║${NC}  ${YELLOW}Default Port:${NC}"
    echo -e "${BOLD}${BLUE}║${NC}    - http://${domain}/api/path"
    echo -e "${BOLD}${BLUE}║${NC}    - https://${domain}/api/path"
    echo -e "${BOLD}${BLUE}║${NC}    - http://${domain}/vps/path"
    echo -e "${BOLD}${BLUE}║${NC}    - https://${domain}/vps/path"
    echo -e "${BOLD}${BLUE}╠════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}${BLUE}║${NC}  ${BOLD}1.${NC} Generate New Key Token  ${CYAN}- Otomatis generate token baru${NC}"
    echo -e "${BOLD}${BLUE}║${NC}  ${BOLD}2.${NC} Change Manual Key Token ${CYAN}- Edit file token manual${NC}"
    echo -e "${BOLD}${BLUE}║${NC}  ${BOLD}3.${NC} Add Key Token API       ${CYAN}- Tambah token manual${NC}"
    echo -e "${BOLD}${BLUE}║${NC}  ${BOLD}4.${NC} Enable API              ${CYAN}- Aktifkan API${NC}"
    echo -e "${BOLD}${BLUE}║${NC}  ${BOLD}5.${NC} Restart API             ${CYAN}- Restart service API${NC}"
    echo -e "${BOLD}${BLUE}║${NC}  ${BOLD}6.${NC} Disable API             ${CYAN}- Nonaktifkan API${NC}"
    echo -e "${BOLD}${BLUE}║${NC}  ${BOLD}0.${NC} Back To Default Menu    ${CYAN}- Kembali ke menu utama${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════╝${NC}"
    echo -ne "${YELLOW}Pilih Opsi [0-6]: ${NC}"
    read -r opw

    case $opw in
      1) generate ;;
      2) manual31 ;;
      3) manual ;;
      4) enable ;;
      5) restart ;;
      6) disable ;;
      0) clear ; menu ;;
      *) echo -e "${RED}Opsi tidak valid!${NC}"; sleep 1 ;;
    esac
  done
}

detail

}

menu-api