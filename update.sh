#!/bin/bash


# stop and clean existing wildduck-dockerized container
#

echo "Stopping and cleaning existing wildduck-dockerized container"
sudo docker compose -f ./config-generated/docker-compose.yml down

sudo docker stop $(sudo docker ps -q)


echo "cleaning generated  files config-generated"
rm -rf ./config-generated
rm -rf ./acme.json
rm -rf update_certs.sh


source "./setup.sh"

