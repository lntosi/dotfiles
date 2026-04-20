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
printf '{"model":{"display_name":"TestModel"},"workspace":{"current_dir":"'"$PWD"'"},"context_window":{"used_percentage":42},"cost":{"total_duration_ms":60000}}' \
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

- **All fields are optional with fallbacks.** The script uses `jq -r '… // default'` for every extraction so an unexpected or partial payload never breaks the statusline. When adding a new field, follow the same pattern.
- **Output must be exactly one line.** The `printf` at the bottom uses a single format string — don't introduce newlines.

The installer (`install.sh`) is deliberately **non-destructive and transparent**:

1. Validates existing `~/.claude/settings.json` is valid JSON before touching it.
2. Shows a unified `diff` of every proposed change (both `settings.json` and `statusline.sh`).
3. Prompts for confirmation **only** when an existing customized value would be overwritten — not for fresh installs or idempotent re-runs.
4. Backs up to `settings.json.bak-<timestamp>`.
5. Merges *only* the `statusLine` field using `jq '. * $new'` — other settings in `settings.json` are preserved.
6. Runs a smoke test by piping the sample payload through the installed script.

Non-interactive shells (no TTY on stdin) abort on conflict rather than silently overwriting; `CLAUDE_STATUSLINE_FORCE=1` is the explicit override for automation. When editing `install.sh`, preserve this invariant: **any path that overwrites an existing customized value must go through the `confirm` helper**, and the backup-then-merge flow must not be bypassed.

## Relevant context from README.md

- Distribution model is `git clone ~/dotfiles` + run the installer. The installer expects `statusline.sh` next to it on disk — curl-pipe is intentionally unsupported.
- Hard dependency: `jq`. The installer fails fast if it's missing.
