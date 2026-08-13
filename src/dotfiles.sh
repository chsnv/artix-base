#!/bin/sh
#
# artix-base — Phase 4: dotfiles capture / restore (secret-safe).
# Copyright (c) 2025 Cosqun Hesenov.  MIT licensed (see LICENSE).
#
# usage:
#   ./src/dotfiles.sh capture   # $HOME -> repo/dotfiles/  (scrubs secrets)
#   ./src/dotfiles.sh restore   # repo/dotfiles/ -> $HOME  (backs up existing)
#
# The repo is PUBLIC: capture redacts anything secret-looking and then refuses
# to keep the result if a real secret survives. Real secrets belong in the
# untracked ~/.zshrc.local (see dotfiles/.zshrc.local.example).

REPO="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
LIST="$REPO/packages/dotfiles.list"
STORE="$REPO/dotfiles"

# secret detectors
NAME='(SECRET|SSHPASS|PASSWORD|PASSWD|TOKEN|API[_-]?KEY|ACCESS[_-]?KEY|CREDENTIAL|PRIVATE[_-]?KEY)'
VAL='ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|://[^/@[:space:]]+:[^/@[:space:]]+@'

scrub() {  # redact secret assignments and token-like values, in place
	sed -i -E "s#^([[:space:]]*(export[[:space:]]+)?[A-Za-z0-9_]*${NAME}[A-Za-z0-9_]*=).*#\1REDACTED#I" "$1"
	sed -i -E "s#(${VAL})#REDACTED#g" "$1"
}

capture() {
	rm -rf "$STORE"; mkdir -p "$STORE"

	# list redacted var NAMES (for the .local example) before scrubbing
	{
		echo "# Copy to ~/.zshrc.local and fill in real values. Gitignored — never commit."
		for s in "$HOME/.zshrc" "$HOME/.bashrc"; do
			[ -f "$s" ] && grep -hoiE "^[[:space:]]*(export[[:space:]]+)?[A-Za-z0-9_]*${NAME}[A-Za-z0-9_]*=" "$s"
		done | sed -E 's/[[:space:]]+/ /g' | sort -u
	} > "$STORE/.zshrc.local.example"

	while read -r rel; do
		case "$rel" in ''|\#*) continue ;; esac
		src="$HOME/$rel"
		[ -e "$src" ] || { printf '  -  yox: %s\n' "$rel"; continue; }
		dest="$STORE/$rel"
		mkdir -p "$(dirname "$dest")"
		cp -a "$src" "$dest"
		case "$rel" in
			.zshrc|.bashrc|.bash_profile|.profile|.zshenv|.zprofile|.gitconfig) scrub "$dest" ;;
		esac
		printf '  +  %s\n' "$rel"
	done < "$LIST"

	# source-guard so secrets load from the untracked local file
	for rc in "$STORE/.zshrc" "$STORE/.bashrc"; do
		[ -f "$rc" ] || continue
		grep -q '.zshrc.local' "$rc" 2>/dev/null || \
			printf '\n# local, untracked secrets\n[ -f ~/.zshrc.local ] && . ~/.zshrc.local\n' >> "$rc"
	done

	# SAFETY NET — refuse to keep any surviving secret
	leak=0
	grep -rIEn --exclude='.zshrc.local.example' "$VAL" "$STORE" 2>/dev/null && leak=1
	grep -rIEn --exclude='.zshrc.local.example' "^[[:space:]]*(export[[:space:]]+)?[A-Za-z0-9_]*${NAME}[A-Za-z0-9_]*=[^[:space:]]" "$STORE" 2>/dev/null \
		| grep -viE 'REDACTED' && leak=1
	if [ "$leak" -ne 0 ]; then
		printf '\n‼️  SIRR AŞKARLANDI — dotfiles/ silinir. COMMIT ETMƏ.\n' >&2
		rm -rf "$STORE"; exit 1
	fi
	printf '\n✅ capture bitdi — scrub + təhlükəsizlik-skanı təmiz.\n'
}

restore() {
	[ -d "$STORE" ] || { printf 'dotfiles/ yoxdur — əvvəlcə capture.\n' >&2; exit 1; }
	ts=$(date +%Y%m%d-%H%M%S); bak="$HOME/.dotfiles-backup/$ts"
	find "$STORE" -type f | while read -r f; do
		rel=${f#"$STORE"/}
		dst="$HOME/$rel"
		if [ -e "$dst" ]; then mkdir -p "$bak/$(dirname "$rel")"; cp -a "$dst" "$bak/$rel"; fi
		mkdir -p "$(dirname "$dst")"; cp -a "$f" "$dst"
		printf '  ->  %s\n' "$rel"
	done
	printf '\n✅ restore bitdi. Köhnələr: %s\n' "$bak"
	printf '⚠  Sirlər üçün ~/.zshrc.local yarat (bax dotfiles/.zshrc.local.example).\n'
}

case "${1:-}" in
	capture) capture ;;
	restore) restore ;;
	*) printf 'usage: %s capture|restore\n' "$0" >&2; exit 2 ;;
esac
