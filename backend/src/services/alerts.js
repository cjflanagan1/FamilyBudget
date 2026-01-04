const db = require('../config/database');
const { sendSMS, sendPersonalizedSMS } = require('./twilio');
const { isFoodDelivery, getDeliveryServiceName } = require('../utils/merchantDetection');

// Format currency
function formatCurrency(amount) {
  return `$${Math.abs(amount).toFixed(2)}`;
}

// Get parent phone numbers
async function getParentPhones() {
  const result = await db.query(
    "SELECT phone_number FROM users WHERE role = 'parent' AND phone_number IS NOT NULL"
  );
  return result.rows.map((r) => r.phone_number);
}

// Get user's phone number
async function getUserPhone(userId) {
  const result = await db.query(
    'SELECT phone_number FROM users WHERE id = $1',
    [userId]
  );
  return result.rows[0]?.phone_number;
}

// Get notification settings for parents
async function getParentNotificationSettings() {
  const result = await db.query(`
    SELECT u.id, u.name, u.phone_number, ns.alert_mode, ns.threshold_amount
    FROM users u
    JOIN notification_settings ns ON ns.user_id = u.id
    WHERE u.role = 'parent' AND u.phone_number IS NOT NULL
  `);
  return result.rows;
}

// Get spending limit status for a user
async function getSpendingStatus(userId) {
  const result = await db.query(`
    SELECT
      sl.monthly_limit,
      COALESCE(
        (SELECT SUM(t.amount)
         FROM transactions t
         JOIN cards c ON t.card_id = c.id
         WHERE c.user_id = $1
           AND t.date >= date_trunc('month', CURRENT_DATE)),
        0
      ) as current_spend
    FROM spending_limits sl
    WHERE sl.user_id = $1
  `, [userId]);

  if (result.rows.length === 0) return null;

  const { monthly_limit, current_spend } = result.rows[0];
  return {
    monthly_limit: parseFloat(monthly_limit),
    current_spend: parseFloat(current_spend),
    percent_used: (current_spend / monthly_limit) * 100,
    remaining: monthly_limit - current_spend,
  };
}

// Check if alert was already sent
async function wasAlertSent(userId, transactionId, alertType) {
  const result = await db.query(
    `SELECT id FROM alerts_sent
     WHERE user_id = $1 AND transaction_id = $2 AND alert_type = $3`,
    [userId, transactionId, alertType]
  );
  return result.rows.length > 0;
}

// Record that an alert was sent
async function recordAlert(userId, transactionId, alertType) {
  await db.query(
    `INSERT INTO alerts_sent (user_id, transaction_id, alert_type)
     VALUES ($1, $2, $3)
     ON CONFLICT DO NOTHING`,
    [userId, transactionId, alertType]
  );
}

