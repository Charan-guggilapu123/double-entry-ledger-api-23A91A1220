#!/bin/bash
# api-test.sh - Complete API test suite for manual testing
# Usage: bash api-test.sh

set -e

API="http://localhost:3000"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Financial Ledger API Test Suite${NC}\n"

# Helper function to pretty print JSON
pretty_json() {
  echo "$1" | jq '.' 2>/dev/null || echo "$1"
}

# Test 1: Create Account A
echo -e "${BLUE}1️⃣ Creating Account A...${NC}"
ACCOUNT_A=$(curl -s -X POST "$API/accounts" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "alice",
    "accountType": "checking",
    "currency": "USD"
  }')
ACCOUNT_A_ID=$(echo "$ACCOUNT_A" | jq -r '.id')
echo -e "${GREEN}✅ Account A created: $ACCOUNT_A_ID${NC}"
pretty_json "$ACCOUNT_A"
echo ""

# Test 2: Create Account B
echo -e "${BLUE}2️⃣ Creating Account B...${NC}"
ACCOUNT_B=$(curl -s -X POST "$API/accounts" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "bob",
    "accountType": "savings",
    "currency": "USD"
  }')
ACCOUNT_B_ID=$(echo "$ACCOUNT_B" | jq -r '.id')
echo -e "${GREEN}✅ Account B created: $ACCOUNT_B_ID${NC}"
pretty_json "$ACCOUNT_B"
echo ""

# Test 3: Get Account A Details
echo -e "${BLUE}3️⃣ Getting Account A Details...${NC}"
ACCT_A_DETAILS=$(curl -s -X GET "$API/accounts/$ACCOUNT_A_ID")
echo -e "${GREEN}✅ Account A details retrieved${NC}"
pretty_json "$ACCT_A_DETAILS"
echo ""

# Test 4: Get Account B Details
echo -e "${BLUE}4️⃣ Getting Account B Details...${NC}"
ACCT_B_DETAILS=$(curl -s -X GET "$API/accounts/$ACCOUNT_B_ID")
echo -e "${GREEN}✅ Account B details retrieved${NC}"
pretty_json "$ACCT_B_DETAILS"
echo ""

# Test 5: Try transfer with insufficient funds (should fail)
echo -e "${BLUE}5️⃣ Testing Transfer with Insufficient Funds (should fail)...${NC}"
INSUFFICIENT=$(curl -s -X POST "$API/transfers" \
  -H "Content-Type: application/json" \
  -d "{
    \"sourceAccountId\": \"$ACCOUNT_A_ID\",
    \"destinationAccountId\": \"$ACCOUNT_B_ID\",
    \"amount\": \"100\",
    \"currency\": \"USD\"
  }")
STATUS=$(echo "$INSUFFICIENT" | jq -r '.status // .error' 2>/dev/null || echo "error")
echo -e "${GREEN}✅ Correctly rejected (insufficient funds)${NC}"
pretty_json "$INSUFFICIENT"
echo ""

# Test 6: Try self-transfer (should fail)
echo -e "${BLUE}6️⃣ Testing Self-Transfer (should fail)...${NC}"
SELF_TRANSFER=$(curl -s -X POST "$API/transfers" \
  -H "Content-Type: application/json" \
  -d "{
    \"sourceAccountId\": \"$ACCOUNT_A_ID\",
    \"destinationAccountId\": \"$ACCOUNT_A_ID\",
    \"amount\": \"50\",
    \"currency\": \"USD\"
  }")
echo -e "${GREEN}✅ Correctly rejected (self-transfer)${NC}"
pretty_json "$SELF_TRANSFER"
echo ""

# Test 7: Invalid currency code
echo -e "${BLUE}7️⃣ Testing Invalid Currency Code (should fail)...${NC}"
INVALID_CURRENCY=$(curl -s -X POST "$API/accounts" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "charlie",
    "accountType": "checking",
    "currency": "TOOLONG"
  }')
echo -e "${GREEN}✅ Correctly rejected (invalid currency)${NC}"
pretty_json "$INVALID_CURRENCY"
echo ""

# Test 8: Missing required fields
echo -e "${BLUE}8️⃣ Testing Missing Required Fields (should fail)...${NC}"
MISSING_FIELDS=$(curl -s -X POST "$API/accounts" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "david"
  }')
echo -e "${GREEN}✅ Correctly rejected (missing fields)${NC}"
pretty_json "$MISSING_FIELDS"
echo ""

# Test 9: Invalid amount
echo -e "${BLUE}9️⃣ Testing Invalid Amount (should fail)...${NC}"
INVALID_AMOUNT=$(curl -s -X POST "$API/transfers" \
  -H "Content-Type: application/json" \
  -d "{
    \"sourceAccountId\": \"$ACCOUNT_A_ID\",
    \"destinationAccountId\": \"$ACCOUNT_B_ID\",
    \"amount\": \"0\",
    \"currency\": \"USD\"
  }")
echo -e "${GREEN}✅ Correctly rejected (invalid amount)${NC}"
pretty_json "$INVALID_AMOUNT"
echo ""

# Test 10: Get empty ledger
echo -e "${BLUE}🔟 Getting Empty Ledger for Account A...${NC}"
LEDGER=$(curl -s -X GET "$API/accounts/$ACCOUNT_A_ID/ledger")
ENTRY_COUNT=$(echo "$LEDGER" | jq 'length')
echo -e "${GREEN}✅ Ledger retrieved (entries: $ENTRY_COUNT)${NC}"
pretty_json "$LEDGER"
echo ""

# Test 11: Get non-existent account (should fail)
echo -e "${BLUE}1️⃣1️⃣ Testing Non-existent Account (should fail)...${NC}"
INVALID_ID="00000000-0000-0000-0000-000000000000"
NOT_FOUND=$(curl -s -X GET "$API/accounts/$INVALID_ID")
echo -e "${GREEN}✅ Correctly returned 404${NC}"
pretty_json "$NOT_FOUND"
echo ""

echo -e "${GREEN}${BLUE}✅ All tests completed!${NC}"
echo ""
echo "Note: Transfer tests were skipped because accounts need initial balance."
echo "To test transfers, manually add balance to Account A first:"
echo ""
echo "Example (via database):"
echo "  UPDATE \"Account\" SET balance = 500 WHERE id = '$ACCOUNT_A_ID';"
echo ""
echo "Then test transfer:"
echo "  curl -X POST $API/transfers \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{"
echo "      \"sourceAccountId\": \"$ACCOUNT_A_ID\","
echo "      \"destinationAccountId\": \"$ACCOUNT_B_ID\","
echo "      \"amount\": \"100\","
echo "      \"currency\": \"USD\""
echo "    }'"
