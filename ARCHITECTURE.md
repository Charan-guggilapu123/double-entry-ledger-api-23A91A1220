# System Architecture

## High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLIENT LAYER                             │
│                    (Postman / Frontend)                          │
└────────────┬────────────────────────────────────────────────────┘
             │
             │ HTTP REST Requests
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      EXPRESS.JS API LAYER                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Routes Layer (Validation & Marshalling)                 │   │
│  │ ├─ POST /accounts          (accounts.js)                │   │
│  │ ├─ GET /accounts/:id       (accounts.js)                │   │
│  │ ├─ GET /accounts/:id/ledger (accounts.js)               │   │
│  │ └─ POST /transfers         (flows.js)                   │   │
│  └──────────────┬───────────────────────────────────────────┘   │
│                 │                                                │
│  ┌──────────────▼───────────────────────────────────────────┐   │
│  │ Services Layer (Business Logic)                         │   │
│  │ └─ ledgerService.js                                     │   │
│  │    ├─ createAccount(userId, type, currency)            │   │
│  │    ├─ getAccount(accountId)                             │   │
│  │    ├─ getBalance(accountId)                             │   │
│  │    ├─ getLedgerHistory(accountId, limit, offset)        │   │
│  │    └─ transfer(source, dest, amount, currency)          │   │
│  └──────────────┬───────────────────────────────────────────┘   │
│                 │                                                │
└─────────────────┼────────────────────────────────────────────────┘
                  │
                  │ Prisma ORM
                  │ • Transaction management
                  │ • Row-level locking
                  │ • Serializable isolation
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                  POSTGRESQL DATABASE LAYER                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Accounts Table                                           │   │
│  │  ├─ id (UUID, Primary Key)                              │   │
│  │  ├─ userId (String)                                     │   │
│  │  ├─ accountType (ENUM: checking/savings)                │   │
│  │  ├─ currency (String, 3 letters)                        │   │
│  │  └─ createdAt (Timestamp)                               │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ LedgerEntries Table (Immutable)                          │   │
│  │  ├─ id (UUID, Primary Key)                              │   │
│  │  ├─ accountId (Foreign Key → Accounts)                  │   │
│  │  ├─ amount (DECIMAL(20,8))                              │   │
│  │  ├─ type (debit/credit)                                 │   │
│  │  ├─ description (String)                                │   │
│  │  └─ createdAt (Timestamp)                               │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Transactions Table (Track transfer operations)           │   │
│  │  ├─ id (UUID, Primary Key)                              │   │
│  │  ├─ sourceAccountId (Foreign Key → Accounts)            │   │
│  │  ├─ destinationAccountId (Foreign Key → Accounts)       │   │
│  │  ├─ amount (DECIMAL(20,8))                              │   │
│  │  ├─ type (transfer/deposit/withdrawal)                  │   │
│  │  └─ createdAt (Timestamp)                               │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Request Flow Diagram

### Create Account Flow
```
POST /accounts
    │
    ├─ Validate input (userId, accountType, currency)
    │
    ├─ ledgerService.createAccount()
    │
    ├─ prisma.account.create()
    │   └─ INSERT INTO accounts (id, userId, accountType, currency)
    │
    └─ Return: { id, userId, accountType, currency, balance: 0, createdAt }
```

### Transfer Flow (Critical Path with Atomicity)
```
POST /transfers
    │
    ├─ Validate inputs (sourceId, destinationId, amount, currency)
    │   ├─ amount > 0
    │   ├─ sourceId ≠ destinationId
    │   └─ currency is 3 letters
    │
    ├─ ledgerService.transfer() starts TRANSACTION
    │   │
    │   ├─ Lock source account:
    │   │   SELECT * FROM accounts WHERE id = sourceId FOR UPDATE
    │   │
    │   ├─ Lock destination account:
    │   │   SELECT * FROM accounts WHERE id = destinationId FOR UPDATE
    │   │
    │   ├─ Calculate source balance:
    │   │   SELECT SUM(amount * type_multiplier) FROM ledger_entries
    │   │   WHERE accountId = sourceId
    │   │
    │   ├─ Validate sufficient funds:
    │   │   if (balance < amount) → ROLLBACK & throw error
    │   │
    │   ├─ Create debit entry (source account):
    │   │   INSERT INTO ledger_entries (accountId, amount, type, description)
    │   │   VALUES (sourceId, amount, 'debit', 'Transfer to X')
    │   │
    │   ├─ Create credit entry (destination account):
    │   │   INSERT INTO ledger_entries (accountId, amount, type, description)
    │   │   VALUES (destinationId, amount, 'credit', 'Transfer from Y')
    │   │
    │   ├─ Record transaction metadata:
    │   │   INSERT INTO transactions (sourceAccountId, destinationAccountId, ...)
    │   │
    │   └─ COMMIT all changes (atomically)
    │
    └─ Return: { sourceBalance, destinationBalance, transactionId }
    
    On Exception → ROLLBACK entire transaction
                → No ledger entries created
                → No transaction recorded
```

