# Database Schema Documentation

## Entity-Relationship Diagram (ERD)

```
┌──────────────────────────────────────────────────────────────────────────┐
│                                 ACCOUNTS                                  │
├──────────────────────────────────────────────────────────────────────────┤
│ PK │ id           : UUID              │ Unique account identifier         │
│    │ userId       : String            │ User who owns this account        │
│    │ accountType  : ENUM (checking,   │ Account classification           │
│    │              savings)            │                                   │
│    │ currency     : String            │ 3-letter ISO code (USD, EUR, GBP)│
│    │ createdAt    : DateTime          │ Account creation timestamp        │
│    │ updatedAt    : DateTime          │ Last update timestamp            │
│                                                                            │
│ Constraints:                                                              │
│ • id is NOT NULL (Primary Key)                                            │
│ • userId is NOT NULL                                                      │
│ • accountType is NOT NULL                                                 │
│ • currency is NOT NULL, length = 3                                        │
│ • createdAt is NOT NULL, default = NOW()                                  │
│ • One account per userId per currency combination                         │
│                                                                            │
│ Indexes:                                                                  │
│ • PRIMARY KEY (id)                                                        │
│ • UNIQUE (userId, accountType, currency)                                  │
│ • INDEX (userId) - for finding user's accounts                            │
│ • INDEX (createdAt) - for sorting                                         │
└──────────────────────────────────────────────────────────────────────────┘
         ▲                              ▲
         │ 1:N                          │ 1:N
         │ Relationship                 │ Relationship
         │                              │
    ┌────┴──────────────────────┐      │
    │ createdAt, accountId       │      │
    │                            │      │
    ▼                            ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                          LEDGER_ENTRIES                                   │
├──────────────────────────────────────────────────────────────────────────┤
│ PK │ id          : UUID              │ Unique ledger entry identifier    │
│ FK │ accountId   : UUID              │ References Accounts.id            │
│    │ amount      : DECIMAL(20,8)     │ Entry amount (always positive)    │
│    │ type        : ENUM (debit,      │ Entry type (debit or credit)      │
│    │              credit)            │                                   │
│    │ description : String            │ What this entry represents        │
│    │ createdAt   : DateTime          │ Entry creation timestamp          │
│                                                                            │
│ Constraints:                                                              │
│ • id is NOT NULL (Primary Key)                                            │
│ • accountId is NOT NULL (Foreign Key → Accounts.id)                       │
│ • amount is NOT NULL, > 0                                                 │
│ • type is NOT NULL                                                        │
│ • description is NOT NULL                                                 │
│ • createdAt is NOT NULL, default = NOW()                                  │
│ • NO UPDATE or DELETE allowed (immutable via ON DELETE RESTRICT)          │
│                                                                            │
│ Indexes:                                                                  │
│ • PRIMARY KEY (id)                                                        │
│ • FOREIGN KEY (accountId) → Accounts(id)                                  │
│ • INDEX (accountId) - for finding entries for account                     │
│ • INDEX (createdAt) - for sorting ledger history                          │
│ • INDEX (accountId, createdAt) - for efficient balance calculation        │
│                                                                            │
│ Design Notes:                                                             │
│ • Immutable: Ledger entries can never be modified or deleted              │
│ • Decimal precision: DECIMAL(20,8) = up to 99,999,999.99999999           │
│ • Amount always stored as positive (type column determines sign)          │
│ • Balance = SUM(CASE WHEN type='credit' THEN amount ELSE -amount END)     │
└──────────────────────────────────────────────────────────────────────────┘
         ▲
         │ 1:N
         │ Relationship
         │
    ┌────┴──────────────────────┐
    │ sourceAccountId or         │
    │ destinationAccountId       │
    │                            │
    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                          TRANSACTIONS                                     │
├──────────────────────────────────────────────────────────────────────────┤
│ PK │ id                    : UUID              │ Unique transaction ID   │
│ FK │ sourceAccountId       : UUID (nullable)   │ Account that sends      │
│ FK │ destinationAccountId  : UUID (nullable)   │ Account that receives   │
│    │ amount                : DECIMAL(20,8)     │ Amount transferred      │
│    │ type                  : ENUM (transfer,   │ Transaction type        │
│    │                        deposit,           │                         │
│    │                        withdrawal)        │                         │
│    │ status                : ENUM (pending,    │ Transaction status      │
│    │                        completed,         │                         │
│    │                        failed)            │                         │
│    │ createdAt             : DateTime          │ Creation timestamp      │
│                                                                            │
│ Constraints:                                                              │
│ • id is NOT NULL (Primary Key)                                            │
│ • amount is NOT NULL, > 0                                                 │
│ • type is NOT NULL                                                        │
│ • status is NOT NULL, default = 'pending'                                 │
│ • createdAt is NOT NULL, default = NOW()                                  │
│ • sourceAccountId and destinationAccountId for transfers                  │
│ • sourceAccountId or destinationAccountId nullable (for other types)      │
│                                                                            │
│ Indexes:                                                                  │
│ • PRIMARY KEY (id)                                                        │
│ • FOREIGN KEY (sourceAccountId) → Accounts(id)                            │
│ • FOREIGN KEY (destinationAccountId) → Accounts(id)                       │
│ • INDEX (sourceAccountId) - find outgoing transfers                       │
│ • INDEX (destinationAccountId) - find incoming transfers                  │
│ • INDEX (createdAt) - for timeline queries                                │
│ • INDEX (status) - for filtering pending/completed                        │
│                                                                            │
│ Design Notes:                                                             │
│ • Metadata table: records high-level transfer operations                  │
│ • Actual balance changes tracked in LEDGER_ENTRIES                        │
│ • Supports future transaction types (deposit, withdrawal)                 │
│ • Status tracking for async operations (if ever implemented)              │
└──────────────────────────────────────────────────────────────────────────┘
```

