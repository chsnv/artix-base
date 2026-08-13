# artix-base

![](https://img.shields.io/badge/OS-Artix%20Linux-blue?logo=Artix+Linux)

My personal, script-driven **Artix Linux (OpenRC)** setup — reproducible from scratch.

**Layout:** btrfs `@` / `@home` / `@var` · NetworkManager · GRUB (ESP at `/boot/efi`) ·
`linux-zen` + `linux-lts` · KDE Plasma · PipeWire.

## Phases

| Phase | Script | What |
|---|---|---|
| **1 — base** | `install.sh` → `src/installer.sh` + `src/iamchroot.sh` | partition, mount, basestrap, fstab, hosts, bootloader, user |
| **2 — desktop** | `src/desktop.sh` | KDE Plasma + apps (`packages/desktop.txt`), PipeWire, enable services |
| **3 — AUR** | `src/aur.sh` | bootstrap `yay` + `packages/aur.txt` |
| **4 — dotfiles** | `src/dotfiles.sh` | zsh + KDE config (secrets scrubbed) |
| **5 — snapshots** | `src/snapshots.sh` | snapper + snap-pac + grub-btrfs (OpenRC) |

## Phase 1 — base (from the Artix live ISO)

1. Boot the Artix **OpenRC** live ISO (user & password: `artix`).
2. Get online — Ethernet is automatic; Wi‑Fi via `connmanctl` or `nmcli`.
3. Clone and run:
   ```sh
   git clone https://github.com/chsnv/artix-base.git
   cd artix-base
   ./install.sh
   ```
4. `poweroff`, remove the ISO, boot into the installed system.

ESP size and btrfs mount options are variables at the top of `src/installer.sh`.

## Phase 2 — desktop (after first boot)

Log in as your user, then:
```sh
cd artix-base
./src/desktop.sh
```
Installs `packages/desktop.txt`, sets up PipeWire, and enables the services in
`packages/services-openrc.txt` (sddm, cupsd, …). Reboot into Plasma.

> Some packages live in Arch's `extra`/`multilib`. If any are reported missing,
> install `artix-archlinux-support` and enable `[lib32]` in `/etc/pacman.conf`,
> then re-run.

## Phase 3 — AUR (after the desktop)

As your user (not root):
```sh
cd artix-base
./src/aur.sh
```
Builds `yay` from the AUR (needs `go`, `base-devel`), then installs
`packages/aur.txt` one by one. AUR packages compile from source — expect time;
any that fail (e.g. missing PGP key) are listed at the end for manual fixing.

## Phase 4 — dotfiles

```sh
./src/dotfiles.sh capture   # $HOME -> dotfiles/  (redacts secrets, then verifies)
./src/dotfiles.sh restore   # dotfiles/ -> $HOME  (backs up what it overwrites)
```
Tracked paths are listed in `packages/dotfiles.list` (curated, safe). This repo is
**public**, so capture scrubs anything secret-looking and refuses to keep the result
if a real secret survives. Put real secrets in `~/.zshrc.local` (gitignored) — see
`dotfiles/.zshrc.local.example`.

## Phase 5 — snapshots (after the desktop)

As your user (not root):
```sh
./src/snapshots.sh
```
Creates a dedicated `@snapshots` subvolume mounted at `/.snapshots`, a snapper
`root` config, automatic pre/post snapshots on every `pacman` transaction
(`snap-pac`), and the GRUB snapshot submenu. Because OpenRC ships none of
snapper's systemd timers, it also installs an OpenRC `grub-btrfsd` service
(the Artix package provides only the binary) and an hourly cron cleanup.

Reboot → pick **Artix snapshots** in GRUB to boot a snapshot; roll back with
`sudo snapper rollback` then reboot.

## Package lists

Generated from the real machine:
- `packages/desktop.txt` — explicit repo packages (`pacman -Qqen`, minus the base set)
- `packages/aur.txt` — explicit AUR/foreign packages (`pacman -Qqem`)
- `packages/services-openrc.txt` — enabled OpenRC services (default runlevel)

## License

MIT © 2025 Cosqun Hesenov — see [LICENSE](LICENSE).
