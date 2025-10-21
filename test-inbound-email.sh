#!/bin/bash

# Test script for inbound email reception
# Verifies that emails can be received and stored in WildDuck

set -e

echo "=== Inbound Email Reception Test ==="
echo ""

# Get domain
if [ -f ".env" ]; then
    source .env
    MAIL_DOMAIN=${EMAIL_DOMAIN:-0xmail.box}
else
    MAIL_DOMAIN="0xmail.box"
fi

# Get MongoDB connection
MONGO_URL=${WILDDUCK_MONGO_URL:-mongodb://mongo:27017/wildduck}

echo "Mail Domain: $MAIL_DOMAIN"
echo "MongoDB URL: $MONGO_URL"
echo ""

# 1. Check if any users exist
echo "1. Checking WildDuck Users"
echo "   ======================="
echo ""

cd ./config-generated/ 2>/dev/null || cd .

echo "   Querying MongoDB for users..."

# Get database name
DB_NAME=$(echo "$MONGO_URL" | sed 's/.*\///' | sed 's/?.*//' | sed 's/\/$//')

# Try to list users
USER_COUNT=$(sudo docker compose exec -T wildduck node -e "
const config = require('wild-config');
const mongodb = require('mongodb');

async function checkUsers() {
    try {
        const client = await mongodb.MongoClient.connect(config.mongo, {
            useNewUrlParser: true,
            useUnifiedTopology: true
        });
        const db = client.db();
        const users = await db.collection('users').find({}).limit(10).toArray();

        console.log(JSON.stringify({
            count: users.length,
            users: users.map(u => ({
                username: u.username,
                address: u.address,
                quota: u.quota
            }))
        }));

        await client.close();
        process.exit(0);
    } catch (err) {
        console.error('Error:', err.message);
        process.exit(1);
    }
}

checkUsers();
" 2>/dev/null || echo '{"count":0,"users":[]}')

echo "   $USER_COUNT"
echo ""

# Parse user count
USERS=$(echo "$USER_COUNT" | grep -o '"count":[0-9]*' | grep -o '[0-9]*' || echo "0")

if [ "$USERS" -gt 0 ]; then
    echo "   ✓ Found $USERS user(s) in WildDuck"
    echo ""
    echo "   Users can receive email at:"
    echo "$USER_COUNT" | grep -o '"username":"[^"]*"' | sed 's/"username":"/   - /' | sed 's/"/@'$MAIL_DOMAIN'/'
else
    echo "   ✗ No users found in WildDuck"
    echo ""
    echo "   You need to create a user first!"
    echo ""
    echo "   To create a user via API (using Ethereum address):"
    echo "   curl -X POST https://$MAIL_DOMAIN/api/users \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{"
    echo "       \"username\": \"0x992049Cc0F63D4C48420C7A76F5c26f923D81b44\","
    echo "       \"password\": \"SecurePass123\","
    echo "       \"name\": \"Test User\","
    echo "       \"address\": \"0x992049Cc0F63D4C48420C7A76F5c26f923D81b44@$MAIL_DOMAIN\","
    echo "       \"retention\": 0,"
    echo "       \"quota\": 1073741824,"
    echo "       \"recipients\": 2000,"
    echo "       \"forwards\": 2000"
    echo "     }'"
    echo ""
fi

echo ""

# 2. Check recent Haraka activity
echo "2. Recent Haraka Activity"
echo "   ======================"
echo ""

echo "   Checking logs for incoming SMTP connections..."
echo ""

RECENT_CONNECTIONS=$(sudo docker compose logs --tail=100 haraka 2>/dev/null | grep -i "connect\|mail from\|rcpt to\|delivered" | tail -10 || echo "No recent activity")

if [ "$RECENT_CONNECTIONS" != "No recent activity" ]; then
    echo "   Recent SMTP activity:"
    echo "$RECENT_CONNECTIONS" | sed 's/^/   /'
else
    echo "   ✗ No recent SMTP connections detected"
    echo ""
    echo "   This means:"
    echo "   - No emails have been attempted to be delivered"
    echo "   - Or the sender's server hasn't tried yet (can take minutes)"
fi

echo ""

# 3. Check WildDuck messages
echo "3. Recent Messages in WildDuck"
echo "   ============================"
echo ""

echo "   Checking for any messages in the database..."

MESSAGE_COUNT=$(sudo docker compose exec -T wildduck node -e "
const config = require('wild-config');
const mongodb = require('mongodb');

async function checkMessages() {
    try {
        const client = await mongodb.MongoClient.connect(config.mongo, {
            useNewUrlParser: true,
            useUnifiedTopology: true
        });
        const db = client.db();

        const count = await db.collection('messages').countDocuments();
        const recent = await db.collection('messages').find({}).sort({idate: -1}).limit(5).toArray();

        console.log(JSON.stringify({
            totalMessages: count,
            recent: recent.map(m => ({
                from: m.mimeTree && m.mimeTree.parsedHeader && m.mimeTree.parsedHeader.from,
                subject: m.mimeTree && m.mimeTree.parsedHeader && m.mimeTree.parsedHeader.subject,
                date: m.idate
            }))
        }));

        await client.close();
        process.exit(0);
    } catch (err) {
        console.error('Error:', err.message);
        process.exit(1);
    }
}

checkMessages();
" 2>/dev/null || echo '{"totalMessages":0,"recent":[]}')

echo "   $MESSAGE_COUNT"

TOTAL_MSGS=$(echo "$MESSAGE_COUNT" | grep -o '"totalMessages":[0-9]*' | grep -o '[0-9]*' || echo "0")

if [ "$TOTAL_MSGS" -gt 0 ]; then
    echo ""
    echo "   ✓ Found $TOTAL_MSGS message(s) in WildDuck"
else
    echo ""
    echo "   ✗ No messages in database yet"
fi

echo ""

# 4. Manual SMTP Test Instructions
echo "4. Manual SMTP Test"
echo "   ================"
echo ""

PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")

echo "   To manually test SMTP reception, run this from another machine:"
echo ""
echo "   telnet $PUBLIC_IP 25"
echo ""
echo "   Then type:"
echo "   HELO test.com"
echo "   MAIL FROM:<sender@test.com>"
echo "   RCPT TO:<0x992049Cc0F63D4C48420C7A76F5c26f923D81b44@$MAIL_DOMAIN>"
echo "   DATA"
echo "   Subject: Test Email"
echo "   "
echo "   This is a test email."
echo "   ."
echo "   QUIT"
echo ""

echo ""

# 5. Recommendations
echo "=== Summary and Next Steps ==="
echo ""

if [ "$USERS" -eq 0 ]; then
    echo "❌ CRITICAL: No users exist in WildDuck"
    echo "   You must create at least one user to receive emails"
    echo ""
fi

if [ "$TOTAL_MSGS" -gt 0 ]; then
    echo "✅ SUCCESS: WildDuck has received $TOTAL_MSGS message(s)"
    echo "   Email reception is working!"
else
    echo "📧 Waiting for emails..."
    echo ""
    echo "   Try sending a test email from Gmail/Outlook to:"
    echo "   0x992049Cc0F63D4C48420C7A76F5c26f923D81b44@$MAIL_DOMAIN"
    echo ""
    echo "   Watch for incoming emails in real-time:"
    echo "   sudo docker compose logs -f haraka"
    echo ""
    echo "   Common reasons for not receiving emails:"
    echo "   1. User doesn't exist (create one first using Ethereum address)"
    echo "   2. DNS not fully propagated (wait 5-30 minutes)"
    echo "   3. Sender's email server hasn't tried yet"
    echo "   4. Sender marked your domain as spam (check spam folder)"
    echo "   5. Sender's server can't resolve MX record"
fi

echo ""

cd - > /dev/null 2>&1 || true
