/**
 * ZoneMTA Plugin: WildDuck API Authentication
 *
 * This plugin authenticates SMTP users via WildDuck's HTTP API instead of
 * querying MongoDB directly. This ensures authentication goes through the
 * IndexerHelper, which supports wallet signature authentication.
 */

'use strict';

const axios = require('axios');

module.exports.title = 'WildDuck API Authentication';
module.exports.init = function(app, done) {

    // Get configuration (check multiple possible config paths)
    const config = app.config['./000-wildduck-api-auth'] ||
                   app.config['modules/000-wildduck-api-auth'] ||
                   app.config.wildduckApiAuth ||
                   {};

    const wildduckApiUrl = config.apiUrl || process.env.WILDDUCK_API_URL || 'http://wildduck:8080';

    app.logger.info('[WildDuck API Auth] Plugin initialized, API URL: ' + wildduckApiUrl);
    app.logger.info('[WildDuck API Auth] Config: ' + JSON.stringify(config));

    /**
     * Hook into SMTP AUTH command
     * This runs before the default wildduck plugin authentication
     */
    app.addHook('smtp:auth', async (auth, session) => {

        // Only handle authentication for our configured interfaces
        const interfaces = config.interfaces || ['feeder'];
        if (!interfaces.includes('*') && !interfaces.includes(session.interface)) {
            return; // Let other plugins handle this
        }

        app.logger.info('[WildDuck API Auth] Authentication attempt for: ' + auth.username);

        try {
            const response = await axios.post(`${wildduckApiUrl}/authenticate`, {
                username: auth.username,
                password: auth.password,
                scope: 'smtp',
                protocol: 'SMTP',
                sess: session.id,
                ip: session.remoteAddress
            }, {
                timeout: 10000,
                headers: {
                    'Content-Type': 'application/json'
                }
            });

            if (response.data && response.data.success) {
                app.logger.info('[WildDuck API Auth] Authentication successful for: ' + auth.username);

                // Set user data for downstream plugins
                auth.user = response.data.id;
                auth.username = response.data.username;

                return {
                    user: response.data.id,
                    username: response.data.username,
                    scope: response.data.scope
                };
            } else {
                app.logger.info('[WildDuck API Auth] Authentication failed for: ' + auth.username);
                throw new Error('Authentication failed');
            }

        } catch (error) {
            app.logger.error('[WildDuck API Auth] Authentication error for ' + auth.username + ': ' + error.message);

            // Return error to client
            const err = new Error('Authentication failed');
            err.responseCode = 535;
            throw err;
        }
    });

    done();
};
