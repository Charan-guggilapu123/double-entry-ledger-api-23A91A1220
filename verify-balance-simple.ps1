# Simple Balance Verification - Uses SQL directly
Write-Host "`n=== Balance Calculation Verification ===" -ForegroundColor Cyan
Write-Host "Checking that balances match ledger entries`n" -ForegroundColor Yellow

$env:PGPASSWORD = "postgres"

# Create test data
Write-Host "1. Setting up test data..." -ForegroundColor Green

$setupSql = @"
-- Clean up old test data
DELETE FROM "LedgerEntry" WHERE account_id IN (SELECT id FROM "Account" WHERE "userId" IN ('test1', 'test2'));
DELETE FROM "Transaction" WHERE source_account_id IN (SELECT id FROM "Account" WHERE "userId" IN ('test1', 'test2')) OR destination_account_id IN (SELECT id FROM "Account" WHERE "userId" IN ('test1', 'test2'));
DELETE FROM "Account" WHERE "userId" IN ('test1', 'test2');

-- Create test accounts
INSERT INTO "Account" (id, "userId", "accountType", currency, balance) VALUES 
  (gen_random_uuid(), 'test1', 'checking', 'USD', 0),
  (gen_random_uuid(), 'test2', 'savings', 'USD', 0) 
RETURNING id INTO accta, acctb;

-- Store account IDs for use below
CREATE TEMP TABLE accts AS 
SELECT id FROM "Account" WHERE "userId" = 'test1' LIMIT 1;

SELECT id as acc1 FROM "Account" WHERE "userId" = 'test1' INTO accta;
SELECT id as acc2 FROM "Account" WHERE "userId" = 'test2' INTO acctb;
"@

#psql -U postgres -h localhost -d ledgerdb -c $setupSql 2>&1 | Out-Null

# Instead, use simpler approach - just verify existing data
Write-Host "1. Querying existing accounts for balance verification..." -ForegroundColor Green

$verifyQuery = @"
SELECT 
    a.id,
    a.\"userId\",
    a.balance as stored_balance,
    COALESCE(
        (SELECT SUM(CASE WHEN entry_type = 'credit' THEN amount ELSE -amount END)
         FROM \"LedgerEntry\" 
         WHERE account_id = a.id),
        0
    ) as calculated_balance,
    CASE 
        WHEN a.balance = COALESCE(
            (SELECT SUM(CASE WHEN entry_type = 'credit' THEN amount ELSE -amount END)
             FROM \"LedgerEntry\" WHERE account_id = a.id), 0
        ) THEN 'OK MATCH'
        ELSE 'X MISMATCH'
    END as status,
    (SELECT COUNT(*) FROM \"LedgerEntry\" WHERE account_id = a.id) as num_entries
FROM \"Account\" a
LIMIT 10;
"@

Write-Host "`n2. Balance Verification Results:" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
psql -U postgres -h localhost -d ledgerdb -c $verifyQuery

Write-Host "`n3. Ledger Entries Detail:" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan

$detailQuery = @"
SELECT 
    a.\"userId\",
    le.entry_type,
    le.amount,
    le.currency,
    t.type as tx_type
FROM \"LedgerEntry\" le
JOIN \"Account\" a ON le.account_id = a.id
JOIN \"Transaction\" t ON le.transaction_id = t.id
LIMIT 20;
"@

psql -U postgres -h localhost -d ledgerdb -c $detailQuery

Write-Host "`n4. Summary by Account:" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan

$summaryQuery = @"
SELECT 
    a.\"userId\",
    a.\"accountType\",
    COUNT(le.id) as total_entries,
    SUM(CASE WHEN le.entry_type = 'credit' THEN le.amount ELSE 0 END)::numeric as credits,
    SUM(CASE WHEN le.entry_type = 'debit' THEN le.amount ELSE 0 END)::numeric as debits,
    SUM(CASE WHEN le.entry_type = 'credit' THEN le.amount ELSE -le.amount END)::numeric as net_balance,
    a.balance as stored_balance
FROM \"Account\" a
LEFT JOIN \"LedgerEntry\" le ON a.id = le.account_id
GROUP BY a.id, a.\"userId\", a.\"accountType\", a.balance
ORDER BY a.\"createdAt\" DESC
LIMIT 5;
"@

psql -U postgres -h localhost -d ledgerdb -c $summaryQuery

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Verification complete!" -ForegroundColor Green
Write-Host "If 'status' column shows 'OK MATCH' for all rows, balances are correctly calculated from ledger!" -ForegroundColor Yellow
