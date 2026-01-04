const db = require('../config/database');

// Detect unusual spending patterns
async function detectUnusualSpend(transaction, userId) {
  const { amount, merchant_name, category } = transaction;

  const flags = [];

  // 1. Check if amount is significantly higher than user's average
  const avgResult = await db.query(`
    SELECT AVG(t.amount) as avg_amount, STDDEV(t.amount) as std_dev
    FROM transactions t
    JOIN cards c ON t.card_id = c.id
    WHERE c.user_id = $1
      AND t.date >= CURRENT_DATE - interval '90 days'
  `, [userId]);

  const { avg_amount, std_dev } = avgResult.rows[0];

  if (avg_amount && std_dev) {
    const avgNum = parseFloat(avg_amount);
    const stdNum = parseFloat(std_dev);

    // Flag if more than 2 standard deviations above average
    if (amount > avgNum + (2 * stdNum)) {
      flags.push({
        type: 'high_amount',
        message: `Transaction of $${amount.toFixed(2)} is unusually high (avg: $${avgNum.toFixed(2)})`,
        severity: 'warning',
      });
    }

    // Flag if more than 3 standard deviations (very unusual)
    if (amount > avgNum + (3 * stdNum)) {
      flags[flags.length - 1].severity = 'alert';
    }
  }

  // 2. Check if this is a new merchant
  const merchantResult = await db.query(`
    SELECT COUNT(*) as count
    FROM transactions t
    JOIN cards c ON t.card_id = c.id
    WHERE c.user_id = $1
      AND LOWER(t.merchant_name) = LOWER($2)
      AND t.date < CURRENT_DATE
  `, [userId, merchant_name]);

  if (parseInt(merchantResult.rows[0].count) === 0) {
    flags.push({
      type: 'new_merchant',
      message: `First purchase at ${merchant_name}`,
      severity: 'info',
    });
  }

  // 3. Check for unusual time (if we had transaction time, we'd check for late night)

  // 4. Check for high velocity (multiple transactions in short time)
  const velocityResult = await db.query(`
    SELECT COUNT(*) as count
    FROM transactions t
    JOIN cards c ON t.card_id = c.id
    WHERE c.user_id = $1
      AND t.date = CURRENT_DATE
  `, [userId]);

  const todayCount = parseInt(velocityResult.rows[0].count);
  if (todayCount > 10) {
    flags.push({
      type: 'high_velocity',
      message: `${todayCount} transactions today (unusually high activity)`,
      severity: 'warning',
    });
  }

  // 5. Check category spending spike
  if (category) {
    const categoryAvg = await db.query(`
      SELECT AVG(daily_total) as avg_daily
      FROM (
        SELECT DATE(t.date), SUM(t.amount) as daily_total
        FROM transactions t
        JOIN cards c ON t.card_id = c.id
        WHERE c.user_id = $1
          AND t.category = $2
          AND t.date >= CURRENT_DATE - interval '30 days'
          AND t.date < CURRENT_DATE
        GROUP BY DATE(t.date)
      ) daily
    `, [userId, category]);

    const catAvg = parseFloat(categoryAvg.rows[0]?.avg_daily || 0);

    // Get today's spending in this category
    const todayCatResult = await db.query(`
      SELECT COALESCE(SUM(t.amount), 0) as today_total
      FROM transactions t
      JOIN cards c ON t.card_id = c.id
      WHERE c.user_id = $1
        AND t.category = $2
        AND t.date = CURRENT_DATE
    `, [userId, category]);

    const todayCatTotal = parseFloat(todayCatResult.rows[0].today_total);

    if (catAvg > 0 && todayCatTotal > catAvg * 3) {
      flags.push({
        type: 'category_spike',
        message: `${category} spending today ($${todayCatTotal.toFixed(2)}) is 3x above average ($${catAvg.toFixed(2)})`,
        severity: 'warning',
      });
    }
  }

  return {
    isUnusual: flags.length > 0,
    flags,
    highestSeverity: flags.reduce((max, f) =>
      f.severity === 'alert' ? 'alert' :
      f.severity === 'warning' && max !== 'alert' ? 'warning' :
      max
    , 'info'),
  };
}

// Get spending trends (month over month comparison)
async function getSpendingTrends(userId) {
  const result = await db.query(`
    SELECT
      DATE_TRUNC('month', t.date) as month,
      SUM(t.amount) as total,
      COUNT(*) as transaction_count
    FROM transactions t
    JOIN cards c ON t.card_id = c.id
    WHERE c.user_id = $1
      AND t.date >= CURRENT_DATE - interval '6 months'
    GROUP BY DATE_TRUNC('month', t.date)
    ORDER BY month DESC
  `, [userId]);

  const trends = result.rows;

  if (trends.length < 2) {
    return { trends, change: null, trend: 'insufficient_data' };
  }

  const current = parseFloat(trends[0]?.total || 0);
  const previous = parseFloat(trends[1]?.total || 0);

  const change = previous > 0 ? ((current - previous) / previous) * 100 : 0;

  return {
    trends,
    currentMonth: current,
    previousMonth: previous,
    change: Math.round(change * 10) / 10,
    trend: change > 10 ? 'increasing' : change < -10 ? 'decreasing' : 'stable',
  };
}

// Get family-wide spending insights
async function getFamilyInsights() {
  // Total spend this month vs last month
  const monthlyComparison = await db.query(`
    SELECT
      CASE
        WHEN DATE_TRUNC('month', t.date) = DATE_TRUNC('month', CURRENT_DATE)
        THEN 'current'
        ELSE 'previous'
      END as period,
      SUM(t.amount) as total
    FROM transactions t
    WHERE t.date >= DATE_TRUNC('month', CURRENT_DATE) - interval '1 month'
    GROUP BY
      CASE
        WHEN DATE_TRUNC('month', t.date) = DATE_TRUNC('month', CURRENT_DATE)
        THEN 'current'
        ELSE 'previous'
      END
  `);

  // Top spending categories
  const topCategories = await db.query(`
    SELECT category, SUM(amount) as total
    FROM transactions
    WHERE date >= DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY category
    ORDER BY total DESC
    LIMIT 5
  `);

  // Biggest spender this month
  const biggestSpender = await db.query(`
    SELECT u.name, SUM(t.amount) as total
    FROM users u
    JOIN cards c ON c.user_id = u.id
    JOIN transactions t ON t.card_id = c.id
    WHERE t.date >= DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY u.id, u.name
    ORDER BY total DESC
    LIMIT 1
  `);

  return {
    monthlyComparison: monthlyComparison.rows,
    topCategories: topCategories.rows,
    biggestSpender: biggestSpender.rows[0] || null,
  };
}

module.exports = {
  detectUnusualSpend,
  getSpendingTrends,
  getFamilyInsights,
};
