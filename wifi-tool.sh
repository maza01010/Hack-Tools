#!/bin/bash
# local_network_manager.sh - Полное управление ВАШЕЙ локальной сетью
# Версия 3.0 с функциями блокировки

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Конфигурация
MY_MAC="D8:DC:40:0C:4E:3E"
CONFIG_DIR="$HOME/.network_manager"
KNOWN_DEVICES="$CONFIG_DIR/devices.txt"
BLOCKED_DEVICES="$CONFIG_DIR/blocked.txt"
LOG_FILE="$CONFIG_DIR/network.log"
SCAN_HISTORY="$CONFIG_DIR/scan_history.txt"

# Создание директорий и файлов
mkdir -p "$CONFIG_DIR"
touch "$KNOWN_DEVICES" "$BLOCKED_DEVICES" "$LOG_FILE" "$SCAN_HISTORY"

# Функция логирования
log_event() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Проверка root прав
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}✗ Нужны root права для этой функции${NC}"
        echo -e "${YELLOW}Запустите с sudo: sudo $0${NC}"
        return 1
    fi
    return 0
}

# Получение локальной информации
get_local_ip() {
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1
}

get_gateway() {
    ip route | grep default | awk '{print $3}'
}

get_subnet() {
    local ip=$(get_local_ip)
    echo "$ip" | cut -d'.' -f1-3
}

# Проверка MAC
check_my_mac() {
    local current_mac=$(ip link show | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | head -1)
    if [ "$current_mac" = "$MY_MAC" ]; then
        echo -e "${GREEN}✓ Ваше устройство идентифицировано${NC}"
        return 0
    else
        echo -e "${YELLOW}! MAC не совпадает (текущий: $current_mac)${NC}"
        echo -e "  Возможно, вы используете приватный MAC iOS"
        return 1
    fi
}

# Функция для получения имени устройства по MAC
get_device_name() {
    local mac="$1"
    local name=$(grep -i "$mac" "$KNOWN_DEVICES" 2>/dev/null | cut -d'|' -f2)
    if [ -n "$name" ]; then
        echo "$name"
    else
        echo "Неизвестное устройство"
    fi
}

# Расширенное сканирование сети
scan_network_detailed() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     ДЕТАЛЬНОЕ СКАНИРОВАНИЕ СЕТИ      ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}\n"
    
    local subnet=$(get_subnet)
    local gateway=$(get_gateway)
    local my_ip=$(get_local_ip)
    local scan_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "Ваш IP: ${GREEN}$my_ip${NC}"
    echo -e "Шлюз: ${GREEN}$gateway${NC}"
    echo -e "Подсеть: ${GREEN}$subnet.0/24${NC}\n"
    
    echo -e "${YELLOW}Сканирование активных устройств...${NC}\n"
    
    # Прогресс бар
    echo -n "["
    for i in {1..20}; do
        echo -n "▓"
        sleep 0.1
    done
    echo -e "] 100%\n"
    
    # Сканирование с помощью различных методов
    local temp_file="/tmp/scan_results_$$.txt"
    
    # Метод 1: ARP сканирование
    if command -v arp-scan &> /dev/null && [ "$EUID" -eq 0 ]; then
        sudo arp-scan --localnet 2>/dev/null | grep -E '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' > "$temp_file"
    else
        # Метод 2: Ping + ARP
        for i in {1..254}; do
            ping -c 1 -W 1 $subnet.$i > /dev/null 2>&1 &
            if [ $((i % 20)) -eq 0 ]; then
                wait
            fi
        done
        wait
        arp -a | grep -v incomplete > "$temp_file"
    fi
    
    # Парсинг и вывод результатов
    printf "${BLUE}%-20s %-20s %-30s %-15s${NC}\n" "IP Адрес" "MAC Адрес" "Устройство" "Статус"
    echo "─────────────────────────────────────────────────────────────────"
    
    local devices_found=0
    local blocked_count=0
    
    while read -r line; do
        local ip=$(echo "$line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
        local mac=$(echo "$line" | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | tr '[:upper:]' '[:lower:]')
        
        if [ -n "$ip" ] && [ -n "$mac" ]; then
            local name=$(get_device_name "$mac")
            local status="${GREEN}Активно${NC}"
            
            # Проверка заблокирован ли
            if grep -qi "$mac" "$BLOCKED_DEVICES" 2>/dev/null; then
                status="${RED}ЗАБЛОКИРОВАНО${NC}"
                ((blocked_count++))
            fi
            
            # Проверка является ли это нашим устройством
            if [ "$ip" = "$my_ip" ]; then
                name="$name (Это вы)"
            fi
            
            printf "%-20s %-20s %-30s %b\n" "$ip" "$mac" "$name" "$status"
            ((devices_found++))
            
            # Сохраняем в историю
            echo "$scan_time|$ip|$mac|$name" >> "$SCAN_HISTORY"
        fi
    done < "$temp_file"
    
    rm -f "$temp_file"
    
    echo -e "\n${GREEN}Найдено устройств: $devices_found${NC}"
    echo -e "${RED}Заблокировано: $blocked_count${NC}"
    
    log_event "Сканирование сети: найдено $devices_found устройств"
    
    # Сохраняем результаты для быстрого доступа
    cp "$temp_file" "$CONFIG_DIR/last_scan.txt" 2>/dev/null
}

