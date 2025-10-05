# Wildduck: dockerized - 🦆+🐋=❤

The default docker-compose file will set up:

| Service          | Why                                                       |
| ---------------- | --------------------------------------------------------- |
| WildDuck         | IMAP, POP3, API                                           |
| ZoneMTA          | Outbound smtp                                             |
| Haraka           | Inbound smtp                                              |
| Rspamd           | Spam filtering                                            |
| Mail Box Indexer | Blockchain indexer for wallet-based email addresses       |
| Traefik          | Reverse proxy with automatic TLS                          |
| MongoDB          | Database used by most services                            |
| PostgreSQL       | Database used by Mail Box Indexer                         |
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

## Deployment Instructions

### Prerequisites

- ensure you have docker installed
- ensure you have docker compose installed
- ensure node is installed
- ensure you have a domain name
- ensure dns record is added to your domain for the VPS
- you have certbot installed, required for ssl certificates
- generate ssl certificates for the domain, follow this tutorial [ssl certifacte instructions](https://certbot.eff.org/instructions?ws=webproduct&os=snap)
- ensure web-servers like nginx or plesk are not using the ports used by traefik(80, 443, 465, 993, 995)

### Setup

- clone the repo
- `cd wildduck-dockerized`
- `./setup.sh` or `npm install && npm run deploy`
- use local MongoDB instance or a hosted MongoDB instance
  - enter `n` to use a hosted instance
  - if using hosted provide following info when asked
    - MONGO_URL with format `mongodb+srv://<username>:<password>@<host>`
    - don't include collection/database name
- provide the domain name for the setup(further referred to as HOSTNAME)
- when asked to install self-signed certs enter 'n' (ensure to select n as setup.sh automatically configures)
- when asked for DNS settings enter 'y'
- let the setup complete
- provide username and password for default admin account

## finishing the setup

- The ACCESS_TOKEN used by the api will be present in the `./config-generated/config-generated/wildduck/api.toml in the accessToken value
- set DNS records for DKIM signing
  - open the file called `<HOSTNAME>-nameserver.txt` in `./config-generated/config-generated`
  - you will need to add 4 dns records in you DNS manger
  - the 4 records are at very last section of the file called TL;DR
  - the section is formatted following way
    ```
    <RECORD_NAME> IN <TYPE> <VALUE>
    ```

## Mail Box Indexer Configuration

The Mail Box Indexer enables blockchain-based email addresses by indexing smart contracts on multiple chains.

### Required Environment Variables

Create a `.env` file in the root directory based on `.env.example`:

```bash
# Required credentials
INDEXER_PRIVATE_KEY=your_indexer_private_key
INDEXER_WALLET_ADDRESS=your_indexer_wallet_address
ALCHEMY_API_KEY=your_alchemy_api_key

# Optional configurations
EMAIL_DOMAIN=0xmail.box
ENABLE_TESTNETS=false
LOG_LEVEL=info
```

### Features

- **Multi-chain Support**: Indexes contracts on Ethereum, Polygon, Optimism, and Base
- **Points System**: Tracks user engagement and referrals
- **KYC Integration**: Optional Sumsub integration for verification
- **Solana Support**: Optional Helius integration for Solana events
- **Subscription Management**: Optional RevenueCat integration

### API Endpoint

The indexer API is accessible at:
- **External**: `https://HOSTNAME/idx` (routed through Traefik)
- **Internal**: `http://mail_box_indexer:42069` (from other containers)
- **Local testing**: Uncomment port mapping in docker-compose.yml for `http://localhost:42069`

For detailed configuration options, see `.env.example`

## Info

### Get Access Token

- The ACCESS_TOKEN used by the api will be present in the `./config-generated/config-generated/wildduck/api.toml in the accessToken value
- the token is used to authenticate the api calls add header `X-Access-Token: <accessToken>` [read this](https://docs.wildduck.email/docs/wildduck-api/wildduck-api)

### API path

- The wildduck api is available at `https://<domain_name>/api`
- Refer to the [Wildduck API](https://docs.wildduck.email/docs/category/wildduck-api) for more information

### Update

- the setup creates a new docker-compose.yml file in the config-generated directory and configs that the services will use
- when changes are required update the configs in `./config-generated` and restart the corresponding service with the following command

  ```bash
  # move into the config-generated directory
  cd config-generated

  #restart service
  docker comspose restart


  # or bring services down and then start them up
  docker compose down
  docker compose up -d
  ```

# Run tests

- ensure node is installed (optional bun)

- run `npm install` or `bun install`

- rename `.env.example` to `.env` and fill in the required values

- refer to the [Get access token](#get-access-token) to get ACCESS_TOKEN

- run `npm run test` or `bun test`
