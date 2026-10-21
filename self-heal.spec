Name:           self-heal
Version:        1.0.0
Release:        1%{?dist}
Summary:        Automatic diagnosis & repair engine for Fedora + KDE Plasma

License:        MIT
URL:            https://github.com/ritchegerona/self-heal
Source0:        %{url}/archive/v%{version}/%{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  systemd-rpm-macros
Requires:       bash coreutils util-linux systemd iproute procps-ng
Recommends:     smartmontools flatpak cups btrfs-progs

%description
Self-Heal is a two-tier, systemd-timer driven engine that periodically
checks a Fedora + KDE Plasma system for common failure modes and repairs
them automatically:

system tier (root, every 15 min)
  * restart failed services (allowlist-only)
  * disk-full emergency cleanup (journal vacuum, dnf cache, flatpak unused)
  * journal size cap, /boot protection, old-kernel pruning (opt-in)
  * corrupt RPM database rebuild, dnf dependency checks
  * stuck CUPS queue cancellation, dead-network NetworkManager bounce
  * BTRFS error watchdog + monthly scrub timer, SMART health checks
  * zram-friendly vm.swappiness enforcement

user tier (session, every 10 min)
  * restart crashed PipeWire / XDG portal / plasmashell units
  * dead-audio auto-recovery
  * stale user-cache and thumbnail purging
  * user flatpak repair

Every action is logged and reported via desktop notifications.
Includes 'self-heal drill', a live-fire failure injection test with a
PASS/FAIL report. All auto-restarts are allowlist-only; nothing
destructive runs unattended.

%prep
%autosetup

%install
install -Dm755 self-heal            %{buildroot}%{_bindir}/self-heal
install -Dm644 self-heal.conf       %{buildroot}%{_sysconfdir}/self-heal.conf
install -Dm644 self-heal.logrotate  %{buildroot}%{_sysconfdir}/logrotate.d/self-heal

sed 's|/usr/local/bin/self-heal|%{_bindir}/self-heal|' self-heal.service \
  > %{buildroot}%{_unitdir}/self-heal.service
install -Dm644 self-heal.timer      %{buildroot}%{_unitdir}/self-heal.timer
install -Dm644 self-heal-scrub.service %{buildroot}%{_unitdir}/self-heal-scrub.service
install -Dm644 self-heal-scrub.timer   %{buildroot}%{_unitdir}/self-heal-scrub.timer

sed 's|/usr/local/bin/self-heal|%{_bindir}/self-heal|' self-heal-user.service \
  > %{buildroot}%{_userunitdir}/self-heal-user.service
install -Dm644 self-heal-user.timer %{buildroot}%{_userunitdir}/self-heal-user.timer

%files
%license LICENSE
%doc README.md
%{_bindir}/self-heal
%{_unitdir}/self-heal.service
%{_unitdir}/self-heal.timer
%{_unitdir}/self-heal-scrub.service
%{_unitdir}/self-heal-scrub.timer
%{_userunitdir}/self-heal-user.service
%{_userunitdir}/self-heal-user.timer
%config(noreplace) %{_sysconfdir}/self-heal.conf
%config(noreplace) %{_sysconfdir}/logrotate.d/self-heal

%post
%systemd_post self-heal.service
systemctl enable --now self-heal.timer >/dev/null 2>&1 || :
if [ "$(findmnt -no FSTYPE /)" = "btrfs" ]; then
  systemctl enable --now self-heal-scrub.timer >/dev/null 2>&1 || :
fi
echo "self-heal: system timer enabled. Optional per-user session timer:"
echo "  systemctl --user enable --now self-heal-user.timer"

%preun
%systemd_preun self-heal.service

%postun
%systemd_postun self-heal.service

%changelog
* Wed Oct 22 2026 ritchegerona <ritchegerona@users.noreply.github.com> - 1.0.0-1
- Initial release: two-tier repair engine, 15 checks, drill, btrfs scrub
