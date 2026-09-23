#!/bin/bash

STATE_FILE="${STATE_FILE:-/var/tmp/process_state.txt}"
WHITELIST_FILE="${WHITELIST_FILE:-/etc/process_whitelist.conf}"
ZABBIX_SENDER="${ZABBIX_SENDER:-/usr/bin/zabbix_sender}"
ZABBIX_SERVER="${ZABBIX_SERVER}"
ZABBIX_HOST="${ZABBIX_HOST}"
ZABBIX_KEY="${ZABBIX_KEY}"

touch "$STATE_FILE"
touch "$WHITELIST_FILE"

get_current_procs() {
    ps -eo args --no-headers 2>/dev/null | \
        awk '{print $1}' | \
        sed 's/.*\///' | \
        grep -v '^$' | \
        sort -u
}

WHITELIST=$(grep -v '^#' "$WHITELIST_FILE" | grep -v '^$' | sort -u)

if [ -n "$WHITELIST" ]; then
    CURRENT_PROCS=$(get_current_procs | grep -v -F -x -f <(echo "$WHITELIST"))
else
    CURRENT_PROCS=$(get_current_procs)
fi

if [ -s "$STATE_FILE" ]; then
    PREV_PROCS=$(cat "$STATE_FILE")
else
    PREV_PROCS=""
fi

NEW_PROCS=$(comm -13 <(echo "$PREV_PROCS" | sort) <(echo "$CURRENT_PROCS" | sort))

if [ -n "$NEW_PROCS" ]; then
    PROC_LIST=$(echo "$NEW_PROCS" | tr '\n' ',' | sed 's/,$//')
    ALERT_MSG="Обнаружены новые процессы: ${PROC_LIST}"
    $ZABBIX_SENDER -z "$ZABBIX_SERVER" -s "$ZABBIX_HOST" -k "$ZABBIX_KEY" -o "$ALERT_MSG" -v
    echo "$CURRENT_PROCS" > "$STATE_FILE"
    logger -t process_watchdog "$ALERT_MSG"
fi
