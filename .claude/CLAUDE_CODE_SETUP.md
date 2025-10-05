# Claude Code Setup for WildDuck Dockerized

This document explains the Claude Code setup for optimal AI-assisted development.

## Available Commands

Custom slash commands are available in `.claude/commands/`:

- `/deploy` - Run setup wizard
- `/test` - Run integration tests
- `/diagnose` - Full system diagnostics

## Auto-Approved Operations

The following operations are pre-approved in `.claude/settings.local.json`:

### File Operations
- `Read(//Users/johnhuang/0xmail/mail_box_indexer/**)` - Read indexer source
- `Read(//Users/johnhuang/0xmail/wildduck/**)` - Read WildDuck source

### Git Operations
- `Bash(chmod:*)` - File permissions
- `Bash(git add:*)` - Stage changes
- `Bash(git commit:*)` - Commit changes
- `Bash(git push:*)` - Push to remote

### Web Operations
- `WebFetch(domain:github.com)` - Fetch GitHub pages
- `WebFetch(domain:raw.githubusercontent.com)` - Fetch raw files

## Context Files

AI assistants should read these files first:

1. **`.claude/PROJECT_CONTEXT.md`** - Project overview, common tasks, quick reference
2. **`.claude/ARCHITECTURE.md`** - System architecture, data flows, integration points
3. **`.claude/AI_DEVELOPMENT_GUIDE.md`** - Development guidelines, coding conventions, testing
4. **`ENDPOINTS.md`** - Complete API reference (150+ endpoints)
5. **`README.md`** - User-facing documentation
6. **`DATABASE-DEBUG.md`** - Debugging guide for database issues

## Project Structure

```
wildduck-dockerized/
├── .claude/                    # Claude Code configuration
│   ├── PROJECT_CONTEXT.md     # Start here for project overview
│   ├── ARCHITECTURE.md        # Technical architecture details
│   ├── AI_DEVELOPMENT_GUIDE.md # Development guidelines for AI
│   ├── CLAUDE_CODE_SETUP.md   # This file
│   ├── commands/              # Slash command definitions
│   └── settings.local.json    # Auto-approval settings
├── docker-compose.yml         # Main deployment (heavily documented)
├── .env.example              # Configuration template
├── ENDPOINTS.md              # API reference
├── DATABASE-DEBUG.md         # Debugging guide
└── README.md                 # User guide
```

## Development Workflow

### 1. Understanding the Codebase

```bash
# Read context files (in order)
.claude/PROJECT_CONTEXT.md     # Overview
.claude/ARCHITECTURE.md        # Architecture
.claude/AI_DEVELOPMENT_GUIDE.md # Guidelines

# Check current deployment
docker-compose.yml             # Service definitions
.env.example                   # Configuration options
```

### 2. Making Changes

```bash
# Modify service configuration
vim docker-compose.yml

# Update environment variables
vim .env.example

# Validate changes
docker-compose config

# Test changes
docker-compose up SERVICE
```

### 3. Testing

```bash
# Run integration tests
npm test

# Run diagnostics
./monitor-containers.sh full

# Check specific service
docker-compose logs -f SERVICE
```

### 4. Documentation

When making changes, update:
- `docker-compose.yml` - Inline comments
- `.env.example` - New variables
- `ENDPOINTS.md` - New API routes
- `README.md` - User-facing features
- `.claude/PROJECT_CONTEXT.md` - Development context
- `.claude/ARCHITECTURE.md` - Architecture changes

## AI Assistant Guidelines

### Quick Start

1. Read `.claude/PROJECT_CONTEXT.md` for project overview
2. Read `.claude/ARCHITECTURE.md` for system architecture
3. Read `.claude/AI_DEVELOPMENT_GUIDE.md` for conventions
4. Check `docker-compose.yml` for current configuration
5. Review `ENDPOINTS.md` for API reference

### Common Tasks

**Adding a Service**:
1. Add to `docker-compose.yml` with inline comments
2. Add env vars to `.env.example`
3. Update README service table
4. Add to ARCHITECTURE.md if major component

**Adding an Endpoint**:
1. Implement in WildDuck or Indexer repo
2. Update `ENDPOINTS.md`
3. Add integration test if applicable

**Debugging**:
1. Run `/diagnose` or `./monitor-containers.sh full`
2. Check service logs: `docker-compose logs -f SERVICE`
3. Consult `DATABASE-DEBUG.md`

**Documenting**:
1. Update inline comments in code
2. Update relevant .md files
3. Ensure .env.example is current

### Code Conventions

- **Docker Compose**: Inline comments for all services
- **Environment Variables**: Document in `.env.example`
- **Shell Scripts**: Header with description and usage
- **Commits**: Follow conventional commits format

See `.claude/AI_DEVELOPMENT_GUIDE.md` for detailed conventions.

## Related Repositories

When working on integrated features:

- **WildDuck**: `/Users/johnhuang/0xmail/wildduck`
  - IMAP/POP3/SMTP server
  - REST API implementation
  - User management

- **Mail Box Indexer**: `/Users/johnhuang/0xmail/mail_box_indexer`
  - Blockchain indexing (Ponder)
  - OAuth 2.0 provider
  - Points system
  - KYC integration

These repos are pre-approved for reading in Claude Code settings.

## Best Practices

1. **Read Before Modify**:
   - Always read context files first
   - Check existing patterns
   - Understand dependencies

2. **Validate Changes**:
   - `docker-compose config` for syntax
   - Test health checks work
   - Verify dependent services

3. **Document Thoroughly**:
   - Inline comments for complex logic
   - Update .md files for new features
   - Keep .env.example current

4. **Test Systematically**:
   - One change at a time
   - Run diagnostics after changes
   - Verify integration tests pass

5. **Follow Conventions**:
   - Match existing code style
   - Use established patterns
   - Follow commit message format

## Troubleshooting Claude Code

### Commands Not Working

- Check `.claude/commands/` directory exists
- Verify command files have `.md` extension
- Ensure files have proper content

### Auto-Approval Not Working

- Check `.claude/settings.local.json` syntax
- Verify paths match exactly
- Restart Claude Code if needed

### Context Not Loading

- Ensure context files exist in `.claude/`
- Check file permissions
- Verify markdown syntax

## Getting Help

If stuck:
1. Run `/diagnose` for system diagnostics
2. Check `DATABASE-DEBUG.md` for database issues
3. Review logs: `docker-compose logs -f SERVICE`
4. Consult `.claude/AI_DEVELOPMENT_GUIDE.md`
5. Check related repos for source code

## Next Steps

After setup:
1. Read all context files in `.claude/`
2. Run `/deploy` to understand setup flow
3. Run `/test` to verify everything works
4. Experiment with `/diagnose` for monitoring
5. Review `docker-compose.yml` for service details
6. Check `ENDPOINTS.md` for API capabilities

Remember: The project is heavily documented for AI comprehension. When in doubt, check the docs!
