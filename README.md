# arch-dotfiles

Bootstrap and configuration for my Arch Linux workstation: Hyprland, Waybar,
Walker, Ghostty, Neovim, Docker and mise, with configs managed by
GNU Stow.

## Assumed base system

Installed with `archinstall` using:

- Minimal profile, x86-64, physical machine
- Btrfs on LUKS, systemd-boot with a Unified Kernel Image
- NetworkManager, PipeWire, zram
- `git`, `base-devel`, `openssh` selected during install
- A regular user with sudo rights (the installer refuses to run as root)

The installer never touches partitions, LUKS, the bootloader, the kernel or
networking. Everything it does is additive: install packages, enable services,
link dotfiles.

## Fresh machine bootstrap

Log in as your user on a TTY with a network connection, then:

```bash
curl -fsSL https://raw.githubusercontent.com/coreymcmahon/arch-dotfiles/main/bootstrap.sh | bash
```

This clones the repo over HTTPS (no SSH key needed) into
`~/Code/coreymcmahon/arch-dotfiles` and runs `install.sh`. To preview first:

```bash
curl -fsSL https://raw.githubusercontent.com/coreymcmahon/arch-dotfiles/main/bootstrap.sh | bash -s -- --dry-run
```

When it finishes, log out and back in (docker group, mise activation), then
start the desktop from the TTY:

```bash
Hyprland
```

Afterwards, switch the remote to SSH once your keys are in place:

```bash
git -C ~/Code/coreymcmahon/arch-dotfiles remote set-url origin git@github.com:coreymcmahon/arch-dotfiles.git
```

## Stages

```bash
./install.sh                       # all default stages, in order
./install.sh --stage desktop       # one stage (repeatable)
./install.sh --from development    # resume from a stage to the end
./install.sh --dry-run             # print planned actions, change nothing
./install.sh --list                # show stages and their scripts
./install.sh --stage dotfiles hypr waybar   # only these stow groups
./install.sh --backup-conflicts    # see "Dotfiles" below
./install.sh --interactive         # let pacman/yay prompt (no --noconfirm)
```

| Stage         | Script                     | What it does |
|---------------|----------------------------|--------------|
| `system`      | `stages/10-system.sh`      | `pacman -Syu` full upgrade, then `packages/system.txt` (CLI baseline, Ghostty, tmux, Neovim, Stow) |
| `aur`         | `stages/20-aur.sh`         | Build `yay-bin` as your user, then `packages/aur.txt` (Walker + elephant providers, Brave, 1Password, Slack, TablePlus, Claude Code, blueberry, iA Writer font, Catppuccin theme) |
| `desktop`     | `stages/30-desktop.sh`     | Detect GPU vendor and install drivers, then `packages/desktop.txt` (greetd + tuigreet, Hyprland stack, Waybar, Mako, Dolphin extras, keyring, udiskie, Obsidian, Spotify, Tailscale, fonts, portals) |
| `development` | `stages/40-development.sh` | Docker, mise, PHP build libraries; `mise use --global node@lts php@latest go@latest` |
| `dotfiles`    | `stages/50-dotfiles.sh`    | Stow the groups in `packages/stow.txt` into `$HOME`; create empty `~/.bashrc.secrets` / `~/.bash_profile.secrets` (mode 600); `xdg-user-dirs-update` |
| `services`    | `stages/60-services.sh`    | Install `etc/greetd/config.toml` and enable `greetd` (tty1 login, starts on next boot); install Brave managed policies to `/etc/brave/policies/managed`; enable `tailscaled.service`; unlock gnome-keyring via PAM and enable the gcr SSH agent; enable `docker.service`, `bluetooth.service`, PipeWire user units; add you to the `docker` and `video` (backlight) groups |
| `optional`    | `stages/90-optional.sh`    | Not run by default: `packages/optional.txt` (alacritty, kvantum, hyprpm, pigz) |

Every stage is independently runnable (`stages/30-desktop.sh` works directly)
and idempotent: packages already present are skipped (`pacman -T` handles
`provides`), services already enabled are left alone, stowed links are
re-stowed. Scripts work from any working directory.

Package installs always go through `pacman -Syu --needed` the first time in a
run and `pacman -S --needed` afterwards, never `pacman -Sy`, so the system is
never left partially upgraded. AUR builds run as your user; `sudo` is used
only for pacman, systemctl and usermod.

## Package inventory

Declarative lists under `packages/`, one or more names per line, `#` comments:

