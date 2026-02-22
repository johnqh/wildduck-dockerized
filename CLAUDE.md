# wildduck-dockerized - AI Development Guide

## Overview

Complete Docker-based deployment infrastructure for the 0xmail email system. Orchestrates 10 containerized services into a production-ready email platform with blockchain wallet authentication, one-command setup, automatic TLS via Let's Encrypt, and multi-chain indexing.

- **Version**: 1.10.2
- **Type**: Infrastructure (private)
- **Package Manager**: npm (with `package-lock.json`; Bun also supported)
- **Language**: TypeScript (ESM, `"type": "module"`)
- **License**: EUPL-1.2

## Project Structure

```
wildduck-dockerized/
├── docker-compose.yml                # Main orchestration template (~18KB)
├── docker-compose-alt-ports.yml      # Alternative port mappings for dev
├── setup.sh                          # Interactive deployment wizard (~1050 lines)
├── upgrade.sh                        # Zero-downtime container upgrade script
├── versions.sh                       # Display version info for running services
├── monitor-containers.sh             # Real-time health monitoring
├── .env.example                      # 60+ environment variables with docs
├── example.env                       # Test-focused env vars (SMTP/IMAP/API)
├── package.json                      # npm scripts: test, deploy, update-certs
├── jest.config.ts / jest.setup.ts    # Jest with ts-jest preset, dotenv loading
├── default-config/                   # Service configuration templates
│   ├── wildduck/                     # TOML configs (default, dbs, api, imap, dkim, etc.)
│   ├── haraka/                       # SMTP config (~40 files: wildduck.yaml, smtp.ini, etc.)
│   ├── zone-mta/                     # Outbound SMTP (dbs-*.toml, plugins/wildduck.toml)
│   └── rspamd/                       # Spam filter (override.d/, worker-normal.conf)
├── setup-scripts/                    # Modular setup: deps, dns, mongo, ssl, kill_ports, user
├── docker-images/                    # Custom Dockerfiles (haraka/, rspamd/, zone-mta/)
├── dynamic_conf/dynamic.yml          # Traefik TLS cert paths (self-signed mode)
├── tests/                            # Jest E2E tests
│   ├── e2e/email.test.ts             # Full email flow: create, send, receive, delete
│   └── utils/                        # usersApi.ts (axios), mailUtils.ts (ImapFlow/Nodemailer)
├── .claude/                          # AI context (ARCHITECTURE.md, commands/)
├── .github/workflows/               # CI: build-haraka, build-rspamd, build-zonemta, build-setup
├── DNS.md / ENDPOINTS.md             # DNS records reference, full API reference (150+ endpoints)
└── DATABASE-DEBUG.md                 # Database troubleshooting guide
```

## Services

All services run on Docker bridge network `wildduck_network` (subnet `172.20.0.0/16`).

| Service | Image | Ports (internal -> external) | Purpose |
|---------|-------|------------------------------|---------|
| WildDuck | `johnqh/wildduck:latest` | 8080->127.0.0.1:8080, 143, 110 | IMAP/POP3 mail server + REST API. Static IP: 172.20.0.10 |
| ZoneMTA | `ghcr.io/zone-eu/zonemta-wildduck:1.32.20` | 587->Traefik:465 | Outbound SMTP: queues, DKIM signs, delivers |
| Haraka | `johnqh/haraka:latest` | 25->25 (direct) | Inbound SMTP: receives mail, integrates Rspamd |
| Rspamd | `nodemailer/rspamd` | 11333/11334 (internal) | Spam filtering, DKIM/SPF/DMARC verification |
| Mail Box Indexer | `johnqh/mail_box_indexer:latest` | 42069->Traefik | Blockchain indexing, wallet auth, OAuth 2.0, points. IP: 172.20.0.20 |
| PostgreSQL | `postgres:15` | 5432->127.0.0.1:5432 | Indexer database (Ponder framework) |
| MongoDB | `mongo` | 27017 (internal) | Users, mailboxes, messages, queues |
| Redis | `redis:alpine` | 6379 (internal) | Sessions (DB 3), ZoneMTA queue (DB 5), rate limiting (DB 8) |
| Traefik | `traefik:2.11` | 80, 443, 993, 995, 465 | Reverse proxy, TLS termination, Let's Encrypt |
| Static Files | `nginx:alpine` | 80 (internal) | Serves robots.txt for API domain |

