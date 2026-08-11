#!/bin/sh -e
#
# artix-base — Phase 1 front-end: gather parameters, then partition + configure.
# Copyright (c) 2025 Cosqun Hesenov.  MIT licensed (see LICENSE).
#
# Run from the Artix live ISO as the live user (uses sudo internally).

die() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

ask() {  # ask "prompt" "default"  -> echoes the answer
	_prompt="$1"; _def="$2"; _ans=""
	[ "$_def" ] && _prompt="$_prompt [$_def]"
	printf '%s: ' "$_prompt" >&2
	read -r _ans
	[ "$_ans" ] || _ans="$_def"
	printf '%s' "$_ans"
}

ask_secret() {  # ask_secret "label"  -> echoes a confirmed password (no echo)
	_label="$1"; _a=x; _b=y
	stty -echo
	while [ "$_a" != "$_b" ] || [ -z "$_a" ]; do
		printf '%s: ' "$_label" >&2;        read -r _a; printf '\n' >&2
		printf 'repeat %s: ' "$_label" >&2; read -r _b; printf '\n' >&2
	done
	stty echo
	printf '%s' "$_a"
}

[ -d /sys/firmware/efi ] || die "UEFI rejimi tapılmadı. Dayanıldı."

INIT=$(ask "Init sistemi (openrc/dinit)" "openrc")

LANGCODE=$(ask "Locale (en_US, az_AZ, ...)" "en_US")
case "$LANGCODE" in
	az_AZ) KEYMAP=az ;;
	en_US) KEYMAP=us ;;
	*)     KEYMAP=$(printf '%s' "$LANGCODE" | cut -c1-2) ;;
esac
sudo loadkeys "$KEYMAP" 2>/dev/null || true

printf '\n'; lsblk -dpno NAME,SIZE,MODEL; printf '\n'
printf '\033[33mSeçilən disk TAMAMİLƏ silinəcək.\033[0m\n'
DISK=""
while [ ! -b "$DISK" ]; do DISK=$(ask "Hədəf disk (məs /dev/nvme0n1)" ""); done
case "$DISK" in
	*nvme*|*mmcblk*) P1="${DISK}p1"; P2="${DISK}p2" ;;
	*)               P1="${DISK}1";  P2="${DISK}2"  ;;
esac

FS=$(ask "Fayl sistemi (btrfs/ext4)" "btrfs")
SWAP=$(ask "Swap ölçüsü GiB (0 = yox)" "0")
CRYPT=$(ask "Diski şifrələ? (y/N)" "n")
if [ "$CRYPT" = y ]; then
	ROOT=/dev/mapper/root
	CRYPTPASS=$(ask_secret "disk şifrəsi")
else
	ROOT="$P2"
fi

TZ=$(ask "Zaman zonası" "Asia/Baku")
[ -f "/usr/share/zoneinfo/$TZ" ] || die "Zaman zonası tapılmadı: $TZ"
HOST=$(ask "Hostname" "artix")
ROOTPASS=$(ask_secret "root parolu")
USERNAME=$(ask "İstifadəçi adı (boş = yaratma)" "")
[ "$USERNAME" ] && USERPASS=$(ask_secret "$USERNAME parolu")

printf '\nQuraşdırma başlayır...\n\n'

sudo INIT="$INIT" DISK="$DISK" P1="$P1" P2="$P2" FS="$FS" SWAP="$SWAP" \
	CRYPT="$CRYPT" ROOT="$ROOT" CRYPTPASS="$CRYPTPASS" \
	sh ./src/installer.sh

sudo cp src/iamchroot.sh /mnt/root/iamchroot.sh
sudo INIT="$INIT" P2="$P2" FS="$FS" CRYPT="$CRYPT" CRYPTPASS="$CRYPTPASS" \
	TZ="$TZ" HOST="$HOST" ROOTPASS="$ROOTPASS" LANGCODE="$LANGCODE" KEYMAP="$KEYMAP" \
	USERNAME="$USERNAME" USERPASS="$USERPASS" \
	artix-chroot /mnt sh -ec 'sh /root/iamchroot.sh; rm -f /root/iamchroot.sh'

printf '\n\033[32mFaza 1 bitdi.\033[0m  poweroff → ISO-nu çıxart → sistemə aç.\n'
printf 'Sonra Faza 2 üçün: cd artix-base && ./src/desktop.sh\n'
