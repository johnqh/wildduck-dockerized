# Wildduck: dockerized - 🦆+🐋=❤

The default docker-compose file will set up:

| Service          | Why                                                       |
| ---------------- | --------------------------------------------------------- |
| WildDuck         | IMAP, POP3                                                |
| WildDuck Webmail | Webmail, creating accounts, <br> editing account settings |
| ZoneMTA          | Outbound smtp                                             |
| Haraka           | Inbound smtp                                              |
| Rspamd           | Spam filtering                                            |
| Traefik          | Reverse proxy with automatic TLS                          |
| MongoDB          | Database used by most services                            |
| Redis            | Key-value store used by most services                     |

For the default docker-compose file to work without any further setup, you need port 80/443 available for Traefik to get certificates or provide your own certificates mounted as a volume. However, the compose file is not set in stone. You can remove Traefik from the equation and use your own reverse proxy (or configure the applications to handle TLS directly), remove certain services, etc.

No STARTTLS support, only SSL/TLS.

Before starting please don't forget to install `Docker` and `Docker compose`

## Deploy Wildduck: dockerized

> For easy setup and startup use the provided `setup.sh` file (only works on Linux or Mac). The "wizard" provided by the script will ask necessary questions required for setting up the suite quickly and easily. The wizard will set up the configuration, secrets, self-signed certs (if required for development), optionally DNS and optionally will create the first user.

Keep in mind that the provided setup script is a basic setup that is intended to set you up quickly for either local development or testing, or to set you up with a simple working email suite on a server (such as a VPS). So for more granular configuration please refer to the appropriate documentation of the used applications and update the config files accordingly. Don't forget to restart the containers after configuration changes.

> Note! Haraka handles certificates completely separately. So in order to have Haraka with TLS you will need to either issue certs for Haraka/SMTP domain beforehand and include them in the specified folder that is set in the `docker-compose.yml` file or if using the provided `setup.sh` setup script there will be a cron created for you that will handle updating the haraka certs.

Additionally, the provided setup currently uses a very basic setup where all the services are ran on the same domain. Ideally you'd want to run outbound smtps (port 465), imap, pop3, inbound smtp (port 25 Haraka), on different domains and have separate certs for them (will be handled by Traefik automatically, except for Haraka). For database and redis sharding refer to Wildduck and Zone-MTA documentation.  
The provided setup also sets you up with basic DNS settings that "work right out the box". Additionally the provided setup script can create the first user for you. For user creation refer to Wildduck documentation at https://docs.wildduck.email.

## Connecting Thunderbird if using self-signed certificates

It may be required to import the generated CA file to Thunderbird in order for it
to connect to IMAP and SMTP. You can find the generated CA file in `config-generated/certs/rootCA.pem`.
If using letsencrypt on a publicly accessible DNS then Thunderbird should connect just fine
as with any other email server.

## Custom configuration

Configuration files for all services reside in `./config-generated`. Alter them in whichever way you want, and restart the service in question.

## Depolyment Instrucutions

### Prerequisites

- ensure you have docker installed
- ensure you have docker compose installed
- ensure node is isntalled
- ensure you have a domain name
- esnure dns record is added to your domain for the VPS
- you have certbot installed, required for ssl certificates
- genearte ssl certificates for the domain, follow this tutorial [ssl certifacte instructions](https://certbot.eff.org/instructions?ws=webproduct&os=snap)
- ensure webservers like nginx or plesk are not using the ports used by traefik(80, 443, 465, 993, 995)

### Setup

- clone the repo
- `cd wildduck-dockerized`
- `./setup.sh` or `npm install` and `npm run deploy`
- provide the domain name for the setup(further referred to as HOSTNAME)
- when asked to install self-signed certs enter 'n'
- when asked for DNS settings enter 'y'
- let the setup complete
- provide username and password for default admin account

## finishing the setup

- The ACCESS_TOKEN used by the api will be present in the `./config-generated/wildduck/api.toml in the sercet value
- set DNS records for DKIM signing
  - open the file called `<HOSTNAME>-nameserver.txt` in `./config-generated/config-generated`
  - you will need to add 4 dns records in you DNS manger
  - the 4 records are at very last section of the fiel called TL;DR
  - the section is formatted follwoing way
    ```
    <RECORD_NAME> IN <TYPE> <VALUE>
    ```

### Update

- the setup creates a new docker-compose.yml file in the config-generated directory and configs that the services will use
- when changes are required update the configs in `./config-generated` and restart the correcsponding service with the follwoping command

  ```
  #list containers copy the name or container id
  docker ps

  #restart service
  docker restart <service_name>

  ```

# run tests

- ensure node is installed (optional bun)

- run `npm install` or `bun install`

- rename `.env.example` to `.env` and fill in the required values

- run `npm run test` or `bun test`
