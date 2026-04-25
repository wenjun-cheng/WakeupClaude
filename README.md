# Wakeup! Claude!

Minimal Linux scheduler to keep Claude usage windows warm with low-cost CLI pings, making better use of the 5h refresh mechanism.

## What This Implements

- CLI-only wake-up path using `@anthropic-ai/claude-code`.
- Default low-cost mode: `haiku` + `effort low` + minimal prompt.
- User-level systemd scheduling.
- Per-run token usage and success status monitoring.

## Prerequisites

- Linux host with `systemd --user`.
- `node` + `npx` available in PATH.
- Claude CLI auth for the same Linux user that runs the timer.

## Setup

1) Authenticate Claude CLI once.

```bash
npx -y @anthropic-ai/claude-code auth login
```

2) Install and enable user timer.

```bash
bash scripts/install_systemd_user.sh
```

3) Edit Schedule.

Open `~/.config/systemd/user/wakeup-claude.timer` and edit `OnCalendar=` lines.

For example:

- `04:58`, `09:59`, `15:00`, `20:01`

Recommended way to edit:

```bash
code ~/.config/systemd/user/wakeup-claude.timer
```

Apply changes (in terminal):

```bash
systemctl --user daemon-reload
systemctl --user restart wakeup-claude.timer
```

Verify (in terminal):
```bash
systemctl --user status wakeup-claude.timer --no-pager
systemctl --user cat wakeup-claude.timer
```

## Uninstall

Before deleting this repository, stop and remove user-level monitoring units:

```bash
bash scripts/uninstall_systemd_user.sh
```

## Token Monitoring

Default command (today):

```bash
python3 scripts/token_monitor.py
```

[Optional] Custom day, Number of rows, Summary:

```bash
python3 scripts/token_monitor.py --day 2026-04-25 --last 12 --summary
```
