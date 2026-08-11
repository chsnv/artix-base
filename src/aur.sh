#!/bin/sh
#
# artix-base — Phase 3: AUR helper (yay) + AUR packages.
# Copyright (c) 2025 Cosqun Hesenov.  MIT licensed (see LICENSE).
#
# Run as your normal user (NOT root), after Phase 2. Builds yay from the AUR,
# then installs packages/aur.txt. AUR packages compile from source — expect time.

REPO="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
AUR="$REPO/packages/aur.txt"

[ "$(id -u)" -ne 0 ] || { printf 'root ilə işlətmə — normal (wheel) istifadəçi lazımdır.\n' >&2; exit 1; }
[ -f "$AUR" ] || { printf 'tapılmadı: %s\n' "$AUR" >&2; exit 1; }

# --- 1) bootstrap yay if not already present ---
if command -v yay >/dev/null 2>&1; then
	printf 'yay artıq var: %s\n' "$(command -v yay)"
else
	printf '\n== yay AUR-dan qurulur (go, base-devel lazım) ==\n'
	sudo pacman -S --needed --noconfirm base-devel git go
	tmp=$(mktemp -d)
	git clone --depth=1 https://aur.archlinux.org/yay.git "$tmp/yay"
	( cd "$tmp/yay" && makepkg -si --noconfirm )
	rm -rf "$tmp"
fi

# --- 2) install AUR set one by one (one failure must not stop the rest) ---
printf '\n== AUR paketləri (%s) ==\n' "$(grep -cve '^[[:space:]]*$' "$AUR")"
failed=""
while read -r pkg; do
	case "$pkg" in ''|\#*|yay) continue ;; esac   # skip blanks / comments / yay itself
	printf '\n--- %s ---\n' "$pkg"
	if yay -S --needed --noconfirm --removemake --answerdiff None --answerclean None "$pkg"; then
		:
	else
		failed="$failed $pkg"
	fi
done < "$AUR"

printf '\n'
if [ "$failed" ]; then
	printf '⚠ uğursuz (əl ilə bax — PGP açarı / ad dəyişikliyi ola bilər):%s\n' "$failed"
	exit 1
fi
printf '✅ Faza 3 bitdi — bütün AUR paketləri quruldu.\n'
