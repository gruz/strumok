#!/bin/sh
# Argos widget: shows which stream-window profile is streaming.
# stream-window writes the active profile to $XDG_RUNTIME_DIR/stream-window.state

RTD="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
STATE="$RTD/stream-window.state"
PROFILES="${STREAM_PROFILES:-$HOME/.config/stream-window/profiles.ini}"
EDIT="$HOME/.local/bin/stream-profiles-edit"

if [ -s "$STATE" ]; then
    echo "● STREAM: $(cat "$STATE") | color=#ff3333 font=monospace"
    echo "---"
    echo "Stop stream | bash='kill \$(cat $RTD/stream-window.pid)' terminal=false refresh=true"
else
    echo "stream: off | color=#888888 font=monospace"
    echo "---"
    if [ -f "$PROFILES" ]; then
        grep -oE '^\[[^]]+\]' "$PROFILES" | tr -d '[]' | grep -vxF 'DEFAULT' | while read -r p; do
            echo "Start: $p | bash='$HOME/.local/bin/stream-window \"$p\"' terminal=false refresh=true"
        done
    else
        echo "no profiles.ini | color=#888888"
    fi
fi
[ -x "$EDIT" ] && echo "Edit profiles… | bash='$EDIT' terminal=false"
