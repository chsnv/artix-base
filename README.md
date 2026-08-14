# artix-base

Script-driven **Artix Linux (OpenRC)** setup, reproducible from scratch.
btrfs `@`/`@home`/`@var` · linux-zen + linux-lts · UEFI GRUB · KDE Plasma · PipeWire.

| # | Script | What |
|---|---|---|
| 1 · base | `install.sh` | partition · mount · basestrap · fstab · bootloader · user |
| 2 · desktop | `src/kde.sh` · `src/i3wm.sh` | KDE Plasma or i3 (packages + configs) |
| 3 · AUR | `src/aur.sh` | `yay` + `packages/aur.txt` |
| 4 · dotfiles | `src/dotfiles.sh` | zsh + KDE config (secrets scrubbed) |
| 5 · snapshots | `src/snapshots.sh` | snapper + snap-pac + grub-btrfs |

## 1 — base (Artix live ISO)

Boot the OpenRC ISO (login `artix` / `artix`). Ethernet is automatic; for Wi‑Fi:

```sh
# connman (default on the live ISO)
connmanctl
  enable wifi
  scan wifi
  services                          # -> wifi_xxxx_xxxx_managed_psk
  agent on
  connect wifi_xxxx_xxxx_managed_psk
  quit
```
```sh
# or wpa_supplicant
rfkill unblock wifi
ip link set wlan0 up
wpa_passphrase "SSID" "PASSWORD" > /etc/wpa_supplicant.conf
wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant.conf
dhcpcd wlan0
```

Then install:
```sh
git clone https://github.com/chsnv/artix-base.git
cd artix-base && ./install.sh
```
`poweroff`, remove the ISO, boot. ESP size / mount options: top of `src/installer.sh`.

## 2–5 — after first boot

Log in as your user (not root):
```sh
cd artix-base
./src/kde.sh               # KDE Plasma   (or ./src/i3wm.sh for i3 + polybar)
./src/aur.sh               # yay + AUR packages
./src/dotfiles.sh restore  # zsh + KDE config
./src/snapshots.sh         # snapper + grub-btrfs
```

- Missing desktop packages → enable `artix-archlinux-support` + `[lib32]` in `/etc/pacman.conf`.
- Secrets live in `~/.zshrc.local` (gitignored); see `dotfiles/.zshrc.local.example`.
- Snapshots → reboot, pick **Artix snapshots** in GRUB; roll back with `sudo snapper rollback`.

## Package lists

From the real machine: `kde.txt` (`pacman -Qqen`), `aur.txt` (`-Qqem`),
`services-openrc.txt` (enabled services), `dotfiles.list` (tracked configs).
i3: `i3.txt` + `config/i3` + `config/polybar` (custom, vendored).

MIT © 2025 Cosqun Hesenov
