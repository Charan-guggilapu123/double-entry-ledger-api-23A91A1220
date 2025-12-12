# Quick Start Guide

## 🚀 Get Started in 5 Minutes

### Option 1: Using Docker (Recommended)

**No PostgreSQL installation needed!**

```bash
# 1. Start services (database + API)
docker-compose up -d

# 2. Run migrations
docker exec -it financial-ledger npm run prisma:migrate

# 3. API is ready at http://localhost:3000
```

**Verify it's working:**
```bash
curl -X POST http://localhost:3000/accounts \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test_user",
    "accountType": "checking",
    "currency": "USD"
  }'
```

**Clean up:**
```bash
docker-compose down -v  # -v removes the database volume
```

---

### Option 2: Local Development

**Prerequisites:**
- Node.js 16+
- PostgreSQL 12+ (must be running)

**Setup:**

```bash
# 1. Install dependencies
npm install

# 2. Create .env file
echo "DATABASE_URL=postgresql://postgres:password@localhost:5432/ledger" > .env
echo "NODE_ENV=development" >> .env
echo "PORT=3000" >> .env

# 3. Setup database
npm run prisma:generate
npm run prisma:migrate

# 4. Start server
npm run dev
```

API runs at `http://localhost:3000`

---

## 📋 Basic API Usage

### 1. Create an Account

```bash
curl -X POST http://localhost:3000/accounts \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "john_doe",
    "accountType": "checking",
    "currency": "USD"
  }'
```

Response:
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "userId": "john_doe",
  "accountType": "checking",
  "currency": "USD",
  "status": "active",
  "balance": "0.00000000"
}
```

**Save the account ID for next steps!**

### 2. Create Another Account (for transfers)

```bash
curl -X POST http://localhost:3000/accounts \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "jane_doe",
    "accountType": "savings",
    "currency": "USD"
  }'
```

### 3. Get Account Details

```bash
curl http://localhost:3000/accounts/123e4567-e89b-12d3-a456-426614174000
```

### 4. View Transaction History

```bash
curl http://localhost:3000/accounts/123e4567-e89b-12d3-a456-426614174000/ledger
```

### 5. Transfer Funds

```bash
# Note: Accounts must have sufficient balance
# For testing, manually add balance to source account via database

curl -X POST http://localhost:3000/transfers \
  -H "Content-Type: application/json" \
  -d '{
    "sourceAccountId": "SOURCE_ACCOUNT_ID",
    "destinationAccountId": "DEST_ACCOUNT_ID",
    "amount": "100.50",
    "currency": "USD"
  }'
```

Response:
```json
{
  "id": "tx-id-here",
  "type": "transfer",
  "sourceAccountId": "SOURCE_ACCOUNT_ID",
  "destinationAccountId": "DEST_ACCOUNT_ID",
  "amount": "100.50000000",
  "currency": "USD",
  "status": "completed",
  "createdAt": "2025-12-11T10:35:00.000Z"
}
```

---

## 🧪 Run Tests

```bash
# All tests
npm test

# Watch mode
npm test -- --watch

# With coverage
npm test -- --coverage
```

---

## 📚 API Documentation

Full documentation available in `README_API.md`:

- Detailed endpoint specs
- Error codes and handling
- Database schema
- Concurrency guarantees

---

## 🔧 Troubleshooting

### Docker Issues

```bash
# Check if services are running
docker-compose ps

# View logs
docker-compose logs app
docker-compose logs db

# Rebuild containers
docker-compose down
docker-compose up --build -d
```

### Database Connection Issues

```bash
# Test PostgreSQL connection
psql "postgresql://postgres:password@localhost:5432/ledger"

# Reset database (⚠️ deletes all data)
npm run prisma:migrate:reset
```

### Tests Failing

```bash
# Create test database
createdb ledger_test

# Create .env.test
echo "DATABASE_URL=postgresql://postgres:password@localhost:5432/ledger_test" > .env.test

# Run tests again
npm test
```

---

## 📖 Next Steps

1. **Explore the API**: Try all endpoints using curl or Postman
2. **Read the docs**: Check `README_API.md` for full API details
3. **Run tests**: `npm test` to see everything working
4. **Deploy**: See `DEPLOYMENT.md` for production setup

---

## 🆘 Common Issues

### "Connection refused"
PostgreSQL is not running. Start it:
```bash
# macOS
brew services start postgresql

# Linux
sudo systemctl start postgresql

# Docker (included in docker-compose)
docker-compose up -d db
```

### "Database already exists"
Drop and recreate:
```bash
dropdb ledger
createdb ledger
npm run prisma:migrate
```

### "Account not found"
Transfer failed? Check account IDs:
```bash
# View all accounts
psql $DATABASE_URL -c "SELECT id, userId, balance FROM \"Account\";"
```

### "Insufficient funds"
You need to add balance first. In a real system, use a deposit endpoint.
For testing with Docker:
```bash
docker-compose exec db psql -U postgres -d ledgerdb -c \
  "UPDATE \"Account\" SET balance = 1000 WHERE id = '...'"
```

---

## 📞 Support

- API Errors: Check status code and `error` field in response
- Database Issues: Check logs with `docker-compose logs`
- Code Issues: See `_tests_/` for example usage

**Happy transferring! 💰**
