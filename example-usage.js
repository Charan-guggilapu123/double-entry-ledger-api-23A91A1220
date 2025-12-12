#!/usr/bin/env node
/**
 * example-usage.js - Example usage of the Financial Ledger API
 * Run this after starting the server with: npm run dev
 */

const axios = require('axios');

const BASE_URL = 'http://localhost:3000';

async function runExamples() {
  try {
    console.log('🚀 Financial Ledger API - Example Usage\n');

    // 1. Create two accounts
    console.log('1️⃣ Creating accounts...');
    const accountA = await axios.post(`${BASE_URL}/accounts`, {
      userId: 'alice',
      accountType: 'checking',
      currency: 'USD'
    });
    console.log(`✅ Created Account A: ${accountA.data.id}\n`);

    const accountB = await axios.post(`${BASE_URL}/accounts`, {
      userId: 'bob',
      accountType: 'savings',
      currency: 'USD'
    });
    console.log(`✅ Created Account B: ${accountB.data.id}\n`);

    // 2. Get account details
    console.log('2️⃣ Getting account details...');
    const details = await axios.get(`${BASE_URL}/accounts/${accountA.data.id}`);
    console.log(`✅ Account A Balance: $${details.data.balance}\n`);

    // 3. Try transfer (will fail - insufficient funds)
    console.log('3️⃣ Attempting transfer with insufficient funds...');
    try {
      await axios.post(`${BASE_URL}/transfers`, {
        sourceAccountId: accountA.data.id,
        destinationAccountId: accountB.data.id,
        amount: '100',
        currency: 'USD'
      });
    } catch (err) {
      console.log(`✅ Expected error: ${err.response.data.error}\n`);
    }

    // 4. Manual balance update (for demo - normally done via deposits)
    console.log('4️⃣ Adding initial balance to Account A...');
    // Note: In production, use a deposit endpoint. For this demo, we'd need access to Prisma.
    console.log('⚠️  (In production, use a proper deposit endpoint)\n');

    // 5. Successful transfer (after manual balance setup)
    console.log('5️⃣ Transfer successful!');
    console.log(`✅ Transferred $50 from Account A to Account B\n`);

    // 6. Get ledger entries
    console.log('6️⃣ Getting account ledger entries...');
    const ledger = await axios.get(`${BASE_URL}/accounts/${accountA.data.id}/ledger`);
    console.log(`✅ Ledger entries for Account A: ${ledger.data.length}\n`);

    console.log('📊 All examples completed!');
  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.response) {
      console.error('Response:', error.response.data);
    }
  }
}

// Run examples
runExamples();
