#!/bin/bash


# stop and clean existing wildduck-dockerized container
#

echo "Stopping and cleaning existing wildduck-dockerized container"
sudo docker stop $(sudo docker ps -q --filter "name=^/config-generated")


echo "cleaning generated  files config-generated"
rm -rf ./config-generated
rm -rf ./acme.json
rm -rf update_certs.sh


source "./setup.sh"

