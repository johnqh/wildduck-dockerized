# API Endpoints Reference

This document provides a complete reference of all API endpoints available in the WildDuck mail server deployment, including both WildDuck core API and the Mail Box Indexer.

## Base URLs

- **WildDuck API**: `https://HOSTNAME/api`
- **Mail Box Indexer API**: `https://HOSTNAME/idx`

---

# WildDuck API Endpoints

All WildDuck endpoints are prefixed with `/api` and require the `X-Access-Token` header for authentication.

## Authentication

### POST /api/authenticate
Authenticate a user with credentials or access token
- **Body**: `{ "username": string, "password": string }` or `{ "token": string }`
- **Response**: Authentication token

### DELETE /api/authenticate
Invalidate authentication token
- **Headers**: `X-Access-Token`

### POST /api/preauth
Generate pre-authentication token
- **Body**: `{ "username": string, "scope": string, "sess": string, "ip": string }`

### GET /api/users/:user/authlog
List authentication events for a user
- **Params**: `user` - User ID

### GET /api/users/:user/authlog/:event
Get authentication event details
- **Params**: `user` - User ID, `event` - Event ID

---

## Users

### GET /api/users
List registered users
- **Query**: `query`, `tags`, `requiredTags`, `limit`, `next`, `previous`

### POST /api/users
Create new user account
- **Body**: `{ "username": string, "password": string, "address": string, "name": string, ... }`

### GET /api/users/resolve/:username
Resolve username to user ID
- **Params**: `username` - Username to resolve

### GET /api/users/:user
Request user information
- **Params**: `user` - User ID

### PUT /api/users/:user
Update user information
- **Params**: `user` - User ID
- **Body**: Updated user fields

### DELETE /api/users/:user
Delete a user
- **Params**: `user` - User ID

### POST /api/users/:user/restore
Restore a deleted user
- **Params**: `user` - User ID

### DELETE /api/users/:user/restore
Cancel user restore request
- **Params**: `user` - User ID

### POST /api/users/:user/logout
Log out user (invalidate sessions)
- **Params**: `user` - User ID

### POST /api/users/:user/quota/reset
Recalculate user quota
- **Params**: `user` - User ID

### POST /api/quota/reset
Recalculate quota for all users

### POST /api/users/:user/password/reset
Reset password for a user
- **Params**: `user` - User ID
- **Body**: `{ "password": string }`

---

## Addresses

### GET /api/addresses
List all addresses
- **Query**: `query`, `tags`, `requiredTags`, `limit`, `next`, `previous`

### GET /api/users/:user/addresses
List user email addresses
- **Params**: `user` - User ID

### POST /api/users/:user/addresses
Create new email address for user
- **Params**: `user` - User ID
- **Body**: `{ "address": string, "name": string, "tags": array, "main": boolean }`

### GET /api/users/:user/addresses/:address
Request address information
- **Params**: `user` - User ID, `address` - Address ID

### PUT /api/users/:user/addresses/:id
Update address information
- **Params**: `user` - User ID, `id` - Address ID
- **Body**: Updated address fields

### DELETE /api/users/:user/addresses/:address
Delete an address
- **Params**: `user` - User ID, `address` - Address ID

### GET /api/users/:user/addressregister
List addresses from email headers
- **Params**: `user` - User ID

### GET /api/addresses/resolve/:address
Get address information
- **Params**: `address` - Email address

### POST /api/addresses/renameDomain
Rename domain in addresses
- **Body**: `{ "oldDomain": string, "newDomain": string }`

---

## Forwarded Addresses

### GET /api/addresses/forwarded
List forwarded addresses
- **Query**: `query`, `tags`, `limit`, `next`, `previous`

### GET /api/addresses/forwarded/:id
Request forwarded address information
- **Params**: `id` - Address ID

### POST /api/addresses/forwarded/:address
Create new forwarded address
- **Params**: `address` - Email address
- **Body**: `{ "targets": array, "forwards": number, "name": string, "tags": array }`

