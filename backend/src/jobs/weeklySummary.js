const db = require('../config/database');
const { sendSMSToMany } = require('../services/twilio');
const { formatCurrency } = require('../services/alerts');

// Generate and send weekly spending summary to parents
async function sendWeeklySummary() {
  try {
    // Calculate date range (last 7 days)
    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - 7);

    const startStr = startDate.toISOString().split('T')[0];
    const endStr = endDate.toISOString().split('T')[0];

    // Get spending by user for the week
    const spendingResult = await db.query(`
      SELECT
        u.id,
        u.name,
        COALESCE(SUM(t.amount), 0) as weekly_total,
        sl.monthly_limit,
        COALESCE(
          (SELECT SUM(t2.amount)
           FROM transactions t2
           JOIN cards c2 ON t2.card_id = c2.id
           WHERE c2.user_id = u.id
             AND t2.date >= date_trunc('month', CURRENT_DATE)),
          0
        ) as monthly_total
      FROM users u
      LEFT JOIN cards c ON c.user_id = u.id
      LEFT JOIN transactions t ON t.card_id = c.id
        AND t.date >= $1 AND t.date <= $2
      LEFT JOIN spending_limits sl ON sl.user_id = u.id
      GROUP BY u.id, u.name, sl.monthly_limit
      ORDER BY u.id
    `, [startStr, endStr]);

    // Get top merchants for the week
    const merchantsResult = await db.query(`
      SELECT
        t.merchant_name,
        SUM(t.amount) as total
      FROM transactions t
      WHERE t.date >= $1 AND t.date <= $2
      GROUP BY t.merchant_name
      ORDER BY total DESC
      LIMIT 3
    `, [startStr, endStr]);

    // Format the weekly summary
    const dateRange = `${formatDate(startDate)} - ${formatDate(endDate)}`;
    let message = `[FamilyBudget] Weekly Summary (${dateRange})\n`;

    let grandTotal = 0;
    for (const user of spendingResult.rows) {
      const warning = user.monthly_limit && (user.monthly_total / user.monthly_limit) >= 0.9 ? ' ⚠️' : '';
      message += `${user.name}: ${formatCurrency(user.weekly_total)}${warning}\n`;
      grandTotal += parseFloat(user.weekly_total);
    }

    message += `---\nTotal: ${formatCurrency(grandTotal)}`;

    // Add top merchants
    if (merchantsResult.rows.length > 0) {
      const topMerchants = merchantsResult.rows
        .map((m) => `${m.merchant_name} (${formatCurrency(m.total)})`)
        .join(', ');
      message += `\nTop: ${topMerchants}`;
    }

    // Get parent phone numbers
    const parentsResult = await db.query(
      "SELECT phone_number FROM users WHERE role = 'parent' AND phone_number IS NOT NULL"
    );
    const parentPhones = parentsResult.rows.map((r) => r.phone_number);

    // Send to parents
    if (parentPhones.length > 0) {
      await sendSMSToMany(parentPhones, message);
      console.log('Weekly summary sent to parents');
    }

    return { message, recipients: parentPhones.length };
  } catch (err) {
    console.error('Error sending weekly summary:', err);
    throw err;
  }
}

// Generate monthly summary (run on 1st of month)
async function sendMonthlySummary() {
  try {
    // Calculate previous month's date range
    const endDate = new Date();
    endDate.setDate(0); // Last day of previous month
    const startDate = new Date(endDate);
    startDate.setDate(1); // First day of previous month

    const startStr = startDate.toISOString().split('T')[0];
    const endStr = endDate.toISOString().split('T')[0];

    // Get spending by user for the month
    const spendingResult = await db.query(`
      SELECT
        u.id,
        u.name,
        COALESCE(SUM(t.amount), 0) as monthly_total,
        sl.monthly_limit
      FROM users u
      LEFT JOIN cards c ON c.user_id = u.id
      LEFT JOIN transactions t ON t.card_id = c.id
        AND t.date >= $1 AND t.date <= $2
      LEFT JOIN spending_limits sl ON sl.user_id = u.id
      GROUP BY u.id, u.name, sl.monthly_limit
      ORDER BY u.id
    `, [startStr, endStr]);

    // Get category breakdown
    const categoryResult = await db.query(`
      SELECT
        t.category,
        SUM(t.amount) as total
      FROM transactions t
      WHERE t.date >= $1 AND t.date <= $2
      GROUP BY t.category
      ORDER BY total DESC
      LIMIT 5
    `, [startStr, endStr]);

    // Format the monthly summary
    const monthName = startDate.toLocaleString('default', { month: 'long', year: 'numeric' });
    let message = `[FamilyBudget] Monthly Summary - ${monthName}\n\n`;

    let grandTotal = 0;
    for (const user of spendingResult.rows) {
      const limitInfo = user.monthly_limit
        ? ` (limit: ${formatCurrency(user.monthly_limit)})`
        : '';
      const overLimit = user.monthly_limit && user.monthly_total > user.monthly_limit ? ' 🚨' : '';
      message += `${user.name}: ${formatCurrency(user.monthly_total)}${limitInfo}${overLimit}\n`;
      grandTotal += parseFloat(user.monthly_total);
    }

    message += `\n📊 Total: ${formatCurrency(grandTotal)}`;

    // Add category breakdown
    if (categoryResult.rows.length > 0) {
      message += '\n\nBy Category:';
      for (const cat of categoryResult.rows) {
        message += `\n• ${cat.category}: ${formatCurrency(cat.total)}`;
      }
    }

    // Get parent phone numbers
    const parentsResult = await db.query(
      "SELECT phone_number FROM users WHERE role = 'parent' AND phone_number IS NOT NULL"
    );
    const parentPhones = parentsResult.rows.map((r) => r.phone_number);

    // Send to parents
    if (parentPhones.length > 0) {
      await sendSMSToMany(parentPhones, message);
      console.log('Monthly summary sent to parents');
    }

    return { message, recipients: parentPhones.length };
  } catch (err) {
    console.error('Error sending monthly summary:', err);
    throw err;
  }
}

// Helper function to format date as "Dec 23"
function formatDate(date) {
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

module.exports = {
  sendWeeklySummary,
  sendMonthlySummary,
};
