#!/bin/sh
#
# artix-base — Phase 5: btrfs snapshots (snapper + snap-pac + grub-btrfs, OpenRC).
# Copyright (c) 2025 Cosqun Hesenov.  MIT licensed (see LICENSE).
#
# Run as your normal user (NOT root), after Phase 2. Sets up a dedicated
# @snapshots subvolume, a snapper "root" config, automatic pre/post snapshots
# on every pacman transaction (snap-pac), the GRUB snapshot submenu, and an
# OpenRC service + cron cleanup (OpenRC has none of snapper's systemd timers).

REPO="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BTRFS_OPTS="noatime,compress=zstd,ssd,discard=async,space_cache=v2"

die() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "root ilə işlətmə — normal (wheel) istifadəçi lazımdır."
command -v findmnt >/dev/null 2>&1 || die "findmnt yoxdur (util-linux)."
findmnt -no FSTYPE / | grep -qx btrfs || die "kök btrfs deyil."
USER_NAME=$(id -un)

printf '\n== 1/6 == paketlər (snapper, snap-pac, grub-btrfs, inotify-tools, cronie)\n'
sudo pacman -S --needed --noconfirm snapper snap-pac grub-btrfs inotify-tools cronie

printf '\n== 2/6 == snapper "root" konfiqi\n'
if [ ! -e /etc/snapper/configs/root ]; then
	sudo snapper -c root create-config /
else
	echo "  root konfiqi onsuz da var"
fi

printf '\n== 3/6 == @snapshots subvolume -> /.snapshots\n'
if findmnt /.snapshots >/dev/null 2>&1; then
	echo "  /.snapshots onsuz da mount olunub"
else
	uuid=$(findmnt -no UUID /)
	dev=$(findmnt -no SOURCE / | sed 's/\[.*\]//')
	# drop the nested .snapshots snapper just created
	if sudo btrfs subvolume show /.snapshots >/dev/null 2>&1; then
		sudo btrfs subvolume delete /.snapshots
	fi
	sudo mkdir -p /.snapshots
	# create @snapshots at the btrfs top level (sibling of @ / @home / @var)
	top=$(mktemp -d)
	sudo mount -o subvolid=5 "$dev" "$top"
	sudo btrfs subvolume create "$top/@snapshots" 2>/dev/null || true
	sudo umount "$top"; rmdir "$top"
	# fstab + mount
	grep -qE 'subvol=/?@snapshots' /etc/fstab || \
		printf 'UUID=%s\t/.snapshots\tbtrfs\t%s,subvol=@snapshots\t0 0\n' "$uuid" "$BTRFS_OPTS" \
		| sudo tee -a /etc/fstab >/dev/null
	sudo mount /.snapshots
fi
sudo chmod 750 /.snapshots

printf '\n== 4/6 == snapper konfiqi (istifadəçi icazəsi, limitlər)\n'
sudo snapper -c root set-config \
	ALLOW_USERS="$USER_NAME" SYNC_ACL=yes \
	TIMELINE_CREATE=no NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=10

printf '\n== 5/6 == grub-btrfsd (OpenRC servisi) + cron cleanup\n'
sudo cp "$REPO/src/grub-btrfsd.openrc" /etc/init.d/grub-btrfsd
sudo chmod +x /etc/init.d/grub-btrfsd
sudo rc-update add grub-btrfsd default
sudo rc-service grub-btrfsd restart
# OpenRC has no snapper-cleanup timer -> hourly cron
printf '# hourly snapper cleanup (OpenRC has no snapper timers)\n0 * * * * root /usr/bin/snapper -c root cleanup number\n' \
	| sudo tee /etc/cron.d/snapper-cleanup >/dev/null
sudo rc-update add cronie default
sudo rc-service cronie start 2>/dev/null || true

printf '\n== 6/6 == GRUB menyusunu snapshot-larla yenilə + baseline\n'
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo snapper -c root create -d "phase5 baseline" 2>/dev/null || true

cat <<EOF

✅ Faza 5 bitdi.
   • Hər 'pacman -S/-U' öncəsi/sonrası avtomatik snapshot (snap-pac)
   • '$USER_NAME' sudo-suz: snapper list / snapper create
   • Yenidən başlat → GRUB-da "Artix snapshots" alt-menyusu
   • Rollback: snapshot-a boot et → 'sudo snapper rollback' → reboot
EOF
