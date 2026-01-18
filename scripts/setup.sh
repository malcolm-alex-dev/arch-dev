#!/bin/bash
#
# Post-install setup script
# Run after booting into new system
#
# Usage: ./scripts/setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[*]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

#--------------------------
# Install devbox
#--------------------------
install_devbox() {
    if command -v devbox &>/dev/null; then
        log "Devbox already installed"
        return
    fi
    
    log "Installing devbox..."
    curl -fsSL https://get.jetify.com/devbox | bash
}

#--------------------------
# Setup devbox global
#--------------------------
setup_devbox_global() {
    log "Setting up devbox global packages..."
    
    # Copy global config
    mkdir -p ~/.local/share/devbox/global/default
    cp "$DOTFILES_DIR/devbox-global.json" ~/.local/share/devbox/global/default/devbox.json
    
    # Install global packages
    devbox global install
    
    log "Devbox global packages installed"
}

#--------------------------
# Link dotfiles with stow
#--------------------------
link_dotfiles() {
    log "Linking dotfiles with stow..."
    
    cd "$DOTFILES_DIR/dotfiles"
    
    # Install stow if not present (should be in devbox global, but fallback)
    if ! command -v stow &>/dev/null; then
        warn "stow not found, installing via pacman..."
        sudo pacman -S --needed --noconfirm stow
    fi
    
    # Stow each package
    for dir in */; do
        dir="${dir%/}"
        log "  Linking $dir..."
        stow -v -R -t ~ "$dir"
    done
    
    log "Dotfiles linked"
}

#--------------------------
# Set zsh as default shell
#--------------------------
set_shell() {
    if [[ "$SHELL" == *"zsh"* ]]; then
        log "zsh already default shell"
        return
    fi
    
    log "Setting zsh as default shell..."
    chsh -s /bin/zsh
}

#--------------------------
# Enable services
#--------------------------
enable_services() {
    log "Enabling user services..."
    
    # Pipewire (usually auto-started by desktop, but ensure socket is enabled)
    systemctl --user enable --now pipewire.socket
    systemctl --user enable --now pipewire-pulse.socket
    systemctl --user enable --now wireplumber.service
}

#--------------------------
# Create devbox shell hook for direnv (optional)
#--------------------------
setup_direnv() {
    if ! command -v direnv &>/dev/null; then
        log "Skipping direnv setup (not installed)"
        return
    fi
    
    log "Setting up direnv..."
    
    # Add direnv hook to zshrc.local if not present
    local zshrc_local="$HOME/.zshrc.local"
    if ! grep -q "direnv hook zsh" "$zshrc_local" 2>/dev/null; then
        echo 'eval "$(direnv hook zsh)"' >> "$zshrc_local"
    fi
}

#--------------------------
# Final message
#--------------------------
finish() {
    echo ""
    log "Setup complete!"
    echo ""
    echo "To start Hyprland:"
    echo "  Log out and log back in, or run: Hyprland"
    echo ""
    echo "Your devbox global tools are ready. Run 'devbox global list' to see them."
    echo ""
    echo "For per-project environments, create a devbox.json in your project:"
    echo "  cd my-project && devbox init && devbox add go rust nodejs"
    echo ""
}

#--------------------------
# Main
#--------------------------
main() {
    log "Starting post-install setup..."
    log "Dotfiles directory: $DOTFILES_DIR"
    echo ""
    
    install_devbox
    setup_devbox_global
    link_dotfiles
    set_shell
    enable_services
    setup_direnv
    finish
}

main "$@"
