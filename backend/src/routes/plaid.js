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
    console.error('Error creating link token:', err.response?.data || err.message || err);
    res.status(500).json({
      error: 'Failed to create link token',
      details: err.response?.data?.error_message || err.message
    });
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

    // Check if card with same last_four already exists for this user
    const existing = await db.query(
      'SELECT id FROM cards WHERE last_four = $1',
      [amexAccount.mask]
    );

    let result;
    if (existing.rows.length > 0) {
      const cardId = existing.rows[0].id;

      // Delete old transactions - Plaid generates new IDs on re-link causing duplicates
      await db.query('DELETE FROM transactions WHERE card_id = $1', [cardId]);
      console.log(`Deleted transactions for card ${cardId} before re-link`);

      // Update existing card with new access token and RESET sync cursor
      result = await db.query(
        `UPDATE cards SET plaid_access_token = $1, plaid_account_id = $2, user_id = $3, sync_cursor = NULL
         WHERE id = $4 RETURNING *`,
        [accessToken, amexAccount.account_id, userId, cardId]
      );
      console.log(`Updated existing card ${cardId} - cursor reset`);
    } else {
      // Insert new card
      result = await db.query(
        `INSERT INTO cards (user_id, plaid_account_id, plaid_access_token, last_four, nickname)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [userId, amexAccount.account_id, accessToken, amexAccount.mask, amexAccount.name]
      );
      console.log(`Created new card ${result.rows[0].id}`);
    }

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

// Get all linked cards (with user info)
router.get('/cards', async (req, res) => {
  try {
    const result = await db.query(
      `SELECT c.id, c.user_id, c.last_four, c.nickname, c.created_at, u.name as user_name
       FROM cards c
       JOIN users u ON c.user_id = u.id
       ORDER BY c.created_at DESC`
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching cards:', err);
    res.status(500).json({ error: 'Failed to fetch cards' });
  }
});

// Get linked cards for a user
router.get('/cards/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const result = await db.query(
      'SELECT id, user_id, last_four, nickname, created_at FROM cards WHERE user_id = $1',
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

// Get card balances from Plaid
router.get('/balances', async (req, res) => {
  try {
    const cards = await db.query('SELECT id, plaid_access_token, plaid_account_id, nickname, last_four FROM cards');
    const balances = [];

    for (const card of cards.rows) {
      try {
        const accounts = await plaidService.getAccounts(card.plaid_access_token);
        const account = accounts.find(a => a.account_id === card.plaid_account_id) || accounts[0];

        let paymentDue = null;
        let minimumPayment = null;
        let nextPaymentDate = null;

        // Try to get liabilities for payment due info
        try {
          const liabilities = await plaidService.getLiabilities(card.plaid_access_token);
          const creditCard = liabilities.credit?.find(c => c.account_id === card.plaid_account_id);
          if (creditCard) {
            paymentDue = creditCard.last_statement_balance;
            minimumPayment = creditCard.minimum_payment_amount;
            nextPaymentDate = creditCard.next_payment_due_date;
          }
        } catch (e) {
          // Liabilities not available for this card
        }

        if (account) {
          balances.push({
            card_id: card.id,
            nickname: card.nickname,
            last_four: card.last_four,
            current_balance: account.balances.current,
            available_credit: account.balances.available,
            credit_limit: account.balances.limit,
            payment_due: paymentDue,
            minimum_payment: minimumPayment,
            next_payment_date: nextPaymentDate
          });
        }
      } catch (e) {
        console.error(`Error fetching balance for card ${card.id}:`, e.message);
      }
    }

    res.json(balances);
  } catch (err) {
    console.error('Error fetching balances:', err);
    res.status(500).json({ error: 'Failed to fetch balances' });
  }
});

// Manual sync trigger
router.post('/sync', async (req, res) => {
  try {
    const { syncAllTransactions, updateMonthlySpending } = require('../jobs/syncTransactions');
    await syncAllTransactions();
    await updateMonthlySpending();
    res.json({ success: true, message: 'Sync complete' });
  } catch (err) {
    console.error('Error syncing:', err);
    res.status(500).json({ error: 'Sync failed' });
  }
});

module.exports = router;
