#!/bin/sh
#
# artix-base — Phase 2 (i3): i3 window manager + polybar + chsnv's configs.
# Copyright (c) 2025 Cosqun Hesenov.  MIT licensed (see LICENSE).
#
# Run as your normal user (NOT root), after the base system. Installs the i3
# stack (packages/i3.txt) and restores the vendored configs (config/i3,
# config/polybar) into ~/.config, backing up anything it would overwrite.

REPO="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PKGS="$REPO/packages/i3.txt"

[ "$(id -u)" -ne 0 ] || { printf 'root ilə işlətmə — normal (wheel) istifadəçi lazımdır.\n' >&2; exit 1; }
[ -f "$PKGS" ] || { printf 'tapılmadı: %s\n' "$PKGS" >&2; exit 1; }

printf '\n== 1/3 == i3 paketləri (%s)\n' "$(grep -cvE '^[[:space:]]*#|^[[:space:]]*$' "$PKGS")"
grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$PKGS" | sudo pacman -Syu --needed --noconfirm -

printf '\n== 2/3 == konfiglər -> ~/.config (köhnələr .bak.<ts>)\n'
mkdir -p "$HOME/.config"
ts=$(date +%s)
for d in i3 polybar; do
	[ -d "$REPO/config/$d" ] || continue
	[ -e "$HOME/.config/$d" ] && mv "$HOME/.config/$d" "$HOME/.config/$d.bak.$ts"
	cp -a "$REPO/config/$d" "$HOME/.config/$d"
	printf '  + ~/.config/%s\n' "$d"
done
chmod +x "$HOME"/.config/polybar/*.sh 2>/dev/null || true

printf '\n== 3/3 == sddm (i3 sessiyası seçilə bilsin)\n'
sudo rc-update add sddm default 2>/dev/null && printf '  + sddm\n' || printf '  sddm onsuz da / keçildi\n'

cat <<'EOF'

✅ i3 hazırdır.
   • sddm-də giriş ekranından sessiya = "i3" seç
   • AUR əlavələri (config istifadə edir): nitrogen · i3lock-fancy · siji-git
       yay -S nitrogen i3lock-fancy siji-git
   • bash-it istəsən:  git clone --depth=1 https://github.com/Bash-it/bash-it ~/.bash_it && ~/.bash_it/install.sh
   • Konfiglər: ~/.config/i3 , ~/.config/polybar
EOF
