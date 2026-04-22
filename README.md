# dotfiles

Personal configuration files for reproducible setup across machines.

## claude/

Custom statusline for [Claude Code](https://claude.com/claude-code).

### Fields

- **cwd** — current working directory (`$HOME` collapsed to `~`).
- **model** — active model's `display_name`, shown in cyan.
- **ctx** — 10-cell progress bar + percentage of the context window used; green <50%, yellow <80%, red ≥80%.
- **5h** — percent consumed of the 5-hour rate-limit window and time until it resets (`78% → 2h22m`). Falls back to `—` until the payload includes `rate_limits.five_hour`.
- **7d** — percent consumed of the 7-day rate-limit window and the day + local time of the next reset (`46% → Thu 18:53`). Falls back to `—` when absent.
- **⏱** — cumulative duration of the current session (`Xh Ym`).

### Install

On any machine where Claude Code is installed:

```bash
git clone git@github.com:lntosi/dotfiles.git ~/dotfiles
~/dotfiles/claude/install.sh
```

### Requirements

- `bash` (macOS / Linux default)
- `jq` — install with `brew install jq` (macOS) or `apt install jq` (Debian/Ubuntu)

### Toggle

- Disable in current shell: `export CLAUDE_STATUSLINE_OFF=1`
- Re-enable: `unset CLAUDE_STATUSLINE_OFF`
- Disable permanently: add the export to `~/.zshrc` / `~/.bashrc`

### What the installer does

1. Copies `claude/statusline.sh` to `~/.claude/statusline.sh`
2. Backs up existing `~/.claude/settings.json` (timestamped)
3. Merges the `statusLine` field into `settings.json` via `jq` — your other settings stay intact
4. Runs a smoke test so you see the output immediately

The installer is transparent and safe-by-default:

- **Always shows a unified diff** of what will change (both in `settings.json` and in `statusline.sh`) before touching anything.
- **Prompts for confirmation** only when there's real risk: an existing customized `statusLine` would be replaced, or the installed `statusline.sh` differs from the source. Fresh installs and identical re-runs are silent no-ops.
- **Non-interactive shells** (e.g. `curl … | bash`) abort with a clear error when a conflict is detected. Set `CLAUDE_STATUSLINE_FORCE=1` to skip prompts in automation.
- **Timestamped backup** (`settings.json.bak-<ts>`) is kept as a final safety net.

### Uninstall

```bash
# Remove the statusLine entry from ~/.claude/settings.json (keeping the rest)
jq 'del(.statusLine)' ~/.claude/settings.json > /tmp/s && mv /tmp/s ~/.claude/settings.json
rm ~/.claude/statusline.sh
```
