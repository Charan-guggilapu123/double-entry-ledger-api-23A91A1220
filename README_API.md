# Financial Ledger REST API

A fully functional REST API for managing financial accounts and transfers with support for concurrent operations, transaction safety, and detailed ledger tracking.

## Features

✅ **Account Management**
- Create accounts with user ID, account type, and currency
- Retrieve account details and current balance
- View complete ledger entries for an account

✅ **Financial Transfers**
- Safe, concurrent-proof transfers between accounts
- Atomic transaction processing with row-level locking
- Serializable isolation level to prevent race conditions

✅ **Ledger Tracking**
- Automatic debit/credit entry creation
- Complete transaction history per account
- Decimal precision for financial amounts

✅ **Input Validation**
- Required field validation
- Currency code validation (3-letter codes)
- Amount validation (must be positive)
- Prevents self-transfers

✅ **Error Handling**
- Centralized error handling
- Descriptive HTTP status codes
- Validation error messages

## Tech Stack

- **Framework**: Express.js
- **Database**: PostgreSQL with Prisma ORM
- **Precision**: Decimal.js for accurate financial calculations
- **Testing**: Jest with Supertest
- **Logging**: Pino

## Prerequisites

- Node.js 16+
- PostgreSQL 12+
- npm or yarn

## Installation

```bash
# Install dependencies
npm install

# Generate Prisma client
npm run prisma:generate

# Set up environment variables (see .env example)
cp .env.example .env

# Run database migrations
npm run prisma:migrate
```

## Environment Setup

Create a `.env` file in the project root:

```
DATABASE_URL=postgresql://postgres:password@localhost:5432/ledger
NODE_ENV=development
PORT=3000
```

For testing, create a `.env.test` file:

```
DATABASE_URL=postgresql://postgres:password@localhost:5432/ledger_test
NODE_ENV=test
```

## Running the API

### Development
```bash
npm run dev
```
Server runs on `http://localhost:3000` with auto-reload.

### Production
```bash
npm start
```

## API Endpoints

### Create Account
**POST** `/accounts`

Request body:
```json
{
  "userId": "user123",
  "accountType": "checking",
  "currency": "USD"
}
```

Response (201):
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "userId": "user123",
  "accountType": "checking",
  "currency": "USD",
  "status": "active",
  "balance": "0.00000000"
}
```

### Get Account Details
**GET** `/accounts/:id`

Response (200):
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "userId": "user123",
  "accountType": "checking",
  "currency": "USD",
  "status": "active",
  "balance": "1500.50000000"
}
```

### Get Account Ledger
**GET** `/accounts/:id/ledger`

Response (200):
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "accountId": "550e8400-e29b-41d4-a716-446655440000",
    "transactionId": "550e8400-e29b-41d4-a716-446655440002",
    "entryType": "credit",
    "amount": "500.00000000",
    "currency": "USD",
    "createdAt": "2025-12-11T10:30:00.000Z"
  }
]
```

### Transfer Funds
**POST** `/transfers`

Request body:
```json
{
  "sourceAccountId": "550e8400-e29b-41d4-a716-446655440000",
  "destinationAccountId": "550e8400-e29b-41d4-a716-446655440003",
  "amount": "100.50",
  "currency": "USD"
}
```

Response (201):
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440002",
  "type": "transfer",
  "sourceAccountId": "550e8400-e29b-41d4-a716-446655440000",
  "destinationAccountId": "550e8400-e29b-41d4-a716-446655440003",
  "amount": "100.50000000",
  "currency": "USD",
  "status": "completed",
  "createdAt": "2025-12-11T10:35:00.000Z"
}
```

## Error Responses

### 400 - Bad Request
Missing required fields or invalid input:
```json
{
  "error": "userId, accountType, currency required"
}
```

### 404 - Not Found
Account does not exist:
```json
{
  "error": "Account not found"
}
```

### 422 - Unprocessable Entity
Business logic errors (insufficient funds, account not found):
```json
{
  "error": "insufficient funds"
}
```

### 500 - Internal Server Error
```json
{
  "error": "Internal error"
}
```

## Testing

```bash
# Run all tests
npm test

# Run specific test file
npm test -- src/_tests_/ledger.test.js

# Run with coverage
npm test -- --coverage
```

Test files:
- `tests/example.test.js` - Account creation and retrieval tests
- `src/_tests_/ledger.test.js` - Transfer and ledger tests

## Database Schema

### Account
- `id` (UUID): Primary key
- `userId` (String): User identifier
- `accountType` (String): Type of account (checking, savings, etc.)
- `currency` (String): 3-letter currency code (USD, EUR, GBP, etc.)
- `balance` (Decimal): Current account balance
- `status` (String): active/inactive
- `createdAt` (DateTime): Creation timestamp

### Transaction
- `id` (UUID): Primary key
- `type` (String): transfer, deposit, withdrawal, etc.
- `sourceAccountId` (UUID): Source account
- `destinationAccountId` (UUID): Destination account
- `amount` (Decimal): Transaction amount
- `currency` (String): Currency code
- `status` (String): pending/completed/failed
- `createdAt` (DateTime): Timestamp

### LedgerEntry
- `id` (UUID): Primary key
- `accountId` (UUID): Associated account
- `transactionId` (UUID): Associated transaction
- `entryType` (String): debit/credit
- `amount` (Decimal): Entry amount
- `currency` (String): Currency code
- `createdAt` (DateTime): Timestamp

## Concurrency & Safety

The API uses **Serializable isolation level** with **row-level locking** to ensure:

1. **No Race Conditions**: Accounts are locked in deterministic order (sorted IDs)
2. **ACID Compliance**: All-or-nothing transfer execution
3. **Overdraft Prevention**: Balance checked after lock acquisition
4. **Concurrent Safety**: Multiple simultaneous transfers are safely serialized

### Example Concurrency Scenario
```
Account A has $100
Two concurrent $60 transfers from A

Result: First transfer succeeds ($40 remaining)
        Second transfer fails with "insufficient funds"
        (Not both executing, leaving negative balance)
```

## Contributing

Please ensure all tests pass before submitting pull requests:

```bash
npm test
```

## License

MIT
