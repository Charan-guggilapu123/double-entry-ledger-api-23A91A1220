const express = require('express');
const router = express.Router();
const prisma = require('../prismaClient');
const Decimal = require('decimal.js');

const { NotFound } = require('../errors');
const { getBalance } = require('../services/ledgerService');

// POST /accounts
router.post('/', async (req, res, next) => {
  try {
    const { userId, accountType, currency } = req.body;
    if (!userId || !accountType || !currency) {
      return res.status(400).json({ error: 'userId, accountType, currency required' });
    }
    
    if (typeof userId !== 'string' || !userId.trim()) {
      return res.status(400).json({ error: 'userId must be a non-empty string' });
    }
    
    if (typeof accountType !== 'string' || !accountType.trim()) {
      return res.status(400).json({ error: 'accountType must be a non-empty string' });
    }
    
    if (typeof currency !== 'string' || currency.length !== 3) {
      return res.status(400).json({ error: 'currency must be a 3-letter code' });
    }

    const acct = await prisma.account.create({
      data: {
        userId: userId.trim(),
        accountType: accountType.trim(),
        currency: currency.toUpperCase(),
        balance: 0
      }
    });

    res.status(201).json({
      id: acct.id,
      userId: acct.userId,
      accountType: acct.accountType,
      currency: acct.currency,
      status: acct.status,
      balance: "0.00000000"
    });
  } catch (err) {
    next(err);
  }
});

// GET /accounts/:id
router.get('/:id', async (req, res, next) => {
  try {
    const acct = await prisma.account.findUnique({ where: { id: req.params.id }});
    if (!acct) return res.status(404).json({ error: 'Account not found' });

    const bal = await getBalance(prisma, acct.id, acct.currency); // note: getBalance accepts tx-like prisma or client; when not in tx, it's OK
    res.json({
      id: acct.id,
      userId: acct.userId,
      accountType: acct.accountType,
      currency: acct.currency,
      status: acct.status,
      balance: bal.toFixed(8)
    });
  } catch (err) {
    next(err);
  }
});

// GET /accounts/:id/ledger
router.get('/:id/ledger', async (req, res, next) => {
  try {
    const { id } = req.params;
    const { limit = '100', offset = '0' } = req.query;
    
    const limitNum = Math.min(parseInt(limit, 10) || 100, 1000); // Max 1000 per request
    const offsetNum = parseInt(offset, 10) || 0;

    // Get total count for pagination
    const totalCount = await prisma.ledgerEntry.count({
      where: { accountId: id }
    });

    const entries = await prisma.ledgerEntry.findMany({
      where: { accountId: id },
      orderBy: { createdAt: 'desc' },
      take: limitNum,
      skip: offsetNum
    });

    res.json({
      entries: entries.map(e => ({
        id: e.id,
        accountId: e.accountId,
        transactionId: e.transactionId,
        entryType: e.entryType,
        amount: e.amount.toString(),
        currency: e.currency,
        createdAt: e.createdAt
      })),
      pagination: {
        total: totalCount,
        limit: limitNum,
        offset: offsetNum,
        hasMore: offsetNum + entries.length < totalCount
      }
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