Health checks: MongoDB (`mongosh ping`, 10s), Redis (`redis-cli ping`, 10s), PostgreSQL (`pg_isready`, 10s), WildDuck (`wget /health`, 30s, 60s start), Indexer (`wget /health`, 30s, 120s start).

## Development Commands

```bash
npm install                           # Install dependencies
npm test                              # Run Jest E2E tests (requires running services + .env)
npm run deploy                        # Run setup.sh (requires sudo)
npm run update-certs                  # Extract certs from Traefik for Haraka

./versions.sh                         # Show all container versions
./upgrade.sh                          # Upgrade containers (6-step: Doppler, config, stop, pull, start)
./monitor-containers.sh full          # Full diagnostics

# Docker Compose (run from config-generated/)
cd config-generated
sudo docker compose up -d             # Start all
sudo docker compose logs -f <svc>     # Follow logs
sudo docker compose restart <svc>     # Restart service
sudo docker compose down              # Stop all
sudo docker compose ps                # Show status
```

## Architecture / Patterns

### Traefik Routing (v2.11 LTS)

| Entrypoint | Port | Routes To |
|------------|------|-----------|
| `web` | 80 | `/api` -> WildDuck:8080, `/idx` -> Indexer:42069, `/robots.txt` -> static-files |
| `websecure` | 443 | Same with TLS; HTTP redirects to HTTPS |
| `imaps` | 993 | `HostSNI(HOSTNAME)` -> WildDuck:143 |
| `pop3s` | 995 | `HostSNI(HOSTNAME)` -> WildDuck:110 |
| `smtps` | 465 | `HostSNI(HOSTNAME)` -> ZoneMTA:587 |

Middleware: CORS headers (allow all origins) -> Strip prefix (`/api` or `/idx`) -> Forward. `HOSTNAME` = mail hostname (e.g., `mail.0xmail.box`), `API_HOSTNAME` = API hostname (e.g., `api.0xmail.box`), both replaced by `setup.sh`.

### Email Flow

- **Inbound**: Internet -> Port 25 -> Haraka -> Rspamd (spam check) -> MongoDB (store)
- **Outbound**: Client -> Traefik:465 -> ZoneMTA:587 (DKIM sign, queue) -> Internet
- **Auth**: WildDuck delegates wallet auth to Indexer via `POST /authenticate` (IP-restricted)

### Configuration Generation (setup.sh)

