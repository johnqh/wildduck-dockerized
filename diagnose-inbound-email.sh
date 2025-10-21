#!/bin/bash

# Diagnostic script for inbound email issues
# Checks DNS, port 25, Haraka container, firewall, etc.

set -e

echo "=== Inbound Email Diagnostic Tool ==="
echo ""

# Get domain from .env or use default
if [ -f ".env" ]; then
    source .env
    MAIL_DOMAIN=${EMAIL_DOMAIN:-0xmail.box}
else
    MAIL_DOMAIN="0xmail.box"
fi

echo "Mail Domain: $MAIL_DOMAIN"
echo ""

# 1. Check DNS Records
echo "1. DNS Configuration"
echo "   =================="
echo ""

echo "   Checking MX record..."
MX_RECORD=$(dig MX $MAIL_DOMAIN +short 2>/dev/null || echo "DNS lookup failed")
if [ -n "$MX_RECORD" ] && [ "$MX_RECORD" != "DNS lookup failed" ]; then
    echo "   ✓ MX Record: $MX_RECORD"
    MX_HOST=$(echo "$MX_RECORD" | awk '{print $2}' | sed 's/\.$//')
    echo "   Mail server hostname: $MX_HOST"
else
    echo "   ✗ No MX record found for $MAIL_DOMAIN"
    MX_HOST=""
fi

echo ""
echo "   Checking A record for domain..."
A_RECORD=$(dig A $MAIL_DOMAIN +short 2>/dev/null || echo "DNS lookup failed")
if [ -n "$A_RECORD" ] && [ "$A_RECORD" != "DNS lookup failed" ]; then
    echo "   ✓ A Record: $A_RECORD"
else
    echo "   ✗ No A record found for $MAIL_DOMAIN"
fi

echo ""

# 2. Check Docker Containers
echo "2. Docker Container Status"
echo "   ======================="
echo ""

cd ./config-generated/ 2>/dev/null || cd .

HARAKA_RUNNING=$(sudo docker compose ps haraka --format json 2>/dev/null | grep -c "running" || echo "0")

if [ "$HARAKA_RUNNING" -gt 0 ]; then
    echo "   ✓ Haraka container is running"

    # Get container details
    echo ""
    echo "   Container details:"
    sudo docker compose ps haraka
else
    echo "   ✗ Haraka container is NOT running"
fi

echo ""

# 3. Check Port 25 Exposure
echo "3. Port 25 Configuration"
echo "   ====================="
echo ""

echo "   Checking docker-compose port mappings..."
PORT_25_MAPPING=$(grep -A 5 "haraka:" docker-compose.yml | grep "25:25" || echo "not found")

if [ "$PORT_25_MAPPING" != "not found" ]; then
    echo "   ✓ Port 25 is mapped in docker-compose.yml"
    echo "   $PORT_25_MAPPING"
else
    echo "   ✗ Port 25 is NOT mapped in docker-compose.yml"
fi

echo ""

# 4. Check if port 25 is listening
echo "4. Port 25 Listening Status"
echo "   ========================"
echo ""

echo "   Checking if port 25 is listening..."
if command -v netstat &> /dev/null; then
    LISTENING=$(sudo netstat -tlnp | grep ":25 " || echo "not listening")
    if [ "$LISTENING" != "not listening" ]; then
        echo "   ✓ Port 25 is listening:"
        echo "   $LISTENING"
    else
        echo "   ✗ Port 25 is NOT listening"
    fi
elif command -v ss &> /dev/null; then
    LISTENING=$(sudo ss -tlnp | grep ":25 " || echo "not listening")
    if [ "$LISTENING" != "not listening" ]; then
        echo "   ✓ Port 25 is listening:"
        echo "   $LISTENING"
    else
        echo "   ✗ Port 25 is NOT listening"
    fi
else
    echo "   ⚠ netstat/ss not available, skipping"
fi

echo ""

# 5. Check Firewall Rules
echo "5. Firewall Configuration"
echo "   ======================"
echo ""

