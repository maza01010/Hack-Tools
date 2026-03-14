#!/bin/bash

echo "Быстрое сканирование сети..."
echo "=========================="

# Получаем подсеть
IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
SUBNET=$(echo $IP | cut -d'.' -f1-3)

echo "Сканирование подсети: $SUBNET.0/24"
echo ""

# Ping сканирование
for i in {1..254}; do
    ping -c 1 -W 1 $SUBNET.$i > /dev/null 2>&1 &
done

wait

# Показываем ARP таблицу
arp -a | grep -v incomplete

echo ""
echo "Сканирование завершено"