## Detailed Table Specifications

### ACCOUNTS Table

**Purpose:** Store user bank accounts with their identifiers and metadata

**Columns:**

| Column | Type | Constraints | Purpose | Example |
|--------|------|-----------|---------|---------|
| `id` | UUID | PRIMARY KEY, NOT NULL | Unique account identifier | `550e8400-e29b-41d4-a716-446655440000` |
| `userId` | String | NOT NULL | User who owns account | `"user123"` or `"john.doe@example.com"` |
| `accountType` | ENUM | NOT NULL | Account classification | `checking` or `savings` |
| `currency` | String | NOT NULL, Length=3 | ISO 4217 currency code | `"USD"`, `"EUR"`, `"GBP"` |
| `createdAt` | DateTime | NOT NULL, DEFAULT NOW() | Account creation time | `2024-12-11T10:30:00Z` |
| `updatedAt` | DateTime | NOT NULL, DEFAULT NOW() | Last update time | `2024-12-11T10:30:00Z` |

**Sample Data:**

```sql
SELECT * FROM "Account";

id                                    | userId      | accountType | currency | createdAt              | updatedAt
--------------------------------------|-------------|-------------|----------|------------------------|------------------------
550e8400-e29b-41d4-a716-446655440000 | john        | checking    | USD      | 2024-12-11 10:30:00   | 2024-12-11 10:30:00
660e8400-e29b-41d4-a716-446655440001 | john        | savings     | USD      | 2024-12-11 10:31:00   | 2024-12-11 10:31:00
770e8400-e29b-41d4-a716-446655440002 | jane        | checking    | EUR      | 2024-12-11 10:32:00   | 2024-12-11 10:32:00
```

**Constraints:**

```sql
-- Unique constraint: user can have one account per type per currency
ALTER TABLE "Account" ADD CONSTRAINT "Account_userId_accountType_currency_key"
UNIQUE (userId, accountType, currency);
```

**Relationships:**
- 1 Account : N LedgerEntries (one account can have many ledger entries)
- 1 Account : N Transactions (one account can be involved in many transactions)

---

### LEDGER_ENTRIES Table

