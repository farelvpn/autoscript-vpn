#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================

# Fungsi warna
red() { echo -e "\033[31;1m[X] ${*}\033[0m"; }
green() { echo -e "\033[32;1m[OK] ${*}\033[0m"; }
yellow() { echo -e "\033[33;1m[*] ${*}\033[0m"; }
blue() { echo -e "\033[34;1m[-] ${*}\033[0m"; }

# Garis pembatas
border() {
  echo -e "\033[35;1m===============================================\033[0m"
}

# Header
header() {
  clear
  border
  echo -e "\033[36;1m               RESTORE SYSTEM              \033[0m"
  border
}

# Fungsi dekripsi URL
decrypt_url() {
  echo "$1" | openssl enc -aes-256-cbc -a -A -d -salt -pass pass:"$2" 2>/dev/null
}

# Fungsi untuk validasi URL
validate_url() {
  if [[ "$1" =~ ^https://github.com.*\.zip$ ]]; then
    return 0
  else
    return 1
  fi
}

restore2() {
  header
  
  # Cek root
  if [[ $EUID -ne 0 ]]; then
    red "Harus dijalankan sebagai root!"
    exit 1
  fi

  # Input user
  echo -e "\033[33;1m Masukkan data backup:\033[0m"
  read -p " URL: " ENCRYPTED_URL
  read -s -p " Password: " BASE64_PASSWORD
  echo ""

  # Validasi input
  if [[ -z "$ENCRYPTED_URL" || -z "$BASE64_PASSWORD" ]]; then
    red "URL dan Password tidak boleh kosong!"
    exit 1
  fi

  # Dekode password
  ZIP_PASSWORD=$(echo -n "$BASE64_PASSWORD" | base64 -d 2>/dev/null)
  if [[ -z "$ZIP_PASSWORD" ]]; then
    red "Password base64 tidak valid!"
    exit 1
  fi

  # Dekripsi URL
  BACKUP_URL=$(decrypt_url "$ENCRYPTED_URL" "$ZIP_PASSWORD")
  if [[ -z "$BACKUP_URL" ]]; then
    red "Gagal mendekripsi URL!"
    exit 1
  fi

  # Validasi URL hasil dekripsi
  if ! validate_url "$BACKUP_URL"; then
    red "URL backup tidak valid!"
    echo "URL harus dari GitHub dan berakhiran .zip"
    exit 1
  fi

  # Download
  border
  yellow " Mengunduh backup..."
  rm -f /tmp/backup.zip
  if ! wget --show-progress -q -O /tmp/backup.zip "$BACKUP_URL"; then
    red "Gagal mengunduh backup!"
    exit 1
  fi

  # Cek file zip
  if ! unzip -l /tmp/backup.zip >/dev/null 2>&1; then
    red "File backup corrupt atau bukan file zip!"
    rm -f /tmp/backup.zip
    exit 1
  fi

  # Ekstrak
  yellow " Mengekstrak backup..."
  rm -rf /tmp/restore
  mkdir -p /tmp/restore
  if ! unzip -P "$ZIP_PASSWORD" /tmp/backup.zip -d /tmp/restore >/dev/null 2>&1; then
    red "Password salah atau file corrupt!"
    rm -rf /tmp/backup.zip /tmp/restore
    exit 1
  fi

  # Validasi struktur direktori
  # Modified to handle the new random folder structure
  RESTORE_DIR=$(find /tmp/restore -type d -path "*backup-*/etc" -print -quit)
  if [[ -z "$RESTORE_DIR" ]]; then
    red "Struktur backup tidak valid!"
    echo "Direktori etc tidak ditemukan dalam struktur backup"
    rm -rf /tmp/backup.zip /tmp/restore
    exit 1
  fi

  # Restore
  border
  yellow " Merestore sistem..."
  
  # File system
  [[ -f "$RESTORE_DIR/passwd" ]] && cp -f "$RESTORE_DIR/passwd" /etc/
  [[ -f "$RESTORE_DIR/group" ]] && cp -f "$RESTORE_DIR/group" /etc/
  [[ -f "$RESTORE_DIR/shadow" ]] && cp -f "$RESTORE_DIR/shadow" /etc/
  [[ -f "$RESTORE_DIR/gshadow" ]] && cp -f "$RESTORE_DIR/gshadow" /etc/
  
  # xray config
  if [[ -d "$RESTORE_DIR/xray" ]]; then
    mkdir -p /etc/xray
    cp -rf "$RESTORE_DIR/xray" /etc/
  else
    yellow "[WARN] Config xray tidak ditemukan dalam backup"
  fi

  # Restart services
  yellow " Merestart layanan..."
  systemctl restart xray 2>/dev/null || yellow "[WARN] Gagal restart xray"
  systemctl restart sshd 2>/dev/null || yellow "[WARN] Gagal restart SSH"
  systemctl restart dropbear 2>/dev/null || yellow "[WARN] Gagal restart Dropbear"

  # Cleanup
  rm -rf /tmp/backup.zip /tmp/restore

  clear
  border
  green "[OK] Restore berhasil!"
  blue " Layanan telah direstart."
  border
}

# Menu utama
menu() {
  header
  echo -e "\033[32;1m1) Backup Data\033[0m"
  echo -e "\033[32;1m2) Restore Data\033[0m"
  echo -e "\033[31;1m3) Keluar\033[0m"
  border

  read -p "Pilih opsi [1-3]: " choice
  case "$choice" in
    1) 
      backup
      read -p "Tekan Enter untuk kembali ke menu..."
      menu
      ;;
    2) restore ;;
    3) exit 0 ;;
    *) 
      red "Pilihan tidak valid!"
      sleep 1
      menu
      ;;
  esac
}

menu