# Wazuh-OpnSense-VirtualLab

Выполнил студент гр.932024 ИПМКН ТГУ Махрин Глеб

## Обзор виртуальных машин и УЗ

В составе виртуальной лаборатории 4 виртуальные машины: межсетевой экран, SIEM&XDR сервер, клиент, атакующий.

![Сетева топология стенда](https://github.com/MakhrinBelggg/Wazuh-OpnSense-VirtualLab/blob/main/NetScheme.png)

### OpnSense_FW

#### Учетные записи

- root:1qa2qa3qa
- Подключиться по SSH с хоста: 127.0.0.1:2220

### Wazuh_Server

#### Учетные записи

- wazuh-server-operator:wazuh
- Подключиться по SSH с хоста: 127.0.0.1:2221

### Ubuntu_Client

#### Учетные записи

- worker:1qaz2wsx3edc
  -alex_adm:qwerty123
- alex:zxcvbnm
- root:010324
- Подключиться по SSH с хоста: 127.0.0.1:2222

### Kali_Attacker

#### Учетные записи

- kali:kali
- Подключиться по SSH с хоста: 127.0.0.1:2223

Для подключению к машинам по SSH выполнен проброс портов в Сети NAT и маршрутизаторе OpnSense. Рекомендую использовать клиенты SSH по типу MobaXterm.

Графический интерфейс Ubuntu_Client и Kali_Attacker выключен командой `sudo systemctl set-default multi-user.target`. Для включения GUI, введите в консоли: `sudo systemctl set-default graphical.target`.

## Системные требования
- 6-core CPU
- 16 GB RAM
- 140 GB HDD free space

## Troubleshooting

### Если нет интернета на машинах Wazuh_Server или Ubuntu_Client

- Убедитесь, что включена виртуальная машина с OpnSense и маршрутизатор работает исправно
- Виртуальные машины OpnSense_FW и Kali_Attacker подключены адаптером NAT_Network, поэтому для них интернет соединение идёт через хостовой компьютер
- Убедитесь, что он имеет интернет подключение

### Если не включается Wazuh

Требуется проверка и перезагрузка компонентов Wazuh

```bash
sudo systemctl status wazuh-manager
sudo systemctl restart wazuh-manager
sudo systemctl status wazuh-dashboard
sudo systemctl restart wazuh-dashboard
sudo systemctl status wazuh-indexer
sudo systemctl restart wazuh-indexer
```

### Если агент OpnSense в статусе Disconnected или Pending

- Выполнить авторизацию на ВМ OpnSense
- Из вкладки Dashboard OpnSense перезагрузить сервис Wazuh Agent (или из консоли `service wazuh-agent status` и `service wazuh-agent restart`)

### Если агент UbuntuClient в статусе Disconnected

- Убедиться, что виртуальная машина запущена

```bash
sudo systemctl status wazuh-agent
sudo systemctl restart wazuh-agent
```

- сли перезагрузка службы не помогла, убедитесь в правильности конфигурации агента

```bash
sudo nano /var/ossec/etc/ossec.conf
```

- Внутри блока <client><server> должен быть указан IP-адрес узла WazuhServer: <address>192.168.1.100</address>
- Проверить можно командой ip a или ifconfig с машины WazuhServer.

## Добавление нового агента в Wazuh

- Зайдите в Wazuh —> перейдите в окно Agents Summary (нажав Active / Disconnected) —> Deploy new agent —> выберите необходимую конфигурацию и запустите получившуюся команду на устройстве, которое хотите подключить
- Server address должен соответствовать IP-адресу машины WazuhServer
- После установки, если агент не подключается, смотри "Если агент UbuntuClient в статусе Disconnected"

## Добавление новых правил и декодеров в Wazuh

- Перед началом формирования собственных правил убедитесь, что источник событий собирает необходимые вам логи и доставляет их на сервер Wazuh
- Логи на сереве Wazuh находятся в файле `/var/ossec/logs/archives/archives.json`, при выключенной настройке менеджера в `ossec.conf` <logall_json>yes</logall_json>
- После этого, соберите сырые логи и начинайте работу по конфигурации декодера и правил
- Кастомные декодеры находятся по пути `/var/ossec/etc/decoders/` в формате xml
- Кастомные правила находятся по пути `/var/ossec/etc/rules/` в формате xml
- Чтение стандартных правил и декодеров можно исключить, если они конфликтуют с вашими кастомными правилами. Сделать это можно в файле конфигурации `/var/ossec/etc/ossec.conf` на Wazuh_Server
- Проверка синтаксиса выполняется командой

```bash
sudo /var/ossec/bin/wazuh-analysisd -t
```

- Проверка декодеров и правил на сырых логах

```bash
sudo /var/ossec/bin/wazuh-logtest
```

- Phase 2 укажет, какой декодер смог распознать заданный лог, Phase 3 — какое правило сработало. Сообщение Alert will be generated означает появление алерта в дашборде (параметр rule должно быть >= 3).
- После изменений необходимо перезапустить manager

```bash
sudo systemctl restart wazuh-manager
```

- После чего можно воспроизвести целевую активность и проверять в дашборде появившиеся события. Если что-то в алерте не соответствует ожиданиям, можно взять из события full_log и отдельно разобрать его в wazuh-logtest
