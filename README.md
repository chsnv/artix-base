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
| **3 — AUR** | _(todo)_ | bootstrap `yay` + `packages/aur.txt` |
| **4 — dotfiles** | _(todo)_ | zsh / oh-my-zsh + KDE config |

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

## Package lists

Generated from the real machine:
- `packages/desktop.txt` — explicit repo packages (`pacman -Qqen`, minus the base set)
- `packages/aur.txt` — explicit AUR/foreign packages (`pacman -Qqem`)
- `packages/services-openrc.txt` — enabled OpenRC services (default runlevel)

## License

MIT © 2025 Cosqun Hesenov — see [LICENSE](LICENSE).
