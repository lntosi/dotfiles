#!/usr/bin/env bash
# Claude Code statusline.
# Reads session JSON from stdin, prints one line.
# Fields: cwd | git branch | model | context bar + % | 5h used% + pace → reset | 7d used% → day+hours | service status | session duration.
#
# Toggle: export CLAUDE_STATUSLINE_OFF=1 to disable (silent exit, no line rendered).
#         unset CLAUDE_STATUSLINE_OFF (or set to 0) to re-enable.

set -eu

[ "${CLAUDE_STATUSLINE_OFF:-0}" = "1" ] && exit 0

INPUT="$(cat)"
[ -n "$INPUT" ] || INPUT='null'

# --- Extract via jq (all fields have fallbacks) ---
# Each extraction is also guarded with `|| fallback` and numeric fields pass
# through `tonumber? // … | floor`, so a malformed or wrong-typed payload
# degrades to defaults instead of aborting under set -e and blanking the line.
MODEL=$(printf '%s' "$INPUT"  | jq -r '.model.display_name    // "?" | gsub("[\n\r]";" ")' 2>/dev/null || echo "?")
CWD=$(printf '%s' "$INPUT"    | jq -r '.workspace.current_dir // "." | gsub("[\n\r]";" ")' 2>/dev/null || echo ".")
CTX_PCT=$(printf '%s' "$INPUT"| jq -r '.context_window.used_percentage // 0 | tonumber? // 0 | floor' 2>/dev/null || echo 0)
DUR_MS=$(printf '%s' "$INPUT" | jq -r '.cost.total_duration_ms          // 0 | tonumber? // 0 | floor' 2>/dev/null || echo 0)
FIVEH_RESET=$(printf '%s' "$INPUT"  | jq -r '.rate_limits.five_hour.resets_at        // empty | tonumber? // empty | floor' 2>/dev/null || true)
FIVEH_PCT=$(printf '%s' "$INPUT"    | jq -r '.rate_limits.five_hour.used_percentage  // empty | tonumber? // empty | floor' 2>/dev/null || true)
SEVEND_PCT=$(printf '%s' "$INPUT"   | jq -r '.rate_limits.seven_day.used_percentage  // empty | tonumber? // empty | floor' 2>/dev/null || true)
SEVEND_RESET=$(printf '%s' "$INPUT" | jq -r '.rate_limits.seven_day.resets_at        // empty | tonumber? // empty | floor' 2>/dev/null || true)

# --- CWD: collapse $HOME to ~ ---
CWD_SHORT="$CWD"
[ -n "${HOME:-}" ] && CWD_SHORT="${CWD/#$HOME/~}"

# --- Context progress bar (10 cells, filled proportional to %) ---
FILLED=$(( CTX_PCT / 10 ))
[ "$FILLED" -gt 10 ] && FILLED=10
EMPTY=$(( 10 - FILLED ))
BAR=""
for ((i=0; i<FILLED; i++)); do BAR+="▓"; done
for ((i=0; i<EMPTY;  i++)); do BAR+="░"; done

# --- Session duration (ms → human) ---
DUR_S=$(( DUR_MS / 1000 ))
DUR_H=$(( DUR_S / 3600 ))
DUR_M=$(( (DUR_S % 3600) / 60 ))
if [ "$DUR_H" -gt 0 ]; then
    DURATION="${DUR_H}h${DUR_M}m"
else
    DURATION="${DUR_M}m"
fi

