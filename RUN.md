# Running Family Budget

## Prerequisites
- PostgreSQL 15 (Homebrew)
- Node.js
- Xcode

## 1. Start PostgreSQL

```bash
brew services start postgresql@15
```

## 2. Start Backend

```bash
cd backend
npm run dev
```

Backend runs at `http://localhost:3000`

## 3. Run iOS App

Open in Xcode:
```bash
open ios/FamilyBudget/FamilyBudget.xcodeproj
```

Or build from command line:
```bash
cd ios/FamilyBudget
xcodebuild -scheme FamilyBudget -destination 'generic/platform=iOS' build
```

## Database

Run migrations:
```bash
cd backend
npm run db:migrate
```

Database: `family_budget` on localhost:5432

## Stop Services

```bash
brew services stop postgresql@15
```
