const express = require('express');
const router = express.Router();
const db = require('../config/database');

// Get all spending limits
router.get('/', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT sl.*, u.name
      FROM spending_limits sl
      JOIN users u ON sl.user_id = u.id
      ORDER BY u.id
    `);
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching limits:', err);
    res.status(500).json({ error: 'Failed to fetch spending limits' });
  }
});

// Get spending limit for a user
router.get('/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const result = await db.query(
      `SELECT sl.*, u.name,
        (SELECT COALESCE(SUM(t.amount), 0)
         FROM transactions t
         JOIN cards c ON t.card_id = c.id
         WHERE c.user_id = $1
           AND t.date >= date_trunc('month', CURRENT_DATE)) as current_spend
       FROM spending_limits sl
       JOIN users u ON sl.user_id = u.id
       WHERE sl.user_id = $1`,
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Spending limit not found' });
    }

    const limit = result.rows[0];
    const percentUsed = (limit.current_spend / limit.monthly_limit) * 100;

    res.json({
      ...limit,
      percent_used: Math.round(percentUsed * 10) / 10,
      remaining: limit.monthly_limit - limit.current_spend,
    });
  } catch (err) {
    console.error('Error fetching limit:', err);
    res.status(500).json({ error: 'Failed to fetch spending limit' });
  }
});

// Update spending limit
router.put('/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { monthly_limit, reset_day } = req.body;

    const result = await db.query(
      `INSERT INTO spending_limits (user_id, monthly_limit, reset_day)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id)
       DO UPDATE SET
         monthly_limit = $2,
         reset_day = COALESCE($3, spending_limits.reset_day),
         updated_at = CURRENT_TIMESTAMP
       RETURNING *`,
      [userId, monthly_limit, reset_day || 1]
    );

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error updating limit:', err);
    res.status(500).json({ error: 'Failed to update spending limit' });
  }
});

// Get spending status for all users (dashboard)
router.get('/status/all', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT
        u.id,
        u.name,
        u.role,
        sl.monthly_limit,
        COALESCE(
          (SELECT SUM(t.amount)
           FROM transactions t
           JOIN cards c ON t.card_id = c.id
           WHERE c.user_id = u.id
             AND t.date >= date_trunc('month', CURRENT_DATE)),
          0
        ) as current_spend
      FROM users u
      LEFT JOIN spending_limits sl ON sl.user_id = u.id
      ORDER BY u.id
    `);

    const status = result.rows.map((row) => ({
      ...row,
      percent_used: row.monthly_limit
        ? Math.round((row.current_spend / row.monthly_limit) * 1000) / 10
        : 0,
      remaining: row.monthly_limit
        ? row.monthly_limit - row.current_spend
        : 0,
      is_warning: row.monthly_limit
        ? row.current_spend >= row.monthly_limit * 0.9
        : false,
      is_over: row.monthly_limit
        ? row.current_spend > row.monthly_limit
        : false,
    }));

    res.json(status);
  } catch (err) {
    console.error('Error fetching status:', err);
    res.status(500).json({ error: 'Failed to fetch spending status' });
  }
});

module.exports = router;
