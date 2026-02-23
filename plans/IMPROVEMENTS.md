# Improvement Plans for wildduck-dockerized

## Priority 1 - High Impact

### 1. Expand E2E Test Coverage
- The `tests/e2e/email.test.ts` file covers the basic email flow (create users, send, receive, delete), but critical deployment scenarios are untested: DKIM signing verification, spam filtering through Rspamd, ZoneMTA outbound delivery, Traefik TLS termination, and wallet-based authentication through the Mail Box Indexer.
- The test utilities (`tests/utils/usersApi.ts`, `tests/utils/mailUtils.ts`) lack error handling documentation and JSDoc. Adding typed error responses and documenting expected environment variables would make tests more maintainable.
- There are no tests for the upgrade flow (`upgrade.sh`) to verify zero-downtime behavior and config preservation. A smoke test that validates service health after an upgrade would catch regressions.

### 2. Harden setup.sh Error Handling and Idempotency
- `setup.sh` is approximately 1050 lines of interactive Bash with limited error recovery. If the script fails mid-execution (e.g., during DKIM generation or Docker Compose startup), there is no documented recovery path. Adding checkpoints and a `--resume` flag would improve reliability.
- The script modifies `config-generated/` in place without backup. Adding automatic backup of previous configs before overwrite would prevent accidental data loss during re-runs.
- Doppler token validation happens early, but if the Doppler API is temporarily unavailable the script fails without a retry mechanism. Adding retry logic for external API calls would improve robustness.

### 3. Add Container Health Check Documentation and Alerting Hooks
- Health checks are defined in `docker-compose.yml` for MongoDB, Redis, PostgreSQL, WildDuck, and Indexer, but there is no alerting integration. Documenting how to connect `monitor-containers.sh` output to external monitoring (e.g., Prometheus, Uptime Kuma) would improve production readiness.
- The `monitor-containers.sh full` command provides diagnostics but the output format is not machine-parseable. Adding a `--json` output mode would enable integration with monitoring dashboards.

## Priority 2 - Medium Impact

### 4. Improve Secret Rotation Workflow
- Shared secrets (SRS_SECRET, DKIM_SECRET, HMAC_SECRET) must match across WildDuck, ZoneMTA, and Haraka, but the rotation process is manual and undocumented. A dedicated `rotate-secrets.sh` script that updates all three services atomically would reduce operational risk.
- DKIM key rotation (monthly selector format `mon-year`) is generated during setup but there is no automated rotation script. Adding a `rotate-dkim.sh` that generates a new key, registers it via the API, and updates DNS records guidance would be valuable.

### 5. Docker Compose Template Improvements
- The `docker-compose.yml` template uses static IPs (`172.20.0.10`, `172.20.0.20`) for inter-service authentication. Replacing IP-based restrictions with Docker network aliases and shared secrets would be more resilient to network reconfiguration.
- Resource limits (CPU, memory) are not defined for any container. Adding resource constraints would prevent a single misbehaving service (e.g., Rspamd under spam attack) from starving other services.

### 6. Centralize Configuration Validation
- Configuration is spread across `.env`, Doppler, TOML templates, and `docker-compose.yml` with placeholder replacement. A validation step (e.g., `./validate-config.sh`) that checks all required variables are set, ports do not conflict, and database URLs are reachable before starting services would catch misconfigurations early.
- The `default-config/` templates contain multiple occurrences of `HOSTNAME` and `API_HOSTNAME` placeholders. Documenting which files contain which placeholders would make debugging configuration issues easier.

## Priority 3 - Nice to Have

### 7. Add Development Mode Docker Compose
- `docker-compose-alt-ports.yml` exists for alternative port mappings but a full development mode with volume mounts for live code reloading, debug logging enabled, and mock external services (Alchemy, Doppler) would accelerate local development.
- Adding a `docker-compose.dev.yml` override that mounts local WildDuck and Haraka source code for rapid iteration would reduce the build-push-pull cycle.

### 8. Document Backup and Disaster Recovery
- MongoDB, PostgreSQL, and Redis all store critical data but there are no backup scripts or documentation. Adding `backup.sh` and `restore.sh` scripts with documented backup strategies (mongodump, pg_dump, Redis RDB snapshots) would improve operational maturity.
- The `DATABASE-DEBUG.md` covers troubleshooting but not preventive measures. Adding a section on regular maintenance tasks (index rebuilding, log rotation, certificate renewal monitoring) would be valuable.

### 9. Add CI/CD for Infrastructure Changes
- `.github/workflows/` contains CI for building custom Docker images (Haraka, Rspamd, ZoneMTA, setup) but there is no validation for the shell scripts themselves. Adding ShellCheck linting and basic syntax validation for `setup.sh`, `upgrade.sh`, and `monitor-containers.sh` would catch scripting errors before deployment.
