#!/bin/bash

STATE_FILE="${STATE_FILE:-/var/tmp/process_state.txt}"
WHITELIST_FILE="${WHITELIST_FILE:-/etc/process_whitelist.conf}"
ZABBIX_SENDER="${ZABBIX_SENDER:-/usr/bin/zabbix_sender}"
ZABBIX_SERVER="${ZABBIX_SERVER:-127.0.0.1}"
ZABBIX_HOST="${ZABBIX_HOST:-MyServerHostname}"
ZABBIX_KEY="${ZABBIX_KEY:-process.watchdog.new.alert}"

touch "$STATE_FILE"
touch "$WHITELIST_FILE"

get_current_procs() {
    ps -eo comm --no-headers 2>/dev/null | \
        sed 's/^[ \t]*//' | \
        grep -v '^$' | \
        grep -v -E '^(kworker|rcu_|migration|ksoftirqd|cpuhp|idle_inject|jbd2|irq/|kcompactd|khugepaged|khungtaskd|kdevtmpfs|kauditd|ksmd|kswapd|kthreadd|ecryptfs)' | \
        sort -u
}

WHITELIST=$(grep -v '^#' "$WHITELIST_FILE" | grep -v '^$' | sort -u)

if [ -n "$WHITELIST" ]; then
    CURRENT_PROCS=$(get_current_procs | grep -v -F -x -f <(echo "$WHITELIST"))
else
    CURRENT_PROCS=$(get_current_procs)
fi

if [ ! -s "$STATE_FILE" ]; then
    echo "$CURRENT_PROCS" > "$STATE_FILE"
    exit 0
fi
PREV_PROCS=$(cat "$STATE_FILE")
NEW_PROCS=$(comm -13 <(echo "$PREV_PROCS" | sort) <(echo "$CURRENT_PROCS" | sort))

if [ -n "$NEW_PROCS" ]; then
    PROC_LIST=$(echo "$NEW_PROCS" | tr '\n' ',' | sed 's/,$//')
    ALERT_MSG="Обнаружены новые процессы: ${PROC_LIST}"
    $ZABBIX_SENDER -z "$ZABBIX_SERVER" -s "$ZABBIX_HOST" -k "$ZABBIX_KEY" -o "$ALERT_MSG" -v
    echo "$CURRENT_PROCS" > "$STATE_FILE"
    logger -t process_watchdog "$ALERT_MSG"
fi
