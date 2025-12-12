const prisma = require('../prismaClient');
const { UnprocessableEntity } = require('../errors');
const Decimal = require('decimal.js');

/**
 * Get balance for an account by calculating from ledger entries.
 * Credits increase balance, debits decrease balance.
 */
async function getBalance(tx, accountId, currency) {
  // Sum all ledger entries for this account
  const entries = await tx.ledgerEntry.findMany({
    where: { accountId }
  });

  let balance = new Decimal(0);
  for (const entry of entries) {
    const amount = new Decimal(entry.amount);
    if (entry.entryType === 'credit') {
      balance = balance.plus(amount);
    } else if (entry.entryType === 'debit') {
      balance = balance.minus(amount);
    }
  }

  return balance;
}

/**
 * Safe, serializable, concurrent-proof transfer.
 */
async function transfer({ sourceAccountId, destinationAccountId, amount, currency }) {
  amount = new Decimal(amount);

  return prisma.$transaction(
    async (tx) => {

      // Always lock accounts in deterministic order
      const lockedIds = [sourceAccountId, destinationAccountId].sort();

      // Row-level locking to block concurrency with UUID cast
      await tx.$queryRawUnsafe(
        `SELECT 1 FROM "Account" WHERE "id" = $1::uuid FOR UPDATE`,
        lockedIds[0]
      );
      await tx.$queryRawUnsafe(
        `SELECT 1 FROM "Account" WHERE "id" = $1::uuid FOR UPDATE`,
        lockedIds[1]
      );

      // Fetch after lock
      const source = await tx.account.findUnique({ where: { id: sourceAccountId } });
      const dest = await tx.account.findUnique({ where: { id: destinationAccountId } });

      if (!source || !dest) throw new UnprocessableEntity("Account does not exist");

      // Calculate current balance from ledger entries
      const sourceBalance = await getBalance(tx, sourceAccountId, currency);

      if (sourceBalance.lessThan(amount)) {
        throw new UnprocessableEntity("insufficient funds");
      }

      // Create transaction record
      const transaction = await tx.transaction.create({
        data: {
          type: "transfer",
          sourceAccountId,
          destinationAccountId,
          amount: amount.toNumber(),
          currency,
          status: "completed"
        }
      });

      // Create ledger entries (source of truth for balances)
      await tx.ledgerEntry.create({
        data: {
          accountId: sourceAccountId,
          transactionId: transaction.id,
          entryType: "debit",
          amount: amount.toNumber(),
          currency
        }
      });

      await tx.ledgerEntry.create({
        data: {
          accountId: destinationAccountId,
          transactionId: transaction.id,
          entryType: "credit",
          amount: amount.toNumber(),
          currency
        }
      });

      // Update stored balances to match calculated balances (for performance)
      const newSourceBalance = await getBalance(tx, sourceAccountId, currency);
      const newDestBalance = await getBalance(tx, destinationAccountId, currency);

      await tx.account.update({
        where: { id: sourceAccountId },
        data: { balance: newSourceBalance.toNumber() }
      });

      await tx.account.update({
        where: { id: destinationAccountId },
        data: { balance: newDestBalance.toNumber() }
      });

      return transaction;
    },
    { isolationLevel: "Serializable" }
  );
}

module.exports = { transfer, getBalance };
