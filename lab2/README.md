# Распределенные системы хранения данных

## Лабораторная работа №2

### Этап 1. Инициализация кластера БД

- Директория кластера: $HOME/ckl25
- Кодировка: ISO_8859_5
- Локаль: русская
- Параметры инициализации задать через переменные окружения

`~/.profile`
```
export PGHOST=pg106
export PGUSERNAME=postgres1
export PGDATA=$HOME/ckl25
export PGENCODING=ISO8859-5
export PGLOCALE=ru_RU.ISO8859-5
export PGCLIENTENCODING=$PGENCODING
export PGHOST=/tmp
export PGUSER=postgres1
export PGDATABASE=postgres
export PGPORT=9853
export PATH="$HOME/scripts:$PATH"
```

### Этап 2. Конфигурация и запуск сервера БД

- Способы подключения:
    1. Unix-domain сокет в режиме peer;
    2. сокет TCP/IP, только localhost
- Номер порта: 9853
- Способ аутентификации TCP/IP клиентов: по имени пользователя
- Остальные способы подключений запретить.

`$PGDATA/postgresql.conf`
```
listen_addresses='localhost'
port = 9853
```
`$PGDATA/pg_hba.conf.conf`
```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     peer
# IPv4 local connections:
host    all             all             127.0.0.1/32            password
# IPv6 local connections:
host    all             all             ::1/128                 password
```

- Настроить следующие параметры сервера БД:
    - max_connections
    - shared_buffers
    - temp_buffers
    - work_mem
    - checkpoint_timeout
    - effective_cache_size
    - fsync
    - commit_delay
    
    Параметры должны быть подобраны в соответствии со сценарием OLTP:
    - 200 одновременных пользователей
    - 2 сессий на каждого
    - каждая сессия инициирует до 7 транзакций на запись размером 24КБ
    - обеспечить максимальную производительность

OLTP (Online Transaction Processing) — это обработка транзакций в реальном времени. Это тип рабочей нагрузки баз данных, при котором система должна быстро и эффективно обрабатывать много частых, небольших операций, чаще всего записей, обновлений и чтений.

`$PGDATA/postgresql.conf`
```
# Общее число подключений
max_connections = 500
# 400 активных сессий + запас для админа, фоновых процессов, очереди.

# Память, выделенная под буферы PostgreSQL
shared_buffers = 4GB
# 25% RAM

# Память, выделяемая на каждое подключение для временных таблиц 
temp_buffers = 64MB
# Достаточно для быстрой работы с временными объектами, но не приведёт к перегрузке памяти даже при 400 подключениях (64MB * 400 = ~25GB, но это максимум, не факт что будет использоваться весь объём)

# Объём памяти, выделяемый на операцию запроса для сортировок, хеш-таблиц, merge join'ов и т.п.
work_mem = 4MB 
# 4МВ - безопасный старт если много коротких и простых транзакций, обычно нет огромных сортировок/джойнов, нужно контролировать использование RAM

# Как часто делать контрольные точки
checkpoint_timeout = 15min
# Чем реже, тем меньше нагрузка на диск, но дольше recovery после сбоя

# Сколько памяти операционной системе доступно под кэш диска (ориентир для планировщика запросов)
effective_cache_size = 12GB 
# 75% RAM

# Запись на диск при каждом коммите 
fsync = off 
# Отключена ради производительности

# Задержка (в микросекундах) для группировки коммитов
commit_delay = 10000
# 10 мс — позволит сгруппировать до 5–10 транзакций при высокой нагрузке, снижая количество fsync'ов
```

- Директория WAL файлов: $PGDATA/pg_wal
- Формат лог-файлов: .csv
- Уровень сообщений лога: ERROR
- Дополнительно логировать: завершение сессий и продолжительность выполнения команд

`$PGDATA/postgresql.conf`
```
log_destination = 'csvlog'
logging_collector = on
log_min_messages = error
log_disconnections = on
log_duration = on
```

### Этап 3. Дополнительные табличные пространства и наполнение базы

- Создать новое табличное пространство для индексов: $HOME/zbn52
- На основе template1 создать новую базу: bigwhitedata
- Создать новую роль, предоставить необходимые права, разрешить подключение к базе.
- От имени новой роли (не администратора) произвести наполнение ВСЕХ созданных баз тестовыми наборами данных. ВСЕ табличные пространства должны использоваться по назначению.
- Вывести список всех табличных пространств кластера и содержащиеся в них объекты.

```PostgreSQL
CREATE DATABASE bigwhitedata TEMPLATE template1;
```

```PostgreSQL
\l
```

```PostgreSQL
CREATE ROLE new_user LOGIN PASSWORD 'qwerty12345';
GRANT CONNECT ON DATABASE bigwhitedata TO new_user;
GRANT USAGE ON SCHEMA public TO new_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO new_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO new_user;
GRANT CREATE ON SCHEMA public TO new_user;
GRANT CREATE ON TABLESPACE idx_space TO new_user;
```

```PostgreSQL
CREATE TABLESPACE idxspс LOCATION '$HOME/zbn52';
```

```PostgreSQL
CREATE TABLE test_data (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT now()
) TABLESPACE pg_default;

CREATE INDEX test_data_idx ON test_data (created_at) TABLESPACE idxspc;

INSERT INTO test_data (name) VALUES 
('Alice'), ('Bob'), ('Charlie'), ('David'), ('Eve');
```

```PostgreSQL
SELECT spcname AS tablespace_name, pg_catalog.pg_get_userbyid(spcowner) AS owner 
FROM pg_tablespace;
```

```PostgreSQL
SELECT n.nspname AS schema_name, c.relname AS object_name, c.relkind, t.spcname AS tablespace_name
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_tablespace t ON t.oid = c.reltablespace
WHERE t.spcname IS NOT NULL
ORDER BY tablespace_name, schema_name, object_name;
```
