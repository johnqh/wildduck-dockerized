#!/bin/bash

# This script is designed to identify and terminate processes occupying specified network ports.
# It is a standalone script and should be run with sudo privileges.

# Define ports that the mail server and Traefik typically use
# IMPORTANT: Adjust this list based on your actual service requirements.
# Be careful not to kill essential services if they are intended to be running.
REQUIRED_PORTS=(80 443 25 465 143 993 995)

# --- Helper Functions (re-defined here for standalone execution) ---
command_exists () {
  type "$1" &> /dev/null ;
}

# --- Installation of lsof (needed by this script) ---
install_lsof() {
  echo "--- Installing lsof (if not already installed) ---"
  if command_exists lsof; then
    echo "lsof is already installed."
    return 0
  fi

  if command_exists apt-get; then # Ubuntu/Debian
    sudo apt-get install -y lsof || { echo "Error: lsof installation failed."; exit 1; }
  elif command_exists dnf; then # Fedora
    sudo dnf install -y lsof || { echo "Error: lsof installation failed."; exit 1; }
  elif command_exists yum; then # CentOS/RHEL
    sudo yum install -y lsof || { echo "Error: lsof installation failed."; exit 1; }
  else
    echo "Unsupported OS for automatic lsof installation. Please install manually."
    exit 1
  fi
  echo "lsof installed successfully."
}

# --- Main Port Clearing Function ---
clear_occupied_ports() {
  echo "--- Checking and clearing occupied ports ---"
  local port_cleared="false" # Flag to track if any port was cleared

  # Loop through each required port
  for port in "${REQUIRED_PORTS[@]}"; do
    echo "Checking port $port..."
    # Use lsof to find processes listening on the port
    PID=$(sudo lsof -i :$port -t -s TCP:LISTEN 2>/dev/null)

    if [ -n "$PID" ]; then
      port_cleared="true" # At least one port found occupied
      PROCESS_INFO=$(sudo lsof -i :$port -n -P | grep LISTEN | awk '{print $1, $2, $9}' | head -n 1)
      echo "  Port $port is occupied by PID $PID ($PROCESS_INFO). Attempting to kill..."

      # Try graceful kill (SIGTERM) first
      sudo kill "$PID" &>/dev/null
      sleep 2 # Give it a moment to terminate

      # Check if it's still running
      if sudo lsof -i :$port -t -s TCP:LISTEN &>/dev/null; then
        echo "  Process $PID did not terminate gracefully. Force killing (kill -9)..."
        sudo kill -9 "$PID" &>/dev/null
        sleep 1
        if sudo lsof -i :$port -t -s TCP:LISTEN &>/dev/null; then
          echo "  Error: Process $PID on port $port could not be killed. Manual intervention might be required."
        else
          echo "  Process $PID on port $port forcefully killed."
        F    fi
      else
        echo "  Process $PID on port $port terminated gracefully."
      fi
    else
      echo "  Port $port is free."
    fi
  done

  if [ "$port_cleared" = "true" ]; then
      echo "--- Port clearing complete. Please check logs for any issues. ---"
  else
      echo "--- All required ports were clear. ---"
  fi
}

# --- Execute this script's main functions ---
install_lsof # Ensure lsof is installed
clear_occupied_ports # Then clear the ports
