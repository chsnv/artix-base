#!/bin/sh -e
#
# artix-base — Phase 1: configuration inside the new root (via artix-chroot).
# Copyright (c) 2025 Cosqun Hesenov.  MIT licensed (see LICENSE).
#
# Env: INIT P2 FS CRYPT CRYPTPASS TZ HOST ROOTPASS LANGCODE KEYMAP USERNAME USERPASS

# --- clock ---
ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
hwclock --systohc

# --- locale + console ---
printf '%s.UTF-8 UTF-8\n' "$LANGCODE" >> /etc/locale.gen
locale-gen
printf 'LANG=%s.UTF-8\n' "$LANGCODE" > /etc/locale.conf
printf 'KEYMAP=%s\n' "$KEYMAP" > /etc/vconsole.conf

# --- hostname + hosts ---
printf '%s\n' "$HOST" > /etc/hostname
[ "$INIT" = openrc ] && printf 'hostname="%s"\n' "$HOST" > /etc/conf.d/hostname
{
	printf '127.0.0.1\tlocalhost\n'
	printf '::1\t\tlocalhost\n'
	printf '127.0.1.1\t%s.localdomain\t%s\n' "$HOST" "$HOST"
} > /etc/hosts

# --- bootloader (ESP at /boot/efi, /boot lives on btrfs @) ---
if [ "$CRYPT" = y ]; then
	uuid=$(blkid -s UUID -o value "$P2")
	sed -i "s#^GRUB_CMDLINE_LINUX_DEFAULT=.*#GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=$uuid:root root=/dev/mapper/root\"#" /etc/default/grub
	sed -i 's/^#\(GRUB_ENABLE_CRYPTODISK=y\)/\1/' /etc/default/grub
fi
if grep -q '^GRUB_DISABLE_OS_PROBER' /etc/default/grub; then
	sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
else
	printf 'GRUB_DISABLE_OS_PROBER=false\n' >> /etc/default/grub
fi
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=artix --recheck
grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# --- accounts ---
printf 'root:%s\n' "$ROOTPASS" | chpasswd
sed -i 's/^#[[:space:]]*\(%wheel ALL=(ALL\(:ALL\)\{0,1\}) ALL\)/\1/' /etc/sudoers
if [ "$USERNAME" ]; then
	useradd -m -G wheel -s /bin/bash "$USERNAME"
	printf '%s:%s\n' "$USERNAME" "$USERPASS" | chpasswd
fi

# --- core services (NetworkManager needs dbus) ---
if [ "$INIT" = openrc ]; then
	rc-update add dbus default
	rc-update add NetworkManager default
elif [ "$INIT" = dinit ]; then
	ln -sf /etc/dinit.d/dbus /etc/dinit.d/boot.d/
	ln -sf /etc/dinit.d/NetworkManager /etc/dinit.d/boot.d/
fi

# --- initramfs ---
[ "$FS" = btrfs ] && sed -i 's#^BINARIES=.*#BINARIES=(/usr/bin/btrfs)#' /etc/mkinitcpio.conf
if [ "$CRYPT" = y ]; then
	sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect keyboard keymap modconf block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
else
	sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect keyboard keymap modconf block filesystems fsck)/' /etc/mkinitcpio.conf
fi
mkinitcpio -P
