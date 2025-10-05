# Diagnose Command

Run comprehensive diagnostics on the mail server deployment.

This provides:
- Container status and health checks
- Service logs and errors
- Database connectivity tests
- Resource usage
- Network configuration

```bash
./monitor-containers.sh full
```

For specific checks:
- `./monitor-containers.sh status` - Quick status
- `./monitor-containers.sh monitor` - Real-time monitoring
- `./monitor-containers.sh test` - Database connectivity

See DATABASE-DEBUG.md for detailed troubleshooting.