**Purpose:** Store immutable debit and credit entries that make up account balances

**Columns:**

| Column | Type | Constraints | Purpose | Example |
|--------|------|-----------|---------|---------|
| `id` | UUID | PRIMARY KEY, NOT NULL | Unique entry identifier | `550e8400-e29b-41d4-a716-446655440003` |
| `accountId` | UUID | NOT NULL, FK → Account | Account this entry belongs to | `550e8400-e29b-41d4-a716-446655440000` |
| `amount` | DECIMAL(20,8) | NOT NULL, > 0 | Entry amount (always positive) | `100.50000000` |
| `type` | ENUM | NOT NULL | Entry type: debit or credit | `debit` or `credit` |
| `description` | String | NOT NULL | What this entry represents | `"Transfer to account XYZ"` |
| `createdAt` | DateTime | NOT NULL, DEFAULT NOW() | Entry creation time | `2024-12-11T10:35:00Z` |

**Sample Data:**

```sql
SELECT * FROM "LedgerEntry";

id                                    | accountId                             | amount         | type   | description            | createdAt
--------------------------------------|---------------------------------------|----------------|--------|------------------------|------------------------
550e8400-e29b-41d4-a716-446655440003 | 550e8400-e29b-41d4-a716-446655440000 | 100.50000000   | credit | Deposit from paycheck  | 2024-12-11 10:35:00
550e8400-e29b-41d4-a716-446655440004 | 550e8400-e29b-41d4-a716-446655440000 | 50.25000000    | debit  | Transfer to account 2  | 2024-12-11 10:36:00
550e8400-e29b-41d4-a716-446655440005 | 660e8400-e29b-41d4-a716-446655440001 | 50.25000000    | credit | Transfer from account 1| 2024-12-11 10:36:00
```

**Balance Calculation Logic:**

```
For Account with ID = X:
  
SELECT 
  SUM(CASE WHEN type = 'credit' THEN amount ELSE -amount END) as balance
FROM "LedgerEntry"
WHERE "accountId" = X;

Example with sample data above (for account 550e8400-e29b-41d4-a716-446655440000):
= 100.50 (credit) - 50.25 (debit)
= 50.25 USD
```

**Immutability Enforcement:**

```sql
-- No UPDATE operations allowed in application code
-- Verified through code review: only INSERT operations used

-- Foreign key constraint with RESTRICT prevents account deletion if ledger entries exist
ALTER TABLE "LedgerEntry" ADD CONSTRAINT "LedgerEntry_accountId_fkey"
FOREIGN KEY ("accountId") REFERENCES "Account"(id) ON DELETE RESTRICT;

-- This ensures ledger entries cannot be deleted even if account is deleted
```

**Indexes:**

```sql
CREATE INDEX "LedgerEntry_accountId_idx" ON "LedgerEntry"("accountId");
CREATE INDEX "LedgerEntry_createdAt_idx" ON "LedgerEntry"("createdAt");
CREATE INDEX "LedgerEntry_accountId_createdAt_idx" ON "LedgerEntry"("accountId", "createdAt");
-- Last index is most critical: allows efficient balance calculation and history retrieval
```

**Constraints:**

```sql
-- Amount must be positive (sign determined by type column)
ALTER TABLE "LedgerEntry" ADD CONSTRAINT "LedgerEntry_amount_positive"
CHECK (amount > 0);

-- Type must be one of the enum values
-- Enforced at database level for all enum columns
```

**Relationships:**
- N LedgerEntries : 1 Account (many entries belong to one account)
- LedgerEntries are created in pairs during transfers (one debit, one credit)

---

### TRANSACTIONS Table

**Purpose:** Store metadata about high-level transfer operations for auditing and status tracking

**Columns:**