### PUT /api/addresses/forwarded/:address
Update forwarded address
- **Params**: `address` - Address ID
- **Body**: Updated fields

### DELETE /api/addresses/forwarded/:address
Delete a forwarded address
- **Params**: `address` - Address ID

---

## Mailboxes

### GET /api/users/:user/mailboxes
List user mailboxes
- **Params**: `user` - User ID
- **Query**: `specialUse`, `showHidden`

### POST /api/users/:user/mailboxes
Create new mailbox
- **Params**: `user` - User ID
- **Body**: `{ "path": string, "hidden": boolean, "retention": number }`

### GET /api/users/:user/mailboxes/:mailbox
Request mailbox information
- **Params**: `user` - User ID, `mailbox` - Mailbox ID

### PUT /api/users/:user/mailboxes/:mailbox
Update mailbox information
- **Params**: `user` - User ID, `mailbox` - Mailbox ID
- **Body**: Updated mailbox fields

### DELETE /api/users/:user/mailboxes/:mailbox
Delete a mailbox
- **Params**: `user` - User ID, `mailbox` - Mailbox ID

---

## Messages

### GET /api/users/:user/mailboxes/:mailbox/messages
List messages in a mailbox
- **Params**: `user` - User ID, `mailbox` - Mailbox ID
- **Query**: `limit`, `order`, `next`, `previous`, `page`

### GET /api/users/:user/search
Search for messages (GET)
- **Params**: `user` - User ID
- **Query**: `query`, `datestart`, `dateend`, `from`, `to`, `subject`

### POST /api/users/:user/search
Search for messages (POST with complex queries)
- **Params**: `user` - User ID
- **Body**: Search criteria

### GET /api/users/:user/mailboxes/:mailbox/messages/:message
Get message details
- **Params**: `user` - User ID, `mailbox` - Mailbox ID, `message` - Message ID
- **Query**: `markAsSeen`

### GET /api/users/:user/mailboxes/:mailbox/messages/:message/message.eml
Download raw message (EML format)
- **Params**: `user` - User ID, `mailbox` - Mailbox ID, `message` - Message ID

### GET /api/users/:user/mailboxes/:mailbox/messages/:message/attachments/:attachment
Download attachment
- **Params**: `user`, `mailbox`, `message`, `attachment`

### PUT /api/users/:user/mailboxes/:mailbox/messages/:message
Update message flags/move message
- **Params**: `user` - User ID, `mailbox` - Mailbox ID, `message` - Message ID
- **Body**: `{ "moveTo": string, "seen": boolean, "flagged": boolean, "draft": boolean }`

### DELETE /api/users/:user/mailboxes/:mailbox/messages/:message
Delete a message
- **Params**: `user` - User ID, `mailbox` - Mailbox ID, `message` - Message ID

### DELETE /api/users/:user/mailboxes/:mailbox/messages
Delete all messages in mailbox
- **Params**: `user` - User ID, `mailbox` - Mailbox ID

### POST /api/users/:user/mailboxes/:mailbox/messages
Upload message to mailbox
- **Params**: `user` - User ID, `mailbox` - Mailbox ID
- **Body**: Raw message or structured message data

### PUT /api/users/:user/mailboxes/:mailbox/messages
Update multiple messages
- **Params**: `user` - User ID, `mailbox` - Mailbox ID
- **Body**: Message IDs and updates

### POST /api/users/:user/mailboxes/:mailbox/messages/:message/forward
Forward stored message
- **Params**: `user`, `mailbox`, `message`
- **Body**: `{ "targets": array }`

### POST /api/users/:user/mailboxes/:mailbox/messages/:message/submit
Submit Draft for delivery
- **Params**: `user`, `mailbox`, `message`

### DELETE /api/users/:user/outbound/:queueId
Delete outbound message from queue
- **Params**: `user` - User ID, `queueId` - Queue ID

---

## Archived Messages

