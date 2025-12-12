require('dotenv').config();
const express = require('express');
const pino = require('pino')();

const accountsRouter = require('./routes/accounts');
const flowsRouter = require('./routes/flows');

const app = express();
app.use(express.json());

// Logger
app.use((req, res, next) => {
  pino.info({ method: req.method, url: req.url });
  next();
});

// Routes
app.use('/accounts', accountsRouter);
app.use('/', flowsRouter);

// Error handler
app.use((err, req, res, next) => {
  pino.error(err);
  if (err.status) return res.status(err.status).json({ error: err.message });
  res.status(500).json({ error: 'Internal error' });
});

module.exports = app;