1. Prompts for domain, hostnames, Doppler token
2. Downloads/merges secrets from Doppler into `.env`
3. Copies `default-config/` -> `config-generated/config/`, `docker-compose.yml` -> `config-generated/`
4. Replaces `HOSTNAME`/`API_HOSTNAME` placeholders in docker-compose
5. Generates shared secrets (SRS, DKIM, HMAC) or uses Doppler values
6. Configures database URLs across WildDuck, ZoneMTA, Haraka
7. Sets up TLS (self-signed for dev, Let's Encrypt for production)
8. Extracts Let's Encrypt certs from `acme.json` for Haraka
9. Generates DKIM keys + DNS record file, registers DKIM via API
10. Starts all services

For remote MongoDB/PostgreSQL, setup.sh auto-detects remote URLs and comments out local service definitions in docker-compose.

### Secrets

- **Doppler**: Primary secrets manager. Token stored in `.doppler-token` (chmod 600). Doppler values override `.env`.
- **Shared secrets**: SRS_SECRET, DKIM_SECRET, HMAC_SECRET must match between WildDuck, ZoneMTA, and Haraka.
- **Inter-service auth**: IP-based restrictions between WildDuck (172.20.0.10) and Indexer (172.20.0.20).

## Environment Configuration

### Required Variables

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection for indexer |
| `INDEXER_PRIVATE_KEY` | Blockchain wallet private key |
| `INDEXER_WALLET_ADDRESS` | Wallet address for indexer auth |
| `ALCHEMY_API_KEY` | Primary RPC provider |

### WildDuck Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WILDDUCK_DBS_MONGO` | `mongodb://mongo:27017/wildduck` | MongoDB connection |
| `WILDDUCK_API_ROOTUSERNAME` | `admin` | Admin username |
| `WILDDUCK_EMAILDOMAIN` | `0xmail.box` | Email domain for accounts |
| `EMAIL_DOMAIN` | `0xmail.box` | Domain for Haraka and Indexer |

### RPC Providers

Multiple providers for redundancy: `ALCHEMY_API_KEY`, `ANKR_API_KEY`, `METAMASK_API_KEY`, `CHAINSTACK_*_ENDPOINT` (per-chain). Select via `PREFERRED_MAILER_RPC` and `PREFERRED_3DNS_RPC`.

### Indexer Tuning

`PONDER_POLLING_INTERVAL` (default 5000ms), per-chain overrides (`PONDER_POLLING_INTERVAL_MAINNET` etc.), `PONDER_MAX_RPS`, `PONDER_RPC_TIMEOUT` (60s), `PONDER_DATABASE_TIMEOUT` (300s), `ENABLE_TESTNETS` (false).

### Optional Integrations

`SUMSUB_*` (KYC, requires `KYC_ENABLED=true`), `HELIUS_API_KEY`/`SOLANA_RPC_URL` (Solana), `JWT_SECRET`/`JWT_ISSUER` (OAuth), `REVENUECAT_*` (subscriptions).

## DNS Records

`setup.sh` generates `<domain>-nameserver.txt` with:

```
<domain>. IN MX 5 <hostname>.                              # Route mail
<domain>. IN TXT "v=spf1 ip4:<SERVER_IP> ~all"             # SPF authorization
<selector>._domainkey.<domain>. IN TXT "v=DKIM1;k=rsa;p=<KEY>" # DKIM signing
_dmarc.<domain>. IN TXT "v=DMARC1; p=reject;"              # DMARC policy
```

DKIM selector format: `mon-year` (e.g., `oct2025`). Keys are 1024-bit RSA, generated by `setup-scripts/dns_setup.sh` and registered via `POST /dkim`. PTR record must be set at hosting provider.

## Common Tasks

### Deploying
```bash
sudo ./setup.sh  # Follow prompts for domain, Doppler token, certs
```

### Upgrading
```bash
./upgrade.sh  # Pulls latest images, preserves config+secrets, restarts
```

### Creating Users
```bash
curl -XPOST https://api.<domain>/api/users \
  -H 'Content-type: application/json' \
  -H 'X-Access-Token: <from_api.toml>' \
  -d '{"username": "alice", "password": "pass", "address": "alice@<domain>"}'
```

### Managing DKIM
```bash
curl http://localhost:8080/dkim                    # List keys
curl -XDELETE http://localhost:8080/dkim/<id>      # Delete key
```

### Certificate Renewal
Traefik auto-renews Let's Encrypt. Haraka needs: `./update_certs.sh` (weekly cron set by setup.sh).

### Running Tests
Configure `.env` with `SMTP_HOST`, `SMTP_PORT=465`, `IMAP_HOST`, `IMAP_PORT=993`, `ACCESS_TOKEN`, `DOMAIN_NAME`, `WILDDUCK_API_URL`. Then: `npm test`.

## Integration Points

### WildDuck <-> Mail Box Indexer
- WildDuck -> Indexer: `POST http://mail_box_indexer:42069/authenticate` (wallet auth, IP-restricted), `POST /wallets/:addr/points/add` (points tracking)
- Indexer -> WildDuck: `POST http://wildduck:8080/users` (account creation on blockchain domain registration)

### Haraka <-> WildDuck
Haraka delivers inbound mail via `wildduck` plugin. Shares MongoDB URL and SRS secret.

### ZoneMTA <-> WildDuck
Both use same MongoDB (same DB name required). ZoneMTA writes to `sender` collection. DKIM secret must be identical in `zone-mta/plugins/wildduck.toml` and `wildduck/dkim.toml`.

### Rspamd <-> Haraka / Redis
Haraka forwards mail to Rspamd for spam analysis. Rspamd uses Redis for stats and greylisting. Runs as UID 11333.

### Traefik <-> Services
Docker socket mount (read-only) for auto-discovery via labels. Services opt-in with `traefik.enable: true`.

### External APIs
- **Alchemy/Ankr/Chainstack**: Blockchain RPC for indexing (Ethereum, Polygon, Optimism, Base, Arbitrum)
- **Helius**: Solana webhooks for SNS domains
- **Sumsub**: KYC verification (optional)
- **RevenueCat**: Subscription management (optional)

### API Surface
- **WildDuck API** at `/api`: 118+ endpoints for users, mailboxes, messages, DKIM, webhooks, 2FA. Auth: `X-Access-Token` header.
- **Indexer API** at `/idx`: 36+ endpoints + GraphQL for OAuth 2.0, wallet auth, points, referrals, KYC, blockchain status. Auth: wallet signature or Bearer token.
- Full reference: `ENDPOINTS.md`
