const app = require('./app');
const prisma = require('./prismaClient');
const pino = require('pino')();

const PORT = process.env.PORT || 3000;

app.listen(PORT, async () => {
  pino.info(`Server listening on ${PORT}`);
  try {
    await prisma.$connect();
    pino.info('Connected to DB');
  } catch (e) {
    pino.error('DB connection error', e);
  }
});
