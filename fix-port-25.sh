#!/bin/bash

# Quick fix script to enable port 25 for inbound email

set -e

echo "=== Port 25 Quick Fix Tool ==="
echo ""
echo "This script will:"
echo "  1. Check if Haraka is running"
echo "  2. Ensure port 25 is exposed in docker-compose"
echo "  3. Open port 25 in firewall (UFW)"
echo "  4. Restart Haraka if needed"
echo ""

read -p "Continue? [Y/n] " CONTINUE

case $CONTINUE in
    [Nn]* ) echo "Aborted"; exit;;
    * ) ;;
esac

echo ""

# 1. Check Haraka
echo "Step 1: Checking Haraka container"
echo "----------------------------------"

cd ./config-generated/

HARAKA_RUNNING=$(sudo docker compose ps haraka --format json 2>/dev/null | grep -c "running" || echo "0")

if [ "$HARAKA_RUNNING" -gt 0 ]; then
    echo "✓ Haraka is running"
else
    echo "✗ Haraka is not running"
    echo "  Starting Haraka..."
    sudo docker compose up -d haraka
    echo "✓ Haraka started"
fi

echo ""

# 2. Check UFW
echo "Step 2: Configuring Firewall (UFW)"
echo "-----------------------------------"

if command -v ufw &> /dev/null; then
    UFW_STATUS=$(sudo ufw status 2>/dev/null || echo "inactive")

    if echo "$UFW_STATUS" | grep -q "Status: active"; then
        echo "UFW is active"

        if echo "$UFW_STATUS" | grep -q "^25"; then
            echo "✓ Port 25 is already allowed"
        else
            echo "Adding port 25 to UFW..."
            sudo ufw allow 25/tcp
            echo "✓ Port 25 allowed in UFW"
        fi
    else
        echo "UFW is not active, skipping"
    fi
else
    echo "UFW not installed, skipping"
fi

echo ""

# 3. Verify port is listening
echo "Step 3: Verifying Port 25 is Listening"
echo "---------------------------------------"

sleep 2  # Give Haraka time to start

if command -v netstat &> /dev/null; then
    LISTENING=$(sudo netstat -tlnp | grep ":25 " || echo "not found")
elif command -v ss &> /dev/null; then
    LISTENING=$(sudo ss -tlnp | grep ":25 " || echo "not found")
else
    LISTENING="not found"
fi

if [ "$LISTENING" != "not found" ]; then
    echo "✓ Port 25 is listening"
    echo "$LISTENING"
else
    echo "✗ Port 25 is NOT listening"
    echo ""
    echo "Possible issues:"
    echo "  1. Haraka failed to start - check logs:"
    echo "     sudo docker compose logs haraka"
    echo ""
    echo "  2. Port 25 not exposed in docker-compose.yml"
    echo "     Check that docker-compose.yml has:"
    echo "     haraka:"
    echo "       ports:"
    echo "         - \"25:25\""
fi

echo ""

# 4. Test external connectivity
echo "Step 4: Testing External Connectivity"
echo "--------------------------------------"

PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")

if [ "$PUBLIC_IP" != "unknown" ]; then
    echo "Public IP: $PUBLIC_IP"
    echo ""
    echo "Testing if port 25 is accessible from internet..."
    echo "(Connecting from this machine to public IP)"

    if command -v nc &> /dev/null; then
        if nc -zv $PUBLIC_IP 25 -w 3 2>&1 | grep -q "succeeded\|open"; then
            echo "✓ Port 25 is accessible from internet!"
        else
            echo "✗ Port 25 is NOT accessible from internet"
            echo ""
            echo "This could be due to:"
            echo "  1. Hosting provider blocking port 25"
            echo "  2. Additional firewall rules (iptables, cloud provider firewall)"
            echo "  3. ISP blocking port 25 (common for residential connections)"
            echo ""
            echo "Please check with your hosting provider:"
            echo "  - Hetzner: Check Cloud Firewall settings"
            echo "  - AWS: Check Security Groups"
            echo "  - DigitalOcean: Check Cloud Firewalls"
            echo "  - Google Cloud: Check VPC Firewall Rules"
        fi
    else
        echo "nc (netcat) not available, cannot test"
    fi
else
    echo "Cannot determine public IP"
fi

echo ""

# 5. Show next steps
echo "=== Next Steps ==="
echo ""
echo "1. Test SMTP manually:"
echo "   telnet $PUBLIC_IP 25"
echo "   # You should see: 220 mail.0xmail.box ESMTP Haraka"
echo ""
echo "2. Send a test email to: 0x992049Cc0F63D4C48420C7A76F5c26f923D81b44@0xmail.box"
echo "   (Make sure the user with this Ethereum address exists in WildDuck)"
echo ""
echo "3. Watch Haraka logs in real-time:"
echo "   cd config-generated && sudo docker compose logs -f haraka"
echo ""
echo "4. If still not working, run the full diagnostic:"
echo "   cd .. && ./diagnose-inbound-email.sh"
echo ""

cd ..
