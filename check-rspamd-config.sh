#!/bin/bash

echo "=== Check Rspamd Configuration ==="
echo ""

cd ./config-generated

echo "1. Check if actions.conf exists in container:"
sudo docker compose exec rspamd sh -c 'find /etc/rspamd -name "actions.conf" 2>/dev/null | while read f; do echo "--- $f ---"; cat "$f"; echo ""; done'

echo ""
echo "2. Check greylisting module:"
sudo docker compose exec rspamd sh -c 'cat /etc/rspamd/local.d/greylist.conf 2>/dev/null || echo "No greylist.conf found"'

echo ""
echo "3. Check rspamd is responding:"
sudo docker compose exec rspamd sh -c 'rspamadm configtest' || echo "Config test failed"

echo ""
echo "=== Done ==="
