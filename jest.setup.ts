// jest.setup.ts
import 'dotenv/config'; // This is the simplest way to load .env
// Or, for more control:
// import * as dotenv from 'dotenv';
// dotenv.config({ path: './.env.test' }); // Load .env.test specifically
// dotenv.config({ path: './.env' });      // Load generic .env

console.log('Environment variables loaded for Jest!');
