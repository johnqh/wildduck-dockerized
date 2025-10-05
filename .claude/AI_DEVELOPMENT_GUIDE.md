# AI-Assisted Development Guide

This guide helps AI assistants understand how to effectively work with this codebase.

## Quick Start for AI

### Understanding the Project

1. **Read First**:
   - `.claude/PROJECT_CONTEXT.md` - Project overview and common tasks
   - `.claude/ARCHITECTURE.md` - System architecture and data flows
   - `ENDPOINTS.md` - Complete API reference
   - `README.md` - User-facing documentation

2. **Key Files**:
   - `docker-compose.yml` - Service definitions
   - `.env.example` - Configuration template
   - `setup.sh` - Setup wizard
   - `DATABASE-DEBUG.md` - Debugging guide

3. **Related Codebases**:
   - WildDuck: `/Users/johnhuang/0xmail/wildduck`
   - Mail Box Indexer: `/Users/johnhuang/0xmail/mail_box_indexer`

## Common Development Tasks

### 1. Adding a New Service

**Steps**:
1. Add service to `docker-compose.yml`:
   ```yaml
   new_service:
     image: service:latest
     restart: unless-stopped
     depends_on:
       required_service:
         condition: service_healthy
     environment:
       - CONFIG_VAR=${CONFIG_VAR}
     healthcheck:
       test: ["CMD", "health-check-command"]
       interval: 30s
       timeout: 10s
       retries: 3
   ```

2. Add environment variables to `.env.example`
3. Update `README.md` service table
4. Add health check endpoint if applicable
5. Document in `.claude/ARCHITECTURE.md` if major component

**Testing**:
```bash
docker-compose config  # Validate syntax
docker-compose up new_service  # Test service
```

### 2. Adding Traefik Routing

**For HTTP/HTTPS**:
```yaml
labels:
  traefik.enable: true
  traefik.http.routers.service-name.entrypoints: websecure
  traefik.http.routers.service-name.rule: Host(`HOSTNAME`) && PathPrefix(`/path`)
  traefik.http.routers.service-name.tls: true
  traefik.http.routers.service-name.tls.certresolver: letsencrypt
  traefik.http.services.service-name.loadbalancer.server.port: 8080
```

**With Path Stripping**:
```yaml
traefik.http.routers.service-name.middlewares: service-stripprefix@docker
traefik.http.middlewares.service-stripprefix.stripprefix.prefixes: /path
```

**For TCP (Mail Protocols)**:
```yaml
traefik.tcp.routers.service-name.entrypoints: imaps
traefik.tcp.routers.service-name.rule: HostSNI(`HOSTNAME`)
traefik.tcp.routers.service-name.tls: true
traefik.tcp.services.service-name.loadbalancer.server.port: 993
```

### 3. Modifying Environment Variables

**Process**:
1. Add to `.env.example` with documentation:
   ```bash
   # Description of what this does
   # Example: value-example
   # Required/Optional: Optional
   NEW_VAR=default-value
   ```

2. Add to service environment in `docker-compose.yml`:
   ```yaml
   environment:
     - NEW_VAR=${NEW_VAR:-default-value}
   ```

3. Update `README.md` if user-facing
4. Update `.claude/PROJECT_CONTEXT.md` if important

### 4. Adding API Endpoints

**When modifying WildDuck or Indexer**:
1. Implement endpoint in respective repository
2. Update `ENDPOINTS.md`:
   ```markdown
   ### METHOD /path/:param
   Description
   - **Params**: param - Description
   - **Body**: `{ "field": type }`
   - **Auth**: Authentication method
   - **Response**: Response description
   ```

3. Add integration test in `tests/` if applicable

### 5. Debugging Issues

**Process**:
1. Run diagnostics:
   ```bash
   ./monitor-containers.sh full > diagnostic.txt
   ```

2. Check service logs:
   ```bash
   docker-compose logs -f SERVICE_NAME
   ```

3. Test connectivity:
   ```bash
   docker-compose exec SERVICE ping OTHER_SERVICE
   ```

4. Check health endpoints:
   ```bash
   curl http://localhost:8080/health  # WildDuck
   curl http://localhost:42069/health # Indexer
   ```

5. Verify configuration:
   ```bash
   docker-compose config  # Show resolved config
   ```

**Common Issues**:
- Container restart loop → See `DATABASE-DEBUG.md`
- Port conflicts → Run `./fix-port-conflict.sh`
- API authentication → Check token in `config-generated/wildduck/api.toml`
- Network issues → Verify Docker DNS resolution

### 6. Writing Tests

**Structure** (`tests/`):
```typescript
import { describe, test, expect } from '@jest/globals';

describe('Feature Name', () => {
  test('should do something', async () => {
    // Arrange
    const input = setupTestData();

    // Act
    const result = await performAction(input);

    // Assert
    expect(result).toBe(expected);
  });
});
```

**Run Tests**:
```bash
npm test                    # All tests
npm test -- tests/file.test.ts  # Specific file
```

### 7. Updating Documentation