# Функция блокировки устройства
block_device() {
    clear
    echo -e "${RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}║        БЛОКИРОВКА УСТРОЙСТВА         ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════╝${NC}\n"
    
    if ! check_root; then
        read -p "Нажмите Enter..."
        return 1
    fi
    
    echo "Выберите способ блокировки:"
    echo "1. По IP адресу"
    echo "2. По MAC адресу"
    echo "3. Выбрать из последнего сканирования"
    read -p "Выбор: " block_choice
    
    local target=""
    local method=""
    
    case $block_choice in
        1)
            read -p "Введите IP адрес для блокировки: " target
            method="ip"
            ;;
        2)
            read -p "Введите MAC адрес для блокировки: " target
            method="mac"
            ;;
        3)
            if [ -f "$CONFIG_DIR/last_scan.txt" ]; then
                echo -e "\n${YELLOW}Последние найденные устройства:${NC}"
                cat "$CONFIG_DIR/last_scan.txt" | head -10 | nl
                read -p "Выберите номер устройства: " num
                target=$(sed -n "${num}p" "$CONFIG_DIR/last_scan.txt" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
                method="ip"
            else
                echo -e "${RED}Нет данных последнего сканирования${NC}"
                read -p "Нажмите Enter..."
                return
            fi
            ;;
        *)
            echo -e "${RED}Неверный выбор${NC}"
            read -p "Нажмите Enter..."
            return
            ;;
    esac
    
    if [ -n "$target" ]; then
        echo -e "\n${YELLOW}Выберите метод блокировки:${NC}"
        echo "1. ARP spoofing (отключение интернета)"
        echo "2. Блокировка по IP (iptables)"
        echo "3. Блокировка портов"
        read -p "Выбор: " method_type
        
        case $method_type in
            1)
                # ARP блокировка
                gateway=$(get_gateway)
                echo "1" > /proc/sys/net/ipv4/ip_forward 2>/dev/null
                arpspoof -i $(ip route | grep default | awk '{print $5}') -t "$target" "$gateway" > /dev/null 2>&1 &
                arpspoof -i $(ip route | grep default | awk '{print $5}') -t "$gateway" "$target" > /dev/null 2>&1 &
                echo "$target|$(date +%s)|arp" >> "$BLOCKED_DEVICES"
                echo -e "${GREEN}✓ ARP spoofing запущен для $target${NC}"
                log_event "Запущен ARP spoofing для $target"
                ;;
            2)
                # IPTables блокировка
                iptables -A FORWARD -s "$target" -j DROP
                iptables -A FORWARD -d "$target" -j DROP
                iptables -A INPUT -s "$target" -j DROP
                iptables -A OUTPUT -d "$target" -j DROP
                echo "$target|$(date +%s)|iptables" >> "$BLOCKED_DEVICES"
                echo -e "${GREEN}✓ IPtables блокировка для $target${NC}"
                log_event "IPTables блокировка для $target"
                ;;
            3)
                # Блокировка портов
                read -p "Введите порт для блокировки: " port
                iptables -A FORWARD -s "$target" -p tcp --dport "$port" -j DROP
                iptables -A FORWARD -s "$target" -p udp --dport "$port" -j DROP
                echo "$target|$(date +%s)|port|$port" >> "$BLOCKED_DEVICES"
                echo -e "${GREEN}✓ Порт $port заблокирован для $target${NC}"
                log_event "Блокировка порта $port для $target"
                ;;
        esac
    fi
    
    read -p "Нажмите Enter..."
}

# Функция разблокировки
unblock_device() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        РАЗБЛОКИРОВКА УСТРОЙСТВА      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"
    
    if ! check_root; then
        read -p "Нажмите Enter..."
        return 1
    fi
    
    if [ ! -s "$BLOCKED_DEVICES" ]; then
        echo -e "${YELLOW}Нет заблокированных устройств${NC}"
        read -p "Нажмите Enter..."
        return
    fi
    
    echo -e "${YELLOW}Заблокированные устройства:${NC}\n"
    cat -n "$BLOCKED_DEVICES" | while read -r line; do
        echo "$line"
    done
    
    read -p "Введите номер для разблокировки: " num
    local target=$(sed -n "${num}p" "$BLOCKED_DEVICES" | cut -d'|' -f1)
    local method=$(sed -n "${num}p" "$BLOCKED_DEVICES" | cut -d'|' -f3)
    
    case $method in
        "arp")
            pkill arpspoof
            echo -e "${GREEN}✓ ARP spoofing остановлен${NC}"
            ;;
        "iptables"|"port")
            iptables -F
            iptables -X
            iptables -t nat -F
            iptables -t nat -X
            iptables -t mangle -F
            iptables -t mangle -X
            echo -e "${GREEN}✓ Все правила iptables сброшены${NC}"
            ;;
    esac
    
    sed -i "${num}d" "$BLOCKED_DEVICES"
    log_event "Разблокировано устройство $target"
    read -p "Нажмите Enter..."
}

