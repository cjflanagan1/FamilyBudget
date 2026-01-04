# Family Budget Backend - Setup Complete ✅

## Server Status
- **Status**: Running ✅
- **URL**: http://localhost:3000
- **Environment**: development
- **Database**: PostgreSQL (family_budget)

## Configuration

### Environment Variables
The `.env` file has been configured with:
- **Database**: `postgresql://localhost/family_budget`
- **Plaid**: Sandbox mode with test credentials (ready for real credentials)
- **Twilio**: Test mode enabled (logs SMS instead of sending)
- **Port**: 3000
- **Node Environment**: development

### Database Setup
- Database created: `family_budget`
- Tables created and initialized
- 4 family members pre-populated:
  - Terry (parent)
  - CJ (parent)
  - Paige (child)
  - Haley (child)

## API Endpoints Available

### Users
- `GET /api/users` - Get all family members
- `GET /api/users/:id` - Get specific user
- `PATCH /api/users/:id/phone` - Update phone number
- `PATCH /api/users/:id/notifications` - Update notification settings

### Transactions
- `GET /api/transactions` - Get transactions
- `GET /api/transactions/summary` - Get spending summary
- `GET /api/transactions/by-category` - Get category breakdown
- `GET /api/transactions/top-merchants` - Get top merchants

### Spending Limits
- `GET /api/limits` - Get all spending limits
- `GET /api/limits/:userId` - Get user's limit
- `PUT /api/limits/:userId` - Update spending limit
- `GET /api/limits/status/all` - Get all spending status

### Subscriptions
- `GET /api/subscriptions` - Get subscriptions
- `GET /api/subscriptions/upcoming` - Get upcoming renewals
- `POST /api/subscriptions` - Add subscription
- `PUT /api/subscriptions/:id` - Update subscription
- `DELETE /api/subscriptions/:id` - Delete subscription

### Plaid Integration
- `POST /api/plaid/create-link-token` - Create Plaid link token
- `POST /api/plaid/exchange-token` - Exchange public token
- `GET /api/plaid/cards/:userId` - Get linked cards

## Next Steps to Production

### 1. Get Real Credentials
- **Plaid**: 
  - Sign up at https://dashboard.plaid.com
  - Copy your Client ID and Secret
  - Update in `.env`: `PLAID_CLIENT_ID` and `PLAID_SECRET`
  - Change `PLAID_ENV` from `sandbox` to `development` or `production`

- **Twilio** (for SMS alerts):
  - Sign up at https://console.twilio.com
  - Get Account SID and Auth Token
  - Get a Twilio phone number
  - Update in `.env`: `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_PHONE_NUMBER`

- **Family Phone Numbers**:
  - Update `PHONE_TERRY`, `PHONE_CJ`, `PHONE_PAIGE`, `PHONE_HALEY` in `.env`

### 2. Deployment Options
- **Railway.app**: Popular for Node.js + PostgreSQL
- **Render.com**: Easy deployment with free tier
- **Heroku**: Classic choice (now has paid tiers)
- **AWS**: Most control, but more complex

### 3. Update iOS App
- In DebugManager or production config, update `apiBaseURL` to your backend URL
- Example: `https://your-app-backend.railway.app`

### 4. Enable Push Notifications
- Set up APNs (Apple Push Notification Service)
- Add push notification certificates in Xcode

## Testing the API

```bash
# Get all users
curl http://localhost:3000/api/users

# Get spending summary
curl http://localhost:3000/api/transactions/summary

# Get spending limits
curl http://localhost:3000/api/limits

# Create a spending limit
curl -X PUT http://localhost:3000/api/limits/1 \
  -H "Content-Type: application/json" \
  -d '{"monthly_limit": 1000}'
```

## Running the Backend

### Start Server
```bash
cd "/Users/cjflanagan/Desktop/Family Budget/backend"
npm start
```

### Start in Development with Auto-reload
```bash
npm run dev
```

### Run Database Migrations
```bash
npm run db:migrate
```

### Stop Server
```bash
pkill -f "node src/index.js"
```

## Scheduled Jobs

The backend automatically runs these tasks:
- **Every 5 minutes**: Sync transactions from Plaid
- **Daily at 9 AM**: Check for subscription renewals (3-day warnings)
- **Every Sunday at 9 AM**: Send weekly spending summaries

## Test Mode
Currently:
- Twilio is in **test mode** (logs SMS instead of sending)
- All SMS messages will appear in console logs
- Once you add real Twilio credentials, actual SMS will be sent

## Troubleshooting

### Database Connection Error
```
Error: connect ECONNREFUSED 127.0.0.1:5432
```
Solution: Ensure PostgreSQL is running
```bash
brew services start postgresql@15
```

### Port 3000 Already in Use
```bash
# Kill existing process
lsof -ti:3000 | xargs kill -9
```

### Transaction Sync Failing
This is normal until Plaid credentials are configured. Cards table is empty, so nothing syncs.

## Current Test Data

Users:
- Terry (ID: 1) - parent
- CJ (ID: 2) - parent  
- Paige (ID: 3) - child
- Haley (ID: 4) - child

Once you link real Amex cards via Plaid, transactions will start syncing automatically.
