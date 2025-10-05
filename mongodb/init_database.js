// MongoDB Initialization Script
// WildDuck Mail Server Database Setup
//
// This script creates the necessary users and databases for WildDuck
// Run this after installing MongoDB with authentication enabled
//
// Usage:
//   mongosh --host localhost --port 27017 init_database.js
//
// Or run interactively:
//   mongosh
//   load("init_database.js")

print("================================================================================");
print("MongoDB Database Initialization for WildDuck Mail Server");
print("================================================================================");
print("");

// ==============================================================================
// Configuration
// ==============================================================================

const config = {
    // Admin user credentials (for MongoDB administration)
    admin: {
        username: "admin",
        password: "admin-password-change-me",  // CHANGE THIS!
        roles: ["root"]
    },

    // WildDuck application user credentials
    wildduck: {
        username: "wildduck",
        password: "wildduck-password",  // CHANGE THIS!
        database: "wildduck",
        roles: ["dbOwner"]
    },

    // Zone MTA user credentials (if using Zone-MTA for sending)
    zonemta: {
        username: "zonemta",
        password: "zonemta-password",  // CHANGE THIS!
        database: "zone-mta",
        roles: ["dbOwner"]
    }
};

// ==============================================================================
// Step 1: Create Admin User
// ==============================================================================

print("Step 1: Creating admin user...");
print("--------------------------------------------------------------------------------");

try {
    // Switch to admin database
    db = db.getSiblingDB("admin");

    // Check if admin user already exists
    const existingAdmin = db.getUser(config.admin.username);

    if (existingAdmin) {
        print(`✓ Admin user '${config.admin.username}' already exists`);
        print("  Skipping admin user creation");
    } else {
        // Create admin user
        db.createUser({
            user: config.admin.username,
            pwd: config.admin.password,
            roles: config.admin.roles
        });

        print(`✓ Created admin user: ${config.admin.username}`);
        print("");
        print("  ⚠️  SECURITY WARNING ⚠️");
        print("  The admin password is set to: " + config.admin.password);
        print("  CHANGE THIS IMMEDIATELY for production!");
        print("");
        print("  To change password, run:");
        print(`  use admin`);
        print(`  db.changeUserPassword("${config.admin.username}", "your-strong-password")`);
    }
} catch (error) {
    print("✗ Error creating admin user:");
    print("  " + error.message);
    print("");
    print("  This is normal if authentication is already enabled.");
    print("  Please authenticate first:");
    print(`  mongosh -u admin -p --authenticationDatabase admin`);
    print("  Then run this script again.");
    quit(1);
}

print("");

// ==============================================================================
// Step 2: Create WildDuck Database and User
// ==============================================================================

print("Step 2: Creating WildDuck database and user...");
print("--------------------------------------------------------------------------------");

