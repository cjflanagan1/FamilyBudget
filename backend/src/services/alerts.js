const db = require('../config/database');
const { sendPushToParents, sendPushToUser } = require('./push');
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

// Process a new transaction and send appropriate alerts via push notifications
async function processNewTransaction(transaction, cardholderInfo) {
  const { id: transactionId, amount, merchant_name, is_food_delivery } = transaction;
  const { user_id: cardholderId, name: cardholderName, role: cardholderRole } = cardholderInfo;

  let notificationsSent = 0;

  // Get spending status
  const spendingStatus = await getSpendingStatus(cardholderId);

  // 1. Alert to CHILD if food delivery
  if (is_food_delivery && cardholderRole === 'child') {
    if (!(await wasAlertSent(cardholderId, transactionId, 'child_food_delivery'))) {
      const serviceName = getDeliveryServiceName(merchant_name) || 'Food Delivery';
      await sendPushToUser(db, cardholderId, {
        title: '🔴 Food Delivery Alert',
        body: `You spent ${formatCurrency(amount)} at ${serviceName}`,
        data: { type: 'food_delivery', transaction_id: transactionId }
      });
      await recordAlert(cardholderId, transactionId, 'child_food_delivery');
      notificationsSent++;
    }
  }

  // 2. Alert to PARENTS (based on their notification settings)
  const parentSettings = await getParentNotificationSettings();

  for (const parent of parentSettings) {
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
        shouldSend = false;
        break;
    }

    if (shouldSend) {
      const isRefund = transaction.is_refund || false;
      const title = isRefund ? '💚 Refund' : (is_food_delivery ? '🔴 Food Delivery' : 'New Purchase');
      let body = isRefund
        ? `${cardholderName} received ${formatCurrency(amount)} from ${merchant_name}`
        : `${cardholderName} spent ${formatCurrency(amount)} at ${merchant_name}`;

      if (spendingStatus && !isRefund) {
        const percentStr = Math.round(spendingStatus.percent_used);
        body += ` (${percentStr}% of limit)`;
      }

      // Include transaction details for Apple Watch display
      await sendPushToUser(db, parent.id, {
        title,
        body,
        data: {
          type: isRefund ? 'refund' : 'purchase',
          transaction_id: transactionId,
          user_id: cardholderId,
          transaction: {
            amount: amount,
            merchant_name: merchant_name,
            cardholder_name: cardholderName,
            is_refund: isRefund,
            is_food_delivery: is_food_delivery
          }
        }
      });
      await recordAlert(parent.id, transactionId, 'parent_purchase');
      notificationsSent++;
    }
  }

  // 3. Check for spending limit warnings (90% threshold)
  if (spendingStatus && spendingStatus.percent_used >= 90 && spendingStatus.percent_used < 100) {
    const warningKey = `limit_warning_90_${new Date().getMonth()}`;
    if (!(await wasAlertSent(cardholderId, transactionId, warningKey))) {
      await sendPushToParents(db, {
        title: '⚠️ Spending Limit Warning',
        body: `${cardholderName} is at ${Math.round(spendingStatus.percent_used)}% of monthly limit (${formatCurrency(spendingStatus.remaining)} remaining)`,
        data: { type: 'limit_warning', user_id: cardholderId }
      });
      await recordAlert(cardholderId, transactionId, warningKey);
      notificationsSent++;
    }
  }

  // 4. Check for over-limit alert
  if (spendingStatus && spendingStatus.percent_used >= 100) {
    const overKey = `limit_exceeded_${new Date().getMonth()}`;
    if (!(await wasAlertSent(cardholderId, transactionId, overKey))) {
      await sendPushToParents(db, {
        title: '🚨 Limit Exceeded!',
        body: `${cardholderName} has exceeded their monthly limit! ${formatCurrency(spendingStatus.current_spend)} / ${formatCurrency(spendingStatus.monthly_limit)}`,
        data: { type: 'limit_exceeded', user_id: cardholderId }
      });
      await recordAlert(cardholderId, transactionId, overKey);
      notificationsSent++;
    }
  }

  if (notificationsSent > 0) {
    console.log(`[Alerts] Sent ${notificationsSent} push notifications for transaction ${transactionId}`);
  }

  return notificationsSent;
}

// Send subscription renewal reminder via push
async function sendRenewalReminder(subscription) {
  const { merchant_name, amount, next_renewal_date, user_id } = subscription;

  // Get cardholder name
  const userResult = await db.query('SELECT name FROM users WHERE id = $1', [user_id]);
  const cardholderName = userResult.rows[0]?.name || 'Unknown';

  await sendPushToParents(db, {
    title: '📅 Subscription Renewal',
    body: `${merchant_name} (${formatCurrency(amount)}) renews in 3 days - ${cardholderName}'s card`,
    data: { type: 'subscription_renewal', subscription_id: subscription.id }
  });

  console.log(`[Alerts] Sent renewal reminder for ${merchant_name}`);
}

module.exports = {
  processNewTransaction,
  sendRenewalReminder,
  getSpendingStatus,
  formatCurrency,
};
