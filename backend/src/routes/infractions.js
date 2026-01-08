const express = require('express');
const router = express.Router();
const db = require('../config/database');

// Get all infraction vendors
router.get('/vendors', async (req, res) => {
  try {
    const result = await db.query(
      'SELECT id, vendor_name, created_at FROM infraction_vendors ORDER BY vendor_name'
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching infraction vendors:', err);
    res.status(500).json({ error: 'Failed to fetch infraction vendors' });
  }
});

// Add infraction vendor
router.post('/vendors', async (req, res) => {
  try {
    const { vendor_name } = req.body;

    if (!vendor_name || vendor_name.trim() === '') {
      return res.status(400).json({ error: 'vendor_name is required' });
    }

    const result = await db.query(
      'INSERT INTO infraction_vendors (vendor_name) VALUES ($1) RETURNING *',
      [vendor_name.toUpperCase().trim()]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Vendor already exists' });
    }
    console.error('Error adding infraction vendor:', err);
    res.status(500).json({ error: 'Failed to add infraction vendor' });
  }
});

// Delete infraction vendor
router.delete('/vendors/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await db.query('DELETE FROM infraction_vendors WHERE id = $1', [id]);
    res.json({ success: true });
  } catch (err) {
    console.error('Error deleting infraction vendor:', err);
    res.status(500).json({ error: 'Failed to delete infraction vendor' });
  }
});

// Get infraction transactions (transactions matching any infraction vendor)
router.get('/transactions', async (req, res) => {
  try {
    // Get all infraction vendor names
    const vendorsResult = await db.query('SELECT vendor_name FROM infraction_vendors');
    const vendorNames = vendorsResult.rows.map(v => v.vendor_name);

    if (vendorNames.length === 0) {
      return res.json([]);
    }

    // Build dynamic ILIKE conditions for each vendor
    const conditions = vendorNames.map((_, i) => `UPPER(t.merchant_name) LIKE $${i + 1}`);
    const patterns = vendorNames.map(v => `%${v}%`);

    const query = `
      SELECT t.id, t.merchant_name, t.amount, t.date, u.name as user_name
      FROM transactions t
      JOIN cards c ON t.card_id = c.id
      JOIN users u ON c.user_id = u.id
      WHERE (${conditions.join(' OR ')})
      ORDER BY t.date DESC, t.created_at DESC
      LIMIT 100
    `;

    const result = await db.query(query, patterns);
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching infraction transactions:', err);
    res.status(500).json({ error: 'Failed to fetch infraction transactions' });
  }
});

module.exports = router;
