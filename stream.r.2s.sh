#!/bin/sh
# Argos widget: shows which stream-window profile is streaming.
# stream-window writes the active profile to $XDG_RUNTIME_DIR/stream-window.state
#
# UI language: STREAM_LANG env > ~/.config/stream-window/lang > uk
# The "Language" menu item toggles the file; refresh re-renders the menu.

RTD="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
STATE="$RTD/stream-window.state"
PROFILES="${STREAM_PROFILES:-$HOME/.config/stream-window/profiles.ini}"
EDIT="$HOME/.local/bin/stream-profiles-edit"
RST="$HOME/.local/bin/stream-reset"
LANG_FILE="$HOME/.config/stream-window/lang"
VER=$(sed -n 's/^VERSION="\(.*\)"/\1/p' "$HOME/.local/bin/stream-window" 2>/dev/null | head -1)

L="${STREAM_LANG:-$(cat "$LANG_FILE" 2>/dev/null)}"
[ "$L" = "en" ] || L="uk"

t() {
    case "$L:$1" in
        en:streaming) echo "● STREAM" ;;
        uk:streaming) echo "● СТРІМ" ;;
        en:stop)      echo "Stop stream" ;;
        uk:stop)      echo "Зупинити стрім" ;;
        en:off)       echo "stream: off" ;;
        uk:off)       echo "стрім: вимк" ;;
        en:start)     echo "Start" ;;
        uk:start)     echo "Запустити" ;;
        en:noprof)    echo "no profiles.ini" ;;
        uk:noprof)    echo "немає profiles.ini" ;;
        en:edit)      echo "Edit profiles…" ;;
        uk:edit)      echo "Редагувати профілі…" ;;
        en:update)    echo "Update version…" ;;
        uk:update)    echo "Оновити версію…" ;;
        en:resetmenu) echo "reset / uninstall" ;;
        uk:resetmenu) echo "скидання / видалення" ;;
        en:r_reset)   echo "Reset stream state…" ;;
        uk:r_reset)   echo "Скинути стан стріму…" ;;
        en:r_backup)  echo "Uninstall (backup profiles)…" ;;
        uk:r_backup)  echo "Видалити (бекап профілів)…" ;;
        en:r_keep)    echo "Uninstall (keep profiles)…" ;;
        uk:r_keep)    echo "Видалити (лишити профілі)…" ;;
        en:lang)      echo "Language: English" ;;
        uk:lang)      echo "Мова: Українська" ;;
    esac
}

if [ -s "$STATE" ]; then
    echo "$(t streaming): $(cat "$STATE") | color=#ff3333 font=monospace"
    echo "---"
    echo "$(t stop) | bash='kill \$(cat $RTD/stream-window.pid)' terminal=false refresh=true"
else
    echo "$(t off) | color=#888888 font=monospace"
    echo "---"
    if [ -f "$PROFILES" ]; then
        grep -oE '^\[[^]]+\]' "$PROFILES" | tr -d '[]' | grep -vxF 'DEFAULT' | while read -r p; do
            echo "$(t start): $p | bash='$HOME/.local/bin/stream-window \"$p\"' terminal=false refresh=true"
        done
    else
        echo "$(t noprof) | color=#888888"
    fi
fi
[ -x "$EDIT" ] && echo "$(t edit) | bash='$EDIT' terminal=false"
# the same one-liner as in README "Install": fetch latest stream-window,
# chmod, run it once — self-install then updates all helper files
echo "$(t update) | bash='curl -L --create-dirs -o $HOME/.local/bin/stream-window \"https://raw.githubusercontent.com/gruz/strumok/master/stream-window?v=\$(date +%s)\" && chmod +x $HOME/.local/bin/stream-window && $HOME/.local/bin/stream-window --list' terminal=true refresh=true"
if [ -x "$RST" ]; then
    echo "$(t resetmenu) | font=monospace size=10 color=#888888"
    # each opens a terminal and waits for a typed 'yes' confirmation
    echo "--$(t r_reset) | bash='$RST --reset' terminal=true refresh=true"
    echo "--$(t r_backup) | bash='$RST --all' terminal=true refresh=true"
    echo "--$(t r_keep) | bash='$RST --all --keep-profiles' terminal=true refresh=true"
fi
CFG_DIR=$(dirname "$LANG_FILE")
if [ "$L" = uk ]; then
    echo "$(t lang) → English | bash='mkdir -p \"$CFG_DIR\" && echo en > \"$LANG_FILE\"' terminal=false refresh=true"
else
    echo "$(t lang) → Українська | bash='mkdir -p \"$CFG_DIR\" && echo uk > \"$LANG_FILE\"' terminal=false refresh=true"
fi
[ -n "$VER" ] && echo "stream-window v$VER | font=monospace size=10 color=#888888 href=https://github.com/gruz/strumok"
exit 0