**When to Update**:
- New service → README.md, ARCHITECTURE.md
- New endpoint → ENDPOINTS.md
- New env var → .env.example, README.md
- Bug fix → No doc update needed (unless fix requires config change)
- New feature → All relevant docs

**Documentation Hierarchy**:
1. `.env.example` - Configuration options
2. `README.md` - User guide
3. `ENDPOINTS.md` - API reference
4. `.claude/PROJECT_CONTEXT.md` - Developer context
5. `.claude/ARCHITECTURE.md` - Technical details
6. `DATABASE-DEBUG.md` - Debugging guide

## Code Style & Conventions

### Docker Compose

**Order of Keys**:
```yaml
service_name:
  image:           # Official image or custom
  restart:         # Usually unless-stopped
  command:         # If overriding
  ports:           # External:internal
  depends_on:      # With health conditions
  volumes:         # Config mounts
  environment:     # Env vars
  healthcheck:     # Health check definition
  labels:          # Traefik labels
```

**Environment Variables**:
- Use `${VAR:-default}` for optional vars
- Use `${VAR}` for required vars
- Document all vars in `.env.example`

**Comments**:
- Add comments for non-obvious configuration
- Document Traefik labels
- Explain health check commands

### Shell Scripts

**Header**:
```bash
#!/bin/bash
# Script Name
# Description: What this script does
# Usage: ./script.sh [arguments]

set -e  # Exit on error
```

**Functions**:
```bash
# Function description
# Arguments: $1 - description
# Returns: return code or output
function_name() {
  local var_name=$1
  # Function body
}
```

**Error Handling**:
```bash
if ! command; then
  echo "Error: Description" >&2
  exit 1
fi
```

### Configuration Files

**TOML** (WildDuck):
```toml
[section]
# Comment describing the setting
key = "value"

# Another setting
other_key = 123
```

**Environment** (.env):
```bash
# Category Header
# =============================================================================

# Setting description
# Example: example-value
# Default: default-value
SETTING_NAME=value
```

## AI-Specific Guidelines

### When Reading Code

1. **Check file context**:
   - Is it production code or testing?
   - Is it config template or generated?
   - What service does it belong to?

2. **Look for patterns**:
   - Similar services in docker-compose
   - Existing API endpoints in same category
   - Established conventions

3. **Consider dependencies**:
   - What services does this depend on?
   - What depends on this?
   - How will changes propagate?

### When Generating Code

1. **Match existing style**:
   - Follow conventions in similar files
   - Use same indentation (spaces in YAML, varies in code)
   - Match naming patterns

2. **Include error handling**:
   - Health checks for new services
   - Error messages in scripts
   - Fallback values in configs

3. **Document changes**:
   - Inline comments for complex logic
   - Update relevant .md files
   - Add to .env.example if new vars

4. **Validate before committing**:
   - `docker-compose config` for syntax
   - Test health checks work
   - Verify dependent services

### When Debugging

1. **Gather information first**:
   - Run diagnostic scripts
   - Check all relevant logs
   - Verify configuration

2. **Form hypothesis**:
   - What could cause this?
   - What changed recently?
   - Is this environment-specific?

3. **Test systematically**:
   - One change at a time
   - Verify each fix
   - Document solution

4. **Update docs if needed**:
   - Add to DATABASE-DEBUG.md if database issue
   - Update README if common issue
   - Create new doc if complex topic

### When Modifying Architecture

1. **Check impact**:
   - What breaks if I change this?
   - What needs updating?
   - Can this be rolled back?

2. **Update diagrams**:
   - ARCHITECTURE.md has ASCII art
   - Update data flows
   - Add new integration points

3. **Consider scaling**:
   - Will this work with multiple instances?
   - Does this affect performance?
   - Are there resource implications?

4. **Document thoroughly**:
   - Why this approach?
   - What alternatives considered?
   - What are the tradeoffs?

## Commit Message Guidelines

**Format**:
```
type: brief description (max 50 chars)

Detailed explanation of what changed and why (wrap at 72 chars).

- Bullet points for multiple changes
- Include breaking changes
- Reference issues if applicable

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types**:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation only
- `refactor:` - Code restructure (no behavior change)
- `test:` - Adding tests
- `chore:` - Maintenance (dependencies, etc.)
- `perf:` - Performance improvement

**Examples**:
```
feat: add PostgreSQL database for blockchain indexing

- Add postgres service to docker-compose.yml
- Configure health checks and dependencies
- Add connection string to .env.example
- Update README with database info
```

```
fix: resolve container restart loop in WildDuck

WildDuck was restarting every 60s due to MongoDB connection timeout.
Added health check dependency and increased connection timeout.

