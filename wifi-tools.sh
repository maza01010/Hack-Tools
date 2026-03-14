#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Конфигурация
CONFIG_DIR="$HOME/.network_monitor"
KNOWN_DEVICES="$CONFIG_DIR/known_devices.txt"
LOG_FILE="$CONFIG_DIR/network.log"

# Создание директории конфигурации
mkdir -p "$CONFIG_DIR"
touch "$KNOWN_DEVICES"
touch "$LOG_FILE"

# Функция для получения текущего IP
get_network_info() {
    local ip_info=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
    local subnet=$(echo $ip_info | cut -d'.' -f1-3)
    echo "$subnet.0/24"
}

# Функция для сканирования сети
scan_network() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       СКАНИРОВАНИЕ СЕТИ              ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}\n"
    
    local network=$(get_network_info)
    echo -e "${YELLOW}Сканирование сети: $network${NC}\n"
    
    # Сканирование с помощью nmap
    local scan_result=$(nmap -sn $network 2>/dev/null | grep -E 'Nmap scan|MAC' | sed 's/Nmap scan report for //')
    
    local devices=()
    local ips=()
    local macs=()
    
    while IFS= read -r line; do
        if [[ $line =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            ips+=("$line")
        elif [[ $line =~ MAC:* ]]; then
            macs+=("$(echo $line | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}')")
        fi
    done <<< "$scan_result"
    
    # Вывод результатов
    echo -e "${GREEN}Найденные устройства:${NC}\n"
    printf "${BLUE}%-20s %-20s %-30s%s${NC}\n" "IP Адрес" "MAC Адрес" "Устройство" "Статус"
    echo "--------------------------------------------------------------------------------"
    
    for i in "${!ips[@]}"; do
        local ip="${ips[$i]}"
        local mac="${macs[$i]:-Не определен}"
        local name=$(get_device_name "$mac")
        local known=$(check_known "$mac")
        
        if [ "$ip" = "$(hostname -I | awk '{print $1}')" ]; then
            printf "%-20s %-20s %-30s${GREEN}%s${NC}\n" "$ip" "$mac" "$name (Это устройство)" "Активно"
        else
            printf "%-20s %-20s %-30s${GREEN}%s${NC}\n" "$ip" "$mac" "$name" "Активно"
        fi
    done
    
    echo -e "\n${YELLOW}Всего устройств: ${#ips[@]}${NC}"
}

# Функция для получения имени устройства
get_device_name() {
    local mac="$1"
    if [ -f "$KNOWN_DEVICES" ]; then
        local name=$(grep "$mac" "$KNOWN_DEVICES" | cut -d'|' -f2)
        if [ -n "$name" ]; then
            echo "$name"
        else
            echo "Неизвестное устройство"
        fi
    else
        echo "Неизвестное устройство"
    fi
}

# Функция для проверки известных устройств
check_known() {
    local mac="$1"
    if [ -f "$KNOWN_DEVICES" ] && grep -q "$mac" "$KNOWN_DEVICES"; then
        echo "✓"
    else
        echo "✗"
    fi
}

# Функция для добавления устройства
add_device() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       ДОБАВЛЕНИЕ УСТРОЙСТВА           ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}\n"
    
    read -p "Введите MAC адрес (формат XX:XX:XX:XX:XX:XX): " mac
    read -p "Введите имя устройства: " name
    
    if [[ $mac =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
        echo "$mac|$name" >> "$KNOWN_DEVICES"
        echo -e "\n${GREEN}✓ Устройство добавлено!${NC}"
        
        # Запись в лог
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Добавлено устройство: $name ($mac)" >> "$LOG_FILE"
    else
        echo -e "\n${RED}✗ Неверный формат MAC адреса!${NC}"
    fi
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция для блокировки устройства (через ARP)
block_device() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       БЛОКИРОВКА УСТРОЙСТВА           ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}\n"
    
    echo -e "${YELLOW}ВНИМАНИЕ: Блокировка может быть временной и не всегда эффективной${NC}\n"
    
    read -p "Введите IP адрес устройства для блокировки: " ip
    
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # Добавление правила iptables (требуются права root)
        if [ "$EUID" -eq 0 ]; then
            iptables -A INPUT -s $ip -j DROP
            iptables -A OUTPUT -d $ip -j DROP
            echo -e "\n${GREEN}✓ Устройство $ip заблокировано${NC}"
            
            # Запись в лог
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Заблокировано устройство: $ip" >> "$LOG_FILE"
        else
            echo -e "\n${RED}✗ Для блокировки нужны права root!${NC}"
            echo -e "${YELLOW}Запустите скрипт с sudo: sudo $0${NC}"
        fi
    else
        echo -e "\n${RED}✗ Неверный IP адрес!${NC}"
    fi
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция для разблокировки устройства
unblock_device() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       РАЗБЛОКИРОВКА УСТРОЙСТВА        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}\n"
    
    read -p "Введите IP адрес устройства для разблокировки: " ip
    
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && [ "$EUID" -eq 0 ]; then
        iptables -D INPUT -s $ip -j DROP 2>/dev/null
        iptables -D OUTPUT -d $ip -j DROP 2>/dev/null
        echo -e "\n${GREEN}✓ Устройство $ip разблокировано${NC}"
        
        # Запись в лог
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Разблокировано устройство: $ip" >> "$LOG_FILE"
    else
        echo -e "\n${RED}✗ Неверный IP или недостаточно прав!${NC}"
    fi
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция для просмотра статистики
show_stats() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       СТАТИСТИКА СЕТИ                 ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}\n"
    
    echo -e "${YELLOW}Известные устройства:${NC}"
    if [ -f "$KNOWN_DEVICES" ] && [ -s "$KNOWN_DEVICES" ]; then
        cat "$KNOWN_DEVICES" | while IFS='|' read -r mac name; do
            printf "  ${GREEN}•${NC} %-30s (%s)\n" "$name" "$mac"
        done
    else
        echo "  Нет известных устройств"
    fi
    
    echo -e "\n${YELLOW}Последние события:${NC}"
    if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
        tail -5 "$LOG_FILE"
    else
        echo "  Нет записей в логе"
    fi
    
    echo -e "\n${YELLOW}Информация о сети:${NC}"
    echo "  IP адрес: $(hostname -I | awk '{print $1}')"
    echo "  MAC адрес: $(ip link show | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | head -1)"
    
    read -p "Нажмите Enter для продолжения..."
}

# Главное меню
show_menu() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     МОНИТОР ДОМАШНЕЙ СЕТИ v1.0        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo -e "${GREEN}Только для вашей собственной сети!${NC}\n"
    
    echo "1. Сканировать сеть"
    echo "2. Показать все устройства"
    echo "3. Добавить устройство в известные"
    echo "4. Заблокировать устройство (требует root)"
    echo "5. Разблокировать устройство (требует root)"
    echo "6. Статистика и логи"
    echo "0. Выход"
    echo ""
    read -p "Выберите действие: " choice
}

# Основной цикл
while true; do
    show_menu
    
    case $choice in
        1)
            scan_network
            read -p "Нажмите Enter для продолжения..."
            ;;
        2)
            scan_network
            read -p "Нажмите Enter для продолжения..."
            ;;
        3)
            add_device
            ;;
        4)
            block_device
            ;;
        5)
            unblock_device
            ;;
        6)
            show_stats
            ;;
        0)
            echo -e "\n${GREEN}До свидания!${NC}"
            exit 0
            ;;
        *)
            echo -e "\n${RED}Неверный выбор!${NC}"
            sleep 1
            ;;
    esac
done
