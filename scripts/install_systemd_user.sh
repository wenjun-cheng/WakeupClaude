#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USER_SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

SERVICE_PATH="$USER_SYSTEMD_DIR/wakeup-claude.service"
TIMER_PATH="$USER_SYSTEMD_DIR/wakeup-claude.timer"

mkdir -p "$USER_SYSTEMD_DIR"

cat >"$SERVICE_PATH" <<EOF
[Unit]
Description=Wake Claude Once (CLI mode)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=$ROOT_DIR
Environment=WAKEUP_ROOT=$ROOT_DIR
Environment=WAKEUP_MODEL=haiku
Environment=WAKEUP_EFFORT=low
Environment=WAKEUP_PROMPT=1
Environment=WAKEUP_SYSTEM_PROMPT=Return exactly: 1
Environment=WAKEUP_TIMEOUT_SECONDS=60
ExecStart=/bin/bash $ROOT_DIR/scripts/claude_wakeup_cli.sh
RuntimeMaxSec=90
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=false

[Install]
WantedBy=default.target
EOF

cat >"$TIMER_PATH" <<'EOF'
[Timer]
OnCalendar=*-*-* 04:58:00
OnCalendar=*-*-* 09:59:00
OnCalendar=*-*-* 15:00:00
OnCalendar=*-*-* 20:01:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now wakeup-claude.timer

echo "Installed units:"
echo "- $SERVICE_PATH"
echo "- $TIMER_PATH"
echo
echo "Timer status:"
systemctl --user status wakeup-claude.timer --no-pager | sed -n '1,12p'
