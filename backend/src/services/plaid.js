const { Configuration, PlaidApi, PlaidEnvironments } = require('plaid');

const configuration = new Configuration({
  basePath: PlaidEnvironments[process.env.PLAID_ENV || 'sandbox'],
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
      'PLAID-SECRET': process.env.PLAID_SECRET,
    },
  },
});

const plaidClient = new PlaidApi(configuration);

// Create a link token for the Plaid Link flow
async function createLinkToken(userId) {
  const response = await plaidClient.linkTokenCreate({
    user: { client_user_id: userId.toString() },
    client_name: 'Family Budget',
    products: ['transactions'],
    country_codes: ['US'],
    language: 'en',
  });
  return response.data;
}

// Exchange public token for access token
async function exchangePublicToken(publicToken) {
  const response = await plaidClient.itemPublicTokenExchange({
    public_token: publicToken,
  });
  return response.data;
}

// Get accounts for an item
async function getAccounts(accessToken) {
  const response = await plaidClient.accountsGet({
    access_token: accessToken,
  });
  return response.data.accounts;
}

// Sync transactions (uses the new sync endpoint)
async function syncTransactions(accessToken, cursor = null) {
  const request = {
    access_token: accessToken,
  };
  if (cursor) {
    request.cursor = cursor;
  }

  const response = await plaidClient.transactionsSync(request);
  return response.data;
}

// Get transactions for a date range (fallback method)
async function getTransactions(accessToken, startDate, endDate) {
  const response = await plaidClient.transactionsGet({
    access_token: accessToken,
    start_date: startDate,
    end_date: endDate,
  });
  return response.data;
}

// Refresh transactions (force update)
async function refreshTransactions(accessToken) {
  const response = await plaidClient.transactionsRefresh({
    access_token: accessToken,
  });
  return response.data;
}

module.exports = {
  plaidClient,
  createLinkToken,
  exchangePublicToken,
  getAccounts,
  syncTransactions,
  getTransactions,
  refreshTransactions,
};
