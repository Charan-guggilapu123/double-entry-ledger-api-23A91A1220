@echo off
REM Balance Calculation Verification Command
REM Run this batch file to verify that balances are calculated from ledger entries

set PGPASSWORD=postgres

echo.
echo ========================================
echo Balance Calculation Verification
echo ========================================
echo.

echo Running query to compare stored vs calculated balances...
echo.

psql -U postgres -h localhost -d ledgerdb -c "SELECT a.\"userId\", a.balance::numeric as stored_balance, COALESCE(SUM(CASE WHEN entry_type = 'credit' THEN amount ELSE -amount END), 0)::numeric as calculated_balance, CASE WHEN a.balance = COALESCE(SUM(CASE WHEN entry_type = 'credit' THEN amount ELSE -amount END), 0) THEN 'MATCH' ELSE 'DIFFERENT' END as status FROM \"Account\" a LEFT JOIN \"LedgerEntry\" le ON a.id = le.account_id GROUP BY a.id, a.balance ORDER BY a.\"userId\";"

echo.
echo ========================================
echo If status shows "MATCH" for all rows:
echo ^- Balances ARE calculated from ledger entries
echo ^- Stored balance = Sum of ledger entries
echo ^- Double-entry bookkeeping is working
echo ========================================
