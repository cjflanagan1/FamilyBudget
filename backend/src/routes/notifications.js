const express = require('express');
const router = express.Router();
const db = require('../config/database');

// Register device token for push notifications
router.post('/register-device', async (req, res) => {
  try {
    const { device_token, user_id, platform = 'ios' } = req.body;

    if (!device_token) {
      return res.status(400).json({ error: 'device_token is required' });
    }

    // Upsert device token
    await db.query(`
      INSERT INTO device_tokens (user_id, device_token, platform, is_active, updated_at)
      VALUES ($1, $2, $3, true, CURRENT_TIMESTAMP)
      ON CONFLICT (device_token)
      DO UPDATE SET
        user_id = COALESCE($1, device_tokens.user_id),
        is_active = true,
        updated_at = CURRENT_TIMESTAMP
    `, [user_id, device_token, platform]);

    console.log(`[Push] Registered device token for user ${user_id}`);
    res.json({ success: true });
  } catch (err) {
    console.error('Error registering device:', err);
    res.status(500).json({ error: 'Failed to register device' });
  }
});

// Unregister device token
router.post('/unregister-device', async (req, res) => {
  try {
    const { device_token } = req.body;

    await db.query(`
      UPDATE device_tokens SET is_active = false WHERE device_token = $1
    `, [device_token]);

    res.json({ success: true });
  } catch (err) {
    console.error('Error unregistering device:', err);
    res.status(500).json({ error: 'Failed to unregister device' });
  }
});

// Get all active device tokens (for testing)
router.get('/devices', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT dt.*, u.name as user_name
      FROM device_tokens dt
      LEFT JOIN users u ON u.id = dt.user_id
      WHERE dt.is_active = true
    `);
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching devices:', err);
    res.status(500).json({ error: 'Failed to fetch devices' });
  }
});

// Test push notification
router.post('/test-push', async (req, res) => {
  try {
    const { sendPushNotification } = require('../services/push');
    const { user_id, title, body } = req.body;

    const result = await db.query(`
      SELECT device_token FROM device_tokens
      WHERE user_id = $1 AND is_active = true
    `, [user_id || 1]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'No device tokens found' });
    }

    const tokens = result.rows.map(r => r.device_token);
    await sendPushNotification(tokens, {
      title: title || 'Test Notification',
      body: body || 'This is a test push notification',
      data: { type: 'test' }
    });

    res.json({ success: true, sent_to: tokens.length });
  } catch (err) {
    console.error('Error sending test push:', err);
    res.status(500).json({ error: 'Failed to send test push' });
  }
});

module.exports = router;
