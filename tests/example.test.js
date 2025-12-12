// tests/example.test.js
const request = require('supertest');
const app = require('../src/app');
const prisma = require('../src/prismaClient');

beforeAll(async () => {
  // Clean up DB
  await prisma.ledgerEntry.deleteMany();
  await prisma.transaction.deleteMany();
  await prisma.account.deleteMany();
});

afterAll(async () => {
  await prisma.$disconnect();
});

describe('Account Creation', () => {
  test('should create a new account', async () => {
    const res = await request(app)
      .post('/accounts')
      .send({
        userId: 'user123',
        accountType: 'checking',
        currency: 'USD'
      });

    expect(res.status).toBe(201);
    expect(res.body.id).toBeDefined();
    expect(res.body.userId).toBe('user123');
    expect(res.body.accountType).toBe('checking');
    expect(res.body.currency).toBe('USD');
    expect(res.body.balance).toBe('0.00000000');
    expect(res.body.status).toBe('active');
  });

  test('should fail with missing fields', async () => {
    const res = await request(app)
      .post('/accounts')
      .send({
        userId: 'user456'
        // missing accountType and currency
      });

    expect(res.status).toBe(400);
    expect(res.body.error).toBeDefined();
  });

  test('should fail with invalid currency code', async () => {
    const res = await request(app)
      .post('/accounts')
      .send({
        userId: 'user789',
        accountType: 'savings',
        currency: 'INVALID' // not 3 letters
      });

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/currency/i);
  });

  test('should get account details', async () => {
    // Create an account first
    const createRes = await request(app)
      .post('/accounts')
      .send({
        userId: 'getUserTest',
        accountType: 'checking',
        currency: 'USD'
      });

    const accountId = createRes.body.id;

    // Get account details
    const getRes = await request(app)
      .get(`/accounts/${accountId}`);

    expect(getRes.status).toBe(200);
    expect(getRes.body.id).toBe(accountId);
    expect(getRes.body.balance).toBe('0.00000000');
  });
});