| File                | Installed by  | Contents |
|---------------------|---------------|----------|
| `system.txt`        | system        | Official: shell tools, editors, Ghostty, tmux, Stow, Neovim helpers |
| `desktop.txt`       | desktop       | Official: Hyprland ecosystem, Waybar, Mako, fonts, Qt/Wayland, Dolphin, Bluetooth, PipeWire, Obsidian, spotify-launcher, Tailscale |
| `gpu-{amd,intel,nvidia,virtual}.txt` | desktop | Official: drivers chosen by PCI vendor detection |
| `aur.txt`           | aur           | AUR: `walker-bin`, `elephant-bin` and providers, `brave-bin`, `1password`, `slack-desktop`, `tableplus`, `claude-code`, `blueberry`, `ttf-ia-writer`, Catppuccin Macchiato GTK theme and cursors |
| `development.txt`   | development   | Official: Docker, mise, PHP build dependencies, shellcheck/shfmt |
| `optional.txt`      | optional      | Official extras (alacritty, kvantum, ...) |
| `stow.txt`          | dotfiles      | Stow groups to link, in order |

All names were verified against the official repos and AUR on 2026-10-19.
Notable mappings: `hyprshot`
moved from the AUR to `extra`; `hyprland-qtutils` was replaced by
`hyprland-guiutils` (a hard dependency of `hyprland`); `libva-mesa-driver`
was merged into `mesa`; `nvidia-dkms` is gone in favour of `nvidia-open-dkms`.

### Adding a package

1. Add the name to the right `packages/*.txt`. Check it exists first:
   `pacman -Si NAME` (official) or `yay -Si NAME` (AUR). Prefer official.
2. Run `tests/run.sh` (catches duplicates, typos and obsolete names).
3. Run the matching stage: `./install.sh --stage desktop`.

## Dotfiles

Each top-level directory (`alacritty`, `bash`, `brave`, `ghostty`, `gtk`, `hypr`,
`mako`, `nvim`, `scripts`, `spotify`, `tmux`, `waybar`) is a Stow package mirroring `$HOME`. The default
set is in `packages/stow.txt`; `alacritty` is an opt-in alternative to Ghostty.

```bash
./install.sh --stage dotfiles              # everything in packages/stow.txt
./install.sh --stage dotfiles nvim         # one group
./install.sh --stage dotfiles alacritty    # opt-in group
stow -D --target ~ alacritty               # unlink a group (run from the repo)
```

Existing files are never overwritten:

- A file identical to its `/etc/skel` default (the `.bashrc` archinstall
  creates) is moved to `~/.dotfiles-backup/<timestamp>/` automatically.
- Anything else is reported, the group is skipped and the stage exits
  non-zero. Merge the differences by hand, or rerun with
  `--backup-conflicts` to move the files to `~/.dotfiles-backup/` first.
- Links that already point into this repo are fine; `--restow` refreshes them.

### Secrets

Anything sensitive lives outside the repo in two git-ignored files:

| File                      | Sourced by           | Put here |
|---------------------------|----------------------|----------|
| `~/.bash_profile.secrets` | `bash/.bash_profile` | `export` statements (tokens such as `NPM_TOKEN`) so GUI apps and the Hyprland session inherit them |
| `~/.bashrc.secrets`       | `bash/.bashrc`       | private aliases and functions for interactive shells |

The dotfiles stage creates both files empty with mode 600 and never touches
them again. `.gitignore` excludes `*.secrets*`, so they cannot be committed.

### Shell aliases

`bash/.bashrc` defines the shell shortcuts: git (`g`, `ga`, `gd`, `gdc`, `gc`,
`gch`, `gs`, `gb`, `pull`, `push`, `pullc`, `pushc`, `co`), Laravel (`s`,
`art`), npm (`ni`, `nrd`), Neovim (`vi`, `vim`), `q`, `ss` (ssh with
`TERM=xterm-256color` for hosts without the Ghostty terminfo) and `killdns`,
which flushes systemd-resolved if it is in use. `bash/.inputrc` adds the Alt+Left/Right word
movement bindings. `~/.local/bin` is on `PATH` via `bash/.bash_profile`.

### Applications

Desktop applications: Obsidian, Spotify (`spotify-launcher`
downloads the client; `spotify/` passes the Wayland flags), Tailscale
(`tailscaled.service` is enabled by the services stage; join with
`sudo tailscale up`), 1Password (started in the tray by hyprland.conf),
Slack, TablePlus and Claude Code (`claude`, used by
`scripts/.local/bin/aicommit`). tmux is installed with its config stowed from
`tmux/`. `EDITOR` and `VISUAL` are set to `nvim` in `bash/.bash_profile`.

### Brave

`brave-bin` is installed by the aur stage and bound to SUPER+B. Its
configuration has three parts:

- `etc/brave/policies/managed/policies.json` (installed by the services stage):
  Rewards, Wallet, VPN, Leo AI and News off; third-party cookies blocked;
  telemetry (metrics, URL-keyed data, P3A, stats ping), search suggestions and
  cloud spell-check off; background mode and the default-browser nag off;
  incognito and devtools kept. Every key was checked against Brave's and
  Chromium's policy templates (checked 2026-10-19). Do Not Track has no
  policy, so `brave-setup` sets it per profile. Check `brave://policy`;
  unknown names show up there as errors.