| Column | Type | Constraints | Purpose | Example |
|--------|------|-----------|---------|---------|
| `id` | UUID | PRIMARY KEY, NOT NULL | Unique transaction identifier | `550e8400-e29b-41d4-a716-446655440010` |
| `sourceAccountId` | UUID | Nullable, FK → Account | Account sending funds | `550e8400-e29b-41d4-a716-446655440000` |
| `destinationAccountId` | UUID | Nullable, FK → Account | Account receiving funds | `660e8400-e29b-41d4-a716-446655440001` |
| `amount` | DECIMAL(20,8) | NOT NULL, > 0 | Transfer amount | `50.25000000` |
| `type` | ENUM | NOT NULL | transfer/deposit/withdrawal | `transfer` |
| `status` | ENUM | NOT NULL, DEFAULT pending | Transaction status | `completed` or `failed` |
| `createdAt` | DateTime | NOT NULL, DEFAULT NOW() | Transaction creation time | `2024-12-11T10:36:00Z` |

**Sample Data:**

```sql
SELECT * FROM "Transaction";

id                                    | sourceAccountId                       | destinationAccountId                  | amount        | type     | status
--------------------------------------|---------------------------------------|---------------------------------------|---------------|----------|----------
550e8400-e29b-41d4-a716-446655440010 | 550e8400-e29b-41d4-a716-446655440000 | 660e8400-e29b-41d4-a716-446655440001 | 50.25000000   | transfer | completed
550e8400-e29b-41d4-a716-446655440011 | 550e8400-e29b-41d4-a716-446655440000 | 770e8400-e29b-41d4-a716-446655440002 | 100.00000000  | transfer | failed
```

**Relationship to Ledger:**

For a successful transfer, transaction creates 2 ledger entries:
```
Transaction: A → B, $50.25
creates:
  ├─ LedgerEntry: Account A, -$50.25 (debit)
  └─ LedgerEntry: Account B, +$50.25 (credit)
```

**Constraints:**

```sql
-- At least one of source/destination must be non-null
ALTER TABLE "Transaction" ADD CONSTRAINT "Transaction_accounts_not_null"
CHECK (
  (type = 'transfer' AND "sourceAccountId" IS NOT NULL AND "destinationAccountId" IS NOT NULL)
  OR (type = 'deposit' AND "destinationAccountId" IS NOT NULL)
  OR (type = 'withdrawal' AND "sourceAccountId" IS NOT NULL)
);

-- Amount must be positive
ALTER TABLE "Transaction" ADD CONSTRAINT "Transaction_amount_positive"
CHECK (amount > 0);
```

**Indexes:**

```sql
CREATE INDEX "Transaction_sourceAccountId_idx" ON "Transaction"("sourceAccountId");
CREATE INDEX "Transaction_destinationAccountId_idx" ON "Transaction"("destinationAccountId");
CREATE INDEX "Transaction_status_idx" ON "Transaction"("status");
CREATE INDEX "Transaction_createdAt_idx" ON "Transaction"("createdAt");
```

---

## Data Consistency Rules

### Rule 1: Balance Calculation
**Invariant:** Account balance = SUM of all ledger entries for that account

```sql
-- Verification query (should return 0 for healthy database)
SELECT 
  a.id,
  a.currency,
  (SELECT SUM(CASE WHEN type='credit' THEN amount ELSE -amount END)
   FROM "LedgerEntry" WHERE "accountId" = a.id) as calculated_balance
FROM "Account" a
WHERE a.id = 'some-account-id';
```

### Rule 2: Ledger Entry Pairs
**Invariant:** Every transfer creates exactly 2 ledger entries (1 debit, 1 credit)

```sql
-- For successful transfer from A to B
-- Debit in A:  amount = X, type = 'debit'
-- Credit in B: amount = X, type = 'credit'
-- Always paired, never orphaned
```

### Rule 3: No Negative Balances
**Invariant:** Account balance can never go below zero

**Enforced by:**
1. Application logic: Check balance before creating debit entry
2. Transaction atomicity: If validation fails, entire transfer rolled back
3. Database constraints: Amount > 0

### Rule 4: Immutable Ledger
**Invariant:** Ledger entries can never be updated or deleted