# --- Colors (ANSI, optional — comment out these 5 lines to go monochrome) ---
DIM=$'\033[2m'; RESET=$'\033[0m'
CYAN=$'\033[36m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; MAGENTA=$'\033[35m'
if   [ "$CTX_PCT" -lt 50 ]; then CTX_COLOR="$GREEN"
elif [ "$CTX_PCT" -lt 80 ]; then CTX_COLOR="$YELLOW"
else                             CTX_COLOR="$RED"; fi
SEP="${DIM}│${RESET}"

# --- Git branch (purely local: no network, no blocking) ---
# Soft dependency on git — outside a repo, or without git, the whole segment
# (including its separator) is omitted instead of rendering an empty slot.
# Detached HEAD falls back to the short commit SHA.
BRANCH_TEXT=""
if command -v git >/dev/null 2>&1; then
    BRANCH=$(git -C "$CWD" symbolic-ref --quiet --short HEAD 2>/dev/null \
          || git -C "$CWD" rev-parse --short HEAD 2>/dev/null \
          || true)
    BRANCH=${BRANCH//[$'\n\r']/ }
    [ -n "$BRANCH" ] && BRANCH_TEXT=" $SEP ${MAGENTA}⎇ ${BRANCH}${RESET}"
fi

# --- 5h quota: used% + pace → time until reset ---
# Pace = used% minus elapsed% of the 5h window. Positive means consumption is
# running ahead of the sustainable rate — the early warning during multi-agent
# runs, since the account-level used% already includes parallel subagents.
NOW=$(date +%s)
FIVEH_TIME=""
FIVEH_PACE=""
if [ -n "$FIVEH_RESET" ]; then
    REMAIN_S=$(( FIVEH_RESET - NOW ))
    if [ "$REMAIN_S" -gt 0 ]; then
        REMAIN_H=$(( REMAIN_S / 3600 ))
        REMAIN_M=$(( (REMAIN_S % 3600) / 60 ))
        FIVEH_TIME="${REMAIN_H}h${REMAIN_M}m"
        if [ -n "$FIVEH_PCT" ] && [ "$REMAIN_S" -le 18000 ]; then
            ELAPSED_PCT=$(( (18000 - REMAIN_S) * 100 / 18000 ))
            PACE=$(( FIVEH_PCT - ELAPSED_PCT ))
            if   [ "$PACE" -ge 15 ]; then FIVEH_PACE="${RED}↑${PACE}${RESET}"
            elif [ "$PACE" -ge 5 ];  then FIVEH_PACE="${YELLOW}↑${PACE}${RESET}"
            elif [ "$PACE" -le -5 ]; then FIVEH_PACE="${DIM}↓$(( -PACE ))${RESET}"
            fi
        fi
    else
        FIVEH_TIME="reset"
    fi
fi
FIVEH_USED=""
if [ -n "$FIVEH_PCT" ]; then
    if [ "$FIVEH_PCT" -ge 100 ]; then
        FIVEH_USED="${RED}MAX${RESET}"
    else
        FIVEH_USED="${FIVEH_PCT}%"
        [ -n "$FIVEH_PACE" ] && FIVEH_USED="$FIVEH_USED $FIVEH_PACE"
    fi
fi

if   [ -n "$FIVEH_USED" ] && [ -n "$FIVEH_TIME" ]; then FIVEH_TEXT="$FIVEH_USED → $FIVEH_TIME"
elif [ -n "$FIVEH_USED" ];                         then FIVEH_TEXT="$FIVEH_USED"
elif [ -n "$FIVEH_TIME" ];                         then FIVEH_TEXT="$FIVEH_TIME"
else                                                    FIVEH_TEXT="—"
fi

# --- 7d quota: used% → day of week + hours until reset ---
SEVEND_TIME=""
if [ -n "$SEVEND_RESET" ]; then
    REMAIN_S=$(( SEVEND_RESET - NOW ))
    if [ "$REMAIN_S" -gt 0 ]; then
        RESET_DAY=$(date -r "$SEVEND_RESET" +%a 2>/dev/null || date -d "@$SEVEND_RESET" +%a)
        RESET_HOUR=$(date -r "$SEVEND_RESET" +%H:%M 2>/dev/null || date -d "@$SEVEND_RESET" +%H:%M)
        SEVEND_TIME="${RESET_DAY} ${RESET_HOUR}"
    else
        SEVEND_TIME="reset"
    fi
fi
SEVEND_USED=""
if [ -n "$SEVEND_PCT" ]; then
    if [ "$SEVEND_PCT" -ge 100 ]; then
        SEVEND_USED="${RED}MAX${RESET}"
    else
        SEVEND_USED="${SEVEND_PCT}%"
    fi
fi

if   [ -n "$SEVEND_USED" ] && [ -n "$SEVEND_TIME" ]; then SEVEND_TEXT="$SEVEND_USED → $SEVEND_TIME"
elif [ -n "$SEVEND_USED" ];                          then SEVEND_TEXT="$SEVEND_USED"
elif [ -n "$SEVEND_TIME" ];                          then SEVEND_TEXT="$SEVEND_TIME"
else                                                      SEVEND_TEXT="—"
fi

# --- Claude service status (status.claude.com) — cached, refreshed in background ---
# Never blocks: a stale cache is rendered while a detached curl revalidates it.
# Soft dependency on curl — without it, the segment falls back to a neutral dot.
STATUS_CACHE="${HOME}/.claude/.statusline-status"
STATUS_TTL=300
STATUS_INDICATOR="none"
if command -v curl >/dev/null 2>&1; then
    CACHE_AGE=$STATUS_TTL
    if [ -f "$STATUS_CACHE" ]; then
        CACHE_MTIME=$(stat -c %Y "$STATUS_CACHE" 2>/dev/null || stat -f %m "$STATUS_CACHE" 2>/dev/null || echo 0)
        CACHE_AGE=$(( NOW - CACHE_MTIME ))
    fi
    if [ "$CACHE_AGE" -ge "$STATUS_TTL" ]; then
        ( curl -fsS --max-time 4 https://status.claude.com/api/v2/status.json 2>/dev/null \
            | jq -r '.status.indicator // "none"' > "${STATUS_CACHE}.tmp" 2>/dev/null \
            && mv "${STATUS_CACHE}.tmp" "$STATUS_CACHE" ) >/dev/null 2>&1 &
    fi
    [ -f "$STATUS_CACHE" ] && STATUS_INDICATOR=$(cat "$STATUS_CACHE" 2>/dev/null || echo none)
fi
case "$STATUS_INDICATOR" in
    none)        STATUS_TEXT="${GREEN}●${RESET}" ;;
    minor)       STATUS_TEXT="${YELLOW}⚠ minor${RESET}" ;;
    major)       STATUS_TEXT="${RED}⚠ major${RESET}" ;;
    critical)    STATUS_TEXT="${RED}⚠ critical${RESET}" ;;
    maintenance) STATUS_TEXT="${CYAN}⚙ maint${RESET}" ;;
    *)           STATUS_TEXT="${GREEN}●${RESET}" ;;
esac

# --- Output ---
printf '%s%s %s %s%s%s %s ctx %s%s%s %d%% %s 5h %s %s 7d %s %s %s %s ⏱ %s\n' \
    "$CWD_SHORT" "$BRANCH_TEXT" "$SEP" \
    "$CYAN" "$MODEL" "$RESET" "$SEP" \
    "$CTX_COLOR" "$BAR" "$RESET" "$CTX_PCT" "$SEP" \
    "$FIVEH_TEXT" "$SEP" \
    "$SEVEND_TEXT" "$SEP" \
    "$STATUS_TEXT" "$SEP" \
    "$DURATION"
