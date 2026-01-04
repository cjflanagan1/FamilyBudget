const db = require('../config/database');
const { sendRenewalReminder } = require('../services/alerts');

// Check for subscriptions renewing in 3 days and send alerts
async function checkUpcomingRenewals() {
  try {
    // Get subscriptions renewing in exactly 3 days
    const result = await db.query(`
      SELECT s.*, u.name as cardholder_name
      FROM subscriptions s
      JOIN users u ON s.user_id = u.id
      WHERE s.is_active = true
        AND s.next_renewal_date = CURRENT_DATE + interval '3 days'
    `);

    const subscriptions = result.rows;
    console.log(`Found ${subscriptions.length} subscriptions renewing in 3 days`);

    for (const sub of subscriptions) {
      await sendRenewalReminder(sub);
    }

    return subscriptions.length;
  } catch (err) {
    console.error('Error checking renewals:', err);
    throw err;
  }
}

// Update next renewal dates after they pass
async function updatePassedRenewals() {
  try {
    // Update monthly subscriptions
    await db.query(`
      UPDATE subscriptions
      SET next_renewal_date = next_renewal_date + interval '1 month'
      WHERE is_active = true
        AND billing_cycle = 'monthly'
        AND next_renewal_date < CURRENT_DATE
    `);

    // Update yearly subscriptions
    await db.query(`
      UPDATE subscriptions
      SET next_renewal_date = next_renewal_date + interval '1 year'
      WHERE is_active = true
        AND billing_cycle = 'yearly'
        AND next_renewal_date < CURRENT_DATE
    `);

    console.log('Passed renewal dates updated');
  } catch (err) {
    console.error('Error updating passed renewals:', err);
    throw err;
  }
}

module.exports = {
  checkUpcomingRenewals,
  updatePassedRenewals,
};
