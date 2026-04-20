# dotfiles

Personal configuration files for reproducible setup across machines.

## claude/

Custom statusline for [Claude Code](https://claude.com/claude-code).

Shows: current directory | model | context usage (bar + %) | 5h quota remaining | 7d quota used | session duration.

### Install

On any machine where Claude Code is installed:

```bash
git clone git@github.com:lntosi/dotfiles.git ~/dotfiles
~/dotfiles/claude/install.sh
```

Or as a one-shot curl-pipe (replace `main` with a tag if you want version pinning):

```bash
curl -fsSL https://raw.githubusercontent.com/lntosi/dotfiles/main/claude/install.sh \
  | STATUSLINE_SRC=https://raw.githubusercontent.com/lntosi/dotfiles/main/claude/statusline.sh bash
```

> The curl-pipe version requires a small tweak to `install.sh` — currently it expects `statusline.sh` to sit next to it. Prefer the `git clone` flow.

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
