const express = require('express');
const router = express.Router();
const db = require('../config/database');

// Get all family members
router.get('/', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT u.*, ns.alert_mode, ns.threshold_amount
      FROM users u
      LEFT JOIN notification_settings ns ON ns.user_id = u.id
      ORDER BY u.id
    `);
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching users:', err);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

// Get single user
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await db.query(
      `SELECT u.*, ns.alert_mode, ns.threshold_amount, sl.monthly_limit, sl.current_spend
       FROM users u
       LEFT JOIN notification_settings ns ON ns.user_id = u.id
       LEFT JOIN spending_limits sl ON sl.user_id = u.id
       WHERE u.id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error fetching user:', err);
    res.status(500).json({ error: 'Failed to fetch user' });
  }
});

// Update user phone number
router.patch('/:id/phone', async (req, res) => {
  try {
    const { id } = req.params;
    const { phone_number } = req.body;

    const result = await db.query(
      'UPDATE users SET phone_number = $1 WHERE id = $2 RETURNING *',
      [phone_number, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error updating phone:', err);
    res.status(500).json({ error: 'Failed to update phone number' });
  }
});

// Update notification settings
router.patch('/:id/notifications', async (req, res) => {
  try {
    const { id } = req.params;
    const { alert_mode, threshold_amount, weekly_summary_day } = req.body;

    const result = await db.query(
      `INSERT INTO notification_settings (user_id, alert_mode, threshold_amount, weekly_summary_day)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (user_id)
       DO UPDATE SET
         alert_mode = COALESCE($2, notification_settings.alert_mode),
         threshold_amount = COALESCE($3, notification_settings.threshold_amount),
         weekly_summary_day = COALESCE($4, notification_settings.weekly_summary_day)
       RETURNING *`,
      [id, alert_mode, threshold_amount, weekly_summary_day]
    );

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error updating notifications:', err);
    res.status(500).json({ error: 'Failed to update notification settings' });
  }
});

module.exports = router;
