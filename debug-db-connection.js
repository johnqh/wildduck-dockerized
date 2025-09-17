#!/usr/bin/env node

/**
 * Database Connection Debug Script
 * This script tests connectivity to MongoDB and Redis using the same configuration as WildDuck
 */

const path = require('path');
const { MongoClient } = require('mongodb');
const Redis = require('ioredis');

// Simulate WildDuck's config loading
const config = {
    dbs: {
        mongo: "mongodb://mongo:27017/wildduck?serverSelectionTimeoutMS=10000&connectTimeoutMS=10000&socketTimeoutMS=0&maxPoolSize=10&minPoolSize=1&maxIdleTimeMS=30000",
        redis: {
            host: "redis",
            port: 6379,
            db: 3
        }
    }
};

console.log('🔍 WildDuck Database Connection Debug Script');
console.log('============================================');
console.log('Starting database connectivity tests...\n');

async function testMongoDB() {
    console.log('📊 Testing MongoDB Connection...');
    console.log('Connection string:', config.dbs.mongo.replace(/\/\/([^:]+):([^@]+)@/, '//***:***@'));
    
    try {
        const client = new MongoClient(config.dbs.mongo);
        console.log('⏳ Connecting to MongoDB...');
        
        const startTime = Date.now();
        await client.connect();
        const connectTime = Date.now() - startTime;
        
        console.log('✅ MongoDB connected successfully in', connectTime, 'ms');
        
        // Test ping
        const pingResult = await client.db().admin().ping();
        console.log('✅ MongoDB ping successful:', pingResult);
        
        // Test write operation
        const testDb = client.db('wildduck');
        const testCollection = testDb.collection('debug_test');
        const insertResult = await testCollection.insertOne({ test: 'debug', timestamp: new Date() });
        console.log('✅ MongoDB write test successful, insertedId:', insertResult.insertedId);
        
        // Clean up test data
        await testCollection.deleteOne({ _id: insertResult.insertedId });
        console.log('✅ MongoDB cleanup successful');
        
        await client.close();
        console.log('✅ MongoDB connection closed\n');
        
        return true;
    } catch (error) {
        console.error('❌ MongoDB connection failed:');
        console.error('  Error:', error.message);
        console.error('  Code:', error.code || 'UNKNOWN');
        console.error('  Stack:', error.stack);
        console.log('');
        return false;
    }
}

async function testRedis() {
    console.log('🔴 Testing Redis Connection...');
    console.log('Redis config:', `${config.dbs.redis.host}:${config.dbs.redis.port} (db:${config.dbs.redis.db})`);
    
    try {
        const redis = new Redis(config.dbs.redis);
        console.log('⏳ Connecting to Redis...');
        
        return new Promise((resolve) => {
            let connected = false;
            let startTime = Date.now();
            
            redis.on('connect', async () => {
                if (connected) return;
                connected = true;
                
                const connectTime = Date.now() - startTime;
                console.log('✅ Redis connected successfully in', connectTime, 'ms');
                
                try {
                    // Test ping
                    const pongResult = await redis.ping();
                    console.log('✅ Redis ping successful:', pongResult);
                    
                    // Test write operation
                    await redis.set('debug_test', 'debug_value');
                    console.log('✅ Redis write test successful');
                    
                    // Test read operation
                    const value = await redis.get('debug_test');
                    console.log('✅ Redis read test successful, value:', value);
                    
                    // Clean up test data
                    await redis.del('debug_test');
                    console.log('✅ Redis cleanup successful');
                    
                    await redis.quit();
                    console.log('✅ Redis connection closed\n');
                    
                    resolve(true);
                } catch (error) {
                    console.error('❌ Redis operation failed:', error.message);
                    await redis.quit();
                    resolve(false);
                }
            });
            
            redis.on('error', (error) => {
                if (connected) return;
                connected = true;
                
                console.error('❌ Redis connection failed:');
                console.error('  Error:', error.message);
                console.error('  Code:', error.code || 'UNKNOWN');
                console.error('  Stack:', error.stack);
                console.log('');
                resolve(false);
            });
            
            // Timeout after 15 seconds
            setTimeout(() => {
                if (!connected) {
                    connected = true;
                    console.error('❌ Redis connection timeout after 15 seconds\n');
                    redis.disconnect();
                    resolve(false);
                }
            }, 15000);
        });
    } catch (error) {
        console.error('❌ Redis setup failed:', error.message);
        return false;
    }
}

async function main() {
    try {
        const mongoSuccess = await testMongoDB();
        const redisSuccess = await testRedis();
        
        console.log('📋 Summary:');
        console.log('==========');
        console.log('MongoDB:', mongoSuccess ? '✅ SUCCESS' : '❌ FAILED');
        console.log('Redis:', redisSuccess ? '✅ SUCCESS' : '❌ FAILED');
        
        if (mongoSuccess && redisSuccess) {
            console.log('\n🎉 All database connections successful!');
            process.exit(0);
        } else {
            console.log('\n💥 One or more database connections failed!');
            console.log('\nDebugging tips:');
            console.log('- Check if MongoDB and Redis containers are running');
            console.log('- Verify network connectivity between containers');
            console.log('- Check Docker Compose service health');
            console.log('- Review container logs for additional details');
            process.exit(1);
        }
    } catch (error) {
        console.error('💥 Unexpected error:', error.message);
        process.exit(1);
    }
}

// Run the debug script
main();