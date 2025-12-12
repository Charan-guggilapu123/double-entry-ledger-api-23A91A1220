#!/bin/bash
# Quick API Test Script - Creates accounts and transfers, then verifies balances

echo "=== Creating test accounts and transfers ==="

# Create Account A
echo -e "\n1. Creating Account A..."
ACCOUNT_A=$(curl -s -X POST http://localhost:3000/accounts \
  -H "Content-Type: application/json" \
  -d '{"userId":"testuser1","accountType":"checking","currency":"USD"}' | jq -r '.id')
echo "Account A ID: $ACCOUNT_A"

# Create Account B
echo -e "\n2. Creating Account B..."
ACCOUNT_B=$(curl -s -X POST http://localhost:3000/accounts \
  -H "Content-Type: application/json" \
  -d '{"userId":"testuser2","accountType":"savings","currency":"USD"}' | jq -r '.id')
echo "Account B ID: $ACCOUNT_B"

# Create initial deposit transaction directly in DB
echo -e "\n3. Creating initial deposit for Account A (100 USD)..."
PGPASSWORD=postgres psql -U postgres -h localhost -d ledgerdb -c "
BEGIN;
WITH new_tx AS (
  INSERT INTO \"Transaction\" (id, type, destination_account_id, amount, currency, status)
  VALUES (gen_random_uuid(), 'deposit', '$ACCOUNT_A', 100.00, 'USD', 'completed')
  RETURNING id
)
INSERT INTO \"LedgerEntry\" (id, account_id, transaction_id, entry_type, amount, currency)
SELECT gen_random_uuid(), '$ACCOUNT_A', id, 'credit', 100.00, 'USD'
FROM new_tx;
UPDATE \"Account\" SET balance = 100.00 WHERE id = '$ACCOUNT_A';
COMMIT;
"

# Transfer 1: 30 USD from A to B
echo -e "\n4. Transfer #1: 30 USD from A to B..."
curl -s -X POST http://localhost:3000/transfers \
  -H "Content-Type: application/json" \
  -d "{\"sourceAccountId\":\"$ACCOUNT_A\",\"destinationAccountId\":\"$ACCOUNT_B\",\"amount\":30,\"currency\":\"USD\"}" | jq '.'

# Transfer 2: 20 USD from A to B
echo -e "\n5. Transfer #2: 20 USD from A to B..."
curl -s -X POST http://localhost:3000/transfers \
  -H "Content-Type: application/json" \
  -d "{\"sourceAccountId\":\"$ACCOUNT_A\",\"destinationAccountId\":\"$ACCOUNT_B\",\"amount\":20,\"currency\":\"USD\"}" | jq '.'

# Get Account A details
echo -e "\n6. Account A Details (should show balance: 50)..."
curl -s http://localhost:3000/accounts/$ACCOUNT_A | jq '.'

# Get Account B details
echo -e "\n7. Account B Details (should show balance: 50)..."
curl -s http://localhost:3000/accounts/$ACCOUNT_B | jq '.'

# Get Account A ledger
echo -e "\n8. Account A Ledger Entries..."
curl -s "http://localhost:3000/accounts/$ACCOUNT_A/ledger" | jq '.'

# Get Account B ledger
echo -e "\n9. Account B Ledger Entries..."
curl -s "http://localhost:3000/accounts/$ACCOUNT_B/ledger" | jq '.'

echo -e "\n=== Test Complete ==="
echo "Expected results:"
echo "  Account A: 100 (initial) - 30 (transfer) - 20 (transfer) = 50"
echo "  Account B: 0 (initial) + 30 (transfer) + 20 (transfer) = 50"
