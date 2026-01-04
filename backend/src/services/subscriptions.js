const db = require('../config/database');
const { SUBSCRIPTION_PATTERNS } = require('../utils/merchantDetection');

// Detect recurring charges from transaction history
async function detectRecurringCharges(userId) {
  try {
    // Find transactions that appear monthly with similar amounts
    const result = await db.query(`
      WITH monthly_charges AS (
        SELECT
          t.merchant_name,
          DATE_TRUNC('month', t.date) as month,
          AVG(t.amount) as avg_amount,
          COUNT(*) as count
        FROM transactions t
        JOIN cards c ON t.card_id = c.id
        WHERE c.user_id = $1
          AND t.date >= CURRENT_DATE - interval '6 months'
        GROUP BY t.merchant_name, DATE_TRUNC('month', t.date)
      ),
      recurring AS (
        SELECT
          merchant_name,
          AVG(avg_amount) as amount,
          COUNT(DISTINCT month) as months_appeared
        FROM monthly_charges
        GROUP BY merchant_name
        HAVING COUNT(DISTINCT month) >= 3
      )
      SELECT * FROM recurring
      ORDER BY amount DESC
    `, [userId]);

    return result.rows.map(row => ({
      merchantName: row.merchant_name,
      amount: parseFloat(row.amount),
      monthsAppeared: parseInt(row.months_appeared),
      isLikelySubscription: true,
    }));
  } catch (err) {
    console.error('Error detecting recurring charges:', err);
    throw err;
  }
}

// Auto-detect and create subscriptions from transaction patterns
async function autoDetectSubscriptions(userId) {
  const recurring = await detectRecurringCharges(userId);
  const created = [];

  for (const charge of recurring) {
    // Check if subscription already exists
    const existing = await db.query(
      'SELECT id FROM subscriptions WHERE user_id = $1 AND LOWER(merchant_name) = LOWER($2)',
      [userId, charge.merchantName]
    );

    if (existing.rows.length === 0) {
      // Estimate next renewal date (assume monthly, on the 1st)
      const nextMonth = new Date();
      nextMonth.setMonth(nextMonth.getMonth() + 1);
      nextMonth.setDate(1);

      // Create subscription
      const result = await db.query(
        `INSERT INTO subscriptions (user_id, merchant_name, amount, billing_cycle, next_renewal_date)
         VALUES ($1, $2, $3, 'monthly', $4)
         RETURNING *`,
        [userId, charge.merchantName, charge.amount, nextMonth.toISOString().split('T')[0]]
      );

      created.push(result.rows[0]);
    }
  }

  return created;
}

// Get subscription insights
async function getSubscriptionInsights(userId) {
  // Total monthly subscription cost
  const totalResult = await db.query(`
    SELECT
      SUM(CASE
        WHEN billing_cycle = 'monthly' THEN amount
        WHEN billing_cycle = 'yearly' THEN amount / 12
        ELSE amount
      END) as monthly_total,
      COUNT(*) as count
    FROM subscriptions
    WHERE is_active = true
      ${userId ? 'AND user_id = $1' : ''}
  `, userId ? [userId] : []);

  // Upcoming renewals in next 7 days
  const upcomingResult = await db.query(`
    SELECT COUNT(*) as count, SUM(amount) as total
    FROM subscriptions
    WHERE is_active = true
      AND next_renewal_date BETWEEN CURRENT_DATE AND CURRENT_DATE + interval '7 days'
      ${userId ? 'AND user_id = $1' : ''}
  `, userId ? [userId] : []);

  // By billing cycle
  const byCycleResult = await db.query(`
    SELECT
      billing_cycle,
      COUNT(*) as count,
      SUM(amount) as total
    FROM subscriptions
    WHERE is_active = true
      ${userId ? 'AND user_id = $1' : ''}
    GROUP BY billing_cycle
  `, userId ? [userId] : []);

  return {
    monthlyTotal: parseFloat(totalResult.rows[0]?.monthly_total || 0),
    subscriptionCount: parseInt(totalResult.rows[0]?.count || 0),
    upcomingRenewals: {
      count: parseInt(upcomingResult.rows[0]?.count || 0),
      total: parseFloat(upcomingResult.rows[0]?.total || 0),
    },
    byCycle: byCycleResult.rows,
  };
}

// Match a transaction to a known subscription
async function matchTransactionToSubscription(transaction) {
  const { merchant_name, amount, user_id } = transaction;

  // Check against known subscription patterns
  for (const pattern of SUBSCRIPTION_PATTERNS) {
    if (pattern.pattern.test(merchant_name)) {
      // Check if we already track this subscription
      const existing = await db.query(
        `SELECT id FROM subscriptions
         WHERE user_id = $1 AND LOWER(merchant_name) LIKE LOWER($2)`,
        [user_id, `%${pattern.name}%`]
      );

      if (existing.rows.length > 0) {
        // Update last renewal date
        const nextDate = new Date();
        nextDate.setMonth(nextDate.getMonth() + 1);

        await db.query(
          `UPDATE subscriptions
           SET next_renewal_date = $1, amount = $2
           WHERE id = $3`,
          [nextDate.toISOString().split('T')[0], amount, existing.rows[0].id]
        );

        return { matched: true, subscriptionId: existing.rows[0].id };
      }
    }
  }

  return { matched: false };
}

module.exports = {
  detectRecurringCharges,
  autoDetectSubscriptions,
  getSubscriptionInsights,
  matchTransactionToSubscription,
};
