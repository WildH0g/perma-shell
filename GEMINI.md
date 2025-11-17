# Gemini Context File: Perma-Shell

This file contains context for the Gemini AI assistant to ensure continuity and understanding of the Perma-Shell project.

## Project Overview

The primary goal of this repository is to create a comprehensive, portable, and efficient persistent development environment for the user's Google Cloud Shell. The core philosophy is to manage configurations and binaries in a way that leverages Cloud Shell's ephemeral nature while maintaining a consistent user experience.

## Key Components & Scripts

- **`install.sh`**: This script performs the **persistent, user-level setup**. It installs all user-level configurations, dotfiles, and pre-compiled binaries into the `$HOME` directory. This script is run **only once** by the user.

- **`~/.customize_environment`**: This script is designed to be run on every Cloud Shell session startup. It handles the installation of **ephemeral, system-level packages** via `apt` and other commands that do not persist across sessions.

## Critical Decisions & Constraints

1.  **Private SSH Keys**: **NEVER** back up private SSH keys (`id_rsa`, `id_ed25519`, etc.). The system intentionally only includes the `~/.ssh/config` file and public (`*.pub`) keys. The user is responsible for manually backing up and restoring their private keys. This is a strict security boundary.

2.  **VS Code Configuration**: The full `~/.config/Code` directory is **intentionally excluded** to keep the repository size small. The system only includes `settings.json`, `keybindings.json`, and a list of installed extensions (`extensions.list`) in the `configs/vscode/` directory.

---

## Session Summary (2025-10-28)

This session was an extensive debugging and hardening exercise for the `install.sh` script, focused on making it robust and reliable in the unique Google Cloud Shell environment. We also added several new tools to the installation.

### 1. `install.sh` Hardening & Debugging

- **Problem**: The script was failing silently or with cryptic errors, preventing a full environment restoration. The root causes were a mix of download failures, incorrect installation logic, permission issues, and environment conflicts.
- **Solutions Implemented**:
  - **Robust Binary Installation**:
    - Created a `download_file` helper function that uses `wget` and gracefully warns on failure instead of crashing the script. This allows for manual file placement as a fallback.
    - Made all binary extraction steps conditional on a successful download, preventing errors from empty or corrupt archives.
    - Fixed brittle extraction logic for `yazi` and `fastfetch` by using temporary directories and robust `mv` or `find` commands.
  - **`fastfetch` Definitive Fix**: After multiple failed attempts with binaries and source builds, the final, working solution is a hybrid approach:
    1.  The persistent script (`install.sh`) downloads the `.deb` package to a permanent location (`~/.local/share/debs/`).
    2.  The ephemeral startup script (`customize_environment.sh`) installs the package from that local file using `dpkg -i` on every startup.
  - **`fancy-git` Fix**: Replaced the unreliable `curl | bash` installer with a robust method that forcefully re-clones the repository and runs the installer non-interactively.
  - **`tmux` Plugin Fix**: Corrected the plugin installation by using `tmux run-shell` to ensure the installer script runs within the necessary `tmux` environment, resolving the `TMUX_PLUGIN_MANAGER_PATH` error.
  - **Font Removal**: All Nerd Font installation logic was removed from the script as requested.

### 2. `customize_environment.sh` (Startup Script) Hardening

- **Problem**: The startup script was failing silently, primarily due to not being executed with root privileges.
- **Solutions Implemented**:
  - **Self-Elevation**: Modified the script to explicitly use `sudo` for all `apt` and `dpkg` commands, making it self-sufficient and removing the dependency on Cloud Shell's implicit root execution.
  - **Logging & Debugging**: Added comprehensive logging (`exec > ...` and `set -x`) to a user-visible file (`~/customize_environment.log`), which was critical for diagnosing the permission issues.
  - **Modularity**: The startup logic was moved to a dedicated file (`scripts/customize_environment.sh`) for better organization.

### 3. New Tool Installations

- **`fzf`**: Added a new function to clone and install `fzf` non-interactively.
- **`termdown`**: Installed persistently using `pipx` for a robust, isolated environment.
- **`ripgrep`**: Added to the ephemeral startup script to satisfy the dependency for Neovim's Telescope live grep.
- **`tty-clock`**: Added to the ephemeral startup script.

The `install.sh` script is now significantly more resilient, reliable, and feature-complete for the Cloud Shell environment.

---

## Google Cloud Shell Persistence Strategy

Due to the ephemeral nature of the Google Cloud Shell environment (where only the `$HOME` directory persists across sessions), a specialized, hybrid approach is required to restore the development environment effectively.

### The Problem

Standard system-wide installations using `sudo apt-get` or placing binaries in `/usr/local/bin` do not persist. Each time a Cloud Shell session starts, the underlying VM is reset, wiping out any changes made outside the user's home directory.

### The Solution: A Hybrid Approach

The installation process is split into two distinct scripts to handle this constraint:

1.  **`install.sh` (Persistent, User-Level Setup)**
    -   **Purpose**: To set up all components that can be stored permanently in the `$HOME` directory.
    -   **Execution**: This script is run **only once** by the user.
    -   **Key Actions**:
        -   Copies all dotfiles (e.g., `.bashrc`, `.vimrc`).
        -   Sets up user-level configurations in `~/.config`.
        -   Installs pre-compiled binaries (Neovim, Lazygit, Yazi) directly into `~/.local/bin`, ensuring they are on the user's `$PATH` and persist.
        -   Installs `nvm` and global Node.js packages, which reside entirely within `$HOME`.
        -   Downloads `.deb` packages for ephemeral tools (like `fastfetch`) to a persistent location.
        -   **Crucially, it creates the `~/.customize_environment` script.**

2.  **`~/.customize_environment` (Ephemeral, System-Level Setup)**
    -   **Purpose**: To install system-level dependencies that are required for the user's tools to function but cannot be stored permanently.
    -   **Execution**: This script is **automatically executed by Cloud Shell** every time a new session starts.
    -   **Key Actions**:
        -   Elevates its own privileges using `sudo`.
        -   Installs all required packages from `apt` (e.g., `tty-clock`, `ripgrep`).
        -   Installs packages from pre-downloaded `.deb` files (e.g., `fastfetch`).

This two-script approach ensures that the environment is both persistent (for user binaries and configs) and complete (with system dependencies re-installed on-demand), providing a consistent and reliable developer experience in Cloud Shell.
