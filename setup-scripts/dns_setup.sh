#!/bin/bash

PUBLIC_IP=`curl -s https://api.ipify.org`

cwd=$(pwd)

CWD_CONFIG="$cwd/$CONFIG_DIR/config-generated"

# Generate DKIM selector like: "jul2025"
DKIM_SELECTOR="$(date '+%b' | tr '[:upper:]' '[:lower:]')$(date '+%Y')"

# Paths
DKIM_KEY_FILE="$CWD_CONFIG/$MAILDOMAIN-dkim.pem"
DKIM_CERT_FILE="$CWD_CONFIG/$MAILDOMAIN-dkim.cert"

# Generate DKIM key
openssl genrsa -out "$DKIM_KEY_FILE" 1024
chmod 400 "$DKIM_KEY_FILE"
openssl rsa -in "$DKIM_KEY_FILE" -out "$DKIM_CERT_FILE" -pubout

# Create DKIM DNS record
DKIM_DNS="v=DKIM1;k=rsa;p=$(grep -v -e '^-' "$DKIM_CERT_FILE" | tr -d '\n')"

# Read and escape private key for JSON
if [ ! -f "$DKIM_KEY_FILE" ]; then
    echo "Error: DKIM private key file not found at $DKIM_KEY_FILE"
    exit 1
fi

DKIM_PRIVATE_KEY_ESCAPED=$(< "$DKIM_KEY_FILE" jq -Rs .)

# Construct JSON
DKIM_JSON=$(cat <<EOF
{
  "domain": "$MAILDOMAIN",
  "selector": "$DKIM_SELECTOR",
  "description": "Default DKIM key for $MAILDOMAIN",
  "privateKey": $DKIM_PRIVATE_KEY_ESCAPED
}
EOF
)

echo "
NAMESERVER SETUP
================

MX
--
Add this MX record to the $MAILDOMAIN DNS zone:

$MAILDOMAIN. IN MX 5 $HOSTNAME.

SPF
---
Add this TXT record to the $MAILDOMAIN DNS zone:

$MAILDOMAIN. IN TXT \"v=spf1 a:$HOSTNAME a:$MAILDOMAIN ip4:$PUBLIC_IP ~all\"

Or:
$MAILDOMAIN. IN TXT \"v=spf1 a:$HOSTNAME ip4:$PUBLIC_IP ~all\"
$MAILDOMAIN. IN TXT \"v=spf1 ip4:$PUBLIC_IP ~all\"

