#!/bin/bash

set -e

# Function to perform an action with exponential backoff
run_with_backoff() {
  local max_attempts=5
  local delay=5
  local attempt=1
  local command_to_run="$@"

  while [ $attempt -le $max_attempts ]; do
    echo "Attempt $attempt to run: $command_to_run"
    if $command_to_run; then
      echo "Command successful."
      return 0
    else
      local exit_code=$?
      echo "Command failed with exit code $exit_code."
      if [[ $exit_code -eq 100 ]]; then # Specific exit code for APT lock errors
        echo "APT lock error detected."
      fi

      if [ $attempt -eq $max_attempts ]; then
        echo "Max attempts reached. Aborting."
        return $exit_code
      fi

      echo "Waiting for $delay seconds before retrying..."
      sleep $delay
      delay=$((delay * 2))
      attempt=$((attempt + 1))
    fi
  done
}

echo "Starting system update..."

echo "Updating Snap packages..."
snap refresh

echo "Updating Flatpak packages..."
flatpak update --noninteractive

echo "Updating APT packages using nala..."
run_with_backoff nala update
nala list --upgradable
run_with_backoff nala upgrade -y

echo "Cleaning up old packages and caches..."
run_with_backoff nala autoremove -y
run_with_backoff nala clean
flatpak uninstall --unused

# echo "Connecting to ExpressVPN..."
# expressvpn connect frpa2 # Uncomment if you want this to run automatically

echo "System update finished."

# Optional: Add commands for other package managers or specific applications here
echo "Updating npm packages..."
sudo -u wildhog bash -c '
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  npm install -g npm@latest
  npm update -g
'

./prioritize-processes.sh


# echo "Updating pip packages..."
# pip list --outdated --user | cut -d ' ' -f1 | xargs -n1 pip install -U --user
