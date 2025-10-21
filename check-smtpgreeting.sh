#!/bin/bash

# Quick check of smtpgreeting file

echo "Checking smtpgreeting file on host:"
cat ./config-generated/config/haraka/smtpgreeting
echo ""
echo "Checking smtpgreeting file in container:"
cd ./config-generated
sudo docker compose exec haraka cat /app/config/smtpgreeting
