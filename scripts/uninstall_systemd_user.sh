#!/usr/bin/env bash
set -euo pipefail

USER_SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SERVICE_PATH="$USER_SYSTEMD_DIR/wakeup-claude.service"
TIMER_PATH="$USER_SYSTEMD_DIR/wakeup-claude.timer"

# Stop future triggers first, then stop any in-flight run.
systemctl --user disable --now wakeup-claude.timer >/dev/null 2>&1 || true
systemctl --user stop wakeup-claude.service >/dev/null 2>&1 || true
systemctl --user disable wakeup-claude.service >/dev/null 2>&1 || true

rm -f "$SERVICE_PATH" "$TIMER_PATH"

systemctl --user daemon-reload
systemctl --user reset-failed wakeup-claude.service wakeup-claude.timer >/dev/null 2>&1 || true

echo "Removed units:"
echo "- $SERVICE_PATH"
echo "- $TIMER_PATH"
echo
echo "Current unit state:"
systemctl --user status wakeup-claude.timer --no-pager 2>/dev/null | sed -n '1,6p' || echo "wakeup-claude.timer not found"
