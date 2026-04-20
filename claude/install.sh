#!/usr/bin/env bash
# Installer for the Claude Code statusline.
# Idempotent and non-destructive: backs up existing settings.json and merges
# only the `statusLine` field — your other settings are preserved.
#
# Safety: shows a diff of every change and prompts for confirmation when
# an existing customized value would be overwritten. Set
# CLAUDE_STATUSLINE_FORCE=1 to skip prompts (e.g. in automation).

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SCRIPT_DEST="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"
SCRIPT_SRC="$(cd "$(dirname "$0")" && pwd)/statusline.sh"
TS=$(date +%Y%m%d-%H%M%S)
FORCE="${CLAUDE_STATUSLINE_FORCE:-0}"

log()  { printf '  %s\n' "$1"; }
warn() { printf '  ⚠  %s\n' "$1" >&2; }
die()  { printf '  ✗  %s\n' "$1" >&2; exit 1; }

confirm() {
    local prompt="$1"
    if [ "$FORCE" = "1" ]; then
        log "CLAUDE_STATUSLINE_FORCE=1 — proceeding without prompt ($prompt)"
        return 0
    fi
    if [ ! -t 0 ]; then
        die "$prompt — non-interactive shell; re-run in a terminal or set CLAUDE_STATUSLINE_FORCE=1"
    fi
    printf '  ? %s [y/N] ' "$prompt"
    read -r ans
    case "$ans" in
        y|Y|yes|YES) return 0 ;;
        *) die "aborted by user" ;;
    esac
}

show_diff() {
    # Prints a unified diff with 2-space indent. Never fails the script.
    diff -u "$1" "$2" 2>/dev/null | sed 's/^/    /' || true
}

echo ""
echo "Claude Code statusline — install"
echo ""

# 1. Prerequisites
command -v jq   >/dev/null 2>&1 || die "jq is required. Install with: brew install jq  (macOS)  |  apt install jq  (Debian/Ubuntu)"
command -v bash >/dev/null 2>&1 || die "bash is required"
command -v diff >/dev/null 2>&1 || die "diff is required"
[ -f "$SCRIPT_SRC" ] || die "statusline.sh not found alongside install.sh (looked at $SCRIPT_SRC)"
log "prerequisites ok (jq, bash, diff, statusline.sh)"

# 2. Ensure ~/.claude exists
if [ ! -d "$CLAUDE_DIR" ]; then
    mkdir -p "$CLAUDE_DIR"
    log "created $CLAUDE_DIR"
fi

# 3. Install statusline.sh — compare before overwriting
if [ -f "$SCRIPT_DEST" ]; then
    if cmp -s "$SCRIPT_SRC" "$SCRIPT_DEST"; then
        log "$SCRIPT_DEST already up to date"
    else
        echo ""
        echo "  Existing $SCRIPT_DEST differs from source:"
        show_diff "$SCRIPT_DEST" "$SCRIPT_SRC"
        echo ""
        confirm "overwrite $SCRIPT_DEST?"
        cp "$SCRIPT_SRC" "$SCRIPT_DEST"
        chmod +x "$SCRIPT_DEST"
        log "overwrote $SCRIPT_DEST"
    fi
else
    cp "$SCRIPT_SRC" "$SCRIPT_DEST"
    chmod +x "$SCRIPT_DEST"
    log "installed $SCRIPT_DEST"
fi

# 4. Update settings.json
NEW_FIELD='{"statusLine": {"type": "command", "command": "bash ~/.claude/statusline.sh"}}'

if [ -f "$SETTINGS" ]; then
    jq empty "$SETTINGS" 2>/dev/null || die "existing $SETTINGS is not valid JSON — fix or move it before re-running"

    CURRENT_CANON=$(jq -S . "$SETTINGS")
    MERGED=$(jq --argjson new "$NEW_FIELD" '. * $new' "$SETTINGS")
    MERGED_CANON=$(printf '%s' "$MERGED" | jq -S .)

    if [ "$CURRENT_CANON" = "$MERGED_CANON" ]; then
        log "$SETTINGS already has the desired statusLine — no changes"
    else
        EXISTING_SL=$(jq -c '.statusLine // null' "$SETTINGS")
        DESIRED_SL=$(printf '%s' "$NEW_FIELD" | jq -c '.statusLine')

        echo ""
        echo "  Proposed change to $SETTINGS:"
        # Use process substitution via temp files so `diff` can label them cleanly.
        TMP_CUR="$(mktemp)"; TMP_NEW="$(mktemp)"
        trap 'rm -f "$TMP_CUR" "$TMP_NEW"' EXIT
        printf '%s\n' "$CURRENT_CANON" > "$TMP_CUR"
        printf '%s\n' "$MERGED_CANON"  > "$TMP_NEW"
        show_diff "$TMP_CUR" "$TMP_NEW"
        echo ""

        if [ "$EXISTING_SL" != "null" ] && [ "$EXISTING_SL" != "$DESIRED_SL" ]; then
            warn "an existing custom statusLine will be replaced"
            confirm "replace existing statusLine in $SETTINGS?"
        fi

        BACKUP="$SETTINGS.bak-$TS"
        cp "$SETTINGS" "$BACKUP"
        log "backed up existing settings → $BACKUP"
        printf '%s\n' "$MERGED" > "$SETTINGS"
        log "merged statusLine field into $SETTINGS"
    fi
else
    echo "$NEW_FIELD" | jq '.' > "$SETTINGS"
    log "created $SETTINGS"
fi

# 5. Smoke test
SAMPLE='{"model":{"display_name":"TestModel"},"workspace":{"current_dir":"'$PWD'"},"context_window":{"used_percentage":42},"cost":{"total_duration_ms":60000}}'
OUTPUT=$(printf '%s' "$SAMPLE" | bash "$SCRIPT_DEST" 2>&1 || true)
if [ -z "$OUTPUT" ]; then
    warn "script ran but produced no output — check $SCRIPT_DEST manually"
else
    log "smoke test ok"
fi

echo ""
echo "Preview:"
echo "  $OUTPUT"
echo ""
echo "Done. Restart Claude Code to see the statusline."
echo ""
echo "Toggle:"
echo "  export CLAUDE_STATUSLINE_OFF=1   # disable in this shell"
echo "  unset  CLAUDE_STATUSLINE_OFF     # re-enable"
echo ""
