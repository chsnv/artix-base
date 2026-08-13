#!/bin/sh -e
#
# artix-base — Phase 1: disk layout + base system.
# Copyright (c) 2025 Cosqun Hesenov.  MIT licensed (see LICENSE).
#
# btrfs layout:  @ / @home / @var   (+ @swap when swap requested)
# mount opts, ESP size are the tunables just below.
# Env from install.sh:  INIT DISK P1 P2 FS SWAP CRYPT ROOT CRYPTPASS

BTRFS_OPTS="noatime,compress=zstd,ssd,discard=async,space_cache=v2"
ESP_SIZE="200MiB"   # matches your real ESP; /boot lives on btrfs @, ESP only holds grubx64.efi

# --- base package set (NetworkManager audio-less; PipeWire comes in Phase 2) ---
pkgs="base base-devel $INIT elogind-$INIT \
networkmanager networkmanager-$INIT openssh openssh-$INIT \
grub grub-btrfs efibootmgr os-prober \
git vim dialog mtools dosfstools xdg-utils xdg-user-dirs \
alsa-utils gvfs sudo"
[ "$FS" = btrfs ] && pkgs="$pkgs btrfs-progs"
[ "$CRYPT" = y ]  && pkgs="$pkgs cryptsetup cryptsetup-$INIT"
case "$(grep -m1 vendor_id /proc/cpuinfo)" in
	*Intel*) pkgs="$pkgs intel-ucode" ;;
	*AMD*)   pkgs="$pkgs amd-ucode"   ;;
esac

# --- GPT: p1 = ESP (EFI System), p2 = root (Linux) ---
printf 'label: gpt\n,%s,U\n,,L\n' "$ESP_SIZE" | sfdisk "$DISK"
partprobe "$DISK" 2>/dev/null || true
udevadm settle 2>/dev/null || true

# --- optional LUKS ---
if [ "$CRYPT" = y ]; then
	printf '%s' "$CRYPTPASS" | cryptsetup -q luksFormat "$P2"
	printf '%s' "$CRYPTPASS" | cryptsetup open "$P2" root
fi

mkfs.fat -F32 "$P1"

# --- root filesystem ---
if [ "$FS" = btrfs ]; then
	mkfs.btrfs -f "$ROOT"

	mount "$ROOT" /mnt
	for sv in @ @home @var; do btrfs subvolume create "/mnt/$sv"; done
	[ "${SWAP:-0}" -gt 0 ] && btrfs subvolume create /mnt/@swap
	umount /mnt

	mount -o "$BTRFS_OPTS,subvol=@" "$ROOT" /mnt
	mkdir -p /mnt/home /mnt/var /mnt/boot/efi
	mount -o "$BTRFS_OPTS,subvol=@home" "$ROOT" /mnt/home
	mount -o "$BTRFS_OPTS,subvol=@var"  "$ROOT" /mnt/var

	if [ "${SWAP:-0}" -gt 0 ]; then
		mkdir -p /mnt/swap
		mount -o noatime,subvol=@swap "$ROOT" /mnt/swap
		btrfs filesystem mkswapfile -s "${SWAP}G" /mnt/swap/swapfile
		swapon /mnt/swap/swapfile
	fi
else
	yes | mkfs.ext4 "$ROOT"
	mount "$ROOT" /mnt
	mkdir -p /mnt/boot/efi
	if [ "${SWAP:-0}" -gt 0 ]; then
		mkdir -p /mnt/swap
		fallocate -l "${SWAP}G" /mnt/swap/swapfile
		chmod 600 /mnt/swap/swapfile
		mkswap /mnt/swap/swapfile
		swapon /mnt/swap/swapfile
	fi
fi

mount "$P1" /mnt/boot/efi

# --- base system + kernels (zen primary, lts fallback) ---
# shellcheck disable=SC2086
basestrap /mnt $pkgs
basestrap /mnt linux-zen linux-zen-headers linux-lts linux-lts-headers linux-firmware mkinitcpio

# --- fstab (the mounted devices) ---
fstabgen -U /mnt > /mnt/etc/fstab