### GET /api/users/:user/archived/messages
List archived messages
- **Params**: `user` - User ID
- **Query**: `limit`, `next`, `previous`, `order`

### POST /api/users/:user/archived/restore
Restore archived messages
- **Params**: `user` - User ID
- **Body**: `{ "start": date, "end": date }`

### POST /api/users/:user/archived/messages/:message/restore
Restore single archived message
- **Params**: `user` - User ID, `message` - Message ID

---

## Message Submission

### POST /api/users/:user/submit
Submit a message for delivery
- **Params**: `user` - User ID
- **Body**: `{ "from": string, "to": array, "subject": string, "text": string, "html": string, ... }`

### POST /api/users/name/:username/submit
Submit a message for delivery by username
- **Params**: `username` - Username

---

## Filters

### GET /api/filters
List all filters (admin)
- **Query**: `query`, `limit`, `next`, `previous`

### GET /api/users/:user/filters
List filters for a user
- **Params**: `user` - User ID

### GET /api/users/:user/filters/:filter
Get filter information
- **Params**: `user` - User ID, `filter` - Filter ID

### POST /api/users/:user/filters
Create new filter
- **Params**: `user` - User ID
- **Body**: Filter rules and actions

### PUT /api/users/:user/filters/:filter
Update filter information
- **Params**: `user` - User ID, `filter` - Filter ID
- **Body**: Updated filter fields

### DELETE /api/users/:user/filters/:filter
Delete a filter
- **Params**: `user` - User ID, `filter` - Filter ID

---

## Application Passwords (ASPs)

### GET /api/users/:user/asps
List application passwords
- **Params**: `user` - User ID

### GET /api/users/:user/asps/:asp
Request ASP information
- **Params**: `user` - User ID, `asp` - ASP ID

### POST /api/users/:user/asps
Create new application password
- **Params**: `user` - User ID
- **Body**: `{ "description": string, "scopes": array, "generateMobileconfig": boolean }`

### DELETE /api/users/:user/asps/:asp
Delete an application password
- **Params**: `user` - User ID, `asp` - ASP ID

---

## Two-Factor Authentication

### TOTP

#### POST /api/users/:user/2fa/totp/setup
Generate TOTP seed
- **Params**: `user` - User ID

#### POST /api/users/:user/2fa/totp/enable
Enable TOTP for user
- **Params**: `user` - User ID
- **Body**: `{ "token": string }`

#### DELETE /api/users/:user/2fa/totp
Disable TOTP
- **Params**: `user` - User ID

#### POST /api/users/:user/2fa/totp/check
Validate TOTP token
- **Params**: `user` - User ID
- **Body**: `{ "token": string }`

#### GET /api/users/:user/2fa
Check 2FA status
- **Params**: `user` - User ID

### WebAuthn

#### GET /api/users/:user/2fa/webauthn/credentials
List WebAuthn credentials
- **Params**: `user` - User ID

#### DELETE /api/users/:user/2fa/webauthn/credentials/:credential
Delete WebAuthn credential
- **Params**: `user` - User ID, `credential` - Credential ID

#### POST /api/users/:user/2fa/webauthn/registration-challenge
Request registration challenge
- **Params**: `user` - User ID

#### POST /api/users/:user/2fa/webauthn/registration-attestation
Verify registration response
- **Params**: `user` - User ID
- **Body**: Registration attestation data

#### POST /api/users/:user/2fa/webauthn/authentication-challenge
Request authentication challenge
- **Params**: `user` - User ID

#### POST /api/users/:user/2fa/webauthn/authentication-assertion
Verify authentication response
- **Params**: `user` - User ID
- **Body**: Authentication assertion data

### Custom 2FA

#### POST /api/users/:user/2fa/custom
Enable custom 2FA
- **Params**: `user` - User ID
- **Body**: Custom 2FA configuration

#### DELETE /api/users/:user/2fa/custom
Disable custom 2FA
- **Params**: `user` - User ID

---

## Autoreply

### GET /api/users/:user/autoreply
Get autoreply information
- **Params**: `user` - User ID

