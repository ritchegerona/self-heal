# Self-Heal for Fedora 44 + KDE Plasma

Automatic error detection and repair for your system, running on a timer.
Every fix is logged and shown as a KDE desktop notification.

## Install (one time)

```bash
cd ~/self-heal
sudo ./install.sh
```

That enables two timers:

| Timer                | Scope | Every    | Fixes                                     |
|----------------------|-------|----------|--------------------------------------------|
| `self-heal.timer`    | root  | 15 min   | services, disk, rpmdb, journals, cups, network, btrfs, SMART, zram |
| `self-heal-user.timer` | you | 10 min   | Plasma/PipeWire/portal crashes, audio, cache, user flatpaks |
| `self-heal-scrub.timer` | root | monthly | btrfs scrub of / (silent corruption detection) |

## What it fixes automatically

**System tier (root):**
- Failed services → restarted, but **only** those on `SERVICE_ALLOWLIST` (defaults: NetworkManager, cups, bluetooth, chronyd, sshd, systemd-resolved). Unknown failures → critical desktop notification instead.
- Disk ≥ 85% → journal vacuum + dnf cache clean + unused flatpak runtime removal; ≥ 92% → critical warning
- Journal over 500 MB → vacuumed
- /boot ≥ 80% → warning; opt-in `AUTO_REMOVE_OLD_KERNELS=1` prunes old kernels (keeps `KERNELS_KEEP=2`)
- Corrupt RPM database → `rpm --rebuilddb` (skipped while dnf is mid-transaction)
- Dependency breakage detected by `dnf check` → notification
- Stuck CUPS jobs with unserviceable printer → queue cancelled + notification
- Network dead for 3 consecutive runs → NetworkManager bounced
- BTRFS errors in journal → critical notification + enables monthly scrub timer
- SMART failing disk → **critical** backup-now notification
- `vm.swappiness` wrong for zram → set to 180 and persisted

**User tier (no root):**
- Crashed pipewire / wireplumber / portals / plasmashell units → restarted (allowlisted)
- plasmashell process missing while session alive → desktop restored
- Dead audio (no sinks / server unresponsive) → PipeWire stack restarted
- `~/.cache` over 2 GB → files unused 30+ days purged; thumbnails over 300 MB purged
- User flatpaks → `flatpak repair --user`

## Safety model

- Allowlist-only restarts — nothing else is ever touched automatically
- Destructive kernel removal is **opt-in** (off by default)
- Every action is logged (`/var/log/self-heal.log`, `~/.local/state/self-heal.log`) and toasted on your desktop
- `self-heal test` previews everything without changing anything

## Commands

```bash
self-heal status      # health dashboard: disk, mem, failed units, audio, timers, recent log
self-heal test        # dry-run: what WOULD be done right now
self-heal drill       # live-fire test: injects safe failures, verifies recovery, PASS/FAIL report
sudo self-heal drill  # same, system tier: SIGKILLs cups and expects auto-restart
self-heal doctor      # verbose real run
sudo self-heal run    # force a full system-tier run
self-heal --user check audio_fix    # run a single check
self-heal checks      # list all checks
```

The drill briefly interrupts audio (~5 s) on purpose; everything else is
isolated in throwaway sandboxes and cannot touch your data.

## Configure

Edit `/etc/self-heal.conf` (system tier) or `~/.config/self-heal.conf`
(user tier overrides). All thresholds, allowlists and toggles are documented
there. Example — auto-remove old kernels and add a service to the restart list:

```bash
sudo sed -i 's/^#AUTO_REMOVE_OLD_KERNELS=0/AUTO_REMOVE_OLD_KERNELS=1/' /etc/self-heal.conf
```

## Logs

```bash
journalctl -u self-heal.service -f          # system tier, live
journalctl --user -u self-heal-user.service # user tier
tail -f /var/log/self-heal.log
```

## Uninstall

```bash
sudo ~/self-heal/uninstall.sh
```
