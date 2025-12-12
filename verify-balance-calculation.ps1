# Balance Verification Script
# This script verifies that balances are calculated correctly from ledger entries

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Balance Calculation Verification Script" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Database connection
$env:PGPASSWORD = "postgres"
$db = "ledgerdb"
$user = "postgres"

# SQL Query to compare stored balance vs calculated balance from ledger entries
$verificationQuery = @"
SELECT 
    a.id,
    a."userId",
    a."accountType",
    a.balance as stored_balance,
    COALESCE(
        (SELECT SUM(CASE WHEN entry_type = 'credit' THEN amount ELSE -amount END)
         FROM "LedgerEntry" 
         WHERE account_id = a.id),
        0
    ) as calculated_balance_from_ledger,
    CASE 
        WHEN a.balance = COALESCE(
            (SELECT SUM(CASE WHEN entry_type = 'credit' THEN amount ELSE -amount END)
             FROM "LedgerEntry" 
             WHERE account_id = a.id),
            0
        ) THEN '✓ MATCH'
        ELSE '✗ MISMATCH'
    END as status
FROM "Account" a
ORDER BY a."createdAt";
"@

Write-Host "Querying database to compare stored vs calculated balances...`n" -ForegroundColor Yellow

psql -U $user -h localhost -d $db -c $verificationQuery

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Ledger Entry Details" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$ledgerQuery = @"
SELECT 
    le.id,
    le.account_id,
    a."userId",
    le.entry_type,
    le.amount,
    le.currency,
    le.created_at,
    t.type as transaction_type
FROM "LedgerEntry" le
JOIN "Account" a ON le.account_id = a.id
JOIN "Transaction" t ON le.transaction_id = t.id
ORDER BY le.created_at;
"@

psql -U $user -h localhost -d $db -c $ledgerQuery

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Per-Account Ledger Summary" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$summaryQuery = @"
SELECT 
    a."userId",
    a."accountType",
    COUNT(le.id) as total_entries,
    SUM(CASE WHEN le.entry_type = 'credit' THEN le.amount ELSE 0 END) as total_credits,
    SUM(CASE WHEN le.entry_type = 'debit' THEN le.amount ELSE 0 END) as total_debits,
    SUM(CASE WHEN le.entry_type = 'credit' THEN le.amount ELSE -le.amount END) as net_balance
FROM "Account" a
LEFT JOIN "LedgerEntry" le ON a.id = le.account_id
GROUP BY a.id, a."userId", a."accountType"
ORDER BY a."userId";
"@

psql -U $user -h localhost -d $db -c $summaryQuery

Write-Host "`nVerification complete!" -ForegroundColor Green
