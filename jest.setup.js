// jest.setup.js
require('dotenv').config({ path: '.env.test', override: true });
process.env.NODE_ENV = 'test';

// Optional: Set test timeout
jest.setTimeout(30000);
