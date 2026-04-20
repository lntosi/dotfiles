#!/usr/bin/env bash
# Installer for the Claude Code statusline.
# Idempotent and non-destructive: backs up existing settings.json and merges
# only the `statusLine` field — your other settings are preserved.

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SCRIPT_DEST="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"
SCRIPT_SRC="$(cd "$(dirname "$0")" && pwd)/statusline.sh"
TS=$(date +%Y%m%d-%H%M%S)

log()  { printf '  %s\n' "$1"; }
warn() { printf '  ⚠  %s\n' "$1" >&2; }
die()  { printf '  ✗  %s\n' "$1" >&2; exit 1; }

echo ""
echo "Claude Code statusline — install"
echo ""

# 1. Prerequisites
command -v jq >/dev/null 2>&1 || die "jq is required. Install with: brew install jq  (macOS)  |  apt install jq  (Debian/Ubuntu)"
command -v bash >/dev/null 2>&1 || die "bash is required"
[ -f "$SCRIPT_SRC" ] || die "statusline.sh not found alongside install.sh (looked at $SCRIPT_SRC)"
log "prerequisites ok (jq, bash, statusline.sh)"

# 2. Ensure ~/.claude exists
if [ ! -d "$CLAUDE_DIR" ]; then
    mkdir -p "$CLAUDE_DIR"
    log "created $CLAUDE_DIR"
fi

# 3. Install the script
cp "$SCRIPT_SRC" "$SCRIPT_DEST"
chmod +x "$SCRIPT_DEST"
log "installed $SCRIPT_DEST"

# 4. Update settings.json
NEW_FIELD='{"statusLine": {"type": "command", "command": "bash ~/.claude/statusline.sh"}}'

if [ -f "$SETTINGS" ]; then
    # Validate JSON before touching
    jq empty "$SETTINGS" 2>/dev/null || die "existing $SETTINGS is not valid JSON — fix or move it before re-running"
    # Backup
    BACKUP="$SETTINGS.bak-$TS"
    cp "$SETTINGS" "$BACKUP"
    log "backed up existing settings → $BACKUP"
    # Merge: overwrites only the statusLine field, preserves everything else
    jq --argjson new "$NEW_FIELD" '. * $new' "$SETTINGS" > "$SETTINGS.tmp" \
        && mv "$SETTINGS.tmp" "$SETTINGS"
    log "merged statusLine field into $SETTINGS"
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
