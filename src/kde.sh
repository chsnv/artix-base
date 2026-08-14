#!/bin/sh
#
# artix-base — Phase 2: KDE Plasma desktop (matches chsnv's current system).
# Copyright (c) 2025 Cosqun Hesenov.  MIT licensed (see LICENSE).
#
# Run AFTER the first boot into the base system, logged in as your user
# (needs sudo). Installs the real desktop package set, sets up PipeWire audio,
# and enables the system services captured from the live machine.

REPO="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DESKTOP="$REPO/packages/desktop.txt"
SERVICES="$REPO/packages/services-openrc.txt"

[ -f "$DESKTOP" ] || { printf 'tapılmadı: %s\n' "$DESKTOP" >&2; exit 1; }

printf '\n== 1/3 == Depoları yenilə + masaüstü paketlərini qur (%s)\n' "$(grep -c . "$DESKTOP")"
# NOTE: some packages come from Arch [extra]/[multilib]; if any are reported
# missing, install `artix-archlinux-support` and enable [lib32] in
# /etc/pacman.conf, then re-run.
sudo pacman -Syu --needed --noconfirm - < "$DESKTOP"

printf '\n== 2/3 == PipeWire audio (PulseAudio/JACK əvəzi)\n'
sudo pacman -S --needed --noconfirm \
	pipewire pipewire-alsa pipewire-pulse pipewire-jack \
	pipewire-audio pipewire-session-manager wireplumber

printf '\n== 3/3 == Sistem servislərini enable et\n'
if [ -f "$SERVICES" ]; then
	while read -r svc; do
		[ "$svc" ] || continue
		if sudo rc-update add "$svc" default 2>/dev/null; then
			printf '  + %s\n' "$svc"
		else
			printf '  ! %s (paket və ya servis yoxdur — keçildi)\n' "$svc"
		fi
	done < "$SERVICES"
fi

cat <<'EOF'

✅ Faza 2 bitdi.
   • Audio: PipeWire (istifadəçi sessiyasında avtomatik başlayır)
   • Giriş meneceri: sddm  →  yenidən başlat, KDE Plasma açılacaq
   ⚠ mariadb/postgresql enable olundusa, DB init ayrıca lazımdır
     (mariadb-install-db / initdb).  tailscaled üçün: sudo tailscale up
EOF
