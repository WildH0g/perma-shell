# Perma-Shell: A Persistent Google Cloud Shell Environment

This repository contains the dotfiles, scripts, and configurations to create a powerful, customized, and persistent development environment within the ephemeral architecture of Google Cloud Shell.

## The Challenge of Cloud Shell

Google Cloud Shell provides a fantastic, temporary compute environment. However, its key limitation is that the underlying VM is ephemeral. Any system-level changes (like packages installed with `apt`) are wiped clean when the session ends. Only the `$HOME` directory persists.

## The Solution: A Hybrid Approach

This project solves the persistence problem by using a hybrid installation strategy managed by two core scripts:

1.  **`install.sh` (The Persistent Installer):** This is the main script you run **once**. It sets up everything that can live permanently in your `$HOME` directory. This includes:
    *   Dotfiles (`.bashrc`, `.tmux.conf`, etc.).
    *   Application configurations (for `lazygit`, `yazi`, etc.) in `~/.config`.
    *   Pre-compiled binaries (like Neovim, Lazygit, Yazi) installed directly into `~/.local/bin`.
    *   User-level package managers like `nvm`.

2.  **`~/.customize_environment` (The Ephemeral Installer):** The `install.sh` script creates this special script in your home directory. Google Cloud Shell automatically executes this script **as root** every single time a new session starts. It is responsible for reinstalling the essential system-level dependencies that your tools need to function, such as `tty-clock`, `ripgrep`, and others.

This two-script system ensures that your environment is both persistent (for your personal files and binaries) and fully functional (with system dependencies re-installed on-demand), giving you a consistent and reliable developer experience every time you log in.

## How to Use

To set up your persistent Cloud Shell environment, follow these steps:

1.  **Clone this repository:**
    ```bash
    git clone https://github.com/your-username/perma-shell.git ~/perma-shell
    ```
2.  **Run the installation script:**
    ```bash
    cd ~/perma-shell
    ./install.sh
    ```
3.  **Restart Your Session:** After the script completes, restart your Google Cloud Shell session. The `~/.customize_environment` script will run automatically on the next startup to finish the setup.

Your environment is now ready.

## Repository Structure

-   `install.sh`: The main, one-time installation script for the persistent user environment.
-   `dotfiles/`: Contains all dotfiles (e.g., `.bashrc`) and dot-directories (e.g., `.config/`) that will be copied to the `$HOME` directory.
-   `scripts/`: Contains helper scripts, including the template for the ephemeral `customize_environment.sh`.
-   `bin/`: Stores pre-downloaded, compressed binaries (like Neovim) for faster installation.
-   `packages/`: Contains lists of binaries to be downloaded and installed.
-   `README.md`: This file.