- `brave/.config/brave-flags.conf`: native Wayland, passwords in
  gnome-keyring, two-finger swipe navigation.
- `scripts/.local/bin/brave-setup`: patches every profile's `Preferences`
  (toolbar and new-tab cleanup, devtools undocked with source maps, autofill
  off, memory saver on) and sets Brave as the default browser. Run it once
  with Brave closed after the first launch has created a profile.

### Adding a configuration

```bash
mkdir -p newapp/.config/newapp
mv ~/.config/newapp/config.toml newapp/.config/newapp/
echo newapp >> packages/stow.txt
./install.sh --stage dotfiles newapp
```

## GPU drivers

The desktop stage reads `/sys/bus/pci/devices/*/class` and installs:

| Vendor  | Packages |
|---------|----------|
| AMD     | `mesa vulkan-radeon` |
| Intel   | `mesa vulkan-intel intel-media-driver` (Broadwell+; older iGPUs need `libva-intel-driver`) |
| NVIDIA  | `nvidia-open-dkms nvidia-utils` plus `<kernel>-headers` for each installed kernel |
| VM/other| `mesa` |

Override detection with `GPU_VENDORS="amd nvidia" ./install.sh --stage desktop`.

NVIDIA notes:

- `nvidia-open-dkms` supports Turing (GTX 16xx / RTX 20xx) and newer. Older
  cards need a legacy driver from the AUR (e.g. `nvidia-580xx-dkms`).
- DKMS rebuilds the module on kernel updates and `mkinitcpio` regenerates the
  UKI automatically. Nothing in the boot configuration is changed.
- Hyprland on NVIDIA usually wants these in `hyprland.conf`
  (not enabled by default because they break other GPUs):

  ```
  env = LIBVA_DRIVER_NAME,nvidia
  env = __GLX_VENDOR_LIBRARY_NAME,nvidia
  env = NVD_BACKEND,direct
  ```

  See https://wiki.hyprland.org/Nvidia/ for the current list.

## Updating and maintaining

```bash
sudo pacman -Syu && yay -Syu          # system + AUR
mise upgrade                          # Node/PHP/Go to newer versions
git -C ~/Code/coreymcmahon/arch-dotfiles pull && ./install.sh   # pick up repo changes
nvim +Lazy sync +qa                   # Neovim plugins
```

Re-running `./install.sh` after a pull is the intended way to apply new
packages or configs. The development stage does not rebuild `php@latest` on
every run; use `mise upgrade` when you want a newer PHP.

## Recovering from a partial run

A failing stage prints why, how long it ran and the exact resume command:

```
ERROR: Stage 'desktop' failed (exit 1) after 42s.
    Fix the problem above, then resume with:
      /home/you/Code/coreymcmahon/arch-dotfiles/install.sh --from desktop
```

Because every stage is idempotent you can also simply rerun `./install.sh`.
Common cases:

- **Network/mirror hiccup during pacman**: rerun the stage.
- **AUR build failure**: inspect `yay`'s output; rerun `--stage aur`. If the
  AUR package's name changed, fix `packages/aur.txt`.
- **Stow conflicts**: see "Dotfiles" above.
- **PHP compile failure**: `mise install php@latest` with the error visible;
  missing headers mean a package is absent from `packages/development.txt`.
- **No sudo session / wrong user**: the installer refuses root; run it as your
  normal user.

## Tests and checks

```bash
tests/run.sh                 # syntax check, shellcheck (if installed), unit tests
./install.sh --dry-run       # end-to-end dry run; safe on any machine
docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable -x \
  install.sh bootstrap.sh lib/*.sh stages/*.sh tests/*.sh tests/stubs/*
```

The tests need bash >= 4 and GNU Stow. They stub `pacman`, `yay`, `sudo`,
`systemctl`, `mise` and `usermod` (see `tests/stubs/`) and run the dotfiles
stage with real Stow against a throwaway `$HOME`, so nothing on the machine
running them is modified. They cover argument parsing, cwd independence,
package inventories, install/skip logic, GPU detection, service idempotency,
stow conflict handling and the bootstrap clone.

## Layout

```
install.sh        stage runner and CLI
bootstrap.sh      curl | bash entry point (HTTPS clone, then install.sh)
lib/common.sh     logging, dry-run wrappers, pacman/yay/systemd helpers, GPU detection
lib/stow.sh       conflict detection, backups, (re)stow
stages/*.sh       one script per stage, runnable on their own
packages/*.txt    declarative package and stow inventories
etc/              system files installed by the services stage (greetd, Brave policies)
tests/            test suite and command stubs
<group>/          Stow packages (alacritty, bash, brave, ghostty, gtk, hypr, mako, nvim, scripts, spotify, tmux, waybar)
```
