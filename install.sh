#!/usr/bin/env bash
# =============================================================================
#  install.sh — one-time installer for the Self-Heal toolkit
#  Run with:  sudo ./install.sh
# =============================================================================
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Run me with sudo: sudo $0" >&2; exit 1; }

echo "▸ Self-Heal installer"

# 1) engine
install -Dm755 "$SRC/self-heal" /usr/local/bin/self-heal
echo "  ✔ /usr/local/bin/self-heal"

# 2) config (never overwrite an existing tuned config)
if [ ! -f /etc/self-heal.conf ]; then
  install -m644 "$SRC/self-heal.conf" /etc/self-heal.conf
  echo "  ✔ /etc/self-heal.conf (defaults)"
else
  echo "  = /etc/self-heal.conf kept as-is"
fi

# 3) state + log
install -d -m755 /var/lib/self-heal
touch /var/log/self-heal.log
chmod 640 /var/log/self-heal.log

# 4) system units
install -m644 "$SRC/self-heal.service"  /etc/systemd/system/
install -m644 "$SRC/self-heal.timer"    /etc/systemd/system/
echo "  ✔ /etc/systemd/system/self-heal.{service,timer}"

# 5) user units (system-wide, available to every user manager)
install -d -m755 /etc/systemd/user
install -m644 "$SRC/self-heal-user.service" /etc/systemd/user/
install -m644 "$SRC/self-heal-user.timer"   /etc/systemd/user/
echo "  ✔ /etc/systemd/user/self-heal-user.{service,timer}"

# 6) logrotate
install -Dm644 "$SRC/self-heal.logrotate" /etc/logrotate.d/self-heal
echo "  ✔ /etc/logrotate.d/self-heal"

# 7) reload + enable system timer
systemctl daemon-reload
systemctl enable --now self-heal.timer
echo "  ✔ system timer enabled (runs every 15 min)"

# 8) btrfs monthly scrub: catch silent corruption early
if [ "$(findmnt -no FSTYPE /)" = "btrfs" ]; then
  if systemctl cat 'btrfs-scrub@-.timer' >/dev/null 2>&1; then
    systemctl enable --now 'btrfs-scrub@-.timer' 2>/dev/null && \
      echo "  ✔ btrfs monthly scrub timer (system template) enabled"
  else
    install -m644 "$SRC/self-heal-scrub.service" /etc/systemd/system/
    install -m644 "$SRC/self-heal-scrub.timer"   /etc/systemd/system/
    systemctl enable --now self-heal-scrub.timer
    echo "  ✔ monthly btrfs scrub timer enabled (self-heal-scrub.timer)"
  fi
fi

# 9) enable the user timer for the calling admin user
CALLER="${SUDO_USER:-}"
if [ -n "$CALLER" ]; then
  if systemctl --machine="$CALLER@.host" --user enable --now self-heal-user.timer 2>/dev/null; then
    echo "  ✔ user timer enabled for $CALLER (runs every 10 min)"
  else
    echo "  ! could not auto-enable user timer; as $CALLER run:"
    echo "      systemctl --user enable --now self-heal-user.timer"
  fi
fi

echo
echo "Done. First run is happening right now — watch it with:"
echo "  self-heal status        health dashboard"
echo "  sudo self-heal test     dry-run preview"
echo "  journalctl -u self-heal.service -f   live system-tier log"
