#!/bin/bash

echo "=== Check Haraka Default connection.ini ==="
echo ""

cd ./config-generated

echo "Checking Haraka default config inside container:"
sudo docker compose exec haraka sh -c "find /app -name 'connection.ini' -type f 2>/dev/null | head -5 | while read f; do echo '--- File: $f ---'; cat \$f; echo ''; done"

echo ""
echo "=== Done ==="
