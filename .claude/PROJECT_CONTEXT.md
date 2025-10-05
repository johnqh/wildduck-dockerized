# WildDuck Dockerized - AI Development Context

## Project Overview

**Purpose**: Docker-based email server deployment combining WildDuck mail server with blockchain-based address management through Mail Box Indexer.

**Key Features**:
- Full-featured email server (IMAP, POP3, SMTP)
- Blockchain wallet-based email addresses (ENS, SNS domains)
- Multi-chain support (Ethereum, Polygon, Optimism, Base, Solana)
- OAuth 2.0/OpenID Connect provider
- Points and referral system
- Optional KYC integration (Sumsub)

## Architecture

### Core Services

1. **WildDuck** (Port 8080)
   - IMAP/POP3 server
   - REST API for mail operations
   - User and mailbox management
   - Source: `johnqh/wildduck:latest`

2. **Mail Box Indexer** (Port 42069)
   - Blockchain event indexer (Ponder framework)
   - Wallet authentication
   - Points and referral system
   - OAuth provider
   - Source: `johnqh/mail_box_indexer:latest`

3. **ZoneMTA** (Port 465)
   - Outbound SMTP server
   - Queue management
   - Source: `ghcr.io/zone-eu/zonemta-wildduck:1.32.20`

4. **Haraka** (Port 25)
   - Inbound SMTP server
   - Spam filtering integration
   - Source: `johnqh/haraka-plugin-wildduck:latest`

5. **Rspamd**
   - Spam detection and filtering
   - Source: `nodemailer/rspamd`