Some explanation:
SPF is basically a DNS entry (TXT), where you can define,
which server hosts (a:[HOSTNAME]) or ip address (ip4:[IP_ADDRESS])
are allowed to send emails.
So the receiver server (eg. gmail's server) can look up this entry
and decide if you(as a sender server) is allowed to send emails as
this email address.

If you are unsure, list more a:, ip4 entries, rather then fewer.

Example:
company website: awesome.com
company's email server: mail.awesome.com
company's reverse dns entry for this email server: mail.awesome.com -> 11.22.33.44

SPF record in this case would be:
awesome.com. IN TXT \"v=spf1 a:mail.awesome.com a:awesome.com ip4:11.22.33.44 ~all\"

The following servers can send emails for *@awesome.com email addresses:
awesome.com (company's website handling server)
mail.awesome.com (company's mail server)
11.22.33.44 (company's mail server's ip address)

Please note, that a:mail.awesome.com is the same as ip4:11.22.33.44, so it is
redundant. But better safe than sorry.
And in this example, the company's website handling server can also send
emails and in general it is an outbound only server.
If a website handles email sending (confirmation emails, contact form, etc).

DKIM
----
Add this TXT record to the $MAILDOMAIN DNS zone:

$DKIM_SELECTOR._domainkey.$MAILDOMAIN. IN TXT \"$DKIM_DNS\"

The DKIM .json text we added to wildduck server:
    curl -i -XPOST http://localhost:8080/dkim \\
    -H 'Content-type: application/json' \\
    -d '$DKIM_JSON'


Please refer to the manual how to change/delete/update DKIM keys
via the REST api (with curl on localhost) for the newest version.

List DKIM keys:
    curl -i http://localhost:8080/dkim
Delete DKIM:
    curl -i -XDELETE http://localhost:8080/dkim/<dkim key id>

Move DKIM keys to another machine:

Save the above curl command and dns entry.
Also copy the following two files too:
$CWD_CONFIG/$MAILDOMAIN-dkim.cert
$CWD_CONFIG/$MAILDOMAIN-dkim.pem

pem: private key (guard it well)
cert: public key

DMARC
---
Add this TXT record to the $MAILDOMAIN DNS zone:

_dmarc.$MAILDOMAIN. IN TXT \"v=DMARC1; p=reject;\"

PTR
---
Make sure that your public IP has a PTR record set to $HOSTNAME.
If your hosting provider does not allow you to set PTR records but has
assigned their own hostname, then edit zone-mta/pools.toml and replace
the hostname $HOSTNAME with the actual hostname of this server.

TL;DR
-----
Add the following DNS records to the $MAILDOMAIN DNS zone:

$MAILDOMAIN. IN MX 5 $HOSTNAME.
$MAILDOMAIN. IN TXT \"v=spf1 ip4:$PUBLIC_IP ~all\"
$DKIM_SELECTOR._domainkey.$MAILDOMAIN. IN TXT \"$DKIM_DNS\"
_dmarc.$MAILDOMAIN. IN TXT \"v=DMARC1; p=reject;\"


(this text is also stored to $CWD_CONFIG/$MAILDOMAIN-nameserver.txt)" > "$CWD_CONFIG/$MAILDOMAIN-nameserver.txt"

echo ""

cat "$CWD_CONFIG/$MAILDOMAIN-nameserver.txt"

printf "\nWaiting for the server to start up...\n\n"

CURRENT_DIR=$(basename "$(pwd)")
if [ -f "docker-compose.yml" ] && [ "$CURRENT_DIR" = "$CONFIG_DIR" ]; then
    sudo docker compose up -d # run docker compose if in config-generated and compose file is present
else
    cd "./$CONFIG_DIR/" # cd into config-generated if not in it
    sudo docker compose up -d
    cd ../
fi

echo "Waiting for the WildDuck API server to start up..."
echo "Testing endpoint: http://localhost:8080/users"
echo ""

WAIT_COUNT=0
MAX_WAIT=180  # 6 minutes total (180 * 2 seconds)
API_URL="http://localhost:8080/users"

while true; do
    # Try to connect to the API
    HTTP_CODE=$(curl --output /dev/null --silent --write-out "%{http_code}" -H 'Content-type: application/json' "$API_URL")

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "000" -a -n "$(curl --silent "$API_URL" 2>/dev/null)" ]; then
        echo ""
        echo "✓ WildDuck API is responding (HTTP $HTTP_CODE)"
        break
    fi

    # Show progress
    printf "."
    WAIT_COUNT=$((WAIT_COUNT + 1))

    # Every 15 attempts (30 seconds), show detailed status
    if [ $((WAIT_COUNT % 15)) -eq 0 ]; then
        echo ""
        echo "[$(date '+%H:%M:%S')] Waited ${WAIT_COUNT} attempts ($(($WAIT_COUNT * 2)) seconds)..."
        echo "  API Response: HTTP $HTTP_CODE"
        echo "  Container Status:"
        sudo docker ps --filter "name=config-generated" --format "    {{.Names}}: {{.Status}}" | head -5
        echo ""
        printf "  Continuing to wait"
    fi

    # Timeout check
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo ""
        echo ""
        echo "⚠ ERROR: WildDuck API did not start within $((MAX_WAIT * 2)) seconds"
        echo ""
        echo "Last HTTP Response Code: $HTTP_CODE"
        echo ""
        echo "Container Status:"
        sudo docker ps -a --filter "name=config-generated" --format "table {{.Names}}\t{{.Status}}"
        echo ""
        echo "WildDuck Container Logs (last 30 lines):"
        sudo docker logs config-generated-wildduck-1 --tail 30 2>&1 || echo "Could not retrieve logs"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Check if MongoDB is accessible: sudo docker logs config-generated-wildduck-1 | grep -i mongo"
        echo "  2. Check all container logs: cd config-generated && sudo docker compose logs"
        echo "  3. Verify all services are running: sudo docker ps"
        echo ""
        exit 1
    fi

    sleep 2
done

# Ensure DKIM key
echo "Registering DKIM key for $MAILDOMAIN"
echo $DKIM_JSON

curl -i -XPOST http://localhost:8080/dkim \
-H 'Content-type: application/json' \
-d "$DKIM_JSON"

echo ""
echo ""


source "./setup-scripts/user_setup.sh"
