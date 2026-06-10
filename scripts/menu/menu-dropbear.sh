#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
clear
BIBlack='\033[1;90m'
BIGreen='\033[1;92m'
BIRed='\033[1;91m'
BIYellow='\033[1;93m'
BIWhite='\033[1;97m'
BILime='\e[38;5;155m'
NC='\033[0m'
DROPBEAR_BIN="/usr/sbin/dropbear"
DROPBEAR_LIB="/usr/lib/dropbear"
DROPBEAR_CONFIG="/etc/dropbear"
DROPBEAR_MAN="/usr/share/man/man8/dropbear.8.gz"
DROPBEAR_URL="https://matt.ucc.asn.au/dropbear/releases"
clear
echo -e "${BIWhite}┌─────────────────────────────────────┐${NC}"
echo -e "${BIWhite}│ \e[41;97;1m         DROPBEAR MANAGER          \033[0m ${BIWhite}│${NC}"
echo -e "${BIWhite}└─────────────────────────────────────┘${NC}"
echo -e "$(/usr/sbin/dropbear -V)"
echo -e "${BILime}[${BIWhite}01${BILime}] ${BIWhite}Version 2018 ( Recomend )"
echo -e "${BILime}[${BIWhite}02${BILime}] ${BIWhite}Version 2019 ( Recomend )"
echo -e "${BILime}[${BIWhite}03${BILime}] ${BIWhite}Version 2020 ( New Stable )"
echo -e "${BILime}[${BIWhite}04${BILime}] ${BIWhite}Version 2022 ( New Stable )"
echo -e "${BILime}[${BIWhite}05${BILime}] ${BIWhite}Version 2024 ( New Stable )"
echo -e "${BIWhite}──────────────────────────────────────${NC}"
echo -e "${BIYellow}Input x or [ Ctrl+C ] • To-${BIWhite}Exit${NC}"
echo -e "${BIWhite}──────────────────────────────────────${NC}"
echo ""
read -p "Select menu : " opt
echo -e ""
case $opt in
1) clear ; DROPBEAR_VERSION="2018.76" ;;
2) clear ; DROPBEAR_VERSION="2019.78" ;;
3) clear ; DROPBEAR_VERSION="2020.81" ;;
4) clear ; DROPBEAR_VERSION="2022.82" ;;
5) clear ; DROPBEAR_VERSION="2024.86" ;;
0) clear ; menu ; exit ;;
x) menu ;;
*) echo "anda salah tekan" ; sleep 1 ; menu ;;
esac

clear
echo -e "${BIWhite}┌─────────────────────────────────────────┐${NC}"
echo -e "${BIWhite}│ \e[41;97;1m      INSTALLING DROPBEAR VERSION      \033[0m ${BIWhite}│${NC}"
echo -e "${BIWhite}└─────────────────────────────────────────┘${NC}"

# Hentikan Dropbear jika berjalan
if systemctl stop dropbear || service dropbear stop; then
    echo -e "${BIGreen}Dropbear dihentikan.${BIWhite}"
else
    echo -e "${BIRed}Gagal menghentikan Dropbear.${BIWhite}"
fi

clear
if [ -f "$DROPBEAR_BIN" ]; then
    echo -e "${BIGreen}Backup versi lama Dropbear...${BIWhite}"
    cp $DROPBEAR_BIN /usr/sbin/dropbear.bak
fi

rm -f $DROPBEAR_BIN $DROPBEAR_LIB/* $DROPBEAR_CONFIG/* $DROPBEAR_MAN
clear

# Install dependensi
dnf groupinstall "Development Tools" -y && dnf install zlib-devel wget bzip2 -y
clear

# Download Dropbear
echo -e "${BIGreen}Mengunduh Dropbear versi $DROPBEAR_VERSION...${BIWhite}"
wget --no-check-certificate -O dropbear.tar.bz2 "$DROPBEAR_URL/dropbear-$DROPBEAR_VERSION.tar.bz2" || \
wget --no-check-certificate -O dropbear.tar.bz2 "https://dropbear.nl/mirror/releases/dropbear-$DROPBEAR_VERSION.tar.bz2"

# Periksa apakah file berhasil diunduh
if [ ! -f "dropbear.tar.bz2" ]; then
    echo -e "${BIRed}Download gagal, periksa URL atau koneksi internet.${BIWhite}"
    echo -e "${BIWhite}Press any key to menu${NC}"
    read -n 1 -s -r
    menu
fi

# Ekstrak file
tar -xjf dropbear.tar.bz2
cd "dropbear-$DROPBEAR_VERSION" || exit

clear
if ./configure --prefix=/usr && make && make install; then
    echo -e "${BIGreen}Kompilasi berhasil.${BIWhite}"
else
    echo -e "${BIRed}Kompilasi gagal.${BIWhite}"
    echo -e "${BIWhite}Press any key to menu${NC}"
    read -n 1 -s -r
    menu
fi

clear
mv /usr/bin/dropbear $DROPBEAR_BIN
mkdir -p $DROPBEAR_LIB
mkdir -p $DROPBEAR_CONFIG
if [ -f "/usr/share/man/man8/dropbear.8.gz" ]; then
    mv /usr/share/man/man8/dropbear.8.gz $DROPBEAR_MAN
else
    echo -e "${BIYellow}File man tidak ditemukan.${BIWhite}"
fi

clear
# Buat ulang key
rm -f /etc/dropbear/dropbear_rsa_host_key
rm -f /etc/dropbear/dropbear_dss_host_key
rm -f /etc/dropbear/dropbear_ecdsa_host_key

dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key
dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key

chmod 600 /etc/dropbear/dropbear_rsa_host_key
chmod 600 /etc/dropbear/dropbear_dss_host_key
chmod 600 /etc/dropbear/dropbear_ecdsa_host_key

clear
if systemctl start dropbear || service dropbear start; then
    echo -e "${BIGreen}Dropbear berhasil dimulai.${BIWhite}"
else
    echo -e "${BIRed}Gagal memulai Dropbear.${BIWhite}"
fi

clear
if dropbear -V; then
    echo -e "${BIGreen}Dropbear versi $DROPBEAR_VERSION telah terinstal.${BIWhite}"
else
    echo -e "${BIRed}Verifikasi gagal, Dropbear mungkin tidak terinstal dengan benar.${BIWhite}"
fi

clear
cd ..
rm -rf dropbear.tar.bz2 "dropbear-$DROPBEAR_VERSION"

# Pesan akhir
echo -e "${BIWhite}──────────────────────────────────────────${NC}"
echo -e "${BIGreen}Dropbear version $DROPBEAR_VERSION installed successfully!${NC}"
echo -e""
echo -e "${BIWhite}Press any key to menu${NC}"
read -n 1 -s -r
menu