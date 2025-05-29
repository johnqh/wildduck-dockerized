#!/bin/bash

# This script handles the installation of all system dependencies.
# It should be sourced or executed from the main setup.sh script.

# --- Script Configuration & Setup ---

# Get the original user who invoked the script (or the current user if not sudo)
# This is crucial for user-specific installations like nvm
ORIGINAL_USER=$(whoami)
echo "Running dependency setup as user: $ORIGINAL_USER"

# --- Variables ---
NODE_VERSION="23" # You can specify a desired Node.js version here (e.g., "18", "20")
NPM_PACKAGES="" # Add any global npm packages you need installed later (e.g., "pm2")
DOCKER_GROUP_ADDED="false" # Flag to track if the user was added to the docker group

# --- Helper Functions for OS Detection ---
command_exists () {
  type "$1" &> /dev/null ;
}

is_ubuntu_debian() {
  command_exists apt-get
}

is_centos_rhel() {
  command_exists yum && ! command_exists dnf # dnf is newer, check yum first if not dnf
}

is_fedora() {
  command_exists dnf
}


# --- Installation Functions ---

install_certbot() {
  echo "--- Installing Certbot ---"
  if command_exists certbot; then
    echo "Certbot is already installed."
    return 0
  fi

  if is_ubuntu_debian; then
    sudo apt-get update -y
    sudo apt-get install -y certbot || { echo "Error: Certbot installation failed."; exit 1; }
  elif is_centos_rhel; then
    sudo yum install -y epel-release
    sudo yum install -y certbot || { echo "Error: Certbot installation failed."; exit 1; }
  elif is_fedora; then
    sudo dnf install -y certbot || { echo "Error: Certbot installation failed."; exit 1; }
  else
    echo "Unsupported OS for automatic Certbot installation. Please install manually."
    exit 1
  fi
  echo "Certbot installed successfully."
}

install_jq() {
  echo "--- Installing jq ---"
  if command_exists jq; then
    echo "jq is already installed."
    return 0
  fi

  if is_ubuntu_debian; then
    sudo apt-get install -y jq || { echo "Error: jq installation failed."; exit 1; }
  elif is_centos_rhel; then
    sudo yum install -y jq || { echo "Error: jq installation failed."; exit 1; }
  elif is_fedora; then
    sudo dnf install -y jq || { echo "Error: jq installation failed."; exit 1; }
  else
    echo "Unsupported OS for automatic jq installation. Please install manually."
    exit 1
  fi
  echo "jq installed successfully."
}

install_docker() {
  echo "--- Installing Docker ---"
  # Check if docker is already installed. If not, proceed with full installation.
  if command_exists docker; then
    echo "Docker is already installed."
  else
    # Official Docker installation steps are more involved than just apt/yum install
    if is_ubuntu_debian; then
      sudo apt-get update -y
      sudo apt-get install -y ca-certificates curl gnupg lsb-release || { echo "Error: Docker prerequisites failed."; exit 1; }
      sudo mkdir -m 0755 -p /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg || { echo "Error: Docker GPG key download failed."; exit 1; }
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || { echo "Error: Docker repository setup failed."; exit 1; }
      sudo apt-get update -y
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || { echo "Error: Docker installation failed."; exit 1; }
    elif is_centos_rhel || is_fedora; then
      sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || { echo "Error: Docker repo setup failed."; exit 1; }
      sudo dnf install -y docker-ce docker-ce-cli containerd.io || { echo "Error: Docker installation failed."; exit 1; }
    else
      echo "Unsupported OS for automatic Docker installation. Please install manually."
      exit 1
    fi

    echo "Docker installed."
  fi

  # Start and enable docker service regardless if it was freshly installed or just verified
  if ! sudo systemctl is-active --quiet docker; then
      echo "Starting Docker service..."
      sudo systemctl start docker || { echo "Error: Failed to start Docker service."; exit 1; }
  fi
  if ! sudo systemctl is-enabled --quiet docker; then
      echo "Enabling Docker service to start on boot..."
      sudo systemctl enable docker || { echo "Error: Failed to enable Docker service."; exit 1; }
  fi
  echo "Docker service started and enabled."

  # Now, handle adding user to docker group if not already there
  if ! id -nG "$ORIGINAL_USER" | grep -qw "docker"; then
    echo "Adding user '$ORIGINAL_USER' to the docker group..."
    sudo usermod -aG docker "$ORIGINAL_USER"
    DOCKER_GROUP_ADDED="true" # Set flag because user was added to the group
    echo "User '$ORIGINAL_USER' added to 'docker' group."
  else
    echo "User '$ORIGINAL_USER' is already in the 'docker' group."
  fi
}

