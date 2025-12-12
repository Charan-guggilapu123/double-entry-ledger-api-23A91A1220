const express = require('express');
const router = express.Router();
const { transfer } = require('../services/ledgerService');
const { UnprocessableEntity } = require('../errors');
const Decimal = require('decimal.js');

router.post('/transfers', async (req, res, next) => {
  try {
    const { sourceAccountId, destinationAccountId, amount, currency } = req.body;

    // Validation
    if (!sourceAccountId || !destinationAccountId || amount === undefined || !currency) {
      return res.status(400).json({ error: 'sourceAccountId, destinationAccountId, amount, currency required' });
    }

    if (sourceAccountId === destinationAccountId) {
      return res.status(400).json({ error: 'sourceAccountId and destinationAccountId must be different' });
    }

    const amountDec = new Decimal(amount);
    if (amountDec.isNaN() || amountDec.lessThanOrEqualTo(0)) {
      return res.status(400).json({ error: 'amount must be a positive number' });
    }

    if (typeof currency !== 'string' || currency.length !== 3) {
      return res.status(400).json({ error: 'currency must be a 3-letter code' });
    }

    const result = await transfer({
      sourceAccountId,
      destinationAccountId,
      amount: amountDec.toString(),
      currency: currency.toUpperCase()
    });

    return res.status(201).json({
      id: result.id,
      type: result.type,
      sourceAccountId: result.sourceAccountId,
      destinationAccountId: result.destinationAccountId,
      amount: result.amount.toString(),
      currency: result.currency,
      status: result.status,
      createdAt: result.createdAt
    });

  } catch (err) {
    if (err instanceof UnprocessableEntity) {
      err.status = 422;
    }
    next(err);
  }
});

module.exports = router;
