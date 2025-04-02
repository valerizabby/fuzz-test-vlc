# Процессы безопасной разработки ПО
### SberTech X MIPT

## 1. Суммирование файлов исходного кода
TODO

## 2. Фаззинг тестирование VLC Media Player

### Установка VLC Media Player

- ОС: Ubuntu 22.04 TLS

Клонируем репозиторий с VLC:
```bash
git clone https://github.com/videolan/vlc.git
cd vlc
```

___
### Сборка VLC
Я сознательно опускаю нудный процесс установки недостающих зависимостей, но если вкратце он выглядел как 
несколько итераций вида "попытка сборки -> ошибка -> ее устранение". Будем считать, что все необходимые зависимости установлены и приступим
к сборке.

Чтобы ускорить фаззинг и не тратить ресурсы на части VLC, которые мне не нужны, я решила использовать частичное инструментирование (файл Partial_instrumentation.txt).
Я посмотрела, какие .c файлы и функции отвечают за обработку формата ASF:

- asf.c 
- asfpacket.c 
- libasf.c

а также функции, которые связаны с чтением, разбором и очередями данных. Цель была в том, чтобы asap получить покрытие и last new find путь =)

Устанвливаем всякие флаги, чтобы собрать не просто clang-ом, а afl-ем:
```bash
export CC=afl-clang-fast
export CXX=afl-clang-fast++
export AFL_USE_ASAN=1
export AFL_LLVM_ALLOWLIST=$HOME/fuzzing_vlc/vlc/Partial_instrumentation.txt
```
Кофингурация:
```
./bootstrap
./configure \
  --disable-lua \
  --disable-qt \
  --enable-debug \
  --with-sanitizer=address \
  --prefix=$HOME/fuzzing_vlc/vlc/install
```

Сконфигурировались:

![configure](images/img.png)

Теперь сборка и инструмнтирование исходного кода:

```bash 
AFL_IGNORE_PROBLEMS=1 make -j$(nproc)
```

Настроим переменную окружения VLC

```bash
export LD_LIBRARY_PATH=~/fuzzing_vlc/vlc/lib:~/fuzzing_vlc/vlc/src/.libs:$LD_LIBRARY_PATH
```

### Фаззинг

#### Корпус:

Источник сэмплов https://sample-videos.com для

- 1 видео mp4 
- 1 аудио mp3

а так же пустые файлы. Обрезаем не пустые файлы командой:
```bash
ffmpeg -i input.mp4 -ss 00:00:00 -t 00:00:02 -c copy output.mp4
```

### Запуск фаззинга

При первом запуске фаззера вернулась ошибка

```
Hmm, your system is configured to send core dump notifications to an external utility.
```

Это значит, что система настроена на использование внешнего обработчика для core dump (например, apport в Ubuntu), 
и это мешает корректному взаимодействию AFL++ с крашами.

Выключим эту настройку для проведения фаззинга:
```bash
echo core | sudo tee /proc/sys/kernel/core_pattern
```
Выключим еще одну штуку по предложению AFL++
```bash
cd /sys/devices/system/cpu
echo performance | sudo tee cpu*/cpufreq/scaling_governor
```
Запускаем:
```bash 
afl-fuzz -i corpus -o findings_test -- ./vlc/test/vlc-demux-run @@ 
```
 
![img_1](images/img_1.png)


## 3. Сбор покрытия по результатам фаззинг-тестирования

Сохраняем результаты из findings, чтобы собрать по ним покрытие

```bash
mkdir ~/fuzzing_vlc/coverage_inputs
cp ~/fuzzing_vlc/findings/master/queue/id* ~/fuzzing_vlc/coverage_inputs/
```

Собираем покрытие скриптом `collect_coverage.sh`, результат:

![123](images/img_2.png)

Посчитаем общее покрытие:

```bash
cat coverage_map/map_*.txt | cut -d ' ' -f 1 | sort -n | uniq | wc -l
```

Это показывает общее количество уникальных «ребёр» покрытия (переключений между блоками кода). Соберем так же покрытие с помощью afl-cov