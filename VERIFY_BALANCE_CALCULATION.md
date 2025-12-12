# Balance Calculation Verification Commands

## Quick Start

### Command 1: Verify All Accounts (Main Verification)

```powershell
$env:PGPASSWORD = "postgres"
psql -U postgres -h localhost -d ledgerdb -c "SELECT a.\"userId\", a.balance::numeric as stored_balance, COALESCE(SUM(CASE WHEN entry_type = 'credit' THEN amount ELSE -amount END), 0)::numeric as calculated, CASE WHEN a.balance = COALESCE(SUM(CASE WHEN entry_type = 'credit' THEN amount ELSE -amount END), 0) THEN 'MATCH' ELSE 'DIFFERENT' END FROM \"Account\" a LEFT JOIN \"LedgerEntry\" le ON a.id = le.account_id GROUP BY a.id, a.balance ORDER BY a.\"userId\";"
```

**What it does:** Shows each account with:
- `stored_balance`: Balance in Account table
- `calculated`: Sum of all ledger entries for that account
- Result: "MATCH" = Balances are correctly calculated ✓

---

### Command 2: Show All Ledger Entries

```powershell
$env:PGPASSWORD = "postgres"
psql -U postgres -h localhost -d ledgerdb -c "SELECT a.\"userId\", le.entry_type, le.amount, t.type FROM \"LedgerEntry\" le JOIN \"Account\" a ON le.account_id = a.id JOIN \"Transaction\" t ON le.transaction_id = t.id ORDER BY le.created_at;"
```

**What it does:** Lists all debit/credit entries showing:
- Account (userId)
- Entry type (debit or credit)
- Amount
- Transaction type

---

### Command 3: Summary Table

```powershell
$env:PGPASSWORD = "postgres"
psql -U postgres -h localhost -d ledgerdb -c "SELECT a.\"userId\", COUNT(*) as entries, SUM(CASE WHEN entry_type='credit' THEN amount ELSE 0 END)::numeric as total_credits, SUM(CASE WHEN entry_type='debit' THEN amount ELSE 0 END)::numeric as total_debits, SUM(CASE WHEN entry_type='credit' THEN amount ELSE -amount END)::numeric as net_calculated, a.balance::numeric as stored FROM \"Account\" a LEFT JOIN \"LedgerEntry\" le ON a.id = le.account_id GROUP BY a.id, a.balance ORDER BY a.\"userId\";"
```

**What it does:** Shows per-account summary:
- Total entries
- Sum of credits
- Sum of debits
- Calculated balance (credits - debits)
- Stored balance in Account table
- If net_calculated = stored, balance is correct ✓

---

## Proof of Concept

Run Command 1 above. If you see:

```
  userId  | stored_balance | calculated | 
----------+----------------+-------------+
 user1    |         100.00 |     100.00  | MATCH
 user2    |          50.00 |      50.00  | MATCH
```

✅ **This proves:**
- Account balances ARE correctly calculated from ledger entries
- The stored balance matches the sum of all ledger entries
- Ledger entries are the source of truth
- Double-entry bookkeeping is working correctly

---

## How Balances are Calculated

Looking at the code in [src/services/ledgerService.js](src/services/ledgerService.js#L9-L25):

```javascript
async function getBalance(tx, accountId, currency) {
  const entries = await tx.ledgerEntry.findMany({
    where: { accountId }
  });
  
  let balance = new Decimal(0);
  for (const entry of entries) {
    const amount = new Decimal(entry.amount);
    if (entry.entryType === 'credit') {
      balance = balance.plus(amount);  // Add credit
    } else if (entry.entryType === 'debit') {
      balance = balance.minus(amount);  // Subtract debit
    }
  }
  return balance;
}
```

**This function:**
1. Fetches all ledger entries for an account
2. Sums credits and subtracts debits
3. Returns the calculated balance
4. Is used for all balance checks and validation

**During transfers** ([src/services/ledgerService.js#L57-105](src/services/ledgerService.js#L57-L105)):
- Balance is calculated from ledger entries (line 60)
- Transfer creates debit for source, credit for destination
- Both entries are in single transaction (atomic)
- Stored balance is updated to match calculated balance (lines 102-110)

---

## Verification Output Format

When you run Command 1, you'll see output like:

| userId  | stored_balance | calculated | MATCH |
|---------|------------------|-------------|-------|
| user123 | 50.00           | 50.00       | YES   |

✅ If all rows show the same value for stored and calculated, balances are correct!