echo "   Checking UFW status..."
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(sudo ufw status 2>/dev/null || echo "inactive")
    if echo "$UFW_STATUS" | grep -q "Status: active"; then
        echo "   UFW is active"
        echo ""
        echo "   Checking if port 25 is allowed..."
        if echo "$UFW_STATUS" | grep -q "25"; then
            echo "   ✓ Port 25 is allowed in UFW"
            echo "$UFW_STATUS" | grep "25"
        else
            echo "   ✗ Port 25 is NOT allowed in UFW"
            echo ""
            echo "   To fix, run:"
            echo "   sudo ufw allow 25/tcp"
        fi
    else
        echo "   UFW is inactive"
    fi
else
    echo "   UFW not installed"
fi

echo ""

echo "   Checking iptables rules..."
if command -v iptables &> /dev/null; then
    IPTABLES_RULES=$(sudo iptables -L -n | grep -i "25" || echo "no rules for port 25")
    if [ "$IPTABLES_RULES" != "no rules for port 25" ]; then
        echo "   Found iptables rules for port 25:"
        echo "$IPTABLES_RULES"
    else
        echo "   No specific iptables rules for port 25"
    fi
else
    echo "   iptables not available"
fi

echo ""

# 6. Check Haraka Logs
echo "6. Haraka Logs (last 20 lines)"
echo "   ==========================="
echo ""

if [ "$HARAKA_RUNNING" -gt 0 ]; then
    sudo docker compose logs --tail=20 haraka
else
    echo "   Haraka is not running, no logs available"
fi

echo ""

# 7. External Connectivity Test
echo "7. External Connectivity Test"
echo "   ============================"
echo ""

echo "   Testing if port 25 is accessible from outside..."
echo "   (This test connects from this machine to the public IP)"
echo ""

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")
echo "   Public IP: $PUBLIC_IP"

if [ "$PUBLIC_IP" != "unknown" ]; then
    echo "   Testing connection to $PUBLIC_IP:25..."

    # Try to connect
    if command -v nc &> /dev/null; then
        CONNECT_TEST=$(nc -zv $PUBLIC_IP 25 -w 3 2>&1 || echo "failed")
        if echo "$CONNECT_TEST" | grep -q "succeeded\|open"; then
            echo "   ✓ Port 25 is accessible from outside"
        else
            echo "   ✗ Port 25 is NOT accessible from outside"
            echo "   $CONNECT_TEST"
        fi
    else
        echo "   nc (netcat) not available for testing"
    fi
fi

echo ""

# 8. Summary and Recommendations
echo "=== Summary and Recommendations ==="
echo ""

if [ "$HARAKA_RUNNING" -eq 0 ]; then
    echo "❌ CRITICAL: Haraka container is not running"
    echo "   Fix: cd config-generated && sudo docker compose up -d haraka"
    echo ""
fi

if [ "$PORT_25_MAPPING" = "not found" ]; then
    echo "❌ CRITICAL: Port 25 is not mapped in docker-compose.yml"
    echo "   Fix: Ensure docker-compose.yml has:"
    echo "   ports:"
    echo "     - \"25:25\""
    echo ""
fi

echo "Common issues and fixes:"
echo ""
echo "1. Firewall blocking port 25:"
echo "   sudo ufw allow 25/tcp"
echo "   sudo ufw reload"
echo ""
echo "2. ISP/Hosting provider blocking port 25:"
echo "   - Check with your hosting provider"
echo "   - Many residential ISPs block port 25"
echo "   - VPS providers usually allow port 25 but may need to enable it"
echo ""
echo "3. Haraka not configured correctly:"
echo "   - Check config-generated/config/haraka/"
echo "   - Verify wildduck.yaml has correct MongoDB connection"
echo ""
echo "4. To test email reception manually:"
echo "   telnet $PUBLIC_IP 25"
echo "   # Should see: 220 hostname ESMTP Haraka"
echo ""
echo "5. Check Haraka logs in real-time:"
echo "   cd config-generated && sudo docker compose logs -f haraka"
echo ""

cd - > /dev/null 2>&1 || true
