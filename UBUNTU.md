## Installing on Ubuntu Server

Changes DNS, and have the A record pointing domain to the server IP
sudo apt update
sudo apt upgrade
sudo install gh
gh auth login
(follow instructions)
gh repo clone johnqh/wildduck-dockerized
cd wildduck-dockerized
./setup.sh
(restart)
cd wildduck-dockerized
./setup.sh
Changes DNS, according to instructions from ./setup.sh
