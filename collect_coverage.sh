#!/bin/bash

mkdir -p coverage_map

i=0
for f in coverage_inputs/*; do
    echo "[*] Обрабатываю файл: $f"
    afl-showmap -o coverage_map/map_$i.txt -- ./vlc/test/vlc-demux-run "$f"
    ((i++))
done

echo "[+] Покрытие собрано. Всего файлов: $i"
