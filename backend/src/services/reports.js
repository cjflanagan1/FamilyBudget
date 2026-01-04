const db = require('../config/database');
const { getFamilyInsights, getSpendingTrends } = require('../utils/unusualSpend');

// Generate spending report for a date range
async function generateSpendingReport(startDate, endDate, userId = null) {
  // Total spending
  let totalQuery = `
    SELECT COALESCE(SUM(t.amount), 0) as total
    FROM transactions t
    JOIN cards c ON t.card_id = c.id
    WHERE t.date >= $1 AND t.date <= $2
  `;
  const totalParams = [startDate, endDate];

  if (userId) {
    totalParams.push(userId);
    totalQuery += ` AND c.user_id = $${totalParams.length}`;
  }

  const totalResult = await db.query(totalQuery, totalParams);

  // By user
  const byUserResult = await db.query(`
    SELECT
      u.id,
      u.name,
      u.role,
      COALESCE(SUM(t.amount), 0) as total,
      COUNT(t.id) as transaction_count
    FROM users u
    LEFT JOIN cards c ON c.user_id = u.id
    LEFT JOIN transactions t ON t.card_id = c.id
      AND t.date >= $1 AND t.date <= $2
    GROUP BY u.id, u.name, u.role
    ORDER BY total DESC
  `, [startDate, endDate]);

  // By category
  let categoryQuery = `
    SELECT
      t.category,
      SUM(t.amount) as total,
      COUNT(*) as count
    FROM transactions t
    JOIN cards c ON t.card_id = c.id
    WHERE t.date >= $1 AND t.date <= $2
  `;
  const categoryParams = [startDate, endDate];

  if (userId) {
    categoryParams.push(userId);
    categoryQuery += ` AND c.user_id = $${categoryParams.length}`;
  }

  categoryQuery += ` GROUP BY t.category ORDER BY total DESC LIMIT 10`;

  const categoryResult = await db.query(categoryQuery, categoryParams);

  // Top merchants
  let merchantQuery = `
    SELECT
      t.merchant_name,
      SUM(t.amount) as total,
      COUNT(*) as count
    FROM transactions t
    JOIN cards c ON t.card_id = c.id
    WHERE t.date >= $1 AND t.date <= $2
  `;
  const merchantParams = [startDate, endDate];

  if (userId) {
    merchantParams.push(userId);
    merchantQuery += ` AND c.user_id = $${merchantParams.length}`;
  }

  merchantQuery += ` GROUP BY t.merchant_name ORDER BY total DESC LIMIT 10`;

  const merchantResult = await db.query(merchantQuery, merchantParams);

  // Food delivery breakdown
  let foodQuery = `
    SELECT
      t.merchant_name,
      SUM(t.amount) as total,
      COUNT(*) as count
    FROM transactions t
    JOIN cards c ON t.card_id = c.id
    WHERE t.date >= $1 AND t.date <= $2
      AND t.is_food_delivery = true
  `;
  const foodParams = [startDate, endDate];

  if (userId) {
    foodParams.push(userId);
    foodQuery += ` AND c.user_id = $${foodParams.length}`;
  }

  foodQuery += ` GROUP BY t.merchant_name ORDER BY total DESC`;

  const foodResult = await db.query(foodQuery, foodParams);

  return {
    period: { startDate, endDate },
    totalSpend: parseFloat(totalResult.rows[0]?.total || 0),
    byUser: byUserResult.rows.map(r => ({
      ...r,
      total: parseFloat(r.total),
      transaction_count: parseInt(r.transaction_count),
    })),
    byCategory: categoryResult.rows.map(r => ({
      ...r,
      total: parseFloat(r.total),
      count: parseInt(r.count),
    })),
    topMerchants: merchantResult.rows.map(r => ({
      ...r,
      total: parseFloat(r.total),
      count: parseInt(r.count),
    })),
    foodDelivery: {
      total: foodResult.rows.reduce((sum, r) => sum + parseFloat(r.total), 0),
      breakdown: foodResult.rows.map(r => ({
        ...r,
        total: parseFloat(r.total),
        count: parseInt(r.count),
      })),
    },
  };
}

// Generate monthly comparison report
async function generateMonthlyComparison(months = 3) {
  const reports = [];

  for (let i = 0; i < months; i++) {
    const startDate = new Date();
    startDate.setMonth(startDate.getMonth() - i);
    startDate.setDate(1);

    const endDate = new Date(startDate);
    endDate.setMonth(endDate.getMonth() + 1);
    endDate.setDate(0);

    const report = await generateSpendingReport(
      startDate.toISOString().split('T')[0],
      endDate.toISOString().split('T')[0]
    );

    reports.push({
      month: startDate.toLocaleString('default', { month: 'long', year: 'numeric' }),
      ...report,
    });
  }

  // Calculate changes
  if (reports.length >= 2) {
    const current = reports[0].totalSpend;
    const previous = reports[1].totalSpend;
    const change = previous > 0 ? ((current - previous) / previous) * 100 : 0;

    return {
      reports,
      comparison: {
        currentMonth: current,
        previousMonth: previous,
        changePercent: Math.round(change * 10) / 10,
        trend: change > 10 ? 'increasing' : change < -10 ? 'decreasing' : 'stable',
      },
    };
  }

  return { reports, comparison: null };
}

// Get report for the dashboard
async function getDashboardReport() {
  const insights = await getFamilyInsights();

  // Current month dates
  const startDate = new Date();
  startDate.setDate(1);
  const endDate = new Date();

  const currentMonth = await generateSpendingReport(
    startDate.toISOString().split('T')[0],
    endDate.toISOString().split('T')[0]
  );

  // Previous month for comparison
  const prevStart = new Date();
  prevStart.setMonth(prevStart.getMonth() - 1);
  prevStart.setDate(1);
  const prevEnd = new Date(prevStart);
  prevEnd.setMonth(prevEnd.getMonth() + 1);
  prevEnd.setDate(0);

  const previousMonth = await generateSpendingReport(
    prevStart.toISOString().split('T')[0],
    prevEnd.toISOString().split('T')[0]
  );

  const change = previousMonth.totalSpend > 0
    ? ((currentMonth.totalSpend - previousMonth.totalSpend) / previousMonth.totalSpend) * 100
    : 0;

  return {
    currentMonth,
    previousMonth,
    monthOverMonthChange: Math.round(change * 10) / 10,
    insights,
  };
}

module.exports = {
  generateSpendingReport,
  generateMonthlyComparison,
  getDashboardReport,
};
