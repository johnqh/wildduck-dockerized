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

> Note! Haraka handles certificates completely separately. So in order to have Haraka with TLS you will need to either issue certs for Haraka/SMTP domain beforehand and include them in the specified folder that is set in the `docker-compose.yml` file or if using the provided `setup.sh` setup script there will we a cron created for you that will handle updating the haraka certs.

Additionally, the provided setup currently uses a very basic setup where all the services are ran on the same domain. Ideally you'd want to run outbound smtps (port 465), imap, pop3, inbound smtp (port 25 Haraka), on different domains and have separate certs for them (will be handled by Traefik automatically, except for Haraka). For database and redis sharding refer to Wildduck and Zone-MTA documentation.  
The provided setup also sets you up with basic DNS settings that "work right out the box". Additionally the provided setup script can create the first user for you. For user creation refer to Wildduck documentation at https://docs.wildduck.email.

## Connecting Thunderbird if using self-signed certificates
It may be required to import the generated CA file to Thunderbird in order for it
to connect to IMAP and SMTP. You can find the generated CA file in `config-generated/certs/rootCA.pem`.
If using letsencrypt on a publicly accessible DNS then Thunderbird should connect just fine
as with any other email server.

## Custom configuration
Configuration files for all services reside in `./config-generated`. Alter them in whichever way you want, and restart the service in question.
