# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Personal dotfiles. Currently ships one artifact: a custom statusline for Claude Code itself (`claude/statusline.sh`) and an idempotent installer (`claude/install.sh`).

## Commands

```bash
# Install the statusline on the current machine
./claude/install.sh

# Skip confirmation prompts (for automation)
CLAUDE_STATUSLINE_FORCE=1 ./claude/install.sh

# Run the statusline directly with a sample payload (what install.sh's smoke test does)
printf '{"model":{"display_name":"TestModel"},"workspace":{"current_dir":"'"$PWD"'"},"context_window":{"used_percentage":42},"cost":{"total_duration_ms":60000},"rate_limits":{"five_hour":{"used_percentage":60,"resets_at":'"$(( $(date +%s) + 9000 ))"'},"seven_day":{"used_percentage":30,"resets_at":'"$(( $(date +%s) + 300000 ))"'}}}' \
  | bash claude/statusline.sh

# Disable at runtime without uninstalling
export CLAUDE_STATUSLINE_OFF=1

# Uninstall (remove statusLine from settings.json, keep everything else)
jq 'del(.statusLine)' ~/.claude/settings.json > /tmp/s && mv /tmp/s ~/.claude/settings.json
rm ~/.claude/statusline.sh
```

No build step, no test suite, no linter configured — this is pure bash.

## Architecture

The statusline is a **stdin → stdout filter**. Claude Code pipes a session JSON blob to `statusline.sh` on every refresh; the script emits a single formatted line. This shapes two properties:

- **All fields are optional with fallbacks.** The script uses `jq -r '… // default'` for every extraction, numeric fields are coerced via `tonumber? // … | floor`, and every extraction carries an `|| fallback` guard — so a missing, wrong-typed, or entirely malformed payload degrades to defaults instead of aborting under `set -e` and blanking the line. When adding a new field, follow the same pattern.
- **External lookups must never block.** The service-status segment polls `status.claude.com` but does so off the critical path: a detached background `curl` revalidates a 5-minute file cache (`~/.claude/.statusline-status`) while the current render uses the stale value. `curl` is a *soft* dependency — without it the segment falls back to a neutral dot, so the statusline still works. Any future network field must follow this cache-then-revalidate pattern, not a synchronous fetch.
- **The 5h pace indicator is purely local.** It compares `rate_limits.five_hour.used_percentage` against the elapsed fraction of the 5-hour window (`(18000 − remaining) / 18000`) and renders the delta: `↑N` when ahead of the sustainable rate (yellow ≥+5, red ≥+15), dim `↓N` when behind (≤−5), nothing when on pace, and suppressed entirely at `MAX` (≥100%). Its value is that the account-level percentage already reflects tokens burned by parallel subagents and other sessions, so pace is an early warning during multi-agent runs. Keep it **integer bash arithmetic on payload fields only** — it must add no dependency and make no network call.
- **Output must be exactly one line.** The `printf` at the bottom uses a single format string — don't introduce newlines.

The installer (`install.sh`) is deliberately **non-destructive and transparent**:

1. Validates existing `~/.claude/settings.json` is valid JSON before touching it.
2. Shows a unified `diff` of every proposed change (both `settings.json` and `statusline.sh`).
3. Prompts for confirmation **only** when an existing customized value would be overwritten — not for fresh installs or idempotent re-runs.
4. Backs up to `settings.json.bak-<timestamp>`.
5. Merges *only* the `statusLine` field using `jq '. * $new'` — other settings in `settings.json` are preserved.
6. Runs a smoke test by piping the sample payload through the installed script.

Non-interactive shells (no TTY on stdin) abort on conflict rather than silently overwriting; `CLAUDE_STATUSLINE_FORCE=1` is the explicit override for automation. When editing `install.sh`, preserve this invariant: **any path that overwrites an existing customized value must go through the `confirm` helper**, and the backup-then-merge flow must not be bypassed.

The merged `statusLine` block also carries `"refreshInterval": 30`, so the line re-renders every 30s while the session idles (in addition to event-driven updates) — this keeps the rate-limit and pace fields live during long multi-agent runs. It lives in the `NEW_FIELD` definition in `install.sh`; any change to the merged settings shape belongs there so the diff-and-merge flow picks it up.

## Relevant context from README.md

- Distribution model is `git clone ~/dotfiles` + run the installer. The installer expects `statusline.sh` next to it on disk — curl-pipe is intentionally unsupported.
- Hard dependency: `jq`. The installer fails fast if it's missing.
- Soft dependency: `curl`, used only by the service-status segment; absent, that segment renders a neutral dot and everything else works.
