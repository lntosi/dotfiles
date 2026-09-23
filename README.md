# statusline-claude

Personal configuration files for reproducible setup across machines.

## claude/

Custom statusline for [Claude Code](https://claude.com/claude-code).

### Fields

- **cwd** — current working directory (`$HOME` collapsed to `~`).
- **git branch** — current branch of the repo containing `cwd`, in magenta (`⎇ main`); a detached HEAD shows the short commit SHA. Read locally with `git`, no network call. Outside a repo (or without `git` installed) the segment and its separator are omitted entirely.
- **model** — active model's `display_name`, shown in cyan.
- **ctx** — 10-cell progress bar + percentage of the context window used; green <50%, yellow <80%, red ≥80%.
- **5h** — percent consumed of the 5-hour rate-limit window, a pace indicator, and time until reset (`60% ↑10 → 2h30m`). The pace arrow compares usage against the elapsed fraction of the window: `↑N` means you're N points ahead of the sustainable rate (yellow from +5, red from +15), dim `↓N` means you're under pace; on-pace shows no arrow. Because the percentage is account-level, it already includes tokens burned by parallel subagents and other sessions — the pace arrow is the early warning that a multi-agent run is eating the quota faster than the window replenishes. When the quota is exhausted (≥100%), the segment shows `MAX` in red. Falls back to `—` until the payload includes `rate_limits.five_hour` (requires a Pro/Max subscription).
- **7d** — percent consumed of the 7-day rate-limit window and the day + local time of the next reset (`46% → Thu 18:53`). Same `MAX` indicator when the quota is hit. Falls back to `—` when absent.
- **service status** — Claude platform health from [status.claude.com](https://status.claude.com): green `●` when all systems are operational, `⚠ minor`/`⚠ major`/`⚠ critical` (yellow/red) during an incident, `⚙ maint` (cyan) during maintenance. The result is cached for 5 minutes and revalidated by a detached background `curl`, so the segment never blocks the statusline. Without `curl` it falls back to the neutral green dot. Reflects Anthropic's global status only — not the selected model or your local session.
- **⏱** — cumulative duration of the current session (`Xh Ym`).

### Install

On any machine where Claude Code is installed:

```bash
git clone https://navinfo-europe.ghe.com/SpecialProjects/statusline-claude.git ~/statusline-claude
~/statusline-claude/claude/install.sh
```

### Requirements

- `bash` (macOS / Linux default)
- `jq` — install with `brew install jq` (macOS) or `apt install jq` (Debian/Ubuntu)
- `curl` (optional) — only for the service-status segment; absent it falls back to a neutral dot

### Toggle

- Disable in current shell: `export CLAUDE_STATUSLINE_OFF=1`
- Re-enable: `unset CLAUDE_STATUSLINE_OFF`
- Disable permanently: add the export to `~/.zshrc` / `~/.bashrc`

### What the installer does

1. Copies `claude/statusline.sh` to `~/.claude/statusline.sh`
2. Backs up existing `~/.claude/settings.json` (timestamped)
3. Merges the `statusLine` field into `settings.json` via `jq` — your other settings stay intact. The merged config sets `refreshInterval: 30`, so the line also re-renders every 30 seconds while the session idles (e.g. during long multi-agent runs) instead of only after each interaction
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
