const express = require('express');
const router = express.Router();
const db = require('../config/database');
const plaidService = require('../services/plaid');
const { processNewTransaction } = require('../services/alerts');

// Create link token for Plaid Link
router.post('/create-link-token', async (req, res) => {
  try {
    const { userId } = req.body;
    const linkToken = await plaidService.createLinkToken(userId);
    res.json(linkToken);
  } catch (err) {
    console.error('Error creating link token:', err);
    res.status(500).json({ error: 'Failed to create link token' });
  }
});

// Exchange public token and save card
router.post('/exchange-token', async (req, res) => {
  try {
    const { publicToken, userId } = req.body;

    // Exchange for access token
    const exchangeResponse = await plaidService.exchangePublicToken(publicToken);
    const accessToken = exchangeResponse.access_token;

    // Get account details
    const accounts = await plaidService.getAccounts(accessToken);

    // Find Amex account (or first credit card)
    const amexAccount = accounts.find(
      (acc) => acc.subtype === 'credit card' || acc.type === 'credit'
    ) || accounts[0];

    // Save card to database
    const result = await db.query(
      `INSERT INTO cards (user_id, plaid_account_id, plaid_access_token, last_four, nickname)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [
        userId,
        amexAccount.account_id,
        accessToken,
        amexAccount.mask,
        amexAccount.name,
      ]
    );

    res.json({ success: true, card: result.rows[0] });
  } catch (err) {
    console.error('Error exchanging token:', err);
    res.status(500).json({ error: 'Failed to link card' });
  }
});

// Webhook handler for Plaid notifications
router.post('/webhook', async (req, res) => {
  const { webhook_type, webhook_code, item_id } = req.body;

  console.log(`Plaid webhook: ${webhook_type} - ${webhook_code}`);

  try {
    if (webhook_type === 'TRANSACTIONS') {
      if (webhook_code === 'SYNC_UPDATES_AVAILABLE') {
        // New transactions available - trigger sync
        const { syncAllTransactions } = require('../jobs/syncTransactions');
        await syncAllTransactions();
      }
    }

    res.json({ received: true });
  } catch (err) {
    console.error('Webhook error:', err);
    res.status(500).json({ error: 'Webhook processing failed' });
  }
});

// Get linked cards for a user
router.get('/cards/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const result = await db.query(
      'SELECT id, last_four, nickname, created_at FROM cards WHERE user_id = $1',
      [userId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching cards:', err);
    res.status(500).json({ error: 'Failed to fetch cards' });
  }
});

// Remove a linked card
router.delete('/cards/:cardId', async (req, res) => {
  try {
    const { cardId } = req.params;
    await db.query('DELETE FROM cards WHERE id = $1', [cardId]);
    res.json({ success: true });
  } catch (err) {
    console.error('Error removing card:', err);
    res.status(500).json({ error: 'Failed to remove card' });
  }
});

module.exports = router;
