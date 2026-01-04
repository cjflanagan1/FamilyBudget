// Food delivery service patterns
const FOOD_DELIVERY_PATTERNS = [
  // DoorDash
  /doordash/i,
  /door\s*dash/i,
  /dd\s*doordash/i,

  // Grubhub
  /grubhub/i,
  /grub\s*hub/i,
  /seamless/i, // Grubhub owns Seamless

  // Other delivery services (for future expansion)
  /uber\s*eats/i,
  /ubereats/i,
  /postmates/i,
  /instacart/i,
  /caviar/i,
];

// Check if a merchant is a food delivery service
function isFoodDelivery(merchantName) {
  if (!merchantName) return false;

  return FOOD_DELIVERY_PATTERNS.some((pattern) =>
    pattern.test(merchantName)
  );
}

// Get the delivery service name (normalized)
function getDeliveryServiceName(merchantName) {
  if (!merchantName) return null;

  const name = merchantName.toLowerCase();

  if (/doordash|door\s*dash/.test(name)) return 'DoorDash';
  if (/grubhub|grub\s*hub|seamless/.test(name)) return 'Grubhub';
  if (/uber\s*eats|ubereats/.test(name)) return 'Uber Eats';
  if (/postmates/.test(name)) return 'Postmates';
  if (/instacart/.test(name)) return 'Instacart';
  if (/caviar/.test(name)) return 'Caviar';

  return null;
}

// Categorize a transaction
function categorizeTransaction(merchantName, plaidCategory) {
  // Check food delivery first
  if (isFoodDelivery(merchantName)) {
    return {
      category: 'Food Delivery',
      is_food_delivery: true,
      service_name: getDeliveryServiceName(merchantName),
    };
  }

  // Use Plaid's category if available
  if (plaidCategory) {
    return {
      category: plaidCategory,
      is_food_delivery: false,
      service_name: null,
    };
  }

  return {
    category: 'Other',
    is_food_delivery: false,
    service_name: null,
  };
}

// Common subscription merchants
const SUBSCRIPTION_PATTERNS = [
  { pattern: /netflix/i, name: 'Netflix' },
  { pattern: /spotify/i, name: 'Spotify' },
  { pattern: /hulu/i, name: 'Hulu' },
  { pattern: /disney\+|disney\s*plus/i, name: 'Disney+' },
  { pattern: /hbo\s*max|max\.com/i, name: 'Max' },
  { pattern: /amazon\s*prime/i, name: 'Amazon Prime' },
  { pattern: /apple\.com\/bill|itunes/i, name: 'Apple' },
  { pattern: /google\s*play|google\s*storage/i, name: 'Google' },
  { pattern: /youtube\s*premium/i, name: 'YouTube Premium' },
  { pattern: /paramount\+|paramount\s*plus/i, name: 'Paramount+' },
  { pattern: /peacock/i, name: 'Peacock' },
  { pattern: /audible/i, name: 'Audible' },
  { pattern: /adobe/i, name: 'Adobe' },
  { pattern: /microsoft\s*365|office\s*365/i, name: 'Microsoft 365' },
  { pattern: /dropbox/i, name: 'Dropbox' },
  { pattern: /icloud/i, name: 'iCloud' },
];

// Check if a transaction is likely a subscription
function isLikelySubscription(merchantName, amount, previousTransactions = []) {
  if (!merchantName) return false;

  // Check against known subscription services
  const knownService = SUBSCRIPTION_PATTERNS.find((s) =>
    s.pattern.test(merchantName)
  );

  if (knownService) {
    return { isSubscription: true, serviceName: knownService.name };
  }

  // Check for recurring charges (same merchant, similar amount)
  const similarPrevious = previousTransactions.filter((t) => {
    const sameMerchant = t.merchant_name?.toLowerCase() === merchantName.toLowerCase();
    const similarAmount = Math.abs(t.amount - amount) < 1; // Within $1
    return sameMerchant && similarAmount;
  });

  if (similarPrevious.length >= 2) {
    return { isSubscription: true, serviceName: merchantName };
  }

  return { isSubscription: false, serviceName: null };
}

module.exports = {
  isFoodDelivery,
  getDeliveryServiceName,
  categorizeTransaction,
  isLikelySubscription,
  FOOD_DELIVERY_PATTERNS,
  SUBSCRIPTION_PATTERNS,
};