6. **Traefik** (Ports 80, 443, 993, 995, 465)
   - Reverse proxy and router
   - Automatic TLS/SSL (Let's Encrypt)
   - Routes `/api` → WildDuck, `/idx` → Indexer

### Databases

1. **MongoDB**
   - User accounts, mailboxes, messages
   - Shared by WildDuck, ZoneMTA, Haraka

2. **PostgreSQL**
   - Blockchain indexing data
   - Used exclusively by Mail Box Indexer

3. **Redis**
   - Session management
   - Caching layer
   - Shared across services

## Directory Structure

```
wildduck-dockerized/
├── .claude/                    # AI assistant configuration
│   ├── PROJECT_CONTEXT.md     # This file
│   ├── ARCHITECTURE.md        # System architecture
│   └── settings.local.json    # Claude Code settings
├── .github/                   # GitHub workflows
├── config/                    # Service configurations (gitignored)
├── config-generated/          # Generated configs (gitignored)
├── certs/                     # SSL certificates (gitignored)
├── default-config/            # Default configuration templates
│   ├── haraka/
│   ├── rspamd/
│   ├── wildduck/
│   └── zone-mta/
├── docker-images/             # Custom Docker image sources
├── dynamic_conf/              # Traefik dynamic configuration
├── setup-scripts/             # Modular setup scripts
├── tests/                     # Integration tests
├── docker-compose.yml         # Main deployment file
├── docker-compose-alt-ports.yml  # Alternative port mapping
├── setup.sh                   # Interactive setup wizard
├── setup_be.sh               # Backend setup
├── setup_fe.sh               # Frontend setup
├── .env.example              # Environment template
├── ENDPOINTS.md              # Complete API reference
├── DATABASE-DEBUG.md         # DB debugging guide
└── README.md                 # User documentation
```

## Configuration Files

### Environment Variables (.env)

**Required for Mail Box Indexer**:
- `INDEXER_PRIVATE_KEY` - EVM private key for signing
- `INDEXER_WALLET_ADDRESS` - Corresponding wallet address
- `ALCHEMY_API_KEY` - Blockchain RPC provider

**Optional**:
- `EMAIL_DOMAIN` - Default email domain (default: 0xmail.box)
- `ENABLE_TESTNETS` - Include testnet chains (default: false)
- `KYC_ENABLED` - Enable Sumsub KYC (default: false)
- `HELIUS_API_KEY` - Solana webhook provider
- `REVENUECAT_API_KEY` - Subscription management

### Docker Compose

**Main file**: `docker-compose.yml`
- Production-ready configuration
- Traefik with Let's Encrypt
- Health checks and dependencies

**Alternative**: `docker-compose-alt-ports.yml`
- Development/testing ports
- Direct port exposure (no Traefik)

### Service Configurations

Located in `default-config/`:
- **WildDuck**: TOML format (`default-config/wildduck/`)
- **Haraka**: JavaScript config (`default-config/haraka/`)
- **ZoneMTA**: TOML format (`default-config/zone-mta/`)
- **Rspamd**: UCL format (`default-config/rspamd/`)

## API Endpoints

See `ENDPOINTS.md` for complete reference (150+ endpoints)

**WildDuck API**: `https://HOSTNAME/api`
- Requires `X-Access-Token` header
- Token in `config-generated/wildduck/api.toml`

**Indexer API**: `https://HOSTNAME/idx`
- Wallet signature authentication
- OAuth 2.0 bearer tokens
- GraphQL endpoint at `/idx/graphql`

## Development Workflow

### Local Setup

1. **Prerequisites**:
   - Docker & Docker Compose
   - Node.js (for tests)
   - Domain name (for production)

2. **Quick Start**:
   ```bash
   ./setup.sh  # Interactive setup wizard
   # OR
   npm run deploy  # Same as setup.sh
   ```

3. **Backend Only**:
   ```bash
   ./setup_be.sh  # Mail services only
   ```

4. **Testing**:
   ```bash
   npm test  # Run integration tests
   ```

### Configuration Management

1. **Initial Setup**: `./setup.sh` generates configs in `config-generated/`
2. **Manual Edits**: Edit files in `config-generated/`
3. **Restart Services**: `cd config-generated && docker-compose restart <service>`

### Debugging

**Container Monitoring**:
```bash
./monitor-containers.sh status   # Check status
./monitor-containers.sh monitor  # Real-time logs
./monitor-containers.sh test     # Test DB connections
./monitor-containers.sh full     # Full diagnostic
```

**Database Issues**: See `DATABASE-DEBUG.md`

**Port Conflicts**:
```bash
./fix-port-conflict.sh    # Quick fix
./quick-fix-ports.sh      # Alternative
```

## Deployment Scenarios

### 1. Development (Local)

```bash
# Use alternative ports to avoid conflicts
docker-compose -f docker-compose-alt-ports.yml up -d

# Or use self-signed certs
./setup.sh  # Select self-signed option
```

### 2. Production (VPS/Cloud)

```bash
# Prerequisites
- Domain with DNS records
- Ports 25, 80, 443, 465, 993, 995 available
- Let's Encrypt for SSL

# Deploy
./setup.sh  # Follow production prompts

# DNS Records (from setup output)
- A record: HOSTNAME → Server IP
- MX record: mail.DOMAIN → HOSTNAME
- SPF, DKIM, DMARC records
```

### 3. Split Deployment

**Backend** (Mail services):
```bash
./setup_be.sh
```

**Frontend** (Webmail - deprecated):
```bash
./setup_fe.sh
```

## Testing

### Integration Tests

Location: `tests/`

**Test Coverage**:
- User authentication
- Email sending (SMTP)
- Email receiving (IMAP)
- API operations

**Run Tests**:
```bash
npm test  # All tests
# Individual test files in tests/
```

**Configuration**: `jest.config.ts`, `jest.setup.ts`

### Manual Testing

1. **API Testing**:
   ```bash
   # Get access token
   grep accessToken config-generated/wildduck/api.toml

   # Test endpoint
   curl -H "X-Access-Token: TOKEN" https://HOSTNAME/api/users
   ```

2. **Email Client**:
   - Server: HOSTNAME
   - IMAP: Port 993 (SSL/TLS)
   - SMTP: Port 465 (SSL/TLS)
   - Username: email@domain
   - Password: user password

## Common Tasks

### Add New User

**Via API**:
```bash
curl -X POST https://HOSTNAME/api/users \
  -H "X-Access-Token: TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "user",
    "password": "pass",
    "address": "user@domain.com",
    "name": "User Name"
  }'
```

**Via Script**: User setup is part of `./setup.sh`

### Update SSL Certificates

```bash
# Manual renewal
./update_certs.sh

# Or use cron (setup.sh creates this automatically)
```

### Check Service Health

```bash
# All services
docker-compose ps

# Specific service logs
docker-compose logs -f wildduck
docker-compose logs -f mail_box_indexer

# Health endpoints
curl http://localhost:8080/health      # WildDuck
curl http://localhost:42069/health     # Indexer
```

### Backup Data

**MongoDB**:
```bash
docker-compose exec mongo mongodump --out /backup
docker cp mongo:/backup ./mongo-backup
```

**PostgreSQL**:
```bash
docker-compose exec postgres pg_dump -U ponder mail_box_indexer > indexer-backup.sql
```

## Troubleshooting

### Container Restart Loop

**Symptoms**: Service restarts every 60s
**Diagnosis**: Check `DATABASE-DEBUG.md`
**Common Causes**:
- MongoDB/Redis not ready
- Network issues
- Configuration errors

### Port Conflicts

**Symptoms**: "Address already in use"
**Solution**:
```bash
./fix-port-conflict.sh
# OR
./setup-scripts/kill_ports.sh
```

### API Authentication Failures

**Check**:
1. Access token: `config-generated/wildduck/api.toml`
2. Token in header: `X-Access-Token: TOKEN`
3. Indexer: Verify wallet signature

### Email Not Sending/Receiving

**Check**:
1. DNS records (SPF, DKIM, MX)
2. Port 25 not blocked by ISP
3. Haraka/ZoneMTA logs
4. Rspamd filtering

## Security Considerations

1. **Access Control**:
   - Change default passwords
   - Restrict API access
   - Use strong tokens

2. **Network Security**:
   - Firewall rules
   - Traefik SSL/TLS
   - Internal network isolation

3. **Secrets Management**:
   - `.env` file (gitignored)
   - Never commit credentials
   - Rotate keys regularly

4. **Mail Security**:
   - SPF/DKIM/DMARC
   - Spam filtering (Rspamd)
   - TLS for all protocols

## AI Development Tips

### When Modifying Docker Compose

1. Always add health checks
2. Use service dependencies with `condition: service_healthy`
3. Expose ports only when needed (prefer internal networking)
4. Use environment variables for configuration
5. Document Traefik labels clearly

### When Adding Features

1. Update `ENDPOINTS.md` for new API routes
2. Add environment variables to `.env.example`
3. Update health checks if needed
4. Add tests in `tests/`
5. Update README with user-facing changes

### When Debugging

1. Start with `./monitor-containers.sh full`
2. Check service logs: `docker-compose logs -f SERVICE`
3. Test DB connections: `./monitor-containers.sh test`
4. Verify health endpoints
5. Check Traefik routing: `docker-compose logs traefik`

## Related Repositories

- **WildDuck**: `/Users/johnhuang/0xmail/wildduck`
- **Mail Box Indexer**: `/Users/johnhuang/0xmail/mail_box_indexer`
- **Haraka Plugin**: Custom build in `docker-images/`

## Version Information

- Project Version: 1.2.0
- WildDuck: latest
- Mail Box Indexer: latest
- Node.js: LTS
- Docker Compose: 3.8

## Quick Reference Commands

```bash
# Setup
./setup.sh                           # Full interactive setup
./setup_be.sh                        # Backend only

# Management
docker-compose up -d                 # Start all services
docker-compose down                  # Stop all services
docker-compose restart SERVICE       # Restart specific service
docker-compose logs -f SERVICE       # Follow logs

# Monitoring
./monitor-containers.sh status       # Service status
./monitor-containers.sh monitor      # Real-time monitoring
./versions.sh                        # Check versions

# Testing
npm test                             # Run tests
./basic-check.sh                     # Basic health check

# Diagnostics
./quick-diagnosis.sh                 # Quick diagnostic
./quick-diagnosis-v2.sh             # Enhanced diagnostic
./monitor-containers.sh full         # Full diagnostic report

# Fixes
./fix-port-conflict.sh              # Fix port conflicts
./fix_cors.sh                       # Fix CORS issues
./fix_wildduck_api.sh               # Fix API issues
```
