const express = require('express');
const router = express.Router();
const db = require('../config/database');

// Get all transactions with optional filters
router.get('/', async (req, res) => {
  try {
    const { userId, startDate, endDate, limit = 100 } = req.query;

    let query = `
      SELECT t.*, u.name as cardholder_name, c.last_four
      FROM transactions t
      JOIN cards c ON t.card_id = c.id
      JOIN users u ON c.user_id = u.id
      WHERE 1=1
    `;
    const params = [];

    if (userId) {
      params.push(userId);
      query += ` AND c.user_id = $${params.length}`;
    }

    if (startDate) {
      params.push(startDate);
      query += ` AND t.date >= $${params.length}`;
    }

    if (endDate) {
      params.push(endDate);
      query += ` AND t.date <= $${params.length}`;
    }

    params.push(limit);
    query += ` ORDER BY t.date DESC, t.created_at DESC LIMIT $${params.length}`;

    const result = await db.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching transactions:', err);
    res.status(500).json({ error: 'Failed to fetch transactions' });
  }
});

// Get spending summary by user for current month
router.get('/summary', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT
        u.id as user_id,
        u.name,
        u.role,
        COALESCE(SUM(t.amount), 0) as total_spent,
        sl.monthly_limit,
        COUNT(t.id) as transaction_count
      FROM users u
      LEFT JOIN cards c ON c.user_id = u.id
      LEFT JOIN transactions t ON t.card_id = c.id
        AND t.date >= date_trunc('month', CURRENT_DATE)
        AND t.date < date_trunc('month', CURRENT_DATE) + interval '1 month'
      LEFT JOIN spending_limits sl ON sl.user_id = u.id
      GROUP BY u.id, u.name, u.role, sl.monthly_limit
      ORDER BY u.id
    `);

    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching summary:', err);
    res.status(500).json({ error: 'Failed to fetch summary' });
  }
});

// Get spending by category
router.get('/by-category', async (req, res) => {
  try {
    const { userId, startDate, endDate } = req.query;

    let query = `
      SELECT
        t.category,
        SUM(t.amount) as total,
        COUNT(*) as count
      FROM transactions t
      JOIN cards c ON t.card_id = c.id
      WHERE t.date >= $1 AND t.date <= $2
    `;
    const params = [
      startDate || new Date(new Date().setDate(1)).toISOString().split('T')[0],
      endDate || new Date().toISOString().split('T')[0],
    ];

    if (userId) {
      params.push(userId);
      query += ` AND c.user_id = $${params.length}`;
    }

    query += ` GROUP BY t.category ORDER BY total DESC`;

    const result = await db.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching by category:', err);
    res.status(500).json({ error: 'Failed to fetch category breakdown' });
  }
});

// Get top merchants
router.get('/top-merchants', async (req, res) => {
  try {
    const { userId, limit = 10 } = req.query;

    let query = `
      SELECT
        t.merchant_name,
        SUM(t.amount) as total,
        COUNT(*) as count
      FROM transactions t
      JOIN cards c ON t.card_id = c.id
      WHERE t.date >= date_trunc('month', CURRENT_DATE)
    `;
    const params = [];

    if (userId) {
      params.push(userId);
      query += ` AND c.user_id = $${params.length}`;
    }

    params.push(limit);
    query += ` GROUP BY t.merchant_name ORDER BY total DESC LIMIT $${params.length}`;

    const result = await db.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching top merchants:', err);
    res.status(500).json({ error: 'Failed to fetch top merchants' });
  }
});

// Get single transaction
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await db.query(
      `SELECT t.*, u.name as cardholder_name, c.last_four
       FROM transactions t
       JOIN cards c ON t.card_id = c.id
       JOIN users u ON c.user_id = u.id
       WHERE t.id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Transaction not found' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error fetching transaction:', err);
    res.status(500).json({ error: 'Failed to fetch transaction' });
  }
});

module.exports = router;