# Мониторинг трафика
monitor_traffic() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║        МОНИТОРИНГ ТРАФИКА            ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════╝${NC}\n"
    
    if ! check_root; then
        read -p "Нажмите Enter..."
        return 1
    fi
    
    echo "Нажмите Ctrl+C для остановки мониторинга"
    echo "----------------------------------------"
    sleep 2
    
    # Мониторинг трафика в реальном времени
    tcpdump -i any -n -v -c 50 2>/dev/null | while read -r line; do
        echo "$line"
        echo "$(date): $line" >> "$CONFIG_DIR/traffic.log"
    done
}

# Показать статистику
show_statistics() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           СТАТИСТИКА СЕТИ            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}\n"
    
    echo -e "${YELLOW}Общая информация:${NC}"
    echo "  Всего сканирований: $(wc -l < "$SCAN_HISTORY" 2>/dev/null || echo 0)"
    echo "  Известных устройств: $(wc -l < "$KNOWN_DEVICES" 2>/dev/null || echo 0)"
    echo "  Сейчас заблокировано: $(wc -l < "$BLOCKED_DEVICES" 2>/dev/null || echo 0)"
    
    echo -e "\n${YELLOW}Последние 10 событий:${NC}"
    tail -10 "$LOG_FILE" 2>/dev/null || echo "  Нет событий"
    
    echo -e "\n${YELLOW}Частота появления устройств:${NC}"
    cut -d'|' -f4 "$SCAN_HISTORY" 2>/dev/null | sort | uniq -c | sort -rn | head -5
}

# Экспорт данных
export_data() {
    clear
    echo -e "${YELLOW}Экспорт данных...${NC}"
    
    tar -czf "network_export_$(date +%Y%m%d).tar.gz" "$CONFIG_DIR" 2>/dev/null
    echo -e "${GREEN}✓ Данные экспортированы в network_export_$(date +%Y%m%d).tar.gz${NC}"
    
    read -p "Нажмите Enter..."
}

# Главное меню
while true; do
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║    ПОЛНЫЙ МЕНЕДЖЕР ЛОКАЛЬНОЙ СЕТИ    ║${NC}"
    echo -e "${CYAN}║           Версия 3.0                  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo -e "${GREEN}Управление ВАШЕЙ домашней сетью${NC}\n"
    
    check_my_mac
    echo -e "Локальный IP: $(get_local_ip)"
    
    echo -e "\n${YELLOW}ОСНОВНЫЕ ФУНКЦИИ:${NC}"
    echo "1.  Детальное сканирование сети"
    echo "2.  Мониторинг активных устройств"
    echo "3.  Блокировать устройство"
    echo "4.  Разблокировать устройство"
    echo "5.  Мониторинг трафика"
    echo "6.  Управление известными устройствами"
    echo "7.  Статистика и логи"
    echo "8.  Тест скорости"
    echo "9.  Экспорт данных"
    echo "0.  Выход"
    echo ""
    read -p "Выберите действие: " choice
    
    case $choice in
        1) scan_network_detailed; read -p "Нажмите Enter..." ;;
        2) 
            while true; do
                clear
                scan_network_detailed
                echo -e "\n${YELLOW}Обновление каждые 5 секунд. Нажмите Ctrl+C для выхода${NC}"
                sleep 5
            done
            ;;
        3) block_device ;;
        4) unblock_device ;;
        5) monitor_traffic ;;
        6) 
            clear
            echo "1. Показать все устройства"
            echo "2. Добавить устройство"
            echo "3. Удалить устройство"
            read -p "Выбор: " dev_choice
            case $dev_choice in
                1) cat "$KNOWN_DEVICES" ;;
                2) 
                    read -p "MAC: " mac
                    read -p "Имя: " name
                    echo "$mac|$name" >> "$KNOWN_DEVICES"
                    log_event "Добавлено устройство $name ($mac)"
                    ;;
                3)
                    cat -n "$KNOWN_DEVICES"
                    read -p "Номер для удаления: " num
                    sed -i "${num}d" "$KNOWN_DEVICES"
                    ;;
            esac
            read -p "Нажмите Enter..."
            ;;
        7) show_statistics; read -p "Нажмите Enter..." ;;
        8)
            clear
            echo "Тест скорости к роутеру:"
            ping -c 10 $(get_gateway) | tail -2
            read -p "Нажмите Enter..."
            ;;
        9) export_data ;;
        0) 
            echo -e "\n${GREEN}До свидания!${NC}"
            log_event "Завершение работы"
            exit 0 
            ;;
        *) 
            echo -e "${RED}Неверный выбор${NC}"
            sleep 1 
            ;;
    esac
done