### Get Balance Flow
```
GET /accounts/:id/balance
    │
    ├─ ledgerService.getBalance(accountId)
    │
    ├─ Query ledger entries:
    │   SELECT amount, type FROM ledger_entries 
    │   WHERE accountId = ? 
    │   ORDER BY createdAt
    │
    ├─ Calculate balance:
    │   balance = 0
    │   for each entry:
    │     if (entry.type == 'credit') balance += entry.amount
    │     if (entry.type == 'debit')  balance -= entry.amount
    │
    └─ Return: { accountId, balance, currency }
```

### Get Ledger History Flow
```
GET /accounts/:id/ledger?limit=20&offset=0
    │
    ├─ Validate pagination params
    │
    ├─ Query ledger entries:
    │   SELECT * FROM ledger_entries 
    │   WHERE accountId = ? 
    │   ORDER BY createdAt DESC
    │   LIMIT 20 OFFSET 0
    │
    ├─ Get total count:
    │   SELECT COUNT(*) FROM ledger_entries WHERE accountId = ?
    │
    └─ Return: { entries: [...], total: N, limit: 20, offset: 0 }
```

## Concurrency Control Strategy

### Problem: Race Conditions in Financial Systems
Without proper locking, two concurrent transfers could both read the same balance and allow both even if insufficient funds.

### Solution: Multi-Layer Protection

```
Layer 1: Database Isolation
  ├─ Serializable Isolation Level
  │   └─ Prevents dirty reads, non-repeatable reads, phantom reads
  │   └─ Most restrictive, highest safety
  │
  └─ Pessimistic Locking
      ├─ SELECT...FOR UPDATE on account rows
      ├─ Locks account for duration of transaction
      ├─ Prevents concurrent modifications
      └─ Deterministic lock ordering (sourceId < destId) prevents deadlocks

Layer 2: Application Validation
  ├─ Balance check inside transaction (not before)
  ├─ If insufficient, throw exception
  └─ Transaction auto-rollback

Layer 3: Database Constraints
  └─ NOT NULL constraints
  └─ Foreign key constraints
  └─ Check constraints on amounts
```

### Example: Two Concurrent $50 Transfers from Account with $50

```
Timeline:

[Time 1] Transaction A starts
         ├─ SELECT * FROM accounts WHERE id = account1 FOR UPDATE
         └─ Lock acquired

[Time 1] Transaction B starts
         ├─ SELECT * FROM accounts WHERE id = account1 FOR UPDATE
         └─ BLOCKED (waiting for A's lock)

[Time 2] Transaction A calculates balance = $50
         ├─ Checks: $50 >= $50 ✓ OK
         ├─ Creates debit entry (A → account2): -$50
         ├─ Creates credit entry (account2): +$50
         └─ COMMIT (releases lock)

[Time 3] Transaction B acquires lock
         ├─ Recalculates balance = $0 (now after A's debit)
         ├─ Checks: $0 >= $50 ✗ FAIL
         ├─ ROLLBACK (no entries created)
         └─ Returns 422 error

Result: Only Transaction A succeeds
        Account balance: $0
        No overspend possible
```

## Technology Choices & Rationale