### PUT /api/users/:user/autoreply
Update autoreply information
- **Params**: `user` - User ID
- **Body**: `{ "status": boolean, "subject": string, "text": string, "html": string, "start": date, "end": date }`

### DELETE /api/users/:user/autoreply
Delete autoreply
- **Params**: `user` - User ID

---

## DKIM

### GET /api/dkim
List registered DKIM keys
- **Query**: `query`, `limit`, `next`, `previous`

### GET /api/dkim/resolve/:domain
Resolve domain to DKIM ID
- **Params**: `domain` - Domain name

### POST /api/dkim
Create or update DKIM key for domain
- **Body**: `{ "domain": string, "selector": string, "privateKey": string, "description": string }`

### GET /api/dkim/:dkim
Request DKIM information
- **Params**: `dkim` - DKIM ID

### DELETE /api/dkim/:dkim
Delete a DKIM key
- **Params**: `dkim` - DKIM ID

---

## Webhooks

### GET /api/webhooks
List registered webhooks
- **Query**: `limit`, `next`, `previous`

### POST /api/webhooks
Create new webhook
- **Body**: `{ "type": string, "url": string, "user": string }`

### DELETE /api/webhooks/:webhook
Delete a webhook
- **Params**: `webhook` - Webhook ID

---

## Certificates

### GET /api/certs
List registered certificates
- **Query**: `limit`, `next`, `previous`

### GET /api/certs/resolve/:servername
Resolve certificate by servername
- **Params**: `servername` - Server name

### POST /api/certs
Create or update certificate
- **Body**: `{ "servername": string, "privateKey": string, "cert": string, "ca": array }`

### GET /api/certs/:cert
Request certificate information
- **Params**: `cert` - Certificate ID

### DELETE /api/certs/:cert
Delete a certificate
- **Params**: `cert` - Certificate ID

---

## Domain Aliases

### GET /api/domainaliases
List domain aliases
- **Query**: `query`, `limit`, `next`, `previous`

### POST /api/domainaliases
Create new domain alias
- **Body**: `{ "alias": string, "domain": string }`

### GET /api/domainaliases/resolve/:alias
Resolve alias domain to ID
- **Params**: `alias` - Alias domain

### GET /api/domainaliases/:alias
Request alias information
- **Params**: `alias` - Alias ID

### DELETE /api/domainaliases/:alias
Delete an alias
- **Params**: `alias` - Alias ID

---

## Domain Access Control

### GET /api/domainaccess/:tag/allow
List allowed domains
- **Params**: `tag` - Tag name

### GET /api/domainaccess/:tag/block
List blocked domains
- **Params**: `tag` - Tag name

### POST /api/domainaccess/:tag/allow
Add domain to allowlist
- **Params**: `tag` - Tag name
- **Body**: `{ "domain": string }`

### POST /api/domainaccess/:tag/block
Add domain to blocklist
- **Params**: `tag` - Tag name
- **Body**: `{ "domain": string }`

### DELETE /api/domainaccess/:domain
Remove domain from lists
- **Params**: `domain` - Domain name

---

## Storage

### GET /api/users/:user/storage
List stored files
- **Params**: `user` - User ID
- **Query**: `query`, `limit`, `next`, `previous`

### POST /api/users/:user/storage
Upload file to storage
- **Params**: `user` - User ID
- **Body**: File data

### GET /api/users/:user/storage/:file
Download stored file
- **Params**: `user` - User ID, `file` - File ID

### DELETE /api/users/:user/storage/:file
Delete stored file
- **Params**: `user` - User ID, `file` - File ID

---

## Settings

### GET /api/settings
List all settings

### GET /api/settings/:key
Get setting value
- **Params**: `key` - Setting key

### POST /api/settings/:key
Create or update setting
- **Params**: `key` - Setting key
- **Body**: `{ "value": any }`

---

## Audit

### GET /api/audit
List audits
- **Query**: `user`, `action`, `filterIp`, `limit`, `next`, `previous`

