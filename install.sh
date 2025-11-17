#!/bin/bash
#
# This script creates a development environment in a persistent-HOME, ephemeral-system
# environment of Google Cloud Shell.
#
# It performs two main functions:
# 1. PERSISTENT SETUP: Installs all user-level configurations, dotfiles, and pre-compiled
#    binaries into the $HOME directory. This is done only once.
# 2. EPHEMERAL SETUP SCRIPT: Creates the `$HOME/.customize_environment` script, which
#    Cloud Shell executes as root on every startup. This script handles the installation
#    of system-level packages via `apt`.

set -e # Exit immediately if a command exits with a non-zero status.

# --- Helper Functions ---
info() {
    echo "[INFO] $1"
}

warn() {
    echo "[WARN] $1"
}

error() {
    echo "[ERROR] $1"
    exit 1
}

# --- Pre-flight Checks ---
if [ "$EUID" -eq 0 ]; then
    error "This script should not be run as root. Run it as your normal user."
fi

# --- Persistent Setup Functions ---

# 1. Create basic configurations and dotfiles
setup_configs_and_dotfiles() {
    info "Creating dotfiles and configurations..."
    local SCRIPT_DIR
    SCRIPT_DIR="$(dirname "$0")"
    local DOTFILES_DIR="$SCRIPT_DIR/dotfiles"

    if [ ! -d "$DOTFILES_DIR" ]; then
        warn "  - Dotfiles directory not found at $DOTFILES_DIR. Skipping."
        return
    fi

    # Copy dotfiles (e.g., .bashrc, .vimrc)
    find "$DOTFILES_DIR" -maxdepth 1 -type f -name ".*" -exec cp {} "$HOME/" \;
    info "  - Dotfiles copied."

    # Copy dot directories (e.g., .config, .gemini)
    find "$DOTFILES_DIR" -maxdepth 1 -type d -name ".*" -exec cp -r {} "$HOME/" \;
    info "  - Dot directories copied."

# 2. Install shell enhancements
install_shell_enhancements() {
    info "Installing shell enhancements..."
    local SCRIPT_DIR
    SCRIPT_DIR="$(dirname "$0")"

    # fancy-git
    info "  - Forcefully re-installing fancy-git to ensure correctness..."
    rm -rf "$HOME/.fancy-git"
    git clone https://github.com/diogocavilha/fancy-git.git "$HOME/.fancy-git"
    # Answer 'n' to font installation, but 'y' to everything else.
    printf 'n\ny\ny\n' | bash "$HOME/.fancy-git/install.sh"
    info "  - fancy-git installed."

    # Tmux Plugin Manager (TPM)
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
        info "  - Tmux Plugin Manager (TPM) installed."
    else
        info "  - TPM already installed. Skipping."
    fi
    
    info "  - Installing tmux plugins..."
    if [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
        tmux run-shell "$HOME/.tmux/plugins/tpm/bin/install_plugins"
        info "    - Tmux plugins installed."
    else
        warn "    - TPM plugin installer not found. Skipping."
    fi
}

# 3. Install resterm
install_resterm() {
    info "Installing resterm using its official installer script..."
    if command -v resterm &> /dev/null; then
        info "  - resterm already installed. Skipping."
    else
        curl -fsSL https://raw.githubusercontent.com/unkn0wn-root/resterm/main/install.sh | bash
        info "  - resterm installed."
    fi
}

# 4. Install NVM and Node.js
setup_nvm_and_node() {
    info "Setting up NVM and Node.js..."
    export NVM_DIR="$HOME/.nvm"

    if [ -d "$NVM_DIR" ]; then
        info "  - NVM already installed. Skipping installation."
    else
        info "  - Installing NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    fi

    # Run nvm in a subshell to source it correctly
    (
        # shellcheck source=/dev/null
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

        info "  - Installing latest Node.js..."
        nvm install node
        nvm alias default node
        nvm use node
        info "  - Latest Node.js installed and set as default."
    )

download_file() {
    local url="$1"
    local output_path="$2"
    info "    - Downloading $url..."
    if wget -O "$output_path" "$url"; then
        return 0 # Success
    else
        warn "    - FAILED to download $url. Please manually upload it to $output_path and re-run."
        # Clean up the failed download file if it exists and is empty
        [ -f "$output_path" ] && [ ! -s "$output_path" ] && rm "$output_path"
        return 1 # Failure
    fi
}

is_binary_installed() {
    [ -x "$HOME/.local/bin/$1" ]
}

# 5. Install persistent binaries
install_persistent_binaries() {
    info "Installing user-level binaries into ~/.local/bin..."
    local BIN_DIR="$HOME/.local/bin"
    local SCRIPT_DIR
    SCRIPT_DIR="$(dirname "$0")"
    mkdir -p "$BIN_DIR"

    # --- Neovim ---
    if is_binary_installed "nvim"; then
        info "  - Neovim already installed. Skipping."
    else
        info "  - Installing Neovim from local archive..."
        local nvim_archive="$SCRIPT_DIR/bin/nvim-linux-x86_64.tar.gz"
        if [ -f "$nvim_archive" ]; then
            tar -xzf "$nvim_archive" -C "$HOME/.local/" --strip-components=1
            info "    - Neovim installed."
        else
            warn "    - Neovim archive not found at $nvim_archive. Skipping Neovim installation."
        fi
    fi

    # --- Lazygit ---
    if is_binary_installed "lazygit"; then
        info "  - Lazygit already installed. Skipping."
    else
        info "  - Installing Lazygit..."
        local lazygit_url
        lazygit_url=$(grep "lazygit" packages/binaries.list)
        if download_file "$lazygit_url" "/tmp/lazygit.tar.gz"; then
            tar -xzf "/tmp/lazygit.tar.gz" -C "$BIN_DIR/" lazygit
            rm "/tmp/lazygit.tar.gz"
            info "    - Lazygit installed."
        fi
    fi

    # --- Yazi ---
    if is_binary_installed "yazi"; then
        info "  - Yazi already installed. Skipping."
    else
        info "  - Installing Yazi..."
        local yazi_url
        yazi_url=$(grep "yazi" packages/binaries.list)
        if download_file "$yazi_url" "/tmp/yazi.zip"; then
            rm -rf /tmp/yazi-unzipped
            unzip -oqd "/tmp/yazi-unzipped" "/tmp/yazi.zip"
            mv /tmp/yazi-unzipped/yazi-*/yazi "$BIN_DIR/"
            rm "/tmp/yazi.zip"
            rm -rf "/tmp/yazi-unzipped"
            info "    - Yazi installed."
        fi
    fi

    # --- 7zip ---
    if is_binary_installed "7zz"; then
        info "  - 7zip (7zz) already installed. Skipping."
    else
        info "  - Installing 7zip..."
        local sevenzip_url
        sevenzip_url=$(grep "7z2501" packages/binaries.list)
        if download_file "$sevenzip_url" "/tmp/7zip.tar.xz"; then
            tar -xf "/tmp/7zip.tar.xz" -C "$BIN_DIR/" 7zz
            rm "/tmp/7zip.tar.xz"
            info "    - 7zip installed."
        fi
    fi

    # --- Fastfetch ---
    if is_binary_installed "fastfetch"; then
        info "  - Fastfetch already installed. Skipping."
    else
        info "  - Installing Fastfetch from local archive..."
        local fastfetch_archive="$SCRIPT_DIR/bin/fastfetch-linux-amd64.tar.gz"
        if [ -f "$fastfetch_archive" ]; then
            tar -xzf "$fastfetch_archive" -C "/tmp/"
            mv "/tmp/fastfetch-linux-amd64/fastfetch" "$BIN_DIR/"
            rm -rf "/tmp/fastfetch-linux-amd64"
            info "    - Fastfetch installed."
        else
            warn "    - Fastfetch archive not found at $fastfetch_archive. Skipping Fastfetch installation."
        fi
    fi

# 6. Create the startup script
create_startup_script() {
    info "Creating the startup script for tty-clock..."
    local SCRIPT_DIR
    SCRIPT_DIR="$(dirname "$0")"

    rm -f "$HOME/.customize_environment"
    cp "$SCRIPT_DIR/scripts/customize_environment.sh" "$HOME/.customize_environment"
    chmod +x "$HOME/.customize_environment"
    info "  - Successfully created ~/.customize_environment for tty-clock."
}

# --- Main Execution ---
main() {
    info "Starting persistent environment creation..."

    setup_configs_and_dotfiles
    install_shell_enhancements
    install_resterm
    setup_nvm_and_node
    install_persistent_binaries
    create_startup_script

    info "----------------------------------------------------------------"
    info "Persistent environment created!"
    warn "ACTION REQUIRED: Please restart your Google Cloud Shell session."
    info "The newly created '~/.customize_environment' script will run on the next startup to install system packages."
    info "----------------------------------------------------------------"

    # Apply tmux changes to current session if possible
    if tmux info &> /dev/null; then
        info "Applying new tmux configuration to the running server..."
        tmux source-file "$HOME/.tmux.conf"
    fi
}

main