Fixes issue with database not ready on startup.
```

## Testing Strategy

### Levels of Testing

1. **Syntax Validation**:
   ```bash
   docker-compose config
   ```

2. **Service Health**:
   ```bash
   docker-compose up -d
   docker-compose ps  # All should be healthy
   ```

3. **Integration Tests**:
   ```bash
   npm test
   ```

4. **Manual Testing**:
   - IMAP/SMTP client connection
   - API endpoint calls
   - Blockchain event processing

### Test Data

**Test Users** (for integration tests):
- Configure in `.env` file
- Use separate test domain
- Clean up after tests

**Test Blockchain Events**:
- Use testnets (Sepolia, etc.)
- Indexer has test transaction endpoint
- Mock data in unit tests

## Security Considerations

### Secret Management

**Never Commit**:
- `.env` files
- Private keys
- API tokens
- Passwords

**Gitignored**:
```
.env
.env.local
.env.*.local
config/
config-generated/
certs/
```

### Configuration Review

**Check for**:
- Hardcoded credentials
- Default passwords
- Exposed ports (should be localhost only where appropriate)
- Missing authentication
- Overly permissive CORS

### Code Review Checklist

- [ ] No secrets in code
- [ ] Environment variables documented
- [ ] Health checks implemented
- [ ] Error handling present
- [ ] Tests passing
- [ ] Documentation updated
- [ ] Breaking changes noted

## Performance Optimization

### Docker Optimization

**Image Size**:
- Use alpine variants where possible
- Multi-stage builds for custom images
- Clean up package caches

**Resource Limits**:
```yaml
deploy:
  resources:
    limits:
      cpus: '1'
      memory: 1G
    reservations:
      cpus: '0.5'
      memory: 512M
```

**Volume Performance**:
- Named volumes for databases (better performance)
- Bind mounts for config (easier editing)

### Database Optimization

**MongoDB**:
- Indexes on common queries
- Connection pooling
- Appropriate chunk sizes

**PostgreSQL**:
- Indexes on address lookups
- Query optimization
- Regular VACUUM

**Redis**:
- Appropriate eviction policy
- Memory limits
- Persistence settings

## Troubleshooting Guide for AI

### Container Won't Start

**Check**:
1. `docker-compose logs SERVICE`
2. Health check command works manually
3. Dependencies are healthy
4. Configuration syntax valid
5. Ports not in use

### Service Unreachable

**Check**:
1. Service running: `docker-compose ps`
2. Network connectivity: `docker-compose exec SERVICE ping TARGET`
3. Traefik routing: `docker-compose logs traefik`
4. Firewall rules
5. DNS resolution

### Database Connection Fails

**Check**:
1. Database service healthy
2. Connection string correct
3. Network connectivity
4. Credentials valid
5. Database initialized

**See**: `DATABASE-DEBUG.md` for detailed guide

### API Returns Errors

**Check**:
1. Authentication headers present
2. Request body valid
3. Service logs for errors
4. Database accessible
5. Rate limiting not triggered

### Blockchain Events Not Indexing

**Check**:
1. Alchemy/Helius API key valid
2. RPC endpoint accessible
3. Contract addresses correct
4. Start block configured
5. PostgreSQL connected

## Quick Reference

### Essential Commands

```bash
# Validate configuration
docker-compose config

# Start services
docker-compose up -d

# View logs
docker-compose logs -f [SERVICE]

# Restart service
docker-compose restart [SERVICE]

# Stop all
docker-compose down

# Check health
docker-compose ps

# Execute in container
docker-compose exec [SERVICE] [COMMAND]

# Diagnostics
./monitor-containers.sh full

# Run tests
npm test
```

### File Locations

```
Configuration:
  - docker-compose.yml          Main deployment file
  - .env                        Environment variables
  - config/                     Service configs (generated)

Documentation:
  - README.md                   User guide
  - ENDPOINTS.md                API reference
  - .claude/PROJECT_CONTEXT.md  Dev context
  - .claude/ARCHITECTURE.md     Technical details

Scripts:
  - setup.sh                    Setup wizard
  - monitor-containers.sh       Diagnostics
  - fix-*.sh                    Fix scripts

Tests:
  - tests/                      Integration tests
  - package.json                Test config
```

### Key Endpoints

```bash
# Health checks
http://localhost:8080/health        # WildDuck
http://localhost:42069/health       # Indexer

# APIs
https://HOSTNAME/api                # WildDuck API
https://HOSTNAME/idx                # Indexer API
https://HOSTNAME/idx/graphql        # GraphQL

# Traefik dashboard (if enabled)
http://localhost:8080               # Traefik UI
```

### Environment Variables Lookup

See `.env.example` for complete list with descriptions.

**Most Important**:
- `INDEXER_PRIVATE_KEY` - Required for indexer
- `INDEXER_WALLET_ADDRESS` - Required for indexer
- `ALCHEMY_API_KEY` - Required for blockchain indexing
- `EMAIL_DOMAIN` - Default email domain

## Next Steps

After reading this guide:
1. Review existing code in `docker-compose.yml`
2. Run `./setup.sh` to understand setup flow
3. Check `tests/` for testing patterns
4. Experiment with diagnostic scripts
5. Read WildDuck and Indexer source code for deeper understanding

Remember: When in doubt, check existing patterns in the codebase and follow established conventions.
