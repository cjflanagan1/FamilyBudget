const express = require('express');
const router = express.Router();
const db = require('../config/database');

// Get all subscriptions
router.get('/', async (req, res) => {
  try {
    const { userId, active_only } = req.query;

    let query = `
      SELECT s.*, u.name as cardholder_name
      FROM subscriptions s
      JOIN users u ON s.user_id = u.id
      WHERE 1=1
    `;
    const params = [];

    if (userId) {
      params.push(userId);
      query += ` AND s.user_id = $${params.length}`;
    }

    if (active_only === 'true') {
      query += ` AND s.is_active = true`;
    }

    query += ` ORDER BY s.next_renewal_date ASC`;

    const result = await db.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching subscriptions:', err);
    res.status(500).json({ error: 'Failed to fetch subscriptions' });
  }
});

// Get upcoming renewals (next N days)
router.get('/upcoming', async (req, res) => {
  try {
    const { days = 7 } = req.query;

    const result = await db.query(
      `SELECT s.*, u.name as cardholder_name
       FROM subscriptions s
       JOIN users u ON s.user_id = u.id
       WHERE s.is_active = true
         AND s.next_renewal_date BETWEEN CURRENT_DATE AND CURRENT_DATE + $1::interval
       ORDER BY s.next_renewal_date ASC`,
      [`${days} days`]
    );

    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching upcoming renewals:', err);
    res.status(500).json({ error: 'Failed to fetch upcoming renewals' });
  }
});

// Add a subscription manually
router.post('/', async (req, res) => {
  try {
    const { user_id, merchant_name, amount, billing_cycle, next_renewal_date } = req.body;

    const result = await db.query(
      `INSERT INTO subscriptions (user_id, merchant_name, amount, billing_cycle, next_renewal_date)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [user_id, merchant_name, amount, billing_cycle || 'monthly', next_renewal_date]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error adding subscription:', err);
    res.status(500).json({ error: 'Failed to add subscription' });
  }
});

// Update subscription
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { merchant_name, amount, billing_cycle, next_renewal_date, is_active } = req.body;

    const result = await db.query(
      `UPDATE subscriptions SET
         merchant_name = COALESCE($1, merchant_name),
         amount = COALESCE($2, amount),
         billing_cycle = COALESCE($3, billing_cycle),
         next_renewal_date = COALESCE($4, next_renewal_date),
         is_active = COALESCE($5, is_active)
       WHERE id = $6
       RETURNING *`,
      [merchant_name, amount, billing_cycle, next_renewal_date, is_active, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Subscription not found' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error updating subscription:', err);
    res.status(500).json({ error: 'Failed to update subscription' });
  }
});

// Delete subscription
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await db.query('DELETE FROM subscriptions WHERE id = $1', [id]);
    res.json({ success: true });
  } catch (err) {
    console.error('Error deleting subscription:', err);
    res.status(500).json({ error: 'Failed to delete subscription' });
  }
});

// Get monthly subscription total
router.get('/total', async (req, res) => {
  try {
    const { userId } = req.query;

    let query = `
      SELECT
        SUM(CASE WHEN billing_cycle = 'monthly' THEN amount
                 WHEN billing_cycle = 'yearly' THEN amount / 12
                 ELSE amount END) as monthly_total,
        COUNT(*) as subscription_count
      FROM subscriptions
      WHERE is_active = true
    `;
    const params = [];

    if (userId) {
      params.push(userId);
      query += ` AND user_id = $${params.length}`;
    }

    const result = await db.query(query, params);
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error calculating total:', err);
    res.status(500).json({ error: 'Failed to calculate subscription total' });
  }
});

module.exports = router;