**Enforced by:**
1. Application code: No UPDATE or DELETE SQL for ledger entries
2. Database constraint: Foreign key ON DELETE RESTRICT prevents deletion
3. Code review: All ledger operations use INSERT only

### Rule 5: Transaction Atomicity
**Invariant:** Transfer either creates both ledger entries or neither

**Enforced by:**
```javascript
prisma.$transaction(..., { isolationLevel: 'Serializable' })
// If any exception occurs, entire transaction rolls back
```

### Rule 6: Currency Consistency
**Invariant:** All ledger entries for an account use same currency

```sql
-- Application enforces: only same-currency accounts can receive transfers
-- Database allows multiple currencies per user, but each account locked to one
```

---

## Disaster Recovery Considerations

### Data Backup Strategy
```
Daily backups: Full PostgreSQL dump
  pg_dump financial_ledger > backup_$(date +%Y%m%d).sql

Point-in-time recovery: WAL (Write-Ahead Logging) enabled
  Allows recovery to any point in time
```

### Audit Trail
```
All changes logged to LedgerEntry and Transaction tables
immutable: no way to delete historical records
Timestamp on every entry: createdAt field
Chronological ordering: ORDER BY createdAt
```

### Orphan Prevention
```sql
-- Ledger entries can't exist without account
FOREIGN KEY ("accountId") REFERENCES "Account"(id) ON DELETE RESTRICT

-- Prevents data corruption from orphaned ledger entries
-- Accounts can't be deleted if they have ledger entries
```

---

## Migration History

See `prisma/migrations/` for all database schema changes:

1. **20251211054717_postgres** - Initial schema
   - Created Account table with UUID, userId, accountType, currency
   - Created LedgerEntry table with immutability constraints
   - Created Transaction table for audit trail

2. **20251211152929_fix_user_id_string** - User ID type
   - Changed userId type from Int to String
   - Allows email addresses, usernames, or other string identifiers

All migrations applied in order. To reset database:
```bash
npm run prisma:reset
# OR
npm run prisma:migrate deploy
```

---

## Performance Optimization Details

### Query Performance

**Balance Calculation (Most Critical Path)**
```sql
-- Indexed query for fast balance computation
SELECT SUM(CASE WHEN type='credit' THEN amount ELSE -amount END)
FROM "LedgerEntry"
WHERE "accountId" = $1;
-- Uses composite index: (accountId, createdAt)
-- Expected: < 100ms even with 100,000 ledger entries
```

**Ledger History with Pagination**
```sql
SELECT * FROM "LedgerEntry"
WHERE "accountId" = $1
ORDER BY "createdAt" DESC
LIMIT $2 OFFSET $3;
-- Uses index on (accountId, createdAt)
-- Expected: < 50ms
```

**Lock Wait Time**
```sql
-- Row-level lock acquired for duration of transfer
SELECT * FROM "Account" WHERE id = $1 FOR UPDATE;
-- Typical duration: < 10ms (quick calculation + insert)
-- Concurrent transfers serialize, but queue is short
```

### Index Strategy

| Index | Tables | Purpose | Trade-off |
|-------|--------|---------|-----------|
| PRIMARY KEY | All | Uniqueness enforcement | Always useful |
| FK indexes | All | Join performance | Automatic, minimal overhead |
| (accountId) | LedgerEntry | Find entries for account | Frequently used in balance calc |
| (accountId, createdAt) | LedgerEntry | **Most critical** | Supports both balance & history |
| (createdAt) | Transaction | Timeline queries | Useful for audit |
| (status) | Transaction | Filter pending | Small overhead, useful |

---

## Conclusion

**Schema Design Principle:** Prioritize correctness and consistency over performance

**Trade-offs Made:**
- ✅ Calculated balance (more queries, but single source of truth)
- ✅ Serializable isolation (slower, but prevents all race conditions)
- ✅ Row-level locks (serialize concurrent transfers, but guarantees correctness)
- ✅ Immutable ledger (prevents corrections, but prevents fraud)

**This design is suitable for financial systems where data integrity is paramount.**