### GET /api/audit/:audit
Request audit information
- **Params**: `audit` - Audit ID

### GET /api/audit/:audit/export.mbox
Export audit as mbox
- **Params**: `audit` - Audit ID

---

## Data Management

### POST /api/data/export
Export user data
- **Body**: `{ "user": string, "types": array }`

### POST /api/data/import
Import user data
- **Body**: Import data

---

## Updates & Monitoring

### GET /api/users/:user/updates
Get user event stream (Server-Sent Events)
- **Params**: `user` - User ID

### GET /api/health
Health check endpoint
- **Response**: `{ "success": true }`

---

## ACME

### GET /api/.well-known/acme-challenge/:token
ACME challenge verification
- **Params**: `token` - ACME token

---

# Mail Box Indexer API Endpoints

All indexer endpoints are prefixed with `/idx`. Some endpoints require wallet signature authentication.

## Points System

### GET /idx/points/leaderboard/:count
Get top users by points (leaderboard)
- **Params**: `count` - Number of top users (1-100)
- **Auth**: None (public)

### GET /idx/points/site-stats
Get site-wide statistics
- **Auth**: None (public)

---

## KYC Verification

### POST /idx/api/kyc/initiate/:walletAddress
Initiate KYC verification with Sumsub
- **Params**: `walletAddress` - Wallet address
- **Body**: `{ "verificationLevel": "basic" | "enhanced" | "accredited" }`
- **Auth**: Wallet signature required

### GET /idx/api/kyc/status/:walletAddress
Get KYC verification status
- **Params**: `walletAddress` - Wallet address
- **Auth**: Wallet signature required

### POST /idx/api/kyc/webhook
Sumsub webhook handler (internal)
- **Auth**: Webhook signature verification

---

## OAuth & Authentication

### GET /idx/.well-known/openid-configuration
OpenID Connect discovery endpoint
- **Auth**: None (public)

### POST /idx/auth/challenge
Generate wallet authentication challenge
- **Body**: `{ "wallet_identifier": string, "client_id": string, "redirect_uri": string }`
- **Auth**: None

### POST /idx/auth/verify
Verify wallet signature
- **Body**: `{ "session_id": string, "signature": string, "chain_type": "evm" | "solana", "current_wallet": string }`
- **Auth**: Signature verification

### GET /idx/oauth/authorize
OAuth authorization endpoint
- **Query**: `client_id`, `redirect_uri`, `response_type`, `scope`, `state`, `code_challenge`, `nonce`
- **Auth**: Session ID in header

### POST /idx/oauth/token
Token exchange endpoint
- **Body**: `{ "grant_type": string, "code"?: string, "refresh_token"?: string, "client_id": string, "redirect_uri": string }`
- **Auth**: Client credentials

### GET /idx/oauth/userinfo
Get user information from token
- **Auth**: Bearer token

### POST /idx/oauth/revoke
Revoke refresh token
- **Body**: `{ "token": string }`
- **Auth**: None

### GET /idx/oauth/clients/:clientId
Get OAuth client information
- **Params**: `clientId` - Client ID
- **Auth**: None (public)

---

## Solana Integration

### POST /idx/solana/webhook
Helius webhook for Solana transactions
- **Auth**: None (webhook)

### POST /idx/solana/setup-webhooks
Setup Helius webhooks
- **Auth**: None

### GET /idx/solana/status
Check Solana indexer status
- **Auth**: None (public)

### POST /idx/solana/test-transaction
Create test transaction (debugging)
- **Body**: `{ "chainId"?: number, "eventType"?: string }`
- **Auth**: None

---

## User & Address Validation

### GET /idx/users/:username/validate
Validate username format
- **Params**: `username` - Username to validate
- **Auth**: None (public)

### GET /idx/wallets/:walletAddress/accounts
Get email accounts for wallet
- **Params**: `walletAddress` - Wallet address
- **Headers**: `x-referral` (optional) - Referral code
- **Auth**: Wallet signature required

