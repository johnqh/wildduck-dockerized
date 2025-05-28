#!/bin/bash

# This script automates Certbot installation (if needed) and SSL certificate
# acquisition in standalone mode.

# --- Configuration ---
EMAIL="your_email@example.com" # IMPORTANT: Replace with your actual email for urgent renewal notices
DOMAINS=""                     # IMPORTANT: Enter your domain(s) separated by commas (e.g., "example.com,www.example.com")

# --- Functions ---

# Function to check if a command exists
command_exists () {
  type "$1" &> /dev/null ;
}

# Function to install Certbot based on OS
install_certbot() {
  echo "Certbot not found. Attempting to install Certbot..."

  if command_exists apt-get; then
    echo "Detected Debian/Ubuntu. Installing Certbot via apt."
    sudo apt-get update
    sudo apt-get install -y certbot
  elif command_exists yum; then
    echo "Detected CentOS/RHEL. Installing Certbot via yum."
    sudo yum install -y epel-release # Enable EPEL repository for Certbot
    sudo yum install -y certbot
  elif command_exists dnf; then
    echo "Detected Fedora. Installing Certbot via dnf."
    sudo dnf install -y certbot
  else
    echo "Unsupported operating system for automatic Certbot installation."
    echo "Please install Certbot manually. Refer to: https://certbot.eff.org/instructions"
    exit 1
  fi

  if ! command_exists certbot; then
    echo "Certbot installation failed. Please check your internet connection and try again, or install manually."
    exit 1
  fi
  echo "Certbot installed successfully."
}

# --- Main Script Logic ---

echo "Starting SSL certificate installation script..."

# 1. Check if Certbot is installed
if ! command_exists certbot; then
  install_certbot
else
  echo "Certbot is already installed."
fi

# 2. Validate DOMAINS and EMAIL
if [ -z "$DOMAINS" ]; then
  read -p "Please enter your domain(s) (e.g., example.com,www.example.com): " DOMAINS
  if [ -z "$DOMAINS" ]; then
    echo "No domains entered. Exiting."
    exit 1
  fi
fi

if [ "$EMAIL" = "your_email@example.com" ]; then
  read -p "Please enter your email address for renewal notices: " EMAIL
  if [ -z "$EMAIL" ]; then
    echo "No email entered. Exiting."
    exit 1
  fi
fi

# Convert comma-separated domains to Certbot format (-d domain1 -d domain2)
CERTBOT_DOMAINS=""
IFS=',' read -ra ADDR <<< "$DOMAINS"
for i in "${ADDR[@]}"; do
  CERTBOT_DOMAINS+=" -d $i"
done

echo "Attempting to obtain SSL certificate for domain(s): $DOMAINS"
echo "Using email: $EMAIL"

# 3. Run Certbot in standalone mode
# --agree-tos: Automatically agree to Let's Encrypt's Terms of Service
# --noninteractive: Run Certbot without asking questions (important for scripting)
# --standalone: Use Certbot's built-in web server for verification
# --preferred-challenges http: Use HTTP-01 challenge
# --email: Your email for renewal notices
# -d: Specify domain(s)
# --keep-until-expiring: Renew only when the certificate is close to expiring
# --staple-ocsp: Enable OCSP stapling (improves performance and privacy)
# --hsts: Enable HTTP Strict Transport Security (HSTS)
# --redirect: Automatically set up HTTP to HTTPS redirection (if applicable, though standalone doesn't configure web servers)
# --rsa-key-size 4096: Use a 4096-bit RSA key for stronger encryption (default is 2048)

sudo certbot certonly \
  --agree-tos \
  --noninteractive \
  --standalone \
  --preferred-challenges http \
  --email "$EMAIL" \
  $CERTBOT_DOMAINS \
  --keep-until-expiring \
  --staple-ocsp \
  --hsts \
  --rsa-key-size 4096

# Check Certbot exit status
if [ $? -eq 0 ]; then
  echo "SSL certificate obtained successfully!"
  echo "Your certificates are usually located in: /etc/letsencrypt/live/$ (first domain listed)"
  echo "Remember to configure your web server (Apache, Nginx, etc.) to use these certificates."
  echo "A cron job for automatic renewal will likely be set up by Certbot during installation."
else
  echo "Certbot failed to obtain the SSL certificate. Please check the output above for errors."
  echo "Common issues: Port 80 not free, DNS not resolving, firewall blocking."
fi

echo "Script finished."