try {
    // Switch to wildduck database
    db = db.getSiblingDB(config.wildduck.database);

    // Check if WildDuck user already exists
    const existingWildDuck = db.getUser(config.wildduck.username);

    if (existingWildDuck) {
        print(`✓ WildDuck user '${config.wildduck.username}' already exists`);
        print("  Skipping WildDuck user creation");
    } else {
        // Create WildDuck user
        db.createUser({
            user: config.wildduck.username,
            pwd: config.wildduck.password,
            roles: [
                {
                    role: config.wildduck.roles[0],
                    db: config.wildduck.database
                }
            ]
        });

        print(`✓ Created WildDuck user: ${config.wildduck.username}`);
        print(`✓ Created WildDuck database: ${config.wildduck.database}`);
        print("");
        print("  ⚠️  SECURITY WARNING ⚠️");
        print("  The WildDuck password is set to: " + config.wildduck.password);
        print("  CHANGE THIS IMMEDIATELY for production!");
        print("");
        print("  To change password, run:");
        print(`  use ${config.wildduck.database}`);
        print(`  db.changeUserPassword("${config.wildduck.username}", "your-strong-password")`);
    }

    // Create initial collections with validation (optional but recommended)
    print("");
    print("  Creating initial collections...");

    const collections = [
        { name: "users", validator: null },
        { name: "addresses", validator: null },
        { name: "mailboxes", validator: null },
        { name: "messages", validator: null },
        { name: "attachments.files", validator: null },
        { name: "attachments.chunks", validator: null },
        { name: "threads", validator: null },
        { name: "autoreplies", validator: null },
        { name: "filters", validator: null },
        { name: "domainaliases", validator: null },
        { name: "auditlog", validator: null }
    ];

    collections.forEach(coll => {
        try {
            if (!db.getCollectionNames().includes(coll.name)) {
                db.createCollection(coll.name);
                print(`    ✓ Created collection: ${coll.name}`);
            } else {
                print(`    - Collection already exists: ${coll.name}`);
            }
        } catch (e) {
            print(`    ✗ Error creating collection ${coll.name}: ${e.message}`);
        }
    });

    // Create indexes for WildDuck (these are also created by WildDuck on startup)
    print("");
    print("  Creating essential indexes...");

    // Users collection indexes
    db.users.createIndex({ username: 1 }, { unique: true });
    db.users.createIndex({ unameview: 1 });
    print("    ✓ Created indexes for 'users' collection");

    // Addresses collection indexes
    db.addresses.createIndex({ addrview: 1 }, { unique: true });
    db.addresses.createIndex({ user: 1 });
    print("    ✓ Created indexes for 'addresses' collection");

    // Mailboxes collection indexes
    db.mailboxes.createIndex({ user: 1, path: 1 }, { unique: true });
    print("    ✓ Created indexes for 'mailboxes' collection");

    // Messages collection indexes
    db.messages.createIndex({ user: 1, mailbox: 1, uid: 1 }, { unique: true });
    db.messages.createIndex({ user: 1, searchable: 1 });
    db.messages.createIndex({ exp: 1 }, { expireAfterSeconds: 0, sparse: true });
    db.messages.createIndex({ rdate: -1 });
    print("    ✓ Created indexes for 'messages' collection");

} catch (error) {
    print("✗ Error creating WildDuck database:");
    print("  " + error.message);
}

print("");

// ==============================================================================
// Step 3: Create Zone-MTA Database and User (Optional)
// ==============================================================================

print("Step 3: Creating Zone-MTA database and user (optional)...");
print("--------------------------------------------------------------------------------");

try {
    // Switch to zone-mta database
    db = db.getSiblingDB(config.zonemta.database);

    // Check if Zone-MTA user already exists
    const existingZoneMTA = db.getUser(config.zonemta.username);

    if (existingZoneMTA) {
        print(`✓ Zone-MTA user '${config.zonemta.username}' already exists`);
        print("  Skipping Zone-MTA user creation");
    } else {
        // Create Zone-MTA user
        db.createUser({
            user: config.zonemta.username,
            pwd: config.zonemta.password,
            roles: [
                {
                    role: config.zonemta.roles[0],
                    db: config.zonemta.database
                }
            ]
        });

        print(`✓ Created Zone-MTA user: ${config.zonemta.username}`);
        print(`✓ Created Zone-MTA database: ${config.zonemta.database}`);
        print("");
        print("  Note: Zone-MTA is optional. Only needed if you're using it for outbound mail.");
    }

} catch (error) {
    print("✗ Error creating Zone-MTA database:");
    print("  " + error.message);
    print("  (This is optional, you can skip this if not using Zone-MTA)");
}

print("");

// ==============================================================================
// Step 4: Verification
// ==============================================================================

print("Step 4: Verifying setup...");
print("--------------------------------------------------------------------------------");

try {
    // List all databases
    db = db.getSiblingDB("admin");
    const databases = db.adminCommand({ listDatabases: 1 });

    print("Databases created:");
    databases.databases.forEach(database => {
        if (["admin", "wildduck", "zone-mta"].includes(database.name)) {
            const size = (database.sizeOnDisk / 1024 / 1024).toFixed(2);
            print(`  ✓ ${database.name} (${size} MB)`);
        }
    });

    print("");

    // List users in each database
    print("Users created:");

    db = db.getSiblingDB("admin");
    const adminUsers = db.getUsers();
    adminUsers.users.forEach(user => {
        print(`  ✓ ${user.user}@admin - roles: ${user.roles.map(r => r.role).join(", ")}`);
    });

    db = db.getSiblingDB(config.wildduck.database);
    const wildDuckUsers = db.getUsers();
    wildDuckUsers.users.forEach(user => {
        print(`  ✓ ${user.user}@${config.wildduck.database} - roles: ${user.roles.map(r => r.role).join(", ")}`);
    });

    try {
        db = db.getSiblingDB(config.zonemta.database);
        const zoneMTAUsers = db.getUsers();
        zoneMTAUsers.users.forEach(user => {
            print(`  ✓ ${user.user}@${config.zonemta.database} - roles: ${user.roles.map(r => r.role).join(", ")}`);
        });
    } catch (e) {
        // Zone-MTA user might not exist if optional step was skipped
    }

} catch (error) {
    print("✗ Error during verification:");
    print("  " + error.message);
}