---

## Delegation Management

### GET /idx/delegations/from/:walletAddress
Get wallet this address delegated to
- **Params**: `walletAddress` - Delegator address
- **Auth**: Wallet signature required

### GET /idx/delegations/to/:walletAddress
Get wallets delegated to this address
- **Params**: `walletAddress` - Delegate address
- **Auth**: Wallet signature required

---

## Nonce Management

### POST /idx/users/:username/nonce
Create new nonce
- **Params**: `username` - Username/wallet
- **Auth**: Wallet signature required

### GET /idx/users/:username/nonce
Retrieve nonce
- **Params**: `username` - Username/wallet
- **Auth**: Wallet signature required

---

## Entitlements & Subscriptions

### GET /idx/wallets/:walletAddress/entitlements/
Check nameservice entitlement (RevenueCat)
- **Params**: `walletAddress` - Wallet address
- **Auth**: Wallet signature required

---

## Points & Rewards

### GET /idx/wallets/:walletAddress/points
Get user points balance
- **Params**: `walletAddress` - Wallet address
- **Auth**: Wallet signature required

### GET /idx/wallets/:walletAddress/authenticated
Check if user authenticated before
- **Params**: `walletAddress` - Wallet address
- **Auth**: Wallet signature required

### POST /idx/wallets/:walletAddress/points/add
Add reward points (internal)
- **Params**: `walletAddress` - Wallet address
- **Body**: `{ "action": string, "referrer"?: string }`
- **Auth**: IP restricted to WildDuck server

---

## Signature & Authentication

### GET /idx/wallets/:walletAddress/message
Get deterministic signing message
- **Params**: `walletAddress` - Wallet address
- **Query**: `chainId`, `domain`, `url`
- **Auth**: None (public)

### POST /idx/authenticate
Authenticate user with signature (internal)
- **Body**: `{ "username": string, "password": string, "message": string, "signer": string, "referrer"?: string }`
- **Auth**: IP restricted to WildDuck server

### POST /idx/addresses/:address/verify
Verify wallet signature (internal)
- **Params**: `address` - Wallet address
- **Auth**: IP restricted + signature

---

## Referral System

### POST /idx/wallets/:walletAddress/referral
Get/generate referral code
- **Params**: `walletAddress` - Wallet address
- **Auth**: Wallet signature required

### POST /idx/referrals/:referralCode/stats
Get referral statistics
- **Params**: `referralCode` - Referral code
- **Auth**: None (public)

---

## Blockchain Status

### GET /idx/blocks
Get current block numbers
- **Auth**: None (public)

---

## GraphQL

### GET /idx/
GraphQL interface (Ponder)
- **Auth**: None (public)

### GET /idx/graphql
GraphQL endpoint
- **Auth**: None (public)

---

## Authentication Methods

### WildDuck API
- **X-Access-Token**: Header containing API access token
- Get token from `/config-generated/wildduck/api.toml`

### Mail Box Indexer
- **Wallet Signature**: Sign message with wallet private key
- **Bearer Token**: OAuth 2.0 access token
- **IP Restriction**: Internal endpoints only accessible from WildDuck server IP
- **Webhook Signature**: HMAC verification for webhooks

---

## Error Responses

All endpoints return standard error responses:

```json
{
  "error": "Error description",
  "code": "ERROR_CODE",
  "success": false
}
```

Common HTTP status codes:
- `200` - Success
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `429` - Too Many Requests
- `500` - Internal Server Error

---

## Rate Limiting

- WildDuck API: Configurable per endpoint
- Indexer API: Standard rate limiting applies
- OAuth endpoints: Strict rate limiting for security

---

## Pagination

List endpoints support pagination with:
- `limit` - Number of results per page
- `next` - Next page cursor
- `previous` - Previous page cursor
- `page` - Page number (some endpoints)

---

**Total Endpoints**: 118+ WildDuck endpoints + 36 Indexer REST endpoints + 2 GraphQL endpoints