| Component | Technology | Why This Choice |
|-----------|-----------|-----------------|
| Runtime | Node.js v20 | Non-blocking I/O, JavaScript ecosystem, good package management |
| Framework | Express.js | Minimal, widely used, industry standard for REST APIs |
| Database | PostgreSQL | ACID compliant, Serializable isolation, DECIMAL type, mature, trusted for finance |
| ORM | Prisma | Type-safe, excellent transaction support, auto-migrations, clean API |
| Precision | Decimal.js | No floating-point rounding errors, financial standard, high precision (20 digits) |
| Testing | Jest + Supertest | Industry standard, fast, good assertion library, integration test support |
| Isolation | Serializable | Highest isolation level, prevents all race conditions, essential for finance |
| Locking | Row-level | Fine-grained concurrency, deterministic ordering prevents deadlocks |

## Error Handling Architecture

```
HTTP Request
    │
    ├─ Input Validation (Route Layer)
    │   ├─ Bad format → 400 Bad Request
    │   └─ Invalid JSON → 400
    │
    ├─ Business Logic Validation (Service Layer)
    │   ├─ Insufficient funds → 422 Unprocessable Entity
    │   ├─ Source = Destination → 422
    │   ├─ Amount <= 0 → 422
    │   └─ Invalid currency → 422
    │
    ├─ Data Access (Prisma Layer)
    │   ├─ Account not found → 404 Not Found
    │   ├─ Database constraint violation → 500 Internal Server Error
    │   └─ Connection error → 500
    │
    └─ Transaction Management
        ├─ Exception in transaction
        ├─ Auto ROLLBACK
        └─ All or nothing guarantee
```

## Data Consistency Guarantees

### Atomicity: All or Nothing
- Entire transfer (both ledger entries) succeeds or fails as unit
- Never partial completion
- Exception during transfer → complete rollback

### Consistency: Balance Integrity
- Balance calculation = SUM of ledger entries
- Never negative balance
- Every transfer creates matching debit/credit pair

### Isolation: No Race Conditions
- Concurrent transfers don't interfere
- Each sees consistent view of database
- Row locks + Serializable = mutual exclusion

### Durability: Persistent Storage
- PostgreSQL writes to disk
- Transaction committed = permanent
- Server crash doesn't lose data

## Performance Considerations

### Row-Level Locking Trade-off
**Pro:** Safe concurrent access, prevents race conditions
**Con:** Concurrent transfers to same account serialize (one at a time)
**Rationale:** Financial correctness > throughput

### Calculated Balance vs. Stored Balance
**Pro:** Single source of truth (ledger), no sync issues, immutable entries
**Con:** Must sum all ledger entries for each balance query
**Rationale:** Correctness critical, balance queries << transfer operations

### Pagination on Ledger History
**Pro:** Prevents loading entire history, memory efficient, scalable
**Con:** Requires offset calculation, slightly more complex
**Rationale:** Account with 100,000 transactions shouldn't load all at once

## Scaling Considerations (Future)

### Current Architecture Limitations
- Single PostgreSQL instance (no horizontal scaling)
- Row locks serialize concurrent transfers to same account
- Balance calculation sums all ledger entries

### Potential Improvements
- Read replicas for balance queries (eventual consistency acceptable for reports)
- Materialized ledger balance view (cached, updated after each transfer)
- Ledger sharding by account ID (if single database too slow)
- Connection pooling (Prisma already handles this)

## Security Considerations

### Input Validation
- userId length limits
- Currency must be 3 letters (ISO 4217)
- Amount must be positive, reasonable size
- Account IDs must be valid UUIDs

### SQL Injection Prevention
- Prisma uses parameterized queries
- No string concatenation for SQL
- Type-safe database access

### Authorization (Not Implemented - Beyond Scope)
- Current: No authentication
- Production: Would need JWT/OAuth
- Ledger endpoints: Should be audit-logged
- Account creation: Should require authorization

### Audit Trail
- All operations timestamped (createdAt)
- Transaction table tracks all transfers
- Ledger entries immutable (no deletion allowed)

---

## Summary

**Architecture Type:** Layered (Routes → Services → Persistence)
**Concurrency Model:** Pessimistic locking with Serializable isolation
**Data Consistency Model:** Double-entry bookkeeping with calculated balances
**Transaction Scope:** Entire transfer operation (both ledger entries) wrapped in single transaction
**Error Strategy:** Fail-fast with automatic rollback on any error

This architecture prioritizes **correctness and consistency** over performance, which is appropriate for financial systems where losing or duplicating transactions is unacceptable.
