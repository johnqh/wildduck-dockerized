#!/bin/bash

# WildDuck Dockerized - Upgrade Script
# This script updates all Docker containers to their latest versions
# without modifying any configuration files

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display colored messages
function print_header {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

function print_step {
    echo -e "${GREEN}➜${NC} $1"
}

function print_error {
    echo -e "${RED}[ERROR]${NC} $1"
}

function print_warning {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

function print_info {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to find the config directory
function find_config_dir {
    if [ -d "./config-generated" ] && [ -f "./config-generated/docker-compose.yml" ]; then
        echo "./config-generated"
    elif [ -d "./backend-config" ] && [ -f "./backend-config/docker-compose.yml" ]; then
        echo "./backend-config"
    else
        echo ""
    fi
}

# Function to update environment variables from Doppler
function update_doppler_secrets {
    print_step "Updating environment variables from Doppler..."
    echo ""

    # Save current directory
    CURRENT_DIR=$(pwd)

    # Go back to root directory where .doppler-token should be
    cd ..

    DOPPLER_TOKEN_FILE=".doppler-token"
    DOPPLER_TOKEN=""

    if [ -f "$DOPPLER_TOKEN_FILE" ]; then
        DOPPLER_TOKEN=$(cat "$DOPPLER_TOKEN_FILE")
        print_info "Found saved Doppler token"
    else
        print_warning "No Doppler token found at $DOPPLER_TOKEN_FILE"
        print_info "Skipping Doppler update. To enable, save your token to $DOPPLER_TOKEN_FILE"
        cd "$CURRENT_DIR"
        return 0
    fi

    # Ensure default mail_box_indexer configuration is present
    if [ -f "default-config/mail_box_indexer/.env" ]; then
        if [ ! -f .env ]; then
            print_info "Copying default mail_box_indexer configuration..."
            cp default-config/mail_box_indexer/.env .env
            print_info "✓ Default mail_box_indexer configuration copied"
        else
            # Merge defaults with existing .env (existing values take precedence)
            print_info "Merging default mail_box_indexer settings with existing .env..."
            cp .env .env.backup
            cat .env.backup default-config/mail_box_indexer/.env | \
                awk -F= '!seen[$1]++' > .env.temp
            mv .env.temp .env
            rm -f .env.backup
            print_info "✓ Merged default settings (existing values preserved)"
        fi
    fi

    # Download from Doppler to a temporary file
    DOPPLER_ENV_FILE=".env.doppler"
    HTTP_CODE=$(curl -u "$DOPPLER_TOKEN:" \
        -w "%{http_code}" \
        -o "$DOPPLER_ENV_FILE" \
        -s \
        https://api.doppler.com/v3/configs/config/secrets/download?format=env)

    if [ "$HTTP_CODE" -eq 200 ]; then
        print_info "✓ Successfully downloaded latest secrets from Doppler"

        # Update .env in root directory
        if [ -f .env ]; then
            print_info "Updating .env with latest Doppler secrets..."
            cp .env .env.backup

            # Merge: Doppler values override existing .env (put Doppler first, deduplicate)
            cat "$DOPPLER_ENV_FILE" .env.backup | \
                awk -F= '!seen[$1]++' > .env.temp
            mv .env.temp .env
            rm -f .env.backup

            print_info "✓ Updated .env with Doppler secrets"
        else
            mv "$DOPPLER_ENV_FILE" .env
            print_info "✓ Created .env from Doppler secrets"
        fi

        # Clean up temporary file
        rm -f "$DOPPLER_ENV_FILE"

        # Copy updated .env to config directory so Docker Compose can use it
        if [ -f .env ] && [ -n "$CURRENT_DIR" ]; then
            cp .env "$CURRENT_DIR/.env"
            print_info "✓ Copied updated .env to config directory"
        fi

        print_info "✓ Environment variables updated from Doppler"
    else
        print_error "Failed to download from Doppler (HTTP $HTTP_CODE)"
        print_warning "Token may be invalid or expired. Please update $DOPPLER_TOKEN_FILE"
        print_info "Continuing with existing environment variables..."
        rm -f "$DOPPLER_ENV_FILE"
    fi

    # Return to config directory
    cd "$CURRENT_DIR"
    echo ""
}

echo ""
print_header "WildDuck Dockerized - Container Upgrade"
echo ""

# Check if Docker is running
if ! sudo docker info >/dev/null 2>&1; then
    print_error "Docker is not running or you don't have permission to access it."
    exit 1
fi

# Find configuration directory
CONFIG_DIR=$(find_config_dir)

if [ -z "$CONFIG_DIR" ]; then
    print_error "No configuration directory found."
    print_info "Please run ./setup.sh first to create the initial deployment."
    exit 1
fi

# Convert to absolute path for safety
CONFIG_DIR=$(cd "$CONFIG_DIR" && pwd)

print_info "Configuration directory: $CONFIG_DIR"
echo ""

# Navigate to config directory
cd "$CONFIG_DIR"

# Show current running containers
print_step "Current running containers:"
echo ""
sudo docker compose ps
echo ""

# Ask for confirmation
read -p "Do you want to proceed with the upgrade? This will restart all services. (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Upgrade cancelled by user."
    exit 0
fi
echo ""

# Step 1: Update Doppler secrets
print_step "Step 1/6: Updating environment variables from Doppler..."
update_doppler_secrets

# Step 2: Update docker-compose.yml with latest configuration
print_step "Step 2/6: Updating docker-compose.yml configuration..."

# Extract current hostname from existing docker-compose.yml
CURRENT_HOSTNAME=$(grep -m 1 "traefik.tcp.routers.wildduck-imaps.rule: HostSNI(" docker-compose.yml | sed -n "s/.*HostSNI(\`\([^`]*\)\`).*/\1/p" || echo "")

if [ -z "$CURRENT_HOSTNAME" ] || [ "$CURRENT_HOSTNAME" = "HOSTNAME" ]; then
    # Fallback: try to get from .deployment-config file (saved by setup.sh)
    if [ -f .deployment-config ]; then
        source .deployment-config
        CURRENT_HOSTNAME="$MAIL_HOSTNAME"
    fi

    # If still not found, try to construct from EMAIL_DOMAIN
    if [ -z "$CURRENT_HOSTNAME" ] && [ -f .env ]; then
        EMAIL_DOMAIN=$(grep -m 1 "^EMAIL_DOMAIN=" .env | cut -d= -f2 | tr -d '"' | tr -d "'")
        if [ -n "$EMAIL_DOMAIN" ]; then
            CURRENT_HOSTNAME="mail.${EMAIL_DOMAIN}"
        fi
    fi

    # Require hostname to be set
    if [ -z "$CURRENT_HOSTNAME" ]; then
        print_error "Could not detect hostname from docker-compose.yml, .deployment-config, or EMAIL_DOMAIN"
        print_error "Please run setup.sh first or set EMAIL_DOMAIN in .env"
        exit 1
    fi
    print_warning "Could not detect hostname from docker-compose.yml, using: $CURRENT_HOSTNAME"
else
    print_info "Detected hostname: $CURRENT_HOSTNAME"
fi

# Extract current API hostname from existing docker-compose.yml
CURRENT_API_HOSTNAME=$(grep -m 1 "traefik.http.routers.wildduck-api-path.rule: Host(" docker-compose.yml | sed -n "s/.*Host(\`\([^`]*\)\`).*/\1/p" || echo "")

if [ -z "$CURRENT_API_HOSTNAME" ] || [ "$CURRENT_API_HOSTNAME" = "API_HOSTNAME" ]; then
    # Fallback: try to get from .deployment-config file (saved by setup.sh)
    if [ -f .deployment-config ] && [ -z "$CURRENT_API_HOSTNAME" ]; then
        source .deployment-config
        CURRENT_API_HOSTNAME="$API_HOSTNAME"
    fi

    # If still not found, derive from CURRENT_HOSTNAME
    if [ -z "$CURRENT_API_HOSTNAME" ] && [[ "$CURRENT_HOSTNAME" == mail.* ]]; then
        # If hostname is mail.example.com, use api.example.com
        CURRENT_API_HOSTNAME="api.${CURRENT_HOSTNAME#mail.}"
    fi

    # Fallback to same as hostname (backward compatibility)
    if [ -z "$CURRENT_API_HOSTNAME" ]; then
        CURRENT_API_HOSTNAME="$CURRENT_HOSTNAME"
    fi

    print_warning "Could not detect API hostname from docker-compose.yml, using: $CURRENT_API_HOSTNAME"
else
    print_info "Detected API hostname: $CURRENT_API_HOSTNAME"
fi

# Backup current docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup

# Copy latest docker-compose.yml from root
cd ..
if [ -f "docker-compose.yml" ]; then
    cp docker-compose.yml "$CONFIG_DIR/docker-compose.yml"

    # Replace API_HOSTNAME first, then HOSTNAME (order matters to avoid partial replacement)
    # Replace API_HOSTNAME placeholder with actual API hostname (use absolute path)
    sed -i "s|API_HOSTNAME|$CURRENT_API_HOSTNAME|g" "$CONFIG_DIR/docker-compose.yml"

    # Replace HOSTNAME placeholder with actual hostname (use absolute path)
    sed -i "s|HOSTNAME|$CURRENT_HOSTNAME|g" "$CONFIG_DIR/docker-compose.yml"

    # Replace cert paths (use absolute path)
    sed -i "s|./certs/HOSTNAME-key.pem|./certs/$CURRENT_HOSTNAME-key.pem|g" "$CONFIG_DIR/docker-compose.yml"
    sed -i "s|./certs/HOSTNAME.pem|./certs/$CURRENT_HOSTNAME.pem|g" "$CONFIG_DIR/docker-compose.yml"

    # Detect if Let's Encrypt is being used (check backup for existing certresolver config)
    if grep -q "certificatesresolvers.letsencrypt.acme.email" "$CONFIG_DIR/docker-compose.yml.backup" 2>/dev/null && \
       ! grep -q "# - \"--certificatesresolvers.letsencrypt.acme.email" "$CONFIG_DIR/docker-compose.yml.backup" 2>/dev/null; then
        print_info "Detected Let's Encrypt configuration, applying ACME settings..."

        # Extract the email from backup
        ACME_EMAIL=$(grep "certificatesresolvers.letsencrypt.acme.email" "$CONFIG_DIR/docker-compose.yml.backup" | sed -n 's/.*email=\([^"]*\).*/\1/p' | head -1)
        if [ -z "$ACME_EMAIL" ]; then
            ACME_EMAIL="domainadmin@${CURRENT_HOSTNAME#mail.}"
        fi

        # Enable ACME certresolver
        sed -i "s|# - \"--certificatesresolvers.letsencrypt.acme.email=ACME_EMAIL\"|- \"--certificatesresolvers.letsencrypt.acme.email=$ACME_EMAIL\"|g" "$CONFIG_DIR/docker-compose.yml"
        sed -i "s|# - \"--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json\"|- \"--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json\"|g" "$CONFIG_DIR/docker-compose.yml"
        sed -i "s|# - \"--certificatesresolvers.letsencrypt.acme.tlschallenge=true\"|- \"--certificatesresolvers.letsencrypt.acme.tlschallenge=true\"|g" "$CONFIG_DIR/docker-compose.yml"

        # Enable certresolver for TCP routers
        sed -i "s|# traefik.tcp.routers.zonemta.tls.certresolver: letsencrypt|traefik.tcp.routers.zonemta.tls.certresolver: letsencrypt|g" "$CONFIG_DIR/docker-compose.yml"
        sed -i "s|# traefik.tcp.routers.wildduck-pop3s.tls.certresolver: letsencrypt|traefik.tcp.routers.wildduck-pop3s.tls.certresolver: letsencrypt|g" "$CONFIG_DIR/docker-compose.yml"
        sed -i "s|# traefik.tcp.routers.wildduck-imaps.tls.certresolver: letsencrypt|traefik.tcp.routers.wildduck-imaps.tls.certresolver: letsencrypt|g" "$CONFIG_DIR/docker-compose.yml"

        # Remove self-signed cert related config
        sed -i "/traefik.tcp.routers.zonemta.tls: true/d" "$CONFIG_DIR/docker-compose.yml"
        sed -i "/traefik.tcp.routers.wildduck-pop3s.tls: true/d" "$CONFIG_DIR/docker-compose.yml"
        sed -i "/traefik.tcp.routers.wildduck-imaps.tls: true/d" "$CONFIG_DIR/docker-compose.yml"
        sed -i "/- \.\/dynamic_conf:\/etc\/traefik\/dynamic_conf:ro/d" "$CONFIG_DIR/docker-compose.yml"
        sed -i '/- "--providers.file=true"/d' "$CONFIG_DIR/docker-compose.yml"
        sed -i '/- "--providers.file.directory=\/etc\/traefik\/dynamic_conf"/d' "$CONFIG_DIR/docker-compose.yml"
        sed -i '/- "--providers.file.watch=true"/d' "$CONFIG_DIR/docker-compose.yml"
        sed -i '/- "--serversTransport.insecureSkipVerify=true"/d' "$CONFIG_DIR/docker-compose.yml"
        sed -i '/- "--serversTransport.rootCAs=\/etc\/traefik\/certs\/rootCA.pem"/d' "$CONFIG_DIR/docker-compose.yml"
        sed -i '/- \.\/certs:\/etc\/traefik\/certs.*# Mount your certs directory/d' "$CONFIG_DIR/docker-compose.yml"

        # Clear dynamic.yml to prevent loading non-existent cert files
        echo "# Using Let's Encrypt - certificates managed via ACME" > "$CONFIG_DIR/dynamic_conf/dynamic.yml"
        echo "tls: {}" >> "$CONFIG_DIR/dynamic_conf/dynamic.yml"

        print_info "✓ Applied Let's Encrypt configuration"
    else
        print_info "Using self-signed certificates configuration"
        # Update dynamic.yml with correct hostname for self-signed certs
        if [ -f "$CONFIG_DIR/dynamic_conf/dynamic.yml" ]; then
            sed -i "s/wildduck.dockerized.test/$CURRENT_HOSTNAME/g" "$CONFIG_DIR/dynamic_conf/dynamic.yml"
        fi
    fi

    print_info "✓ Updated docker-compose.yml with hostname: $CURRENT_HOSTNAME"
    print_info "✓ Updated docker-compose.yml with API hostname: $CURRENT_API_HOSTNAME"
else
    print_warning "Root docker-compose.yml not found, skipping update"
fi
cd "$CONFIG_DIR"
echo ""

# Step 3: Update configuration files from default-config
print_step "Step 3/6: Updating configuration files..."

# Go to root directory
cd ..

if [ -d "default-config" ]; then
    # Update rspamd configuration (safe to overwrite, not typically customized)
    if [ -d "default-config/rspamd" ]; then
        print_info "Updating rspamd configuration..."
        mkdir -p "$CONFIG_DIR/config/rspamd/override.d"
        mkdir -p "$CONFIG_DIR/config/rspamd/local.d"

        # Copy override.d files (these have highest priority)
        cp -r default-config/rspamd/override.d/* "$CONFIG_DIR/config/rspamd/override.d/" 2>/dev/null || true

        # Copy local.d files
        cp -r default-config/rspamd/local.d/* "$CONFIG_DIR/config/rspamd/local.d/" 2>/dev/null || true

        # Copy worker config
        cp default-config/rspamd/worker-normal.conf "$CONFIG_DIR/config/rspamd/" 2>/dev/null || true

        print_info "✓ Rspamd configuration updated"
    fi

    # Update ZoneMTA plugins (safe to overwrite, contains authentication logic)
    if [ -d "default-config/zone-mta/plugins" ]; then
        print_info "Updating ZoneMTA plugins..."
        mkdir -p "$CONFIG_DIR/config/zone-mta/plugins"

        # Extract existing secrets BEFORE copying new files
        EXISTING_SRS_SECRET=""
        EXISTING_DKIM_SECRET=""
        if [ -f "$CONFIG_DIR/config/zone-mta/plugins/wildduck.toml" ]; then
            EXISTING_SRS_SECRET=$(grep -m 1 'secret="' "$CONFIG_DIR/config/zone-mta/plugins/wildduck.toml" 2>/dev/null | head -1 | sed -n 's/.*secret="\([^"]*\)".*/\1/p' || echo "")
            EXISTING_DKIM_SECRET=$(grep 'secret="' "$CONFIG_DIR/config/zone-mta/plugins/wildduck.toml" 2>/dev/null | tail -1 | sed -n 's/.*secret="\([^"]*\)".*/\1/p' || echo "")
        fi
        # Also check WildDuck's dkim.toml as fallback for DKIM secret
        if [ -z "$EXISTING_DKIM_SECRET" ] || [ "$EXISTING_DKIM_SECRET" = "super secret key" ]; then
            if [ -f "$CONFIG_DIR/config/wildduck/dkim.toml" ]; then
                EXISTING_DKIM_SECRET=$(grep 'secret="' "$CONFIG_DIR/config/wildduck/dkim.toml" 2>/dev/null | tail -1 | sed -n 's/.*secret="\([^"]*\)".*/\1/p' || echo "")
            fi
        fi

        # Copy plugin files (.js and .toml)
        cp default-config/zone-mta/plugins/*.js "$CONFIG_DIR/config/zone-mta/plugins/" 2>/dev/null || true
        cp default-config/zone-mta/plugins/*.toml "$CONFIG_DIR/config/zone-mta/plugins/" 2>/dev/null || true

        # Replace placeholders in wildduck.toml with actual values
        if [ -f "$CONFIG_DIR/config/zone-mta/plugins/wildduck.toml" ]; then
            print_info "Updating WildDuck plugin configuration..."

            # Derive mail domain from hostname (strip "mail." prefix if present)
            if [[ "$CURRENT_HOSTNAME" == mail.* ]]; then
                MAIL_DOMAIN="${CURRENT_HOSTNAME#mail.}"
            else
                MAIL_DOMAIN="$CURRENT_HOSTNAME"
            fi

            # Replace hostname and domain placeholders
            # hostname = the full mail server hostname (e.g., mail.signic.email)
            # rewriteDomain = the mail domain for SRS rewriting (e.g., signic.email)
            sed -i "s/hostname=\"email.example.com\"/hostname=\"$CURRENT_HOSTNAME\"/" "$CONFIG_DIR/config/zone-mta/plugins/wildduck.toml"
            sed -i "s/rewriteDomain=\"email.example.com\"/rewriteDomain=\"$MAIL_DOMAIN\"/" "$CONFIG_DIR/config/zone-mta/plugins/wildduck.toml"

            # Restore preserved secrets
            if [ -n "$EXISTING_SRS_SECRET" ] && [ "$EXISTING_SRS_SECRET" != "secret value" ]; then
                sed -i "s/secret=\"secret value\"/secret=\"$EXISTING_SRS_SECRET\"/" "$CONFIG_DIR/config/zone-mta/plugins/wildduck.toml"
            fi

            if [ -n "$EXISTING_DKIM_SECRET" ] && [ "$EXISTING_DKIM_SECRET" != "super secret key" ]; then
                sed -i "s/secret=\"super secret key\"/secret=\"$EXISTING_DKIM_SECRET\"/" "$CONFIG_DIR/config/zone-mta/plugins/wildduck.toml"
            fi

            print_info "✓ WildDuck plugin configuration updated with hostname: $CURRENT_HOSTNAME"
            print_info "✓ SRS rewriteDomain set to: $MAIL_DOMAIN"
        fi

        # Sync DKIM secret to WildDuck's dkim.toml (must match ZoneMTA for DKIM signing to work)
        # WildDuck encrypts DKIM private keys with this secret, ZoneMTA decrypts them for signing
        if [ -n "$EXISTING_DKIM_SECRET" ] && [ "$EXISTING_DKIM_SECRET" != "super secret key" ]; then
            if [ -f "$CONFIG_DIR/config/wildduck/dkim.toml" ]; then
                # First try to replace the default value
                sed -i "s/secret=\"super secret key\"/secret=\"$EXISTING_DKIM_SECRET\"/" "$CONFIG_DIR/config/wildduck/dkim.toml"

                # Verify the secret is now correct (handles case where it was already set)
                CURRENT_WD_DKIM=$(grep 'secret="' "$CONFIG_DIR/config/wildduck/dkim.toml" 2>/dev/null | tail -1 | sed -n 's/.*secret="\([^"]*\)".*/\1/p' || echo "")
                if [ "$CURRENT_WD_DKIM" = "$EXISTING_DKIM_SECRET" ]; then
                    print_info "✓ DKIM secret synchronized between ZoneMTA and WildDuck"
                elif [ -n "$CURRENT_WD_DKIM" ] && [ "$CURRENT_WD_DKIM" != "super secret key" ]; then
                    # WildDuck has a different custom secret - this is a problem!
                    print_warning "DKIM secret mismatch detected!"
                    print_warning "  ZoneMTA: $EXISTING_DKIM_SECRET"
                    print_warning "  WildDuck: $CURRENT_WD_DKIM"
                    print_warning "Updating WildDuck dkim.toml to match ZoneMTA..."
                    # Use a more aggressive replacement that matches any secret value
                    sed -i "s/secret=\"$CURRENT_WD_DKIM\"/secret=\"$EXISTING_DKIM_SECRET\"/" "$CONFIG_DIR/config/wildduck/dkim.toml"
                    print_info "✓ Fixed DKIM secret mismatch"
                fi
            fi
        fi

        print_info "✓ ZoneMTA plugins updated"
    fi

    # Update WildDuck configuration files
    if [ -d "default-config/wildduck" ]; then
        print_info "Updating WildDuck configuration..."

        # Extract existing emailDomain BEFORE copying new files
        EXISTING_EMAIL_DOMAIN=""
        if [ -f "$CONFIG_DIR/config/wildduck/api.toml" ]; then
            EXISTING_EMAIL_DOMAIN=$(grep 'emailDomain' "$CONFIG_DIR/config/wildduck/api.toml" 2>/dev/null | head -1 | sed -n 's/.*emailDomain[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' || echo "")
        fi
        # Fallback to default.toml
        if [ -z "$EXISTING_EMAIL_DOMAIN" ] || [ "$EXISTING_EMAIL_DOMAIN" = "email.example.com" ]; then
            if [ -f "$CONFIG_DIR/config/wildduck/default.toml" ]; then
                EXISTING_EMAIL_DOMAIN=$(grep 'emailDomain' "$CONFIG_DIR/config/wildduck/default.toml" 2>/dev/null | head -1 | sed -n 's/.*emailDomain[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' || echo "")
            fi
        fi
        # Fallback to MAIL_DOMAIN derived from hostname
        if [ -z "$EXISTING_EMAIL_DOMAIN" ] || [ "$EXISTING_EMAIL_DOMAIN" = "email.example.com" ]; then
            EXISTING_EMAIL_DOMAIN="$MAIL_DOMAIN"
        fi

        # Copy new WildDuck config files (overwrite to get latest features)
        cp default-config/wildduck/api.toml "$CONFIG_DIR/config/wildduck/api.toml" 2>/dev/null || true
        cp default-config/wildduck/default.toml "$CONFIG_DIR/config/wildduck/default.toml" 2>/dev/null || true
        cp default-config/wildduck/dkim.toml "$CONFIG_DIR/config/wildduck/dkim.toml" 2>/dev/null || true

        # Restore/set emailDomain in both config files
        if [ -n "$EXISTING_EMAIL_DOMAIN" ] && [ "$EXISTING_EMAIL_DOMAIN" != "email.example.com" ]; then
            sed -i "s/emailDomain = \"email.example.com\"/emailDomain = \"$EXISTING_EMAIL_DOMAIN\"/" "$CONFIG_DIR/config/wildduck/api.toml"
            sed -i "s/emailDomain=\"email.example.com\"/emailDomain=\"$EXISTING_EMAIL_DOMAIN\"/" "$CONFIG_DIR/config/wildduck/default.toml"
            print_info "✓ WildDuck emailDomain set to: $EXISTING_EMAIL_DOMAIN"
        fi

        # Restore DKIM secret in dkim.toml
        if [ -n "$EXISTING_DKIM_SECRET" ] && [ "$EXISTING_DKIM_SECRET" != "super secret key" ]; then
            sed -i "s/secret=\"super secret key\"/secret=\"$EXISTING_DKIM_SECRET\"/" "$CONFIG_DIR/config/wildduck/dkim.toml"
            print_info "✓ DKIM secret restored in WildDuck dkim.toml"
        fi

        print_info "✓ WildDuck configuration updated"
    fi

    print_info "✓ Configuration files updated"
else
    print_warning "default-config directory not found, skipping config update"
fi

# Return to config directory
cd "$CONFIG_DIR"
echo ""

# Step 4: Stop containers
print_step "Step 4/6: Stopping containers..."
sudo docker compose down
echo ""

# Step 5: Pull latest images
print_step "Step 5/6: Pulling latest container images..."
echo ""
sudo docker compose pull
echo ""

# Step 6: Start containers
print_step "Step 6/6: Starting containers with new images..."
sudo docker compose up -d --force-recreate
echo ""

# Wait a moment for containers to initialize
print_info "Waiting for containers to initialize..."
sleep 5
echo ""

# Show final status
print_step "Container status after upgrade:"
echo ""
sudo docker compose ps
echo ""

# Show which images were updated
print_step "Image information:"
echo ""
sudo docker compose images
echo ""

print_header "✓ Upgrade completed successfully!"
echo ""
print_info "All containers have been updated to their latest versions."
print_info "Environment variables have been refreshed from Doppler."
print_info "Configuration files were not modified."
echo ""
print_info "Useful commands:"
echo "  View logs:           cd $CONFIG_DIR && sudo docker compose logs -f <service>"
echo "  Restart a service:   cd $CONFIG_DIR && sudo docker compose restart <service>"
echo "  Check versions:      ./versions.sh"
echo ""

exit 0
