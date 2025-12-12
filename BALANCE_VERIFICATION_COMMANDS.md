## Commands to Verify Balance Calculation

Run these commands in PowerShell to verify that balances are calculated correctly from ledger entries:

### Quick Verification (Run this first):

```powershell
$env:PGPASSWORD = "postgres"
psql -U postgres -h localhost -d ledgerdb -c "SELECT a.id, a.\"userId\", a.balance::numeric as stored_balance, COALESCE(SUM(CASE WHEN le.entry_type = 'credit' THEN le.amount ELSE -le.amount END), 0)::numeric as calculated_balance, CASE WHEN a.balance = COALESCE(SUM(CASE WHEN le.entry_type = 'credit' THEN le.amount ELSE -le.amount END), 0) THEN 'MATCH' ELSE 'MISMATCH' END as status FROM \"Account\" a LEFT JOIN \"LedgerEntry\" le ON a.id = le.account_id GROUP BY a.id, a.balance ORDER BY a.\"createdAt\" LIMIT 10;"
```

**Expected Output:**
- A table showing each account with:
  - `stored_balance`: Balance stored in Account table
  - `calculated_balance`: Sum of ledger entries (credits - debits)
  - `status`: Should show "MATCH" if they're equal ✓

### Detailed Ledger Entries:

```powershell
$env:PGPASSWORD = "postgres"
psql -U postgres -h localhost -d ledgerdb -c "SELECT a.\"userId\", le.entry_type, le.amount, le.currency, t.type as transaction_type, le.created_at FROM \"LedgerEntry\" le JOIN \"Account\" a ON le.account_id = a.id JOIN \"Transaction\" t ON le.transaction_id = t.id ORDER BY le.created_at DESC LIMIT 20;"
```

**Expected Output:**
- List of all ledger entries showing:
  - Account userId
  - Entry type (debit or credit)
  - Amount
  - Transaction type

### Summary by Account:

```powershell
$env:PGPASSWORD = "postgres"
psql -U postgres -h localhost -d ledgerdb -c "SELECT a.\"userId\", a.\"accountType\", COUNT(le.id) as entry_count, SUM(CASE WHEN le.entry_type = 'credit' THEN le.amount ELSE 0 END)::numeric as total_credits, SUM(CASE WHEN le.entry_type = 'debit' THEN le.amount ELSE 0 END)::numeric as total_debits, SUM(CASE WHEN le.entry_type = 'credit' THEN le.amount ELSE -le.amount END)::numeric as net_balance, a.balance::numeric as stored_balance FROM \"Account\" a LEFT JOIN \"LedgerEntry\" le ON a.id = le.account_id GROUP BY a.id, a.\"userId\", a.\"accountType\", a.balance ORDER BY a.\"createdAt\";"
```

**What this proves:**
- Credits and debits are properly recorded
- Net balance (sum of all ledger entries) matches stored balance
- All accounts maintain a complete audit trail

### Step-by-Step Manual Test:

If you want to create test data and verify, follow these steps:

**Terminal 1 - Start API:**
```powershell
npm start
```

**Terminal 2 - Create test transactions:**
```powershell
# Verify the ledger entries with the first command above
$env:PGPASSWORD = "postgres"
psql -U postgres -h localhost -d ledgerdb << 'EOF'

-- View all accounts and their balances
SELECT id, "userId", balance FROM "Account";

-- View all transactions
SELECT id, type, source_account_id, destination_account_id, amount, status, created_at FROM "Transaction" ORDER BY created_at DESC;

-- View all ledger entries
SELECT id, account_id, entry_type, amount, currency, created_at FROM "LedgerEntry" ORDER BY created_at DESC;

EOF
```

### Verification Proof:

If all three queries above show matching stored balances and calculated balances:
✓ **Account balances ARE correctly calculated from ledger entries**
✓ **The ledger system is the source of truth**
✓ **Stored balances match the sum of all ledger entries**
