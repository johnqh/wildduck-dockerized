# Rspamd logging configuration for Docker containers
# Override default file-based logging to use console output
# This file goes in override.d/ for highest priority

# Log to console (stdout/stderr) instead of file
type = "console";

# Set log level
level = "info";

# Disable systemd journal (not available in container)
systemd = false;
