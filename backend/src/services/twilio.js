const twilio = require('twilio');

let client = null;
const FROM_NUMBER = process.env.TWILIO_PHONE_NUMBER;
const isTestMode = !process.env.TWILIO_ACCOUNT_SID || !process.env.TWILIO_ACCOUNT_SID.startsWith('AC');

if (!isTestMode) {
  client = twilio(
    process.env.TWILIO_ACCOUNT_SID,
    process.env.TWILIO_AUTH_TOKEN
  );
}

// Send SMS to a single recipient
async function sendSMS(to, message) {
  try {
    if (isTestMode) {
      console.log(`[TEST MODE] SMS to ${to}: "${message}"`);
      return { sid: `test_${Date.now()}`, to, body: message };
    }

    const result = await client.messages.create({
      body: message,
      from: FROM_NUMBER,
      to: to,
    });
    console.log(`SMS sent to ${to}: ${result.sid}`);
    return result;
  } catch (err) {
    console.error(`Failed to send SMS to ${to}:`, err.message);
    throw err;
  }
}

// Send SMS to multiple recipients
async function sendSMSToMany(recipients, message) {
  const results = await Promise.allSettled(
    recipients.map((to) => sendSMS(to, message))
  );

  const succeeded = results.filter((r) => r.status === 'fulfilled').length;
  const failed = results.filter((r) => r.status === 'rejected').length;

  console.log(`SMS sent: ${succeeded} succeeded, ${failed} failed`);
  return results;
}

// Send different messages to different recipients
async function sendPersonalizedSMS(messages) {
  // messages = [{ to: '+1234567890', body: 'Hello' }, ...]
  const results = await Promise.allSettled(
    messages.map((msg) => sendSMS(msg.to, msg.body))
  );
  return results;
}

module.exports = {
  sendSMS,
  sendSMSToMany,
  sendPersonalizedSMS,
};