install_nvm_node() {
  echo "--- Installing NVM and Node.js for user '$ORIGINAL_USER' ---"

  # Check if NVM is already installed for the user
  NVM_DIR="/home/$ORIGINAL_USER/.nvm"
  if [ -d "$NVM_DIR" ]; then
    echo "NVM already installed for user '$ORIGINAL_USER'."
    # Source NVM for the current script's user environment
    export NVM_DIR="$NVM_DIR"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
  else
    echo "Installing NVM for user '$ORIGINAL_USER'..."
    # Install NVM as the regular user
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash || { echo "Error: NVM installation failed."; exit 1; }
    # Source NVM for the current script's user environment immediately after install
    export NVM_DIR="$NVM_DIR"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
  fi

  # Check if Node.js is already the desired version
  if command_exists node && node -v | grep -q "^v$NODE_VERSION\."; then
    echo "Node.js v$NODE_VERSION is already installed and active."
  else
    echo "Installing Node.js version $NODE_VERSION..."
    # Ensure nvm is loaded before trying to install node
    if ! command_exists nvm; then
        echo "Error: nvm command not found after installation/sourcing. Node.js installation skipped."
        exit 1
    fi
    nvm install "$NODE_VERSION" || { echo "Error: Node.js installation failed."; exit 1; }
    nvm use "$NODE_VERSION" || { echo "Error: Could not switch to Node.js version."; exit 1; }
    nvm alias default "$NODE_VERSION" || { echo "Error: Could not set default Node.js version."; exit 1; }
    echo "Node.js version: $(node -v)"
    echo "NPM version: $(npm -v)"
  fi

  # Install global npm packages if specified
  if [ -n "$NPM_PACKAGES" ]; then
    echo "Installing global npm packages: $NPM_PACKAGES..."
    npm install -g $NPM_PACKAGES || { echo "Error: Global npm package installation failed."; exit 1; }
  fi

  echo "NVM and Node.js ($NODE_VERSION) installation complete for user '$ORIGINAL_USER'."
}

install_crontab() {
  echo "--- Installing Crontab (Cron Daemon) ---"
  if command_exists crontab; then
    echo "Crontab is already installed."
    return 0
  fi

  if is_ubuntu_debian; then
    sudo apt-get install -y cron || { echo "Error: Cron installation failed."; exit 1; }
    sudo systemctl enable cron || { echo "Error: Failed to enable cron service."; exit 1; }
    sudo systemctl start cron || { echo "Error: Failed to start cron service."; exit 1; }
  elif is_centos_rhel || is_fedora; then
    sudo dnf install -y cronie || { echo "Error: Cronie installation failed."; exit 1; } # cronie provides crontab
    sudo systemctl enable crond || { echo "Error: Failed to enable crond service."; exit 1; }
    sudo systemctl start crond || { echo "Error: Failed to start crond service."; exit 1; }
  else
    echo "Unsupported OS for automatic Crontab installation. Please install manually."
    exit 1
  fi
  echo "Crontab installed and cron service started successfully."
}


install_all_dependencies() {
  echo "--- Starting Dependency Installation ---"
  install_certbot
  install_jq
  install_docker
  install_crontab
  install_nvm_node
  echo "--- All Dependencies Installed ---"
}

# --- Main execution of dependency setup ---
install_all_dependencies

# --- Final user prompt for restart if Docker group was modified ---
# This variable is defined and set in the install_docker function above.
if [ "$DOCKER_GROUP_ADDED" = "true" ]; then
  echo ""
  echo "========================================================================="
  echo " IMPORTANT: Docker group membership changed for user '$ORIGINAL_USER'."
  echo " You need to log out and log back in (or open a new terminal session)"
  echo " for these changes to take full effect and use 'docker' without 'sudo'."
  echo " Once you've done that, you won't see this message again. Please re-run"
  echo " the main setup script after logging back in."
  echo "========================================================================="
  echo ""
  exit 0 # Exit the script here, requiring re-login and re-run of main setup.sh
fi
