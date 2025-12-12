# Financial Ledger REST API

A **production-ready REST API** for managing financial accounts and safe, concurrent fund transfers with complete ledger tracking.

## 🎯 Overview

This is a fully functional REST API that handles:

- **Account Creation**: Create and manage financial accounts
- **Account Retrieval**: Get account details and balance
- **Fund Transfers**: Safe, atomic transfers between accounts
- **Ledger Tracking**: Complete transaction history with debit/credit entries
- **Concurrent Operations**: Thread-safe with serializable isolation
- **Input Validation**: Comprehensive validation on all endpoints
- **Error Handling**: Proper HTTP status codes and error messages

## 🚀 Quick Start

### Option 1: Docker (Recommended)
```bash
docker-compose up -d
docker exec -it financial-ledger npm run prisma:migrate
# API ready at http://localhost:3000
```

### Option 2: Local Development
```bash
npm install
npm run prisma:generate
npm run prisma:migrate
npm run dev
```

For detailed instructions, see [QUICKSTART.md](QUICKSTART.md).

## 📋 API Endpoints

### Accounts

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/accounts` | Create a new account |
| GET | `/accounts/:id` | Get account details and balance |
| GET | `/accounts/:id/ledger` | Get transaction history |

### Transfers

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/transfers` | Execute a fund transfer |

## 📖 Full Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - Get started in 5 minutes
- **[README_API.md](README_API.md)** - Complete API reference
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Production deployment guide
- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - Technical overview

## 🔐 Security & Safety

✅ **ACID Compliant**: All-or-nothing transactions  
✅ **Concurrent Safe**: Row-level locking prevents race conditions  
✅ **Overdraft Prevention**: Balance verified after lock  
✅ **Input Validation**: All inputs validated  
✅ **SQL Injection Safe**: Uses Prisma ORM  
✅ **Serializable Isolation**: Prevents dirty reads/writes  

## 🧪 Testing

```bash
# Run all tests
npm test

# Run specific test
npm test -- src/_tests_/ledger.test.js

# Watch mode
npm test -- --watch

# Manual API testing
bash api-test.sh
```

## 📊 Example Usage

### Create Account
```bash
curl -X POST http://localhost:3000/accounts \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "john_doe",
    "accountType": "checking",
    "currency": "USD"
  }'
```

### Transfer Funds
```bash
curl -X POST http://localhost:3000/transfers \
  -H "Content-Type: application/json" \
  -d '{
    "sourceAccountId": "550e8400-e29b-41d4-a716-446655440000",
    "destinationAccountId": "550e8400-e29b-41d4-a716-446655440001",
    "amount": "100.50",
    "currency": "USD"
  }'
```

See [README_API.md](README_API.md) for full API documentation.

## 🛠️ Tech Stack

- **Framework**: Express.js
- **Database**: PostgreSQL with Prisma ORM
- **Precision**: Decimal.js for accurate financial calculations
- **Testing**: Jest + Supertest
- **Logging**: Pino
- **Containerization**: Docker & Docker Compose

## 📦 Project Structure

```
src/
├── app.js                 # Express app configuration
├── server.js              # Server startup
├── index.js               # Entry point
├── prismaClient.js        # Prisma client
├── errors.js              # Error classes
├── routes/
│   ├── accounts.js        # Account endpoints
│   └── flows.js           # Transfer endpoints
├── services/
│   └── ledgerService.js   # Business logic
└── _tests_/
    └── ledger.test.js     # Ledger tests

prisma/
├── schema.prisma          # Database schema
└── migrations/            # Database migrations

tests/
└── example.test.js        # Account tests

docker-compose.yml         # Full stack setup
Dockerfile                 # Container image
jest.config.js            # Jest configuration
```

## 🔄 Concurrency Handling

The API uses **serializable isolation** with **row-level locking**:

1. Locks are acquired in **deterministic order** (sorted IDs)
2. Accounts are locked **before balance check**
3. Transfer is **atomic** - all or nothing
4. Concurrent transfers are **safely serialized**

**Example**: If Account A has $100 and two concurrent $60 transfers are attempted:
- ✅ First transfer succeeds ($40 remaining)
- ❌ Second transfer fails with "insufficient funds"

## 🌐 Deployment

- **Docker**: `docker-compose up -d`
- **Azure App Service**: See [DEPLOYMENT.md](DEPLOYMENT.md)
- **AWS Lambda**: See [DEPLOYMENT.md](DEPLOYMENT.md)
- **Kubernetes**: See [DEPLOYMENT.md](DEPLOYMENT.md)

## 📋 Environment Setup

### Development (.env)
```env
DATABASE_URL=postgresql://postgres:password@localhost:5432/ledger
NODE_ENV=development
PORT=3000
```

### Testing (.env.test)
```env
DATABASE_URL=postgresql://postgres:password@localhost:5432/ledger_test
NODE_ENV=test
```

## 🚦 Health Check

```bash
# Test if API is running
curl http://localhost:3000/accounts

# View logs (Docker)
docker-compose logs -f app
```

## 🐛 Troubleshooting

### Connection Issues
```bash
# Test database connection
psql $DATABASE_URL -c "SELECT 1"

# Restart services
docker-compose restart db app
```

### Tests Failing
```bash
# Create test database
createdb ledger_test

# Run tests
npm test
```

### Migration Issues
```bash
# View migration status
npx prisma migrate status

# Reset database (⚠️ deletes all data)
npx prisma migrate reset
```

See [DEPLOYMENT.md](DEPLOYMENT.md) for more troubleshooting.

## ✨ Features

- ✅ RESTful API design
- ✅ Account management
- ✅ Safe fund transfers
- ✅ Ledger tracking
- ✅ Input validation
- ✅ Error handling
- ✅ Concurrent operation safety
- ✅ Decimal precision
- ✅ Docker containerization
- ✅ Comprehensive testing
- ✅ Complete documentation
- ✅ Deployment ready

## 📞 Support

For detailed API documentation, see [README_API.md](README_API.md)

For deployment instructions, see [DEPLOYMENT.md](DEPLOYMENT.md)

For quick setup, see [QUICKSTART.md](QUICKSTART.md)

## 📄 License

MIT

---

**Ready to deploy? Start with [QUICKSTART.md](QUICKSTART.md) 🚀**
