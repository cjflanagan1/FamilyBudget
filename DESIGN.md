# Family Budget - Design Document

## Overview

Family Budget is an iOS app for tracking American Express credit card spending. It connects to Amex via Plaid to sync transactions automatically and provides spending insights, subscription tracking, and alerts.

**Primary User:** CJ (account holder, user_id = 2)

**Plaid Limitation:** Plaid pulls transactions at the account level, not per-card. Authorized users on the same Amex account cannot be tracked separately.

---

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   iOS App       │────▶│  Node.js API    │────▶│  PostgreSQL     │
│   (SwiftUI)     │     │  (Express)      │     │  (family_budget)│
└─────────────────┘     └─────────────────┘     └─────────────────┘
                               │
                               ▼
                        ┌─────────────────┐
                        │  Plaid API      │
                        │  (Transactions) │
                        └─────────────────┘
```

---

## Database Schema

| Table | Purpose |
|-------|---------|
| `users` | Family members (Terry, CJ, Paige, Haley) |
| `cards` | Linked credit cards with Plaid access tokens |
| `transactions` | All transactions synced from Plaid |
| `subscriptions` | Recurring charges (detected or manual) |
| `spending_limits` | Monthly spending limits per user |
| `alerts_sent` | Log of SMS alerts sent (prevents duplicates) |
| `notification_settings` | Per-user alert preferences |
| `device_tokens` | iOS push notification tokens |
| `infraction_vendors` | Banned vendor list (unused - feature removed) |

---

## Backend Structure

### `/backend/src/`

#### Core
| File | Purpose |
|------|---------|
| `index.js` | Express server entry point, route registration |
| `config/database.js` | PostgreSQL connection pool |
| `config/migrate.js` | Database schema migrations |

#### Routes (API Endpoints)
| File | Endpoints | Purpose |
|------|-----------|---------|
| `routes/users.js` | `/api/users` | User CRUD, phone updates |
| `routes/transactions.js` | `/api/transactions` | List transactions, summaries, categories |
| `routes/subscriptions.js` | `/api/subscriptions` | Subscription CRUD, upcoming renewals |
| `routes/limits.js` | `/api/limits` | Spending limits, status checks |
| `routes/plaid.js` | `/api/plaid` | Link tokens, card management, balances |
| `routes/notifications.js` | `/api/notifications` | Device token registration |
| `routes/infractions.js` | `/api/infractions` | Banned vendors (unused) |

#### Services
| File | Purpose |
|------|---------|
| `services/plaid.js` | Plaid API client wrapper |
| `services/twilio.js` | SMS sending via Twilio |
| `services/alerts.js` | Spending alert logic |
| `services/subscriptions.js` | Subscription detection from transactions |
| `services/reports.js` | Weekly summary generation |
| `services/push.js` | iOS push notifications (APNs) |

#### Jobs (Background Tasks)
| File | Purpose |
|------|---------|
| `jobs/syncTransactions.js` | Sync transactions from Plaid (runs on interval) |
| `jobs/checkRenewals.js` | Check for upcoming subscription renewals |
| `jobs/weeklySummary.js` | Send weekly spending summaries |

#### Utils
| File | Purpose |
|------|---------|
| `utils/merchantDetection.js` | Categorize merchants, detect subscriptions |
| `utils/unusualSpend.js` | Detect unusual spending patterns |

---

## iOS App Structure

### `/ios/FamilyBudget/FamilyBudget/`

#### Entry Point
| File | Purpose |
|------|---------|
| `FamilyBudgetApp.swift` | App entry, TabView with 4 tabs |
| `AppDelegate.swift` | Push notification handling |

#### Models
| File | Purpose |
|------|---------|
| `User.swift` | User model with spending limits |
| `Transaction.swift` | Transaction model, SpendingSummary, CategorySpend |
| `Subscription.swift` | Subscription model |
| `SpendingLimit.swift` | SpendingLimit, SpendingStatus, CardBalance |

#### Services
| File | Purpose |
|------|---------|
| `APIClient.swift` | HTTP client for all API calls |
| `DebugManager.swift` | Debug mode, API URL switching (local vs production) |
| `PlaidLinkHandler.swift` | Plaid Link SDK integration |

#### ViewModels
| File | Purpose |
|------|---------|
| `DashboardViewModel.swift` | Dashboard data fetching |

#### Views
| File | Purpose |
|------|---------|
| `DashboardView.swift` | Home tab - balance, recent transactions, alerts |
| `TransactionListView.swift` | Transactions tab - searchable list |
| `SubscriptionsView.swift` | Subs tab - recurring charges |
| `SettingsView.swift` | Settings tab - linked cards management |
| `CardholderListView.swift` | (Unused - Family tab removed) |
| `TrendsView.swift` | Spending trends charts |
| `LimitsSettingsView.swift` | Spending limit configuration |
| `DeveloperModeView.swift` | Debug settings (hidden, tap version 7x) |

---

## Watch App

### `/ios/FamilyBudget/FamilyBudgetWatch/`

| File | Purpose |
|------|---------|
| `FamilyBudgetWatchApp.swift` | Watch app entry point |
| `ContentView.swift` | Main watch UI - balance, spending summary |
| `NotificationController.swift` | Watch notification handling |

---

## App Tabs (Current)

1. **Home** - Dashboard with balance, spending, recent transactions
2. **Transactions** - Full transaction list with search
3. **Subs** - Subscription tracking
4. **Settings** - Card management, developer mode

---

## Key Features

### Transaction Sync
- Plaid syncs transactions automatically via `syncTransactions.js`
- Runs every 30 minutes when backend is running
- Detects subscriptions automatically from recurring merchants

### Alerts
- SMS alerts via Twilio when spending threshold exceeded
- Configurable per-user (all transactions, threshold only, or off)

### Developer Mode
- Hidden in Settings - tap version number 7 times
- Allows switching between local and production API
- Shows API request/response logging

---

## Environment Variables (Backend)

```
DATABASE_URL=postgresql://localhost:5432/family_budget
PLAID_CLIENT_ID=xxx
PLAID_SECRET=xxx
PLAID_ENV=production
TWILIO_ACCOUNT_SID=xxx
TWILIO_AUTH_TOKEN=xxx
TWILIO_PHONE_NUMBER=+1xxx
APNS_KEY_ID=xxx
APNS_TEAM_ID=xxx
```

---

## Deployment

- **Backend:** Railway (auto-deploys from GitHub main branch)
- **Database:** Railway PostgreSQL
- **iOS:** Xcode direct to device (TestFlight not set up)

---

## Removed Features

These were built but removed due to Plaid limitations:

- **Family Tab** - Per-family-member spending (Plaid can't distinguish cards)
- **Reports Tab** - Gauges, pie charts, infractions
- **Infractions** - Banned vendor tracking

The backend routes still exist but iOS doesn't use them.