// Process a new transaction and send appropriate alerts
async function processNewTransaction(transaction, cardholderInfo) {
  const { id: transactionId, amount, merchant_name, is_food_delivery } = transaction;
  const { user_id: cardholderId, name: cardholderName, role: cardholderRole } = cardholderInfo;

  const messages = [];

  // Get spending status
  const spendingStatus = await getSpendingStatus(cardholderId);

  // 1. Alert to CHILD if food delivery (with red banner)
  if (is_food_delivery && cardholderRole === 'child') {
    const childPhone = await getUserPhone(cardholderId);
    if (childPhone) {
      const serviceName = getDeliveryServiceName(merchant_name) || 'Food Delivery';
      const childMessage = `🔴 FOOD DELIVERY: You spent ${formatCurrency(amount)} at ${serviceName}`;

      messages.push({ to: childPhone, body: childMessage });
      await recordAlert(cardholderId, transactionId, 'child_food_delivery');
    }
  }

  // 2. Alert to PARENTS (based on their notification settings)
  const parentSettings = await getParentNotificationSettings();

  for (const parent of parentSettings) {
    // Skip if already sent
    if (await wasAlertSent(parent.id, transactionId, 'parent_purchase')) {
      continue;
    }

    let shouldSend = false;

    switch (parent.alert_mode) {
      case 'all':
        shouldSend = true;
        break;
      case 'threshold':
        shouldSend = amount >= parent.threshold_amount;
        break;
      case 'weekly':
        // Don't send individual alerts in weekly mode
        shouldSend = false;
        break;
    }

    if (shouldSend) {
      let parentMessage = `[FamilyBudget] ${cardholderName} spent ${formatCurrency(amount)} at ${merchant_name}`;

      // Add spending status if available
      if (spendingStatus) {
        const percentStr = Math.round(spendingStatus.percent_used);
        parentMessage += `\nMonthly: ${formatCurrency(spendingStatus.current_spend)} / ${formatCurrency(spendingStatus.monthly_limit)} (${percentStr}%)`;
      }

      // Add food delivery warning for parents too
      if (is_food_delivery) {
        parentMessage = `🔴 ${parentMessage}`;
      }

      messages.push({ to: parent.phone_number, body: parentMessage });
      await recordAlert(parent.id, transactionId, 'parent_purchase');
    }
  }

  // 3. Check for spending limit warnings (90% threshold)
  if (spendingStatus && spendingStatus.percent_used >= 90 && spendingStatus.percent_used < 100) {
    const parentPhones = await getParentPhones();

    for (const phone of parentPhones) {
      const warningMessage = `[FamilyBudget] ⚠️ ${cardholderName} is at ${Math.round(spendingStatus.percent_used)}% of monthly limit\n${formatCurrency(spendingStatus.current_spend)} / ${formatCurrency(spendingStatus.monthly_limit)} - ${formatCurrency(spendingStatus.remaining)} remaining`;

      // Only send if we haven't sent a 90% warning this month
      const warningKey = `limit_warning_90_${new Date().getMonth()}`;
      if (!(await wasAlertSent(cardholderId, transactionId, warningKey))) {
        messages.push({ to: phone, body: warningMessage });
        await recordAlert(cardholderId, transactionId, warningKey);
      }
    }
  }

  // 4. Check for over-limit alert
  if (spendingStatus && spendingStatus.percent_used >= 100) {
    const parentPhones = await getParentPhones();

    for (const phone of parentPhones) {
      const overMessage = `[FamilyBudget] 🚨 ${cardholderName} has EXCEEDED monthly limit!\n${formatCurrency(spendingStatus.current_spend)} / ${formatCurrency(spendingStatus.monthly_limit)} (${Math.round(spendingStatus.percent_used)}%)`;

      const overKey = `limit_exceeded_${new Date().getMonth()}`;
      if (!(await wasAlertSent(cardholderId, transactionId, overKey))) {
        messages.push({ to: phone, body: overMessage });
        await recordAlert(cardholderId, transactionId, overKey);
      }
    }
  }

  // Send all messages
  if (messages.length > 0) {
    await sendPersonalizedSMS(messages);
    console.log(`Sent ${messages.length} alerts for transaction ${transactionId}`);
  }

  return messages.length;
}

// Send subscription renewal reminder
async function sendRenewalReminder(subscription) {
  const { merchant_name, amount, next_renewal_date, user_id } = subscription;

  // Get cardholder name
  const userResult = await db.query('SELECT name FROM users WHERE id = $1', [user_id]);
  const cardholderName = userResult.rows[0]?.name || 'Unknown';

  // Send to parents
  const parentPhones = await getParentPhones();
  const message = `[FamilyBudget] Renewal in 3 days:\n${merchant_name} - ${formatCurrency(amount)} (${cardholderName}'s card)`;

  await sendSMSToMany(parentPhones, message);
  console.log(`Sent renewal reminder for ${merchant_name}`);
}

module.exports = {
  processNewTransaction,
  sendRenewalReminder,
  getSpendingStatus,
  formatCurrency,
};
