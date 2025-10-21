

NAMESERVER SETUP
================

MX
--
Add this MX record to the 0xmail.box DNS zone:

0xmail.box. IN MX 5 0xmail.box.

SPF
---
Add this TXT record to the 0xmail.box DNS zone:

0xmail.box. IN TXT "v=spf1 a:0xmail.box a:0xmail.box ip4:212.1.213.215 ~all"

Or:
0xmail.box. IN TXT "v=spf1 a:0xmail.box ip4:212.1.213.215 ~all"
0xmail.box. IN TXT "v=spf1 ip4:212.1.213.215 ~all"

Some explanation:
SPF is basically a DNS entry (TXT), where you can define,
which server hosts (a:[HOSTNAME]) or ip address (ip4:[IP_ADDRESS])
are allowed to send emails.
So the receiver server (eg. gmail's server) can look up this entry
and decide if you(as a sender server) is allowed to send emails as
this email address.

If you are unsure, list more a:, ip4 entries, rather then fewer.

Example:
company website: awesome.com
company's email server: mail.awesome.com
company's reverse dns entry for this email server: mail.awesome.com -> 11.22.33.44

SPF record in this case would be:
awesome.com. IN TXT "v=spf1 a:mail.awesome.com a:awesome.com ip4:11.22.33.44 ~all"

The following servers can send emails for *@awesome.com email addresses:
awesome.com (company's website handling server)
mail.awesome.com (company's mail server)
11.22.33.44 (company's mail server's ip address)

Please note, that a:mail.awesome.com is the same as ip4:11.22.33.44, so it is
redundant. But better safe than sorry.
And in this example, the company's website handling server can also send
emails and in general it is an outbound only server.
If a website handles email sending (confirmation emails, contact form, etc).

DKIM
----
Add this TXT record to the 0xmail.box DNS zone:

oct2025._domainkey.0xmail.box. IN TXT "v=DKIM1;k=rsa;p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDo7a1BcTgtvBDlzHmfVeCTnyLO2TJrvY7VEQLHMGLT4A3akD3vZknvhZWcS73tMFS0SbeoFlx5GKnaFJ2nHi14qNFbnmDzlvm88gzGOnUByUrK6/nIhrsro68NFl929SdyUWsnOprLPxRkGyEqmzEWqGlMEFGhEK3IrKg4+7vWOwIDAQAB"

The DKIM .json text we added to wildduck server:
    curl -i -XPOST http://localhost:8080/dkim \
    -H 'Content-type: application/json' \
    -d '{
  "domain": "0xmail.box",
  "selector": "oct2025",
  "description": "Default DKIM key for 0xmail.box",
  "privateKey": "-----BEGIN PRIVATE KEY-----\nMIICdwIBADANBgkqhkiG9w0BAQEFAASCAmEwggJdAgEAAoGBAOjtrUFxOC28EOXM\neZ9V4JOfIs7ZMmu9jtURAscwYtPgDdqQPe9mSe+FlZxLve0wVLRJt6gWXHkYqdoU\nnaceLXio0VueYPOW+bzyDMY6dQHJSsrr+ciGuyujrw0WX3b1J3JRayc6mss/FGQb\nISqbMRaoaUwQUaEQrcisqDj7u9Y7AgMBAAECgYAbKv22UFpZG0JtSzg0WXPkQ/9v\nWO4Emwt51o4YZZBhXhS/lWtj7O5avZ4BqOPyMlzu2lpNhK4sga/t+9GXmHF9FFkE\n2SVnTnPDWEEDkr42jye/5PIG/F4YK/+9flLBuVRi2GtuUclXpHLElJ2Z0bbG5x9z\nTIcRs8rZtXfMLee5oQJBAPngZKEltrFam4o5sif6+3Lc6oWPW3WCUdCRPKVkoA9Z\nKvyu/airPpZf3SzTrZ+AmSEq/ZbaapVVEzP+1lJ+E28CQQDuovWTunxmQW5ux0us\nmzQbRmPK9M9y1/qTOEngBn4UFfEqupjZ4l+Wiiktui7oHHFGMX/F4NVl5OqCY/Az\nfhP1AkEAhgal8wmXhGllJC7uMCOe221DHYBXPiA4YfaE4PGoKJNbS01RITc4ys+A\ngprHddY0TGYSvudIY/DN7AW0T2rwYQJALj5uEH6m9LnhSJ5eT8iTxGVTmVTvjnXE\nHRtfVYZskD/gSEN4s2Bm3alQaYgW5uv8F3ooJJR5RhGiUDpFpfTcsQJBAM1DuFCj\nlPorFH+SPTgxGNkZftO4UxUAlWbaRlV9tbnvUdnja8PXR2iUh4Sp/XklC/Wrzdog\ntA4ZsuXJGTfkq4s=\n-----END PRIVATE KEY-----\n"
}'


Please refer to the manual how to change/delete/update DKIM keys
via the REST api (with curl on localhost) for the newest version.

List DKIM keys:
    curl -i http://localhost:8080/dkim
Delete DKIM:
    curl -i -XDELETE http://localhost:8080/dkim/<dkim key id>

Move DKIM keys to another machine:

Save the above curl command and dns entry.
Also copy the following two files too:
/root/wildduck-dockerized/config-generated/config-generated/0xmail.box-dkim.cert
/root/wildduck-dockerized/config-generated/config-generated/0xmail.box-dkim.pem

pem: private key (guard it well)
cert: public key

DMARC
---
Add this TXT record to the 0xmail.box DNS zone:

_dmarc.0xmail.box. IN TXT "v=DMARC1; p=reject;"

PTR
---
Make sure that your public IP has a PTR record set to 0xmail.box.
If your hosting provider does not allow you to set PTR records but has
assigned their own hostname, then edit zone-mta/pools.toml and replace
the hostname 0xmail.box with the actual hostname of this server.

TL;DR
-----
Add the following DNS records to the 0xmail.box DNS zone:

0xmail.box. IN MX 5 0xmail.box.
0xmail.box. IN TXT "v=spf1 ip4:212.1.213.215 ~all"
oct2025._domainkey.0xmail.box. IN TXT "v=DKIM1;k=rsa;p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDo7a1BcTgtvBDlzHmfVeCTnyLO2TJrvY7VEQLHMGLT4A3akD3vZknvhZWcS73tMFS0SbeoFlx5GKnaFJ2nHi14qNFbnmDzlvm88gzGOnUByUrK6/nIhrsro68NFl929SdyUWsnOprLPxRkGyEqmzEWqGlMEFGhEK3IrKg4+7vWOwIDAQAB"
_dmarc.0xmail.box. IN TXT "v=DMARC1; p=reject;"


(this text is also stored to /root/wildduck-dockerized/config-generated/config-generated/0xmail.box-nameserver.txt)

Waiting for the server to start up...

[+] Running 7/7
 ✔ Container config-generated-traefik-1           Running                                                                                                     0.0s 
 ✔ Container config-generated-redis-1             Healthy                                                                                                     0.5s 
 ✔ Container config-generated-zonemta-1           Running                                                                                                     0.0s 
 ✔ Container config-generated-rspamd-1            Running                                                                                                     0.0s 
 ✔ Container config-generated-haraka-1            Running                                                                                                     0.0s 
 ✔ Container config-generated-mail_box_indexer-1  Running                                                                                                     0.0s 
 ✔ Container config-generated-wildduck-1          Running                                                                                                     0.0s 
Waiting for the WildDuck API server to start up...
Testing endpoint: http://localhost:8080/users

......
✓ WildDuck API is responding (HTTP 200)
Registering DKIM key for 0xmail.box
{ "domain": "0xmail.box", "selector": "oct2025", "description": "Default DKIM key for 0xmail.box", "privateKey": "-----BEGIN PRIVATE KEY-----\nMIICdwIBADANBgkqhkiG9w0BAQEFAASCAmEwggJdAgEAAoGBAOjtrUFxOC28EOXM\neZ9V4JOfIs7ZMmu9jtURAscwYtPgDdqQPe9mSe+FlZxLve0wVLRJt6gWXHkYqdoU\nnaceLXio0VueYPOW+bzyDMY6dQHJSsrr+ciGuyujrw0WX3b1J3JRayc6mss/FGQb\nISqbMRaoaUwQUaEQrcisqDj7u9Y7AgMBAAECgYAbKv22UFpZG0JtSzg0WXPkQ/9v\nWO4Emwt51o4YZZBhXhS/lWtj7O5avZ4BqOPyMlzu2lpNhK4sga/t+9GXmHF9FFkE\n2SVnTnPDWEEDkr42jye/5PIG/F4YK/+9flLBuVRi2GtuUclXpHLElJ2Z0bbG5x9z\nTIcRs8rZtXfMLee5oQJBAPngZKEltrFam4o5sif6+3Lc6oWPW3WCUdCRPKVkoA9Z\nKvyu/airPpZf3SzTrZ+AmSEq/ZbaapVVEzP+1lJ+E28CQQDuovWTunxmQW5ux0us\nmzQbRmPK9M9y1/qTOEngBn4UFfEqupjZ4l+Wiiktui7oHHFGMX/F4NVl5OqCY/Az\nfhP1AkEAhgal8wmXhGllJC7uMCOe221DHYBXPiA4YfaE4PGoKJNbS01RITc4ys+A\ngprHddY0TGYSvudIY/DN7AW0T2rwYQJALj5uEH6m9LnhSJ5eT8iTxGVTmVTvjnXE\nHRtfVYZskD/gSEN4s2Bm3alQaYgW5uv8F3ooJJR5RhGiUDpFpfTcsQJBAM1DuFCj\nlPorFH+SPTgxGNkZftO4UxUAlWbaRlV9tbnvUdnja8PXR2iUh4Sp/XklC/Wrzdog\ntA4ZsuXJGTfkq4s=\n-----END PRIVATE KEY-----\n" }
HTTP/1.1 200 OK
Server: WildDuck API
vary: origin,access-control-request-method,access-control-request-headers
Content-Type: application/json; charset=utf-8
Content-Length: 884
Date: Fri, 17 Oct 2025 23:17:44 GMT
Connection: keep-alive
Keep-Alive: timeout=5

{
  "id": "68f2c5aecc647449d1db25fe",
  "domain": "0xmail.box",
  "selector": "oct2025",
  "description": "Default DKIM key for 0xmail.box",
  "fingerprint": "9f:4c:a1:e3:7d:95:f9:07:3b:bb:44:f8:3f:c8:a1:fc:cd:f8:d0:eb:4c:39:c1:c7:90:1f:9f:ff:c7:d0:72:30",
  "publicKey": "-----BEGIN PUBLIC KEY-----\nMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDo7a1BcTgtvBDlzHmfVeCTnyLO\n2TJrvY7VEQLHMGLT4A3akD3vZknvhZWcS73tMFS0SbeoFlx5GKnaFJ2nHi14qNFb\nnmDzlvm88gzGOnUByUrK6/nIhrsro68NFl929SdyUWsnOprLPxRkGyEqmzEWqGlM\nEFGhEK3IrKg4+7vWOwIDAQAB\n-----END PUBLIC KEY-----\n",
  "dnsTxt": {
    "name": "oct2025._domainkey.0xmail.box",
    "value": "v=DKIM1;t=s;p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDo7a1BcTgtvBDlzHmfVeCTnyLO2TJrvY7VEQLHMGLT4A3akD3vZknvhZWcS73tMFS0SbeoFlx5GKnaFJ2nHi14qNFbnmDzlvm88gzGOnUByUrK6/nIhrsro68NFl929SdyUWsnOprLPxRkGyEqmzEWqGlMEFGhEK3IrKg4+7vWOwIDAQAB"
  },
  "success": true
}



=========================================
✓ Setup completed successfully!
=========================================

Your WildDuck mail server is now running at:
  API:  https://0xmail.box/api
  Web:  https://0xmail.box/

To create users, use the WildDuck API:
  curl -XPOST https://0xmail.box/api/users \
    -H 'Content-type: application/json' \
    -d '{"username": "yourname", "password": "yourpassword", "address": "yourname@0xmail.box"}'

root@srv858831:~/wildduck-dockerized# ./versions.sh

============================================
   WildDuck Dockerized - Container Versions
============================================

Configuration directory: ./config-generated

Fetching container information...

----------------------------------------
SERVICE              IMAGE                                              APP VERSION         
----------------------------------------
WildDuck             johnqh/wildduck:latest                             7.0.0               
WildDuck Webmail     Not running                                        -                   
ZoneMTA              ghcr.io/zone-eu/zonemta-wildduck:1.32.20           1.7.0               
Haraka               johnqh/haraka:latest                               3.0.5               
Rspamd               nodemailer/rspamd                                  Rspamd daemon version 2.7
MongoDB              Not running                                        -                   
Redis                redis:alpine                                       8.2.2               
Traefik              traefik:3.3.4                                      3.3.4               
----------------------------------------

Summary:
  Services running: 6
  Total containers: 7

System Information:
  Docker version: 28.5.1
  Docker Compose version: 2.40.1

  Config last modified: ./config-generated/docker-compose.yml 236f2912ce961bf3 255 ef53 4096 4096 25119164 23832092 23827996 12976128 12716673
2025-10-17 23:17:14.165951968

Useful commands:
  View logs:        cd ./config-generated && sudo docker compose logs -f <service>
  Restart service:  cd ./config-generated && sudo docker compose restart <service>
  Update services:  ./update_be.sh (for backend) or ./update.sh (for full stack)