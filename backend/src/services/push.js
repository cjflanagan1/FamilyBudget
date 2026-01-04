const apn = require('@parse/node-apn');
const path = require('path');

let apnProvider = null;

// Initialize APNs provider
function initAPNs() {
  if (apnProvider) return apnProvider;

  const keyPath = process.env.APNS_KEY_PATH || path.join(__dirname, '../../certs/AuthKey.p8');

  const options = {
    token: {
      key: keyPath,
      keyId: process.env.APNS_KEY_ID,
      teamId: process.env.APNS_TEAM_ID,
    },
    production: process.env.NODE_ENV === 'production',
  };

  try {
    apnProvider = new apn.Provider(options);
    console.log('[APNs] Provider initialized');
    return apnProvider;
  } catch (err) {
    console.error('[APNs] Failed to initialize:', err.message);
    return null;
  }
}

// Send push notification to device tokens
async function sendPushNotification(deviceTokens, { title, body, data = {}, badge, sound = 'default' }) {
  const provider = initAPNs();

  if (!provider) {
    console.error('[APNs] Provider not available - check your APNs configuration');
    return { success: false, error: 'APNs not configured' };
  }

  const notification = new apn.Notification();
  notification.alert = { title, body };
  notification.topic = process.env.APNS_BUNDLE_ID || 'com.familybudget.ios';
  notification.sound = sound;
  notification.payload = data;

  if (badge !== undefined) {
    notification.badge = badge;
  }

  const tokens = Array.isArray(deviceTokens) ? deviceTokens : [deviceTokens];

  try {
    const result = await provider.send(notification, tokens);

    if (result.failed.length > 0) {
      console.error('[APNs] Failed to send to some devices:', result.failed);
    }

    console.log(`[APNs] Sent to ${result.sent.length} devices, failed: ${result.failed.length}`);
    return { success: true, sent: result.sent.length, failed: result.failed.length };
  } catch (err) {
    console.error('[APNs] Send error:', err);
    return { success: false, error: err.message };
  }
}

// Send push to all parent devices
async function sendPushToParents(db, { title, body, data = {} }) {
  const result = await db.query(`
    SELECT DISTINCT dt.device_token
    FROM device_tokens dt
    JOIN users u ON u.id = dt.user_id
    WHERE u.role = 'parent' AND dt.is_active = true
  `);

  if (result.rows.length === 0) {
    console.log('[APNs] No parent devices registered');
    return { success: true, sent: 0 };
  }

  const tokens = result.rows.map(r => r.device_token);
  return sendPushNotification(tokens, { title, body, data });
}

// Send push to specific user's devices
async function sendPushToUser(db, userId, { title, body, data = {} }) {
  const result = await db.query(`
    SELECT device_token FROM device_tokens
    WHERE user_id = $1 AND is_active = true
  `, [userId]);

  if (result.rows.length === 0) {
    console.log(`[APNs] No devices registered for user ${userId}`);
    return { success: true, sent: 0 };
  }

  const tokens = result.rows.map(r => r.device_token);
  return sendPushNotification(tokens, { title, body, data });
}

// Send push to all active devices
async function sendPushToAll(db, { title, body, data = {} }) {
  const result = await db.query(`
    SELECT device_token FROM device_tokens WHERE is_active = true
  `);

  if (result.rows.length === 0) {
    return { success: true, sent: 0 };
  }

  const tokens = result.rows.map(r => r.device_token);
  return sendPushNotification(tokens, { title, body, data });
}

module.exports = {
  initAPNs,
  sendPushNotification,
  sendPushToParents,
  sendPushToUser,
  sendPushToAll,
};
