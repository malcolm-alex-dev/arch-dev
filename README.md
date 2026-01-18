# Minimal Arch Linux Setup

A lightweight, devbox-centric Arch Linux configuration for development workstations and servers.

## Philosophy

- **Minimal OS layer**: Arch provides only what devbox can't (kernel, drivers, display server, WM)
- **Devbox global**: All dev tools managed via Nix for reproducibility
- **Devbox local**: Per-project isolated environments
- **Dotfiles**: Managed with GNU stow for clean symlinking

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Per-Project: devbox.json (local shells)            │
│  (go, rust, nodejs, android-tools, etc.)            │
├─────────────────────────────────────────────────────┤
│  Global Dev Tools: devbox global                    │
│  (git, neovim, ripgrep, fd, fzf, lazygit, etc.)    │
├─────────────────────────────────────────────────────┤
│  System Essentials: pacman (~25 packages)           │
│  (hyprland, ghostty, waybar, pipewire, etc.)       │
├─────────────────────────────────────────────────────┤
│  Base: Arch Linux (LUKS + btrfs + snapshots)       │
└─────────────────────────────────────────────────────┘
```

## Components

| Layer | Tool | Purpose |
|-------|------|---------|
| WM | Hyprland | Wayland tiling compositor |
| Bar | Waybar | Status bar |
| Terminal | Ghostty | GPU-accelerated terminal |
| Shell | zsh + starship | Shell with modern prompt |
| Launcher | wofi | Application launcher |
| Notifications | mako | Notification daemon |
| Lock | hyprlock + hypridle | Screen lock and idle management |
| Dev tools | devbox global | Reproducible dev environment |
| Snapshots | snapper + snap-pac | Auto btrfs snapshots on updates |

## Installation

### Fresh Install (from Arch ISO)

1. Boot the Arch ISO

2. Connect to the network:
   ```bash
   # For WiFi
   iwctl
   # Then inside iwctl:
   #   station wlan0 scan
   #   station wlan0 get-networks
   #   station wlan0 connect <network-name>
   #   exit

   # For Ethernet (usually auto-connects, but if not):
   dhcpcd
   ```

3. Download and run the install script:
   ```bash
   curl -sL https://raw.githubusercontent.com/YOUR_USER/dotfiles/main/scripts/install.sh -o install.sh
   bash install.sh

   # Or for server variant:
   bash install.sh server
   ```

> **Note**: Download the script first rather than piping directly to bash. The installer has interactive prompts (especially for LUKS encryption) that can get hidden when piping.

### Post-Install Setup

After rebooting into the new system:

```bash
git clone https://github.com/YOUR_USER/dotfiles.git
cd dotfiles
./scripts/setup.sh
```

## Directory Structure

```
.
├── dotfiles/                    # Stow packages (each mirrors ~/)
│   ├── hyprland/
│   │   └── .config/hypr/        # hyprland.conf, hyprlock.conf, hypridle.conf
│   ├── waybar/
│   │   └── .config/waybar/      # config, style.css
│   ├── ghostty/
│   │   └── .config/ghostty/     # config
│   ├── mako/
│   │   └── .config/mako/        # config
│   ├── wofi/
│   │   └── .config/wofi/        # config, style.css
│   └── zsh/
│       └── .zshrc
├── scripts/
│   ├── install.sh               # Full system install (from Arch ISO)
│   └── setup.sh                 # Post-install setup (devbox + stow)
├── packages/
│   ├── desktop.txt              # Packages for desktop install
│   └── server.txt               # Packages for headless server
└── devbox-global.json           # Global devbox packages
```

## Using Stow

Dotfiles are managed with [GNU Stow](https://www.gnu.org/software/stow/). Each directory under `dotfiles/` is a "package" that mirrors your home directory structure.

```bash
cd dotfiles/dotfiles

# Link all packages
stow -t ~ */

# Link a single package
stow -t ~ hyprland

# Unlink a package
stow -D -t ~ hyprland

# Re-link (adopt existing files)
stow -R -t ~ hyprland
```

## Devbox Usage

### Global tools (always available)

```bash
# List global packages
devbox global list

# Add a global package
devbox global add tmux

# The shellenv is loaded in .zshrc automatically
```

### Per-project environments

```bash
cd my-project

# Initialize devbox
devbox init

# Add project-specific tools
devbox add go@1.22 gopls golangci-lint

# Enter the shell
devbox shell

# Or generate direnv integration
devbox generate direnv
```

### Example project devbox.json

```json
{
  "packages": [
    "go@1.22",
    "gopls",
    "golangci-lint"
  ],
  "shell": {
    "init_hook": ["echo 'Go environment ready'"]
  }
}
```

## Variants

### Desktop (default)
Full Hyprland setup with GUI tools, audio, and all the bells.

### Server
Headless, minimal packages. Same devbox global for consistent tooling.

```bash
./scripts/install.sh server
```

## Key Bindings (Hyprland)

| Key | Action |
|-----|--------|
| `Super + Return` | Open terminal (Ghostty) |
| `Super + Q` | Close window |
| `Super + Space` | App launcher (wofi) |
| `Super + H/J/K/L` | Focus left/down/up/right |
| `Super + Shift + H/J/K/L` | Move window |
| `Super + 1-9` | Switch workspace |
| `Super + Shift + 1-9` | Move window to workspace |
| `Super + V` | Toggle floating |
| `Super + F` | Toggle fullscreen |
| `Super + L` | Lock screen |
| `Print` | Screenshot region |
| `Shift + Print` | Screenshot full |

## Customization

1. Fork this repo
2. Edit `devbox-global.json` for your dev tools
3. Modify dotfiles to taste
4. Update `scripts/install.sh` with your hostname/username defaults
5. Commit and push

## Target Hardware

Originally configured for 2013 MacBook Pro 13" (Intel Iris graphics).
Should work on any x86_64 machine with Intel/AMD graphics.

For NVIDIA, you'll need to add nvidia drivers to `packages/desktop.txt` and configure Hyprland accordingly.
