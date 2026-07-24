#!/bin/bash
PIDFILE=/tmp/per-window-lang.pid

if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE")
    kill "$OLD_PID" 2>/dev/null
    sleep 0.3
fi

echo $$ > "$PIDFILE"
exec python3 "$(dirname "$0")/per-window-lang.py"
