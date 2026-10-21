#!/usr/bin/env bash
# uninstall.sh — remove the Self-Heal toolkit completely
set -e
[ "$(id -u)" -eq 0 ] || { echo "Run me with sudo: sudo $0" >&2; exit 1; }
systemctl disable --now self-heal.timer 2>/dev/null || true
rm -f /etc/systemd/system/self-heal.service /etc/systemd/system/self-heal.timer
rm -f /etc/systemd/system/self-heal-scrub.service /etc/systemd/system/self-heal-scrub.timer
systemctl disable --now self-heal-scrub.timer 2>/dev/null || true
rm -f /etc/systemd/user/self-heal-user.service /etc/systemd/user/self-heal-user.timer
systemctl disable --now self-heal-user.timer 2>/dev/null || true
rm -f /usr/local/bin/self-heal /etc/logrotate.d/self-heal
systemctl daemon-reload
rm -f /etc/self-heal.conf
echo "Self-Heal removed. Logs kept at /var/log/self-heal.log — delete manually if unwanted."
