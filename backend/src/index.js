require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const cron = require('node-cron');

const db = require('./config/database');
const plaidRoutes = require('./routes/plaid');
const transactionRoutes = require('./routes/transactions');
const userRoutes = require('./routes/users');
const limitRoutes = require('./routes/limits');
const subscriptionRoutes = require('./routes/subscriptions');

const { syncAllTransactions } = require('./jobs/syncTransactions');
const { checkUpcomingRenewals } = require('./jobs/checkRenewals');
const { sendWeeklySummary } = require('./jobs/weeklySummary');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100
});
app.use(limiter);

// Routes
app.use('/api/plaid', plaidRoutes);
app.use('/api/transactions', transactionRoutes);
app.use('/api/users', userRoutes);
app.use('/api/limits', limitRoutes);
app.use('/api/subscriptions', subscriptionRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Scheduled jobs
// Sync transactions every 5 minutes
cron.schedule('*/5 * * * *', async () => {
  console.log('Running transaction sync...');
  await syncAllTransactions();
});

// Check subscription renewals daily at 9am
cron.schedule('0 9 * * *', async () => {
  console.log('Checking upcoming renewals...');
  await checkUpcomingRenewals();
});

// Weekly summary every Sunday at 9am
cron.schedule('0 9 * * 0', async () => {
  console.log('Sending weekly summary...');
  await sendWeeklySummary();
});

// Error handling
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

// Start server
app.listen(PORT, () => {
  console.log(`Family Budget API running on port ${PORT}`);
});

module.exports = app;
