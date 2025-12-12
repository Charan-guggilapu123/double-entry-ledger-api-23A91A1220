# Deployment Guide

## Prerequisites

- Node.js 16+ and npm
- PostgreSQL 12+
- Docker (optional, for containerized deployment)

## Local Development Setup

### 1. Clone and Install

```bash
git clone <repository>
cd Financial_legder
npm install
```

### 2. Database Setup

Ensure PostgreSQL is running locally:

```bash
# macOS with Homebrew
brew services start postgresql

# Linux
sudo systemctl start postgresql

# Windows (PostgreSQL Service should be running)
```

### 3. Environment Configuration

Create `.env` file:

```bash
DATABASE_URL=postgresql://postgres:your_password@localhost:5432/ledger
NODE_ENV=development
PORT=3000
```

### 4. Initialize Database

```bash
# Generate Prisma Client
npm run prisma:generate

# Create and migrate database
npm run prisma:migrate
```

### 5. Start Development Server

```bash
npm run dev
```

Server runs at `http://localhost:3000`

## Testing

```bash
# Create test database
createdb ledger_test

# Create .env.test file
echo "DATABASE_URL=postgresql://postgres:your_password@localhost:5432/ledger_test" > .env.test

# Run tests
npm test
```

## Docker Deployment

### Build Docker Image

```bash
docker build -t financial-ledger:latest .
```

### Run with Docker Compose

```bash
# Start services
docker-compose up -d

# Migrate database
docker exec financial-ledger npm run prisma:migrate

# View logs
docker-compose logs -f app

# Stop services
docker-compose down
```

The `docker-compose.yml` includes:
- **app**: Express API server on port 3000
- **db**: PostgreSQL database on port 5432

### Environment for Docker

Create `.env` for Docker:

```
DATABASE_URL=postgresql://postgres:postgres@db:5432/ledger
NODE_ENV=production
PORT=3000
```

## Production Deployment

### 1. Cloud Deployment (Azure/AWS/Google Cloud)

#### Azure App Service Example

```bash
# Install Azure CLI
npm install -g @azure/cli

# Login
az login

# Create resource group
az group create --name ledger-rg --location eastus

# Create App Service Plan
az appservice plan create \
  --name ledger-plan \
  --resource-group ledger-rg \
  --sku B1 \
  --is-linux

# Create App Service
az webapp create \
  --resource-group ledger-rg \
  --plan ledger-plan \
  --name financial-ledger-api \
  --runtime "node|18"

# Set environment variables
az webapp config appsettings set \
  --resource-group ledger-rg \
  --name financial-ledger-api \
  --settings \
    DATABASE_URL=$PRODUCTION_DB_URL \
    NODE_ENV=production

# Deploy from Git
az webapp up --name financial-ledger-api
```

### 2. Docker Registry Deployment

```bash
# Tag image
docker tag financial-ledger:latest myregistry.azurecr.io/financial-ledger:latest

# Push to registry
docker push myregistry.azurecr.io/financial-ledger:latest

# Deploy to container instance
az container create \
  --resource-group ledger-rg \
  --name financial-ledger \
  --image myregistry.azurecr.io/financial-ledger:latest \
  --environment-variables \
    DATABASE_URL=$PRODUCTION_DB_URL \
    NODE_ENV=production \
  --ports 3000
```

### 3. Kubernetes Deployment

Create `k8s-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: financial-ledger
spec:
  replicas: 3
  selector:
    matchLabels:
      app: financial-ledger
  template:
    metadata:
      labels:
        app: financial-ledger
    spec:
      containers:
      - name: api
        image: financial-ledger:latest
        ports:
        - containerPort: 3000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: connection-string
        - name: NODE_ENV
          value: "production"
---
apiVersion: v1
kind: Service
metadata:
  name: financial-ledger-service
spec:
  type: LoadBalancer
  selector:
    app: financial-ledger
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
```

Deploy:

```bash
kubectl apply -f k8s-deployment.yaml
```

## Performance Optimization

### 1. Database Optimization

```sql
-- Index on userId for faster account lookups
CREATE INDEX idx_account_userid ON "Account"("userId");

-- Index on createdAt for ledger queries
CREATE INDEX idx_ledger_accountid_createdat ON "LedgerEntry"("accountId", "createdAt" DESC);
```

### 2. Connection Pooling

Update Prisma configuration in `prisma/schema.prisma`:

```prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
  directUrl = env("DATABASE_DIRECT_URL")
}
```

Use PgBouncer or similar for connection pooling in production.

### 3. Caching Layer (Redis)

Optional: Add Redis for caching account balances:

```bash
npm install redis
```

### 4. Monitoring & Logging

Set up log aggregation:

```bash
npm install winston winston-daily-rotate-file
```

## Security Best Practices

1. **Use HTTPS**: Always use HTTPS in production
2. **Environment Variables**: Never commit secrets to git
3. **Input Validation**: All inputs are validated (already implemented)
4. **SQL Injection Prevention**: Using Prisma ORM prevents SQL injection
5. **Rate Limiting**: Consider adding rate limiting middleware
6. **CORS**: Configure CORS appropriately

Add rate limiting:

```bash
npm install express-rate-limit
```

```javascript
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});

app.use('/transfers', limiter);
```

## Monitoring

### Health Check Endpoint

Add to `src/routes/health.js`:

```javascript
router.get('/', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date(),
    uptime: process.uptime()
  });
});
```

Register in `src/app.js`:

```javascript
app.use('/health', require('./routes/health'));
```

## Backup Strategy

### PostgreSQL Backups

```bash
# Full backup
pg_dump ledger > backup.sql

# Compressed backup
pg_dump ledger | gzip > backup.sql.gz

# Restore from backup
psql ledger < backup.sql
```

Schedule with cron:

```bash
# Daily backup at 2 AM
0 2 * * * pg_dump ledger | gzip > /backups/ledger-$(date +\%Y\%m\%d).sql.gz
```

## Troubleshooting

### Connection Issues

```bash
# Test DB connection
psql $DATABASE_URL -c "SELECT 1"

# View Prisma logs
DEBUG=prisma:* npm run dev
```

### Migration Issues

```bash
# View migration status
npx prisma migrate status

# Reset database (⚠️ caution: deletes all data)
npx prisma migrate reset
```

### Performance Issues

```bash
# Analyze query performance
EXPLAIN ANALYZE SELECT * FROM "Account" WHERE "userId" = $1;

# Check slow query logs
tail -f /var/log/postgresql/postgresql.log
```

## Maintenance

### Regular Tasks

1. Monitor database size
2. Vacuum and analyze tables
3. Review slow query logs
4. Update dependencies: `npm audit fix`
5. Test backup restoration

### Dependency Updates

```bash
# Check for updates
npm outdated

# Update safely
npm update

# Major updates (review changelog)
npm install package@latest
```

## Rollback Procedure

```bash
# If deployment fails, revert to previous version
git revert <commit-hash>
git push

# Rollback database migrations
npx prisma migrate resolve --rolled-back <migration-name>
```

## Support & Documentation

- API Documentation: See `README_API.md`
- Prisma Docs: https://www.prisma.io/docs/
- Express Docs: https://expressjs.com/
- PostgreSQL Docs: https://www.postgresql.org/docs/
