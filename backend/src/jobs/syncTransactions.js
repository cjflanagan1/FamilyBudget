const db = require('../config/database');
const plaidService = require('../services/plaid');
const { processNewTransaction } = require('../services/alerts');
const { categorizeTransaction } = require('../utils/merchantDetection');

// Store sync cursors per card
const syncCursors = new Map();

// Sync transactions for a single card
async function syncCardTransactions(card) {
  const { id: cardId, plaid_access_token: accessToken, user_id: userId } = card;

  try {
    // Get cursor from memory or database (in production, store in DB)
    let cursor = syncCursors.get(cardId) || null;

    // Sync transactions
    const syncResponse = await plaidService.syncTransactions(accessToken, cursor);

    const { added, modified, removed, next_cursor, has_more } = syncResponse;

    console.log(`Card ${cardId}: ${added.length} new, ${modified.length} modified, ${removed.length} removed`);

    // Get user info for alerts
    const userResult = await db.query(
      'SELECT id, name, role FROM users WHERE id = $1',
      [userId]
    );
    const userInfo = userResult.rows[0];

    // Process added transactions
    for (const txn of added) {
      const category = categorizeTransaction(txn.merchant_name, txn.personal_finance_category?.primary);

      // Plaid: positive = charge, negative = refund/credit
      const isRefund = txn.amount < 0;
      const amount = Math.abs(txn.amount);

      // Insert transaction
      const result = await db.query(
        `INSERT INTO transactions
         (card_id, plaid_transaction_id, amount, merchant_name, category, date, is_recurring, is_food_delivery, is_refund)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         ON CONFLICT (plaid_transaction_id) DO NOTHING
         RETURNING *`,
        [
          cardId,
          txn.transaction_id,
          amount,
          txn.merchant_name || txn.name,
          isRefund ? 'Refund' : category.category,
          txn.date,
          txn.personal_finance_category?.detailed === 'SUBSCRIPTION',
          category.is_food_delivery,
          isRefund,
        ]
      );

      // If this was a new transaction (not duplicate), send alerts
      if (result.rows.length > 0) {
        const savedTransaction = result.rows[0];
        await processNewTransaction(savedTransaction, userInfo);
      }
    }

    // Process modified transactions (update existing)
    for (const txn of modified) {
      const category = categorizeTransaction(txn.merchant_name, txn.personal_finance_category?.primary);
      const isRefund = txn.amount < 0;

      await db.query(
        `UPDATE transactions SET
           amount = $1,
           merchant_name = $2,
           category = $3,
           date = $4,
           is_food_delivery = $5,
           is_refund = $6
         WHERE plaid_transaction_id = $7`,
        [
          Math.abs(txn.amount),
          txn.merchant_name || txn.name,
          isRefund ? 'Refund' : category.category,
          txn.date,
          category.is_food_delivery,
          isRefund,
          txn.transaction_id,
        ]
      );
    }

    // Process removed transactions
    for (const txn of removed) {
      await db.query(
        'DELETE FROM transactions WHERE plaid_transaction_id = $1',
        [txn.transaction_id]
      );
    }

    // Update cursor
    syncCursors.set(cardId, next_cursor);

    // If there are more transactions, continue syncing
    if (has_more) {
      await syncCardTransactions(card);
    }

    return { added: added.length, modified: modified.length, removed: removed.length };
  } catch (err) {
    console.error(`Error syncing card ${cardId}:`, err.message);
    throw err;
  }
}

// Sync all linked cards
async function syncAllTransactions() {
  try {
    // Get all cards with access tokens
    const result = await db.query(
      'SELECT id, user_id, plaid_access_token FROM cards WHERE plaid_access_token IS NOT NULL'
    );

    const cards = result.rows;
    console.log(`Syncing ${cards.length} cards...`);

    const results = await Promise.allSettled(
      cards.map((card) => syncCardTransactions(card))
    );

    const succeeded = results.filter((r) => r.status === 'fulfilled').length;
    const failed = results.filter((r) => r.status === 'rejected').length;

    console.log(`Transaction sync complete: ${succeeded} succeeded, ${failed} failed`);

    return { succeeded, failed };
  } catch (err) {
    console.error('Error in syncAllTransactions:', err);
    throw err;
  }
}

// Update spending totals for the current month
async function updateMonthlySpending() {
  try {
    await db.query(`
      UPDATE spending_limits sl
      SET current_spend = (
        SELECT COALESCE(SUM(t.amount), 0)
        FROM transactions t
        JOIN cards c ON t.card_id = c.id
        WHERE c.user_id = sl.user_id
          AND t.date >= date_trunc('month', CURRENT_DATE)
      ),
      updated_at = CURRENT_TIMESTAMP
    `);

    console.log('Monthly spending totals updated');
  } catch (err) {
    console.error('Error updating monthly spending:', err);
    throw err;
  }
}

module.exports = {
  syncCardTransactions,
  syncAllTransactions,
  updateMonthlySpending,
};