print("");

// ==============================================================================
// Step 5: Connection Strings
// ==============================================================================

print("================================================================================");
print("Setup completed successfully!");
print("================================================================================");
print("");
print("Connection strings for your .env file:");
print("");
print("WildDuck (local):");
print(`  mongodb://${config.wildduck.username}:${config.wildduck.password}@localhost:27017/${config.wildduck.database}?authSource=${config.wildduck.database}`);
print("");
print("WildDuck (remote - replace SERVER_IP):");
print(`  mongodb://${config.wildduck.username}:${config.wildduck.password}@SERVER_IP:27017/${config.wildduck.database}?authSource=${config.wildduck.database}`);
print("");
print("WildDuck (Docker on Windows - use host.docker.internal):");
print(`  mongodb://${config.wildduck.username}:${config.wildduck.password}@host.docker.internal:27017/${config.wildduck.database}?authSource=${config.wildduck.database}`);
print("");
print("Zone-MTA (optional, if using):");
print(`  mongodb://${config.zonemta.username}:${config.zonemta.password}@localhost:27017/${config.zonemta.database}?authSource=${config.zonemta.database}`);
print("");
print("================================================================================");
print("IMPORTANT SECURITY STEPS:");
print("================================================================================");
print("");
print("1. CHANGE ALL PASSWORDS IMMEDIATELY:");
print("");
print("   mongosh -u admin -p --authenticationDatabase admin");
print("");
print(`   use admin`);
print(`   db.changeUserPassword("admin", "your-strong-admin-password")`);
print("");
print(`   use ${config.wildduck.database}`);
print(`   db.changeUserPassword("${config.wildduck.username}", "your-strong-wildduck-password")`);
print("");
print("2. Update mongod.cfg:");
print("   - Change bindIp from 0.0.0.0 to specific IPs");
print("   - Ensure security.authorization is enabled");
print("");
print("3. Configure Windows Firewall:");
print("   - Allow port 27017 only from trusted IPs");
print("   - Block port 27017 from public internet");
print("");
print("4. Set up automated backups:");
print("   - Use backup_database.ps1 script");
print("   - Schedule daily backups with Task Scheduler");
print("");
print("5. Test connections:");
print("   - From local: mongosh connection-string");
print("   - From remote: mongosh connection-string");
print("   - From Docker: docker exec container mongosh connection-string");
print("");
print("================================================================================");
print("Next Steps:");
print("================================================================================");
print("");
print("1. Update WildDuck configuration:");
print("   - Edit docker-compose.yml or WildDuck config file");
print("   - Set MONGO_URL or mongo connection string");
print("   - Restart WildDuck service");
print("");
print("2. Verify WildDuck can connect:");
print("   - Check WildDuck logs for connection errors");
print("   - WildDuck will create additional indexes on startup");
print("");
print("3. Monitor MongoDB:");
print("   - Use MongoDB Compass for GUI monitoring");
print("   - Check slow queries: db.system.profile.find()");
print("   - Monitor disk space and memory usage");
print("");
print("4. Set up monitoring (optional):");
print("   - Install MongoDB Ops Manager");
print("   - Or use Prometheus + Grafana");
print("   - Or use Cloud monitoring (Atlas, etc.)");
print("");
print("================================================================================");
print("Documentation:");
print("================================================================================");
print("");
print("MongoDB Documentation:");
print("  https://docs.mongodb.com/manual/");
print("");
print("WildDuck Documentation:");
print("  https://github.com/nodemailer/wildduck");
print("  https://wildduck.email/");
print("");
print("Security Checklist:");
print("  https://docs.mongodb.com/manual/administration/security-checklist/");
print("");
print("================================================================================");
print("");

// Return success
quit(0);
