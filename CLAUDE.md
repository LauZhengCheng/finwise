# FinWise — FYP Project
# Programmer : Lau Zheng Cheng (TP071393)
# Institution : Asia Pacific University (APU)

---

## Project Vision

**FinWise** is an AI-powered 24/7 Virtual Financial Advisor Android mobile app.
This is a simulation system — NOT a real banking app.
All financial operations use simulated/mock data.

**Core Concept:** Instead of one big bank balance, users have personalised
"vaults" (spending categories) and "goals" (saving targets). AI advisor named
Aion monitors spending, gives real-time advice, intercepts risky transactions,
and proactively guides users toward financial wellness — replacing everything
a real human financial advisor does.

**Academic Context:** FYP for APU — demonstrating RAG architecture,
agentic AI behaviour, and positive friction design for impulse spending control.

**The app covers the 7 roles of a real Financial Advisor:**
1. Budget & Cash Flow Management → Traffic Controller + Vault System
2. Savings & Goal Planning → Goal vaults + Goal Guardian + Goal Timeline Calculator
3. Debt Management → Debt tracker, payoff strategy, Aion debt advice
4. Investment Planning → TradingView charts + Aion investment roadmap
5. Protection Planning → Emergency fund analysis + insurance awareness prompts
6. Tax & Financial Health → Financial Health Score (FHN FinHealth Score)
7. Continuous Monitoring & Advice → Proactive notifications + Advisory Chat (Aion)

---

## Tech Stack

### Backend (Node.js)

| Package | Purpose |
|---|---|
| express | HTTP server framework |
| @supabase/supabase-js | Supabase client (PostgreSQL + Auth + Realtime) |
| @google/genai | Gemini 2.5 Flash via Vertex AI (ADC auth) |
| @langchain/langgraph | Aion ReAct agent framework — 16 tools + orchestration |
| @langchain/google-vertexai | LangGraph ↔ Vertex AI integration |
| zod | Schema validation for LangGraph tool inputs/outputs |
| mongoose | MongoDB Atlas ODM for document collections |
| ioredis | Redis client (Upstash) for caching layer |
| bullmq | Job queue backed by Redis — background workers |
| axios | HTTP client for Jina AI Reader + external APIs |
| rss-parser | Parse RSS feeds for financial news |
| helmet | HTTP security headers |
| express-rate-limit | API rate limiting |
| hpp | HTTP parameter pollution protection |
| express-mongo-sanitize | NoSQL injection prevention |
| cors | Cross-origin resource sharing |
| dotenv | Environment variable loading |
| winston | Structured application logging |
| morgan | HTTP request logging |
| @sentry/node | Backend error tracking (planned) |
| finnhub | Real-time US stock quotes for ticker row (60 calls/min free) |

### Frontend (Flutter / Dart)

| Package | Purpose |
|---|---|
| flutter_riverpod | State management |
| go_router | Navigation + auth redirect |
| dio | HTTP client — injects JWT automatically |
| supabase_flutter | Auth + Realtime subscriptions |
| mobile_scanner | QR code camera scanning |
| fl_chart | Spending donut chart + line charts |
| flutter_inappwebview | TradingView WebView for investment charts |
| flutter_secure_storage | Secure local storage |
| firebase_core | Firebase SDK base |
| firebase_messaging | Push notifications (FCM) |
| firebase_analytics | User analytics |
| lottie | Goal completion celebration animation |
| shimmer | Loading skeleton shimmer effect |
| timeline_tile | Allocation history vertical timeline |
| url_launcher | Open bank FD application URLs |
| share_plus | Share content |
| qr_flutter | QR code generation for P2P receive |
| cached_network_image | Network image caching |
| flutter_launcher_icons | App launcher icon generation |
| sentry_flutter | Frontend error tracking (planned) |
| intl | Date/number formatting |

### Cloud & Infrastructure

| Service | Purpose |
|---|---|
| Google Cloud Run | Backend deployment — auto Vertex AI auth via ADC |
| Google Cloud Scheduler | Triggers daily BullMQ scraping jobs via HTTP |
| Google Artifact Registry | Docker image storage for Cloud Run |
| Google Cloud Build | CI/CD pipeline — auto-deploy on git push |
| Google Cloud Monitoring | Uptime checks + alerting |
| Google Secret Manager | Secure storage for API keys (production) |
| Vertex AI (Gemini 2.5 Flash) | Core AI model — all Gemini calls |
| Vertex AI (text-embedding-004) | Session embeddings for RAG |
| Supabase | PostgreSQL + Auth + Realtime + pgvector + RLS |
| MongoDB Atlas | Document store — FD rates, deals, news, market cache, stock listings, volatility cache (free M0, Singapore) |
| Upstash Redis | Serverless Redis — cache layer for FD/market/news data |
| Firebase | FCM push notifications + Analytics + Crashlytics |
| LangSmith | LangGraph agent observability — traces, tool call logs (planned) |
| Sentry | Error monitoring — backend + Flutter (planned) |
| Docker | Containerisation for consistent deployment |

### External APIs & Data Sources

| API | Purpose | Cache TTL |
|---|---|---|
| Jina AI Reader (`r.jina.ai/{url}`) | Scrape iMoney / RinggitPlus FD rates as clean Markdown | 6 hours |
| Jina AI Reader | Scrape merchant deals from loopme.my / shopback.my | 6 hours |
| Alpha Vantage | Stock historical data (volatility) + US stock/ETF listings | 24h / 7d |
| CoinGecko | Crypto prices (top 100) + historical data (volatility) | 1 min / 6h |
| Finnhub | Real-time US stock quotes (S&P 500) + symbol list | 5 min |
| ExchangeRate-API | Forex rates (160+ MYR pairs) | 6 hours |
| NewsAPI.org | Financial news (50 articles, broad finance query) | 2 hours |

**ADC Auth note:** Vertex AI calls (Gemini + embeddings) use Application Default Credentials.
No JSON key file. Works locally via `gcloud auth application-default login`.
Works on Cloud Run automatically via the service account.

### API Rate Limits

| API | Limit | Budget Strategy |
|---|---|---|
| Alpha Vantage | **25 calls/day** | TTLs are tight — 24h for prices/volatility, 7d for listings |
| CoinGecko (Demo) | **10,000 calls/month** | Generous headroom — 1 min TTL for list, 6h for volatility |
| ExchangeRate-API | **1,500 calls/month** | 6h TTL keeps well under |
| NewsAPI.org | **100 calls/day** | Fetched on startup (dev) or every 2h (prod) |

### 4-Tier Cache Architecture: Redis → MongoDB Fresh → API → MongoDB Stale

All external data follows this flow:
1. **Tier 1 — Redis** → hit → return immediately (fastest)
2. **Tier 2 — MongoDB fresh** (within same TTL as Redis) → return, skip API call
3. **Tier 3 — External API** → call → write to BOTH Redis + MongoDB → return
4. **Tier 4 — MongoDB stale** (any data, expired) → last resort when API also fails → return old data

Tier 2 and Tier 4 are the SAME MongoDB, checked twice — first with freshness (within TTL),
second without (any data). This prevents burning API calls when Redis is down (Tier 2),
and ensures users always see data even when everything else fails (Tier 4).

In production (Redis working): Tier 1 handles 99% of reads, Tier 2-4 rarely touched.
In development (Redis down): Tier 2 takes over with identical TTLs, API only called when truly expired.

**Supabase (PostgreSQL)** = all user/relational data (profiles, vaults, transactions, debts, investments, etc.)
**MongoDB Atlas** = all external/scraped data (news, FD rates, deals, market prices, stock listings)
**Redis (Upstash)** = fast cache layer on top of MongoDB, controls refresh frequency via TTL
**Firebase** = push notifications only (FCM)

### Investment Data — Calling Patterns & Cache TTLs

**CoinGecko calls:**

| Data | Endpoint | Batch? | Redis Key | Redis TTL | MongoDB? |
|---|---|---|---|---|---|
| Crypto list (100 coins + prices) | `/coins/markets?per_page=100` | 1 call = all 100 | `crypto:market_list` | 1 min | `market_data_cache` |
| Crypto volatility (90-day history) | `/coins/{id}/market_chart?days=90` | 1 call = 1 coin | `volatility:{TICKER}` | 6 hours | `volatility_cache` |

- Crypto list also writes individual `market:BTCUSD` etc. for Aion analysis / LangGraph tools
- Crypto volatility: 2 held crypto = 2 API calls when cache expired. Within TTL = 0 calls.
- Volatility stores calculated number only (e.g. `65.2`), not raw 90-day history

**Alpha Vantage calls:**

| Data | Endpoint | Batch? | Redis Key | Redis TTL | MongoDB? |
|---|---|---|---|---|---|
| Stock/ETF listings (names only) | `LISTING_STATUS` | 1 call = all ~8000 | `invest:stock_listings` | 7 days | `stock_listings` |
| Stock/ETF price (per ticker) | `GLOBAL_QUOTE` | 1 call = 1 ticker | `market:{TICKER}` | 24 hours | `market_data_cache` |
| Stock volatility (90-day history) | `TIME_SERIES_DAILY` | 1 call = 1 ticker | `volatility:{TICKER}` | 24 hours | `volatility_cache` |
| Stock current prices (SPY, QQQ) | `GLOBAL_QUOTE` | 1 call = 1 ticker | `market:SPY` etc. | 24 hours | `market_data_cache` |

- Stock volatility also extracts latest close price → writes `market:{TICKER}` (saves a separate GLOBAL_QUOTE call)
- Held tickers' prices come free from volatility fetch → quote-on-tap only needed for NEW tickers

**Other APIs:**

| Data | Endpoint | Redis Key | Redis TTL | MongoDB? |
|---|---|---|---|---|
| FX rates | ExchangeRate-API `/latest/MYR` | `market:MYR{CUR}` | 6 hours | `market_data_cache` |
| Financial news | NewsAPI `/v2/everything` (50 articles, broad finance query) | `news` (top 10 for Aion) | 2 hours | `NewsArticle` |
| FD rates | Jina AI Reader + Gemini | `fd_rates` | 6 hours | `FDRate` |
| Deals | Jina AI Reader + Gemini | `deals:{category}` | 6 hours | `Deal` |

**Production estimated usage (per month):**

| API | Usage | Limit | % Used |
|---|---|---|---|
| Alpha Vantage | ~12 calls/day = ~360/month | 750/month (25/day) | 48% |
| CoinGecko | ~1,300 calls/month | 10,000/month | 13% |
| ExchangeRate-API | ~120 calls/month (6h refresh) | 1,500/month | 8% |

**Market Data** — NO Cloud Scheduler. Refreshed on-demand by user requests when TTL expires.
`refreshAllMarketData()` runs once on server startup (via `setTimeout`) to populate initial data.
After that, each endpoint checks Redis → calls API only when TTL expired → writes Redis + MongoDB.

---

## Project Structure

```
C:\fyp-neobanking\
  backend\
    config\
      supabase.js            — Supabase client singleton
      gemini.js              — Vertex AI Gemini client (ADC auth)
      mongodb.js             — Mongoose connection to MongoDB Atlas
      redis.js               — ioredis client for Upstash Redis
      bullmq.js              — BullMQ queue + worker setup
      aiWhitelist.js         — Allowed AI update fields whitelist
      firebase.js            — Firebase Admin SDK initialisation for FCM
    controllers\
      aiController.js        — All AI routes (chat, onboarding, profile, vault changes)
      vaultController.js     — Vault CRUD
      transactionController.js
      incomeController.js    — Salary + general deposit
      authController.js      — Profile read/update
      financeController.js   — Health score, FD rates, deals, news, insurance, ticker, protection
      debtController.js      — Debt CRUD + payoff strategy
      investController.js    — Investment holdings CRUD
      transferController.js  — P2P transfer send/receive
      billController.js      — Bill reminders CRUD
      achievementController.js — Achievement unlock logic (derived, no table)
      jobController.js       — BullMQ job trigger endpoints (for Cloud Scheduler)
      notificationController.js — FCM token registration + push send
    middleware\
      auth.js                — JWT verification via Supabase, sets req.user
      errorHandler.js        — Centralised error handler (registered LAST in server.js)
      aiValidator.js         — Validates AI request payloads
    routes\
      auth.js                — /api/auth/...
      ai.js                  — /api/ai/...
      vaults.js              — /api/vaults/...
      transactions.js        — /api/transactions/...
      income.js              — /api/income/...
      finance.js             — /api/finance/... (FD, deals, news, health score)
      debt.js                — /api/debt/...
      invest.js              — /api/invest/...
      transfer.js            — /api/transfer/...
      bills.js               — /api/bills/...
      achievements.js        — /api/achievements/...
      jobs.js                — /api/jobs/... (Cloud Scheduler webhook endpoints)
      notifications.js       — /api/notifications/...
    services\
      geminiService.js       — All Gemini prompt builders + safeGeminiCall()
      supabaseService.js     — getProfile(), getUserVaults(), getRecentTransactions(), etc.
      validationService.js   — Business logic validation
      notificationService.js — FCM push notification sending
      langGraphService.js    — Aion LangGraph ReAct agent runner
      aionTools.js           — 16 callable tools for Aion agent
      profileUpdateService.js — Continuous AI profile updates after every financial event
      marketDataService.js   — Alpha Vantage + CoinGecko + FX data
      scrapeService.js       — Jina AI Reader → Gemini extraction → MongoDB/Redis
      embeddingService.js    — Vertex AI text-embedding-004 for RAG + multi-query search
      newsService.js         — NewsAPI fetch + Gemini summarisation
      cacheService.js        — Redis cache read/write helpers (get, set, invalidate)
      healthScoreService.js  — FHN Financial Health Score calculation (8 indicators)
    workers\
      fdScrapeWorker.js      — Daily FD rate scraping job
      dealsScrapeWorker.js   — Daily deals scraping job
      newsFetchWorker.js     — Hourly news fetch job
      marketDataWorker.js    — 15-min market data refresh job
    models\ (Mongoose schemas for MongoDB)
      FDRate.js
      Deal.js
      NewsArticle.js
      MarketDataCache.js
      StockListing.js
      VolatilityCache.js
    constants\
      index.js               — All enums and constants
    server.js                — Express entry point, port 3000
    Dockerfile               — Container definition for Cloud Run (created at deployment)
    docker-compose.yml       — Local development with all services (created at deployment)
    .env                     — All environment variables (see section below)

  frontend\
    lib\
      main.dart              — Supabase init, Firebase init, ProviderScope, MaterialApp.router
      config\
        app_router.dart      — GoRouter — all routes + auth redirect logic
        app_theme.dart       — Material3 dark theme, colours, AppTheme class
        app_config.dart      — baseUrl (localhost dev / Cloud Run prod)
      constants\
        app_constants.dart   — All enums: TransactionStatus, VaultType, etc.
      models\
        vault_model.dart
        message_model.dart
      providers\
        auth_provider.dart
        onboarding_provider.dart
        vault_provider.dart
        notification_provider.dart
        debt_provider.dart
        finance_provider.dart
        achievement_provider.dart
        pending_income_provider.dart
      screens\
        auth\
          welcome_screen.dart        — animated entrance
          login_screen.dart          — friendly error messages
          register_screen.dart
        onboarding\
          onboarding_screen.dart
          widgets\
            chat_bubble.dart
            chat_input.dart
        dashboard\
          dashboard_screen.dart
          widgets\
            vault_card.dart
            fund_card.dart
            spending_chart.dart      — real-time spending breakdown
        chat\
          chat_screen.dart           — LangGraph 16-tool Aion chat
        grow\
          grow_screen.dart           — Health Score hero + 2x2 grid
          debt_screen.dart
          debt_strategy_screen.dart
          investment_screen.dart     — USD/MYR toggle + risk score
          holdings_edit_screen.dart  — 3-tab Crypto/Stocks/ETF
          tradingview_screen.dart    — full-screen TradingView chart
          protection_screen.dart    — emergency fund + insurance checklist
          health_score_screen.dart  — FHN gauge + Aion advice
        discover\
          discover_screen.dart      — scrolling tickers + 3 image cards
          fd_marketplace_screen.dart
          deals_screen.dart
          news_screen.dart
          spending_forecast_screen.dart
          loan_calculator_screen.dart
        transaction\
          qr_scanner_screen.dart
          salary_deposit_screen.dart
          salary_preview_screen.dart
          general_deposit_screen.dart
          merchant_pay_screen.dart
          transaction_history_screen.dart
          vault_detail_screen.dart
          transfer_screen.dart
          receive_screen.dart
          widgets\
            active_pilot_popup.dart
            goal_guardian_popup.dart
        profile\
          profile_screen.dart          — Financial Profile (read-only)
          account_profile_screen.dart  — Account Profile (edit + password OTP)
          achievements_screen.dart
          bill_reminders_screen.dart
      services\
        api\
          auth_api.dart
          ai_api.dart
          vault_api.dart
          transaction_api.dart
          income_api.dart
          finance_api.dart     — health score, FD rates, deals, news, insurance, ticker
          debt_api.dart
          invest_api.dart
          transfer_api.dart
          notification_api.dart
      widgets\                 — Shared widgets (shimmer_loading, goal_celebration_overlay)
    android\
    pubspec.yaml

  database\
    schema.sql               — Complete SQL for all Supabase tables

  qr_codes.html              — Printable QR codes for demo (21 total)
```

---

## Environment Variables (.env)

```
SUPABASE_URL=
SUPABASE_ANON_KEY=
GOOGLE_CLOUD_PROJECT=
GOOGLE_CLOUD_LOCATION=asia-southeast1
MONGODB_URI=
UPSTASH_REDIS_URL=
UPSTASH_REDIS_TOKEN=
ALPHA_VANTAGE_API_KEY=
COINGECKO_API_KEY=
EXCHANGERATE_API_KEY=
NEWS_API_KEY=
FINNHUB_API_KEY=
FIREBASE_SERVICE_ACCOUNT_PATH=
JOB_TRIGGER_SECRET=
LANGSMITH_API_KEY=
SENTRY_DSN=
PORT=3000
NODE_ENV=development
```

---

## Database Architecture

### Supabase (PostgreSQL) — 16 Tables

All tables have RLS enabled. Users can only access their own data.

| # | Table | Purpose | Status |
|---|---|---|---|
| 1 | `profiles` | User identity — id, full_name, email, phone_number, fcm_token, created_at, updated_at | ✅ |
| 2 | `onboarding_profiles` | User-declared financial facts + `insurance_coverage` JSONB (5 types) | ✅ |
| 3 | `ai_financial_profiles` | AI-concluded intelligence — classification, key_insights, recommendations | ✅ |
| 4 | `vaults` | Personalised spending vaults and saving goals | ✅ |
| 5 | `vault_transfers` | Money movements between vaults (Active Pilot + P2P source) | ✅ |
| 6 | `transactions` | Every transaction attempt with full Goal Guardian data | ✅ |
| 7 | `merchant_qr_codes` | 21 seeded QR codes (20 merchants + 1 salary + 1 general deposit) | ✅ |
| 8 | `income_injections` | Salary deposit records with allocation_snapshot + carryover_snapshot | ✅ |
| 9 | `ai_logs` | All AI interactions — chat, proactive, goal guardian, background analysis | ✅ |
| 10 | `allocation_history` | Append-only timeline of all AI allocation recommendation changes | ✅ |
| 11 | `debts` | User debt records — loans, credit cards, BNPL, etc. | ✅ |
| 12 | `investments` | User investment holdings — stocks, crypto, ETF | ✅ |
| 13 | `bills` | Recurring bill reminders with due dates and vault links | ✅ |
| 14 | `p2p_transfers` | Peer-to-peer transfer records between users | ✅ |
| 15 | `bill_payment_history` | FHN: tracks each bill payment cycle with on-time flag | ✅ |
| 16 | `debt_balance_snapshots` | FHN: tracks debt balance changes over time for trending | ✅ |

**Financial Health Score** is derived on-the-fly from existing tables (FHN methodology) —
no dedicated storage. Uses: vaults, debts, bills, bill_payment_history, debt_balance_snapshots, onboarding_profiles.insurance_coverage.

### Key Field Rules — Existing Tables

**vaults:**
- `vault_type` CHECK IN ('vault', 'fund')
  - `vault` = spending category — no goal fields
  - `fund` = saving goal — must have `linked_goal` and `goal_target_amount`
- `UNIQUE(user_id, category_key)` — unique per user, not globally
- `current_balance` carries over monthly — NEVER resets
- `spent_amount` resets to 0 each income cycle
- `allocated_amount` updates each income cycle
- `category_key` must always be lowercase_underscore format
- Soft-delete only: `is_active = false` — never hard-delete (transaction history preserved)

**onboarding_profiles — financial_goals JSONB:**
```json
{
  "goals": [
    { "goal": "Trip to Japan", "timeline": "1 year", "priority": "short-term", "added_date": "2026-05-23" }
  ]
}
```

**ai_financial_profiles:**
- `behavioral_classification` ENUM (DB-enforced):
  `disciplined_saver`, `balanced_spender`, `impulse_spender`,
  `risk_averse`, `high_variability_spender`, `goal_oriented_spender`
- `recommended_allocation` JSONB — must always sum to 100%
- `key_insights` JSONB — Aion's observed intelligence (see AI Memory section)

**ai_logs:**
- `interaction_type` CHECK IN: `'chat'`, `'goal_guardian'`, `'background_analysis'`, `'proactive'`, `'system_notification'`
- `validation_status` CHECK IN: `'passed'`, `'schema_failed'`, `'business_logic_failed'`, `'fallback_used'`
- `is_proactive` BOOLEAN — true for Aion-initiated messages shown in dashboard notification card
- `ai_response` — for `chat` type: JSON `{message}`. For `proactive` type: plain string
- `embedding` VECTOR(768) — for RAG (added when RAG is implemented)

**transactions:**
- `status` CHECK IN ('approved', 'blocked', 'cancelled')
- `transaction_type` CHECK IN ('expense', 'income', 'transfer')
- `ai_categorisation_attempts` — max 2 retries, then user manually picks vault

**profiles:**
- `fcm_token TEXT` — stores latest FCM device token, updated on app open
- `phone_number TEXT` — unique constraint, used as P2P transfer recipient identifier

### New Table Schemas

**debts:**
```sql
CREATE TABLE debts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  debt_type TEXT NOT NULL,
  -- 'personal_loan', 'credit_card', 'bnpl', 'car_loan', 'home_loan', 'student_loan', 'other'
  original_amount DECIMAL(12,2) NOT NULL,
  current_balance DECIMAL(12,2) NOT NULL,
  interest_rate DECIMAL(5,2),
  minimum_payment DECIMAL(10,2),
  due_date INTEGER,                     -- Day of month (1-31)
  is_active BOOLEAN DEFAULT true,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**investments:**
```sql
CREATE TABLE investments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  asset_name TEXT NOT NULL,
  ticker TEXT,
  category TEXT NOT NULL,
  -- 'stocks', 'crypto', 'etf' (only 3 categories — all have real tickers + live pricing)
  units DECIMAL(18,8) NOT NULL,
  purchase_price DECIMAL(12,2) NOT NULL,
  current_price DECIMAL(12,2),          -- Updated via market data worker
  purchase_date DATE,
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**bills:**
```sql
CREATE TABLE bills (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  due_date DATE NOT NULL,
  frequency TEXT NOT NULL,              -- 'monthly', 'quarterly', 'annually', 'one_time'
  category TEXT,
  vault_id UUID REFERENCES vaults(id),
  notification_days_before INTEGER DEFAULT 3,
  is_paid BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```


**p2p_transfers:**
```sql
CREATE TABLE p2p_transfers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID REFERENCES profiles(id),
  receiver_id UUID REFERENCES profiles(id),
  amount DECIMAL(10,2) NOT NULL,
  source_vault_id UUID REFERENCES vaults(id),
  note TEXT,
  status TEXT DEFAULT 'completed',      -- 'pending', 'completed', 'failed'
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### MongoDB Atlas — 6 Collections

**fd_rates** (scraped daily via BullMQ):
```json
{
  "bank": "Maybank",
  "product": "Maybank Fixed Deposit-i",
  "min_amount": 1000,
  "tenure_months": 12,
  "interest_rate": 3.65,
  "apply_url": "https://www.maybank2u.com.my/...",
  "source_url": "https://imoney.my/fixed-deposit",
  "scraped_at": "ISODate",
  "is_islamic": false
}
```

**deals** (scraped daily):
```json
{
  "merchant": "Shopee",
  "deal_title": "10% cashback on groceries",
  "category": "food",
  "discount_pct": 10,
  "max_cashback": 5.00,
  "valid_until": "ISODate",
  "is_need": true,
  "is_want": false,
  "aria_note": "Good deal for regular grocery spend",
  "apply_url": "https://shopee.com.my/...",
  "source": "shopback",
  "scraped_at": "ISODate"
}
```

**news_articles** (fetched hourly):
```json
{
  "title": "Bank Negara holds OPR at 3.00%",
  "summary": "Aion-generated 2-sentence summary in plain language",
  "sentiment": "neutral",
  "source": "The Edge Malaysia",
  "published_at": "ISODate",
  "url": "https://theedgemalaysia.com/...",
  "tags": ["monetary_policy", "interest_rates"],
  "fetched_at": "ISODate"
}
```

**market_data_cache** (refreshed every 15 minutes):
```json
{
  "symbol": "BTCUSD",
  "type": "crypto",
  "price": 105234.50,
  "change_pct_24h": 2.31,
  "high_24h": 106000,
  "low_24h": 103000,
  "volume": 45234123,
  "updated_at": "ISODate"
}
```


**stock_listings** (US stock/ETF names from Alpha Vantage LISTING_STATUS, refreshed weekly):
```json
{
  "ticker": "AAPL",
  "name": "Apple Inc",
  "exchange": "NASDAQ",
  "category": "stocks",
  "fetched_at": "ISODate"
}
```

**volatility_cache** (calculated annualised volatility per ticker):
```json
{
  "ticker": "BTC",
  "category": "crypto",
  "volatility": 65.23,
  "updated_at": "ISODate"
}
```

---

## Authentication Flow

1. Supabase handles login/signup directly in Flutter — no backend call needed
2. After registration → auto-login → navigate to `/onboarding`
3. After login → check if `onboarding_profiles` row exists:
   - Yes → navigate to `/dashboard` (home tab)
   - No → navigate to `/onboarding`
4. Session persists across app restarts (Instagram-like behaviour)
6. Logout clears session → shows Welcome screen on next open
7. Flutter stores JWT — Dio injects as `Authorization: Bearer <token>`
8. Backend `middleware/auth.js` validates JWT via `supabase.auth.getUser(token)`

**Supabase Auth Trigger:**
Auto-creates `profiles` row on registration.
Captures `full_name` and `phone_number` from `raw_user_meta_data`.
Uses `SET search_path = public` — critical for finding tables correctly.

**Password Reset Flow:**
- User taps "Change Password" in Account Profile screen
- App calls `supabase.auth.resetPasswordForEmail(email)` — sends OTP to email
- User enters OTP + new password in-app
- No backend endpoint needed — handled entirely by Supabase Auth

---

## Navigation Structure

**4-Tab Shell (StatefulShellRoute with GoRouter):**

```
Home  |  Grow  |  [Scanner]  |  Discover  |  Profile
  🏠      📈        📷           🔍           👤
```
Shell indices: 0=Home, 1=Grow, 2=Discover, 3=Profile
Aion/Chat is a **push route** (`/chat`), NOT a shell tab.

**QR Scanner:** Floating centre button elevated above the nav bar pill.
Uses `context.push('/qr-scanner')` — NOT a shell tab.

**Push routes (no nav bar shown):**
- `/chat` — Aion Advisory Chat
- `/profile` — Financial Profile (name tap from Home)
- `/vault-detail/:id` — Vault Detail
- `/qr-scanner`, `/salary-deposit`, `/salary-preview`
- `/general-deposit`, `/merchant-pay`
- `/transactions` — Transaction History
- `/transfer`, `/receive`
- `/grow/health-score`, `/grow/debt`, `/grow/debt/strategy`
- `/grow/invest`, `/grow/invest/holdings`, `/grow/invest/chart`
- `/grow/protection`
- `/discover/fd-rates`, `/discover/deals`, `/discover/news`
- `/discover/loan-calc`, `/discover/forecast`
- `/achievements`, `/bills`

**Tab 1 — Home:**
- Greeting + tappable first name with gold chevron → Financial Profile push
- Bell icon → Aion chat
- Total Safe-to-Spend (sum of vault `current_balance` only, excludes goals)
- Quick actions: Transfer | Aion | Receive
- MY GOALS (PageView with dot indicators)
- MY VAULTS (progress bars + `currentBalance`)
- Spending donut chart
- AI notification card (when unread proactive messages)

**Tab 2 — Grow:**
- Financial Health Score hero card (FHN gauge + dimension bars)
- 2x2 grid: Debt Management, Investment Portfolio, Protection Planning, Bill Reminders

**Tab 3 — Discover:**
- Scrolling ticker rows: News, Stocks (Finnhub), Crypto (CoinGecko), FX (ExchangeRate-API)
- 3 feature cards with background images: Financial News, Smart Deals, FD Marketplace

**Tab 4 — Profile:**
- Account Profile (edit name, phone, change password via OTP)
- Achievements, Loan Calculator, Spending Forecast
- Logout

**Push — Aion Chat** (`/chat`):
- WhatsApp-style persistent conversation with Aion
- LangGraph ReAct agent with 16 tools + RAG
- Full 4-layer session-aware context

---

## AI System Architecture

### AI Advisor: Aion
Warm, natural, real financial advisor personality.
Never robotic. Never uses system-like language.
Always speaks as if she knows the user personally.
Proactively reaches out — doesn't wait to be asked.

### Three Profile Tables
- `profiles` = identity layer (name, phone — never AI-updated)
- `onboarding_profiles` = user-declared truth (what user said about themselves)
- `ai_financial_profiles` = AI-concluded intelligence (what Aion observed)

### AI Memory — 3 Layers
| Layer | Storage | Scope |
|---|---|---|
| Long-term personality | `onboarding_profiles` + `ai_financial_profiles` | Permanent |
| Behavioural memory | `ai_financial_profiles.key_insights` JSONB | Compressed session summaries |
| Short-term conversation | `ai_logs` — split by session boundary | Current session + recency buffer (10 messages) |

**onboarding_profiles vs key_insights — NOT the same:**
- `onboarding_profiles` = what the **user declared** (income, stated goals, life situation, spending habit in their own words, risk level they chose)
- `key_insights` = what **Aion observed and concluded** over sessions (behavioural patterns, responses to advice, relationship notes, session summaries)
- Both always sent to Gemini on every advisory chat call — they serve different roles, not duplicates

**key_insights JSONB structure:**
```json
{
  "summary": "overall financial personality description",
  "financial_patterns": ["pattern 1", "pattern 2"],
  "goals_discussed": ["goal 1", "goal 2"],
  "behavioral_notes": ["note 1", "note 2"],
  "relationship_notes": ["note about Aion-user relationship"],
  "last_summarised_at": "2026-06-06T10:30:00.000Z"
}
```

### Session-Based Summarization
- `last_summarised_at` in key_insights marks the session boundary
- On chat OPEN → `summarizeSession()` fires before history loads
- Finds all messages since `last_summarised_at` → Gemini merges into key_insights → `last_summarised_at` updated to now
- Fire-and-forget — failures silently ignored, chat still works
- Fires on OPEN (not close) — avoids missed summarization from force-close
- Summarizes the PREVIOUS session, not the current one

### Chat Context Sent to Gemini (4 Layers)
1. `key_insights` + `onboarding_profiles` + vault balances — always included
2. Recency buffer — last 10 messages (5 ai_logs rows) before session boundary — for conversational continuity
3. RAG — top 3 semantically relevant past sessions via pgvector cosine similarity
4. Current session — all messages since `last_summarised_at` — verbatim

**Why recency buffer exists:** Without it, if user exits mid-conversation and re-enters immediately, `summarizeSession()` fires and the current session becomes empty. User says "can you fix that?" and Aion has no context. 10-message buffer bridges this gap.

**Recency buffer is 10 messages (5 rows)** — sized deliberately small to avoid polluting context with irrelevant older content.

### Context Per Gemini Call Type
| Call Type | Profile | Vault | Chat History | Transactions |
|---|---|---|---|---|
| Chat | Full (onboarding + AI profile) | Balances | 4-layer (see above) | None |
| Goal Guardian | Full | Balances | None | Last 10 |
| Categorisation | None | category_keys only | None | None |
| Proactive | Full | Balances | Last 5 | Last 10 |

### LangGraph Agent ✅

**Current state:** Aion uses prompt-response (Gemini 2.5 Flash called once per turn).

**LangGraph upgrade:** Aion becomes a ReAct agent that can call tools autonomously during a single turn.
User asks: "Can I afford a new phone?" → Aion calls `get_vault_balances` → `get_user_debts` → `get_spending_velocity` → reasons → responds.

**Aion's Tool Library (when LangGraph is implemented):**

| Tool | What it does |
|---|---|
| `get_vault_transactions` | Transaction history for a specific vault |
| `get_recent_transactions` | Last N transactions across all vaults |
| `get_spending_velocity` | Daily spend rate + days until vault runs out |
| `get_user_debts` | All active debt records with calculated fields |
| `get_debt_strategy` | Avalanche vs snowball payoff analysis |
| `get_user_bills` | All active bills with due dates and paid status |
| `get_investment_portfolio` | Holdings + value in USD and RM + P&L + allocation |
| `get_market_data` | Real-time stock/crypto/FX prices from cache |
| `get_news` | Latest financial news with AI summaries |
| `get_fd_rates` | Latest FD rates from MongoDB cache |
| `get_deals` | Current deals filtered by category |
| `calculate_loan` | EMI calculation: principal, rate, tenure |
| `calculate_goal_timeline` | Months to reach a savings goal at current rate |
| `search_past_conversations` | RAG search — finds relevant past sessions via pgvector |
| `update_debt_payment` | Record a debt payment (updates balance + snapshot) |
| `get_health_score` | FHN Financial Health Score with 4-dimension breakdown |

**LangSmith:** Traces every agent run — tool calls, reasoning steps, latencies. Free 5k traces/month.
**Zod:** All tool input/output schemas validated before/after each call.

### RAG Architecture ✅

| Step | What |
|---|---|
| Enable pgvector | `CREATE EXTENSION vector` in Supabase |
| Add embedding column | `embedding vector(768)` on `ai_logs` |
| Embed after summarization | `text-embedding-004` via Vertex AI (same ADC) |
| In advisoryChat | Embed user message → cosine similarity search → top 3 sessions > 0.72 threshold |
| Replace recency buffer | Layer 3 becomes RAG results instead of recency buffer |

**Session-level chunking:** One embedding per summarised session, not per message. Retrieving a session gives coherent context, not fragments. Session boundary = `last_summarised_at`.

### AI Update Rules — CRITICAL

**onboarding_profiles:**
| Field | Rule |
|---|---|
| `financial_goals` | Silent — add/remove based on explicit user statements only |
| `life_situation` | Silent — when user explicitly states a change |
| `financial_challenges` | Silent — when user explicitly describes |
| `spending_habit` | Confirm first — extract from user's own words, map to ENUM |
| `risk_level` | Confirm first — through natural conversation |
| `monthly_income` | Confirm first — detected via salary QR discrepancy |

**ai_financial_profiles — AI owns entirely, silent updates:**
- `behavioral_classification` — ENUM validated by backend before write
- `recommended_allocation` — must sum to 100%, validated before write
- `ai_reasoning` — always required when any update happens
- `key_insights` — append and summarise over time

**NEVER AI-updated:**
- `profiles` table (name, phone, email)
- `monthly_income` silently
- Any vault balances directly
- Any transaction records

### AI Safety Layer (Every Gemini Response)
1. Schema validation — required fields present, correct data types
2. Allowed field whitelist — `aiWhitelist.js` controls what can be updated
3. Business logic validation — allocations sum to 100%, ENUMs correct
4. Fallback behaviour — validation failure → graceful degradation, not crash
5. Gemini NEVER writes to DB directly — always through backend validator

---

## Gemini Service — Functions

| Function | Purpose |
|---|---|
| `safeGeminiCall(prompt)` | Wraps every call — strips markdown fences, parses JSON, returns {success, data} |
| `buildOnboardingPrompt(history, context, isInit)` | New user onboarding — collects profile + builds vault plan |
| `buildReviewerPrompt(history, context, currentVaults)` | Vault plan refinement when user wants to adjust before confirming |
| `buildGoalGuardianPrompt(transaction, vaults, profile)` | Transaction analysis — alert_user + matched_vault_category + profile_update |
| `buildChatPrompt(message, userContext, currentSessionHistory, pastSessionHistory)` | Advisory chat — 4-layer session-aware context |
| `buildCategorizationPrompt(merchantName, userVaults)` | Merchant → vault mapping — always includes user's vault list |
| `buildSummarizationPrompt(existingSummary, sessionMessages)` | Merges session messages into key_insights JSON |
| `buildProactivePrompt(userContext, vaults, recentTransactions)` | Generates proactive advisor message for notification |
| `buildFDExtractionPrompt(rawMarkdown)` | Extracts structured FD rates from Jina-scraped Markdown |
| `buildDealExtractionPrompt(rawMarkdown)` | Extracts deal info + need/want classification from scraped Markdown |
| `buildNewsSummaryPrompt(rawArticle)` | Summarises news article into 2 plain-language sentences + sentiment |
| `buildGoalCompletionPrompt(goalVault, userProfile)` | Generates warm celebration message when saving goal is reached |
| `buildDebtStrategyPrompt(debts, vaultBalances, income)` | Recommends avalanche/snowball payoff strategy |

---

## Background Job Architecture

**Stack:** BullMQ (Redis-backed queue) + Google Cloud Scheduler (HTTP webhook trigger)

**How it works:**
1. Cloud Scheduler hits `POST /api/jobs/trigger` with `{ jobType: 'fd_scrape' }` on a cron
2. `jobController.js` validates request (bearer token) and adds job to BullMQ queue
3. Corresponding worker processes job asynchronously
4. Results stored in MongoDB, then written to Redis cache

**Job Schedule:**
| Job | Schedule | Worker |
|---|---|---|
| FD rate scraping | Daily 06:00 MYT | `fdScrapeWorker.js` |
| Deals scraping | Daily 07:00 MYT | `dealsScrapeWorker.js` |
| News fetch | Every 2 hours | `newsFetchWorker.js` |
| Bill auto-advance check | Daily 08:00 MYT | `checkAllBillsOnStartup()` via Cloud Scheduler |

**NOTE:** Market data (stocks, crypto, FX) does NOT use Cloud Scheduler. Refreshed on-demand
by user requests when Redis TTL expires. Startup `setTimeout` provides initial data only.
Proactive notifications are of two types: scheduled (daily morning advice, Cloud Scheduler)
and real-time (P2P transfer, goal completion — triggered by the event itself, no scheduler).

**Redis Cache Keys:**
- `fd_rates` → TTL 6h
- `deals:{category}` → TTL 6h
- `news` → TTL 2h
- `market:{symbol}` → TTL 15m
- `fx_rates` → TTL 1h

---

## External Data Pipelines

### FD Rate Pipeline
```
Cloud Scheduler (daily 06:00 MYT)
  → POST /api/jobs/trigger { jobType: 'fd_scrape' }
  → BullMQ adds job → fdScrapeWorker picks up:
      GET r.jina.ai/https://imoney.my/fixed-deposit
      → clean Markdown returned
      → buildFDExtractionPrompt() → Gemini extracts structured JSON
      → validate + upsert MongoDB fd_rates collection
      → write to Redis (6h TTL)
Flutter GET /api/finance/fd-rates → Redis (or MongoDB fallback)
```

### Market Data Pipeline
```
Cloud Scheduler (every 15 min)
  → BullMQ marketDataWorker:
      Alpha Vantage: major indices (KLCI, S&P500, NASDAQ)
      CoinGecko: BTC, ETH, BNB prices
      ExchangeRate-API: MYR/USD/SGD/JPY
      Write each to Redis (15-min TTL)
Flutter GET /api/finance/market?symbols=BTCUSD,KLCI → Redis read
```

### Deals Pipeline
```
Cloud Scheduler (daily 07:00 MYT)
  → BullMQ dealsScrapeWorker:
      GET r.jina.ai/{deals_page_url}
      → Gemini extracts deal + classifies need vs want
      → MongoDB upsert (match on merchant + deal_title)
      → Redis cache 6h TTL
```

### News Pipeline
```
Cloud Scheduler (every 2 hours)
  → BullMQ newsFetchWorker:
      NewsAPI.org: query "Malaysia finance money"
      RSS: The Edge Malaysia, FMT Business
      Deduplicate by URL
      → Gemini: buildNewsSummaryPrompt() → 2-sentence summary + sentiment
      → MongoDB insert (new articles only)
      → Redis write 2h TTL
```

---

## Feature Modules

### M1 — Traffic Controller ✅ COMPLETE
Automated income allocation engine.
- `POST /api/income/inject` — splits salary by allocation_percentage per vault
- `POST /api/income/deposit` — general deposit to specific vault
- salary_deposit_screen.dart → salary_preview_screen.dart
- general_deposit_screen.dart — 2-step: enter amount → pick vault
- QR types: `salary_deposit`, `general_deposit`
- spent_amount resets to 0 on salary inject. current_balance always carries over.

### M2 — Real-Time Dashboard ✅ COMPLETE
- Supabase Realtime subscription on `vaults` table
- Total Safe-to-Spend = sum of vault `current_balance` (NOT goal/fund balances)
- MY GOALS = PageView of fund cards with goal progress bars
- MY VAULTS = spending vault cards with `current_balance` + progress bar (spent/allocated)
- Spending donut chart (fl_chart)
- AI notification card (taps into Aion tab)

### M3 — Active Pilot + Goal Guardian ✅ COMPLETE
Full transaction interception. See "Complete Transaction Flow" section.

### M4 — AI Advisory Chat ✅ COMPLETE
- chat_screen.dart — WhatsApp-style, full history, date dividers
- Vault confirmation bottom sheet — Aion proposes → Flutter shows sheet → user confirms → POST apply-vault-changes
- `summarizeSession()` fires on chat open
- Routes: POST /api/ai/chat, GET /api/ai/chat/history, POST /api/ai/chat/summarize, POST /api/ai/chat/apply-vault-changes

### M5 — P2P Transfer ✅ COMPLETE
- User enters recipient phone number + amount + source vault
- Backend looks up receiver by phone_number in profiles (unique constraint)
- Deducts from sender's vault, credits to receiver's best matching vault
- Creates p2p_transfers record + vault_transfers records for both sides
- transfer_screen.dart — enter phone, amount, vault, note
- receive_screen.dart — shows user's own QR with their phone number

### M6 — Firebase Push Notifications ✅ COMPLETE
- FCM token stored in `profiles.fcm_token` — updated on app open
- Triggers: income injected, salary amount mismatch, goal deadline 7 days, repeated Goal Guardian overrides, bill due soon, investment risk mismatch, P2P transfer received, new Aion proactive message
- Notification payload includes route to open in Flutter
- `flutter_local_notifications` handles display when app is in foreground

### M7 — Debt Management ✅ COMPLETE
- Adaptive form per debt type (credit card, personal loan, BNPL, car loan, etc.)
- Aion's Strategy page — whiteboard-style payoff analysis (avalanche vs snowball)
- Update Balance button with debt_balance_snapshots tracking
- Deep Integration: Goal Guardian + proactive notifications include debt context

### M8 + M12 — Investment Planning + TradingView ✅ COMPLETE
- Trader-friendly holdings editor: 3 tabs (Crypto/Stocks/ETF)
- Crypto list from CoinGecko (top 100), Stocks/ETF from Alpha Vantage LISTING_STATUS
- Real volatility from 90-day historical data (PRIIPs mapping + HHI concentration penalty)
- Morningstar risk thresholds: Conservative 0-23, Moderate 24-47, Aggressive 48-78, Very Aggressive 79-100
- TradingView chart on separate page via `flutter_inappwebview`
- Aion analysis with risk score + market context + USD(RM) conversion
- USD/MYR toggle on investment screen using live FX rate
- Live price sync: 4-tier cache feeds into Supabase for all consumers

### M9 — Protection Planning ✅ COMPLETE
- Emergency fund analysis: months covered vs 6-month target
- Insurance checklist: 5 types (medical, life, personal accident, motor, critical illness)
- Aion reads checklist → recommends only what's missing
- Checklist feeds into FHN Financial Health Score (Plan dimension)

### M10 — Financial Health Score ✅ COMPLETE
- FHN FinHealth Score methodology — 8 sub-indicators, 4 dimensions (Spend/Save/Borrow/Plan)
- 3 tiers: Vulnerable (0-39), Coping (40-79), Healthy (80-100)
- Animated radial donut gauge with FHN colours (orange/purple/blue)
- Expandable dimension cards with Aion per-dimension advice
- Hero card in Grow hub with mini gauge + dimension bars
- LangGraph `get_health_score` tool for Aion chat integration

### M11 — FD + Savings Marketplace ✅ COMPLETE
- Real-time FD rates scraped via Jina AI Reader + Gemini extraction
- Deposit calculator, bank logos, Apply to bank website via `url_launcher`
- `GET /api/finance/fd-rates` → 4-tier cache

### M13 — Smart Deals Page ✅ COMPLETE
- Deals scraped from Malaysian banks (CIMB, HSBC, SC, HLB, etc.)
- Gemini classifies need vs want, category filter
- `GET /api/finance/deals` → 4-tier cache

### M14 — Financial News Feed ✅ COMPLETE
- 50 articles per fetch, broad finance query (finance/economy/stocks/investment/banking/inflation/cryptocurrency)
- AI-summarised with sentiment analysis
- Breaking news carousel, category tabs, in-app browser

### M15 — Loan Calculator ✅ COMPLETE
- Flat rate + reducing balance toggle, amortisation schedule
- 100% local calculation — no API call

### M17 — Spending Forecast ✅ COMPLETE
- Weighted avg, burst detection, pace comparison, target daily spend
- Vault runway countdown with colour-coded chips

### M19 — Bill Reminders ✅ COMPLETE
- Auto-advance billing cycles (monthly/quarterly/annually)
- Bill payment history logging for FHN health score
- Aion Deep Integration: Goal Guardian + proactive notifications include bills

### M22 — Goal Timeline Calculator ✅ COMPLETE
- Aion uses `calculate_goal_timeline` LangGraph tool in chat
- "How long to save RM5000 at current rate?"

### M24 — Financial Achievements ✅ COMPLETE
- Archived goals roadmap with gaming UI
- Trophy summary on achievements screen

### M27 — Loading Skeletons ✅ COMPLETE
- Shimmer skeleton screens on all list/card views

### M28 — Goal Completion Celebration ✅ COMPLETE
- Lottie confetti overlay + archive button
- Aion sends congratulatory chat message

### M29 — Transaction Search + Filter ✅ COMPLETE
- Search bar + filter chips (status, vault, date)
- Income deposits merged into transaction timeline

### M30 — Vault Detail Screen ✅ COMPLETE
- Vault name + balance + progress bar + transaction history
- Income allocation records shown per vault
- "Ask Aion about this vault" shortcut → pre-filled Aion chat

---

## Complete Transaction Flow

```
User scans merchant QR → merchant_pay_screen.dart opens
        ↓
Step 1  Flutter reads QR payload (merchant_name, merchant_id)
Step 2  User enters amount
Step 3  POST /api/transactions/initiate
Step 4  Instant vault balance check — READ vaults (no AI, ~50ms)

Outcome A — Vault insufficient:
  → WRITE transactions (status = 'blocked')
  → Return { outcome: 'blocked', matched_vault: { id, name, current_balance }, shortfall, all_vaults }
  → Flutter shows Active Pilot 3-step popup
  → User reallocates → POST /api/vaults/transfer → WRITE vault_transfers → retry initiate

Outcome B — Vault sufficient:
Step 5  Fetch context (onboarding_profiles + ai_financial_profiles + vaults)
Step 6  POST /api/transactions/categorize → Gemini maps merchant → category_key (max 2 attempts)
Step 7  If categorization fails → Flutter shows vault picker (user manual select)
Step 8  Build Goal Guardian prompt with full context
Step 9  Flutter shows "Advisor reviewing..." — NO cancel button
Step 10 Call Gemini API — no timeout (deliberate positive friction)
Step 11 Backend validates Gemini JSON response
Step 12 If alert_user = true:
          → Return { outcome: 'alert', alert_message, alert_severity, goal_guardian_result }
          → Flutter shows Goal Guardian popup
          → User proceeds → continue. User cancels → WRITE (status='cancelled') → end
Step 13 Deduct vault — WRITE vaults (ACID)
Step 14 WRITE transactions (status = 'approved')
Step 15 Silent WRITE ai_financial_profiles (behaviour update)
Step 16 WRITE ai_logs
        ↓
Return { outcome: 'approved', matched_vault: { id, name } }
Flutter shows success screen: green checkmark + vault name + amount
User taps "Back to Dashboard" → Supabase real-time → vault balances update live
```

**Backend response structure:**
```json
{ "outcome": "blocked", "matched_vault": { "id", "name", "current_balance" }, "shortfall", "all_vaults" }
{ "outcome": "alert", "vault_id", "vault_name", "alert_message", "alert_severity", "goal_guardian_result" }
{ "outcome": "approved", "matched_vault": { "id", "name" } }
```

**Goal Guardian Response Format:**
```json
{
  "alert_user": true,
  "alert_message": "natural advisor message",
  "alert_severity": "high",
  "matched_vault_category": "food_dining",
  "profile_update": { "update_needed": false, "updates": {} }
}
```

**Active Pilot — 3 Steps:**
```
Step 1: Block notification + [Transfer from another vault] [Cancel]
Step 2: Show ALL vaults AND goals — goal picker shows warning about goal impact
Step 3: Confirm transfer — shows before/after balances
```

---

## Salary Deposit Flow

```
Scan Employer QR (qr_type = 'salary_deposit')
        ↓
salary_deposit_screen: user enters salary amount
        ↓
POST /api/income/inject
        ↓
Traffic Controller: allocated_amount = salary × (percentage / 100) per vault
        ↓
salary_preview_screen: each vault + allocation amount preview
        ↓
User confirms
        ↓
WRITE all vaults: current_balance += allocated_amount
WRITE income_injections with allocation_snapshot + carryover_snapshot
spent_amount resets to 0 for all vaults
        ↓
Supabase real-time → home dashboard updates
        ↓
AI proactive notification (BullMQ) about carryover surplus
```

---

## General Deposit Flow

```
Scan FinWise General Deposit QR (qr_type = 'general_deposit')
        ↓
general_deposit_screen Step 1: enter amount
        ↓
general_deposit_screen Step 2: pick vault (all vaults + goals shown)
        ↓
POST /api/income/deposit { vault_id, amount }
        ↓
WRITE vault: current_balance += amount AND allocated_amount += amount
WRITE income_injections (type: 'general_deposit')
        ↓
context.go('/dashboard') → Supabase real-time → vault card updates
```

---

## Onboarding AI Conversation Flow

```
New user → /onboarding screen
        ↓
Flutter sends __INIT__ → Aion greets warmly
        ↓
Natural conversation 8-12 exchanges (income, goals, spending habits, risk level)
        ↓
Aion generates personalised vault structure as JSON (5-8 vaults always)
        ↓
Flutter shows BottomSheet vault summary (MY VAULTS + MY GOALS sections)
        ↓
User can adjust → Aion modifies → shows again (buildReviewerPrompt used here)
        ↓
User confirms → POST /api/ai/onboarding/confirm-vaults
        ↓
Backend saves: onboarding_profiles + ai_financial_profiles + vaults + allocation_history
        ↓
Flutter calls fetchVaults() explicitly before navigating (StatefulShellRoute preserves state)
Navigate to /dashboard
```

**Vault Category Rules:**
- AI creates categories from conversation — NO fixed list
- `category_key` must be lowercase_underscore (validated before save)
- 5-8 vaults total always
- Always include emergency and savings-type vault
- All `allocation_percentage` values must sum to exactly 100
- Specific goal keys: `travel_fund_japan` not generic `travel_fund`
- `vault_type = 'vault'` for spending. `vault_type = 'fund'` for saving goals
- Funds must have `linked_goal` and `goal_target_amount`

**Onboarding Prompt Response Format:**
```json
{
  "message": "natural conversational message",
  "vault_plan_ready": false,
  "profile_data": null,
  "vault_recommendations": null
}
```
When `vault_plan_ready: true` → includes full `profile_data` and `vault_recommendations`.

---

## App Screens — Complete List

| Screen | Route | Nav | Purpose | Status |
|---|---|---|---|---|
| Welcome | `/` | — | Get Started + Login (animated entrance) | ✅ |
| Login | `/login` | — | Email + password + friendly errors | ✅ |
| Register | `/register` | — | Name, email, phone, password | ✅ |
| Onboarding Chat | `/onboarding` | — | AI conversation to create profile + vaults | ✅ |
| Home | `/dashboard` | Tab 1 | Live vault balances + spending summary + notifications | ✅ |
| Grow Hub | `/grow` | Tab 2 | Health Score hero + 2x2 grid (Debt/Invest/Protection/Bills) | ✅ |
| Discover Hub | `/discover` | Tab 3 | Scrolling tickers + 3 feature cards with images | ✅ |
| Account Profile | `/account-profile` | Tab 4 | Edit name/phone, change password (OTP), features, logout | ✅ |
| Aion Chat | `/chat` | Push | LangGraph 16-tool AI advisor, persistent history | ✅ |
| Financial Health Score | `/grow/health-score` | Push | FHN gauge + 4 dimensions + Aion advice | ✅ |
| Debt Management | `/grow/debt` | Push | Debt list + update balance + Aion strategy | ✅ |
| Debt Strategy | `/grow/debt/strategy` | Push | Aion whiteboard payoff analysis | ✅ |
| Investment Portfolio | `/grow/invest` | Push | Risk score + holdings + USD/MYR toggle | ✅ |
| Holdings Editor | `/grow/invest/holdings` | Push | 3-tab trader-friendly (Crypto/Stocks/ETF) | ✅ |
| TradingView Chart | `/grow/invest/chart` | Push | Full-screen TradingView widget | ✅ |
| Protection Planning | `/grow/protection` | Push | Emergency fund + insurance checklist + Aion recs | ✅ |
| FD Marketplace | `/discover/fd-rates` | Push | Rate comparison + deposit calc + apply links | ✅ |
| Smart Deals | `/discover/deals` | Push | Need/want filter + category filter | ✅ |
| Financial News | `/discover/news` | Push | AI-summarised + sentiment + breaking carousel | ✅ |
| Loan Calculator | `/discover/loan-calc` | Push | Flat/reducing balance + amortisation | ✅ |
| Spending Forecast | `/discover/forecast` | Push | Vault runway + velocity analysis | ✅ |
| Achievements | `/achievements` | Push | Archived goals roadmap | ✅ |
| Bill Reminders | `/bills` | Push | Auto-advance + mark paid + history | ✅ |
| QR Scanner | `/qr-scanner` | Float | Scan merchant / salary / deposit QR | ✅ |
| Salary Deposit | `/salary-deposit` | Push | Enter salary amount | ✅ |
| Salary Preview | `/salary-preview` | Push | Confirm allocation split | ✅ |
| General Deposit | `/general-deposit` | Push | Enter amount → pick vault | ✅ |
| Merchant Pay | `/merchant-pay` | Push | Transaction flow with Goal Guardian | ✅ |
| Transaction History | `/transactions` | Push | Expenses + income merged, search + filter | ✅ |
| Vault Detail | `/vault-detail/:id` | Push | Vault history + income allocation per vault | ✅ |
| P2P Transfer | `/transfer` | Push | Send money by phone number | ✅ |
| P2P Receive | `/receive` | Push | Show own QR for receiving | ✅ |
| Financial Profile | `/profile` | Push | AI profile + allocation % — read-only | ✅ |
| Goal Guardian Popup | — | Dialog | Transaction alert — proceed or cancel | ✅ |
| Active Pilot Popup | — | Bottom Sheet | 3-step vault reallocation with AI warnings | ✅ |
| Vault Change Bottom Sheet | — | Bottom Sheet | Aion vault change confirmation | ✅ |

---

## Backend Routes — Complete List

```
Auth:
  GET    /api/auth/profile
  PATCH  /api/auth/profile

AI:
  POST   /api/ai/onboarding/chat
  POST   /api/ai/onboarding/confirm-vaults
  POST   /api/ai/chat
  GET    /api/ai/chat/history
  POST   /api/ai/chat/summarize
  POST   /api/ai/chat/apply-vault-changes
  GET    /api/ai/profile

Vaults:
  GET    /api/vaults/status
  POST   /api/vaults/transfer
  POST   /api/vaults/:id/archive
  POST   /api/vaults/:id/unarchive

Transactions:
  POST   /api/transactions/initiate
  POST   /api/transactions/execute
  POST   /api/transactions/cancel
  POST   /api/transactions/categorize
  GET    /api/transactions/history

Income:
  POST   /api/income/inject
  POST   /api/income/deposit
  POST   /api/income/stage
  POST   /api/income/apply
  GET    /api/income/pending

Finance:
  GET    /api/finance/health-score
  GET    /api/finance/spending-forecast
  GET    /api/finance/news
  GET    /api/finance/fd-rates
  GET    /api/finance/deals
  GET    /api/finance/protection
  GET    /api/finance/insurance
  PATCH  /api/finance/insurance
  GET    /api/finance/ticker

Debt:
  GET    /api/debt
  POST   /api/debt
  PATCH  /api/debt/:id
  DELETE /api/debt/:id
  GET    /api/debt/strategy

Invest:
  GET    /api/invest
  GET    /api/invest/risk
  GET    /api/invest/analysis
  GET    /api/invest/crypto-prices
  GET    /api/invest/quote/:ticker
  GET    /api/invest/listings
  POST   /api/invest
  POST   /api/invest/save-all
  PATCH  /api/invest/:id
  DELETE /api/invest/:id

Transfer:
  GET    /api/transfer/lookup
  POST   /api/transfer/send
  POST   /api/transfer/allocate
  GET    /api/transfer/history

Bills:
  GET    /api/bills
  POST   /api/bills
  PATCH  /api/bills/:id
  DELETE /api/bills/:id

Achievements:
  GET    /api/achievements

Notifications:
  POST   /api/notifications/register-token
  DELETE /api/notifications/clear-token
  GET    /api/notifications/history
  POST   /api/notifications/mark-chat-opened

Jobs (Cloud Scheduler webhooks — bearer token protected):
  POST   /api/jobs/trigger
```

---

## Seeded QR Codes (21 Total)

Food: McDonald's Sunway Pyramid, KFC IOI City Mall, Tealive Mid Valley,
      GrabFood Delivery, Village Grocer Bangsar
Transport: Shell Petrol Station PJ, Grab Transport, Touch n Go Reload
Entertainment: TGV Cinemas 1 Utama, Steam Online Gaming, Spotify Premium
Shopping: H&M Pavilion KL, Uniqlo Suria KLCC
Health: Caring Pharmacy SS2, Fitness First Monthly
Education: Popular Bookstore, Udemy Online Course
Large purchases: Yamaha Motor Showroom PJ, Harvey Norman Electronics
Salary: Simulated Employer Sdn Bhd (`qr_type: salary_deposit`)
General: FinWise General Deposit (`qr_type: general_deposit`, `merchant_id: SIM-GEN-001`)

---

## Coding Rules — ALWAYS FOLLOW

### File Header (every backend .js file)
```javascript
// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : filename.js
// Description   : what this file does
// First Written : DD-MM-YYYY
// Edited on     : DD-MM-YYYY
// ============================================
```

### File Header (every Flutter .dart file)
```dart
// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : filename.dart
// Description   : what this file does
// First Written : DD-MM-YYYY
// Edited on     : DD-MM-YYYY
// ============================================
```

### Modifying Files
- Tell exact line number to change
- Show only the specific change — never replace whole file unless complete rewrite
- Explain why the change is needed
- Preserve all existing comments

### Platform
- Android ONLY — no iOS, no web, no desktop

### Step by Step
- Guide one step at a time
- Wait for confirmation before next step
- Analyse screenshots before continuing

### Comments
- No comments unless the WHY is non-obvious
- No docstring blocks
- Never explain WHAT the code does — names do that

---

## Run Commands

```bash
# Backend (development)
cd C:\fyp-neobanking\backend
node server.js

# Backend (Docker — all services)
cd C:\fyp-neobanking
docker compose up

# Frontend
cd C:\fyp-neobanking\frontend
flutter run

# Gemini ADC auth (run once per machine)
gcloud auth application-default login

# Deploy backend to Cloud Run
gcloud run deploy finwise-backend \
  --source . \
  --region asia-southeast1 \
  --allow-unauthenticated \
  --set-env-vars "NODE_ENV=production"

# Build release APK
cd C:\fyp-neobanking\frontend
flutter build apk --release

## ─── PRODUCTION DEPLOYMENT CHECKLIST ───

### Before deploying backend:
1. Set `NODE_ENV=production` on Cloud Run (enables BullMQ workers)
2. Set all env vars on Cloud Run (or use Google Secret Manager):
   - SUPABASE_URL, SUPABASE_SERVICE_KEY
   - GOOGLE_CLOUD_PROJECT, GOOGLE_CLOUD_LOCATION
   - MONGODB_URI, UPSTASH_REDIS_URL, UPSTASH_REDIS_TOKEN
   - ALPHA_VANTAGE_API_KEY, COINGECKO_API_KEY, EXCHANGERATE_API_KEY
   - NEWS_API_KEY
   - JOB_TRIGGER_SECRET — create a random password, set same value in Cloud Scheduler AND Cloud Run. This authenticates Cloud Scheduler → backend job triggers.
   - LANGSMITH_API_KEY (optional, for observability)
   - SENTRY_DSN (optional, for error monitoring)
3. SQL migrations — already done in development (same Supabase project). Only needed if setting up a fresh Supabase:
   - pgvector extension + ai_logs embedding columns + match_session_embeddings function
   - debts table: added columns (lender, interest_type, term_months, etc.)
   - Optional cleanup: bills CHECK constraint remove 'one_time'
4. Monitor Upstash Redis usage — 500k requests/month limit (drainDelay: 300000 keeps it under)

### After deploying backend:
5. Create Cloud Scheduler jobs (all use POST /api/jobs/trigger with Bearer token):
   - `market_data` — every 15 min
   - `news_fetch` — every 2 hours
   - `fd_scrape` — daily 06:00 MYT
   - `deals_scrape` — daily 07:00 MYT
   - Bill auto-advance check — daily 08:00 MYT
   - Proactive notifications — daily 09:00 MYT

### Before building Flutter APK:
6. Update `app_config.dart` baseUrl from localhost to Cloud Run URL
7. Set up APK signing keystore for release build
8. Verify Firebase `google-services.json` is for production project

# Git commit convention
git add .
git commit -m "Week X Day Y - description"
git push origin main
```

---

## Key Architectural Decisions

1. No timeout on Gemini calls — deliberate positive friction (user committed when they pressed Pay)
2. `current_balance` carries over monthly — `spent_amount` resets, `current_balance` never does
3. No manual UI to edit financial data — ALL vault/profile changes through Aion in chat
4. AI never writes directly to DB — always through backend validation layer
5. Transaction categorisation uses user's specific vault list — no global category list
6. Three transaction statuses only — approved, blocked, cancelled
7. No cancel button during AI loading screen — intentional product design
8. Gemini 2.5 Flash via Vertex AI — ADC auth, no JSON key file, no API key in .env
9. Deployment: Google Cloud Run — automatic Vertex AI auth, no service account JSON
10. Total Safe-to-Spend excludes goal/fund balances — goal money is not for spending
11. onboarding_complete = existence of `onboarding_profiles` row — no separate boolean
12. `spending_habit` in onboarding_profiles = extracted from user's own words (not AI-concluded)
13. `behavioral_classification` in ai_financial_profiles = AI's own observation from transaction patterns
14. `allocation_history` is append-only — never updated or deleted
15. No salary deposit frequency restriction — multiple deposits allowed for FYP demo
16. Session summarization fires on chat OPEN (not close) — summarizes the previous session
17. `last_summarised_at` injected by backend after Gemini returns — Gemini never sets timestamps
18. Financial Profile (`/profile`) is read-only and has NO nav bar — pushed from name tap
19. Account Profile (`/account-profile`) is the only place for user to edit personal data
20. Vault changes in chat → 2-step: Aion proposes → Flutter confirmation bottom sheet → user confirms → backend executes
21. `applyVaultPlanUpdate` syncs full vault plan: update existing, create new, soft-delete removed (`is_active=false`)
22. Temporary vault changes use `is_temporary: true` → stored in allocation_history `change_reason` with `[TEMPORARY]` prefix
23. `buildReviewerPrompt` used when vault plan already exists and user wants to adjust before confirming
24. `fetchVaults()` called explicitly before navigating after onboarding (StatefulShellRoute preserves state)
25. Transaction flow pre-step: `POST /api/transactions/categorize` → AI suggests vault → user can override → then `initiate`
26. RAG uses session-level chunking (one embedding per summarised session, not per message) — cosine threshold 0.72
27. Vault confirmation: `advisoryChat` returns `vault_plan_update` to Flutter — Flutter shows sheet. Only after "Confirm" does Flutter call `apply-vault-changes`. Swipe away = nothing applied
28. Recency buffer = 10 messages (5 ai_logs rows) — sized small for continuity, not history browsing
29. Proactive messages: `ai_response` uses `{message}` JSON format (same as chat) + `is_proactive=true` + `interaction_type='proactive'`. Old records may still be plain strings — all readers use `typeof` fallback.
30. `getChatHistory` fetches `interaction_type` IN `['chat', 'proactive']` for Flutter display. Gemini context (`advisoryChat` + `summarizeSession`) fetches `['chat', 'proactive', 'goal_guardian']` — Aion sees transaction history and its own warnings even though they don't appear as chat bubbles.
31. QR scanner: `_controller.stop()` on scan, `.then(() => restart())` on every `context.push()` — prevents black camera screen on return
32. General deposit: writes `current_balance += amount` AND `allocated_amount += amount` (unlike salary which splits across all vaults)
33. `vault_type='fund'` cards show 'GOAL' badge and 'Saving Goal' subtitle — differentiates from "Emergency Fund" naming
34. P2P transfer uses `phone_number` as recipient identifier — unique per user (enforced at registration)
35. Jina AI Reader URL format: `https://r.jina.ai/{target_url}` — returns clean Markdown, free for basic usage
36. 4-tier cache: Redis → MongoDB fresh (within TTL) → External API → MongoDB stale (last resort). See "4-Tier Cache Architecture" section.
37. MongoDB for document/append data (FD rates, deals, news, market cache, stock listings, volatility cache) — NOT for relational user data
38. Financial Health Score uses FHN FinHealth Score methodology — 8 sub-indicators across 4 dimensions (Spend, Save, Borrow, Plan). 3 tiers: Vulnerable (0-39), Coping (40-79), Healthy (80-100). Derived on demand, never stored.
39. Nav bar has 4 shell tabs: Home · Grow · [Scanner] · Discover · Profile. Chat/Aion is a push route (no nav bar when open). QR scanner floats above pill centre. Financial Profile push has no nav bar.
40. LangGraph ReAct agent (16 tools) + RAG (pgvector + multi-query + RRF) are fully implemented. Old single-shot Gemini call is kept as fallback only.
43. Investment categories limited to stocks, crypto, etf — all have real tickers + live pricing via Alpha Vantage / CoinGecko
44. Investment risk score: PRIIPs volatility mapping + HHI concentration penalty + Morningstar thresholds (0-23 Conservative, 24-47 Moderate, 48-78 Aggressive, 79-100 Very Aggressive). Real historical volatility from 90-day API data, not hardcoded.
45. Continuous AI Financial Profile updates: `profileUpdateService.js` fires `assessProfileUpdate()` after every financial event (salary, debt, investment, bill, transfer, Goal Guardian override/cancel). Gemini decides if profile should evolve.
46. Insurance coverage: 5 fixed types (medical_health, life_takaful, personal_accident, motor_vehicle, critical_illness) stored as JSONB on onboarding_profiles. Aion reads checklist before recommending — only suggests what's missing.
47. Password reset: in-app OTP flow via Supabase Auth — resetPasswordForEmail → verifyOTP(recovery) → updateUser(password). No backend endpoint needed.
41. BullMQ workers are DISABLED in development (`NODE_ENV !== 'production'`) to prevent burning Upstash Redis free tier limit. Workers auto-enable when deployed to Cloud Run with `NODE_ENV=production`. All workers use `drainDelay: 300000` (5-min polling) to stay under 500k requests/month. Data is fetched once on startup via `setTimeout` calls in development.
42. DEPLOYMENT REMINDER: Set `NODE_ENV=production` on Cloud Run — this enables BullMQ workers. Without it, workers won't start and Cloud Scheduler jobs won't be processed.

---

## Development Status & Build Sequence

### Completed ✅
- Weeks 1–5 core: Auth, Onboarding AI, Traffic Controller, Dashboard, Active Pilot, Goal Guardian, Advisory Chat, Financial Profile, Account Profile
- Transaction History screen (colour-coded status + transaction type + search + filter chips)
- General Deposit flow (general_deposit_screen.dart + QR type + seeded QR)
- QR scanner restart fix (black screen bug resolved)
- Vault cards showing `currentBalance` (actual money, not remaining budget)
- Fund/Goal terminology ('GOAL' badge, 'Saving Goal' label)
- Proactive messages appearing in chat history alongside regular chat messages
- Goal Completion Celebration (M28) — Lottie overlay + archive button + completed_at/is_archived columns
- Goal archive/unarchive — completed goals hideable from dashboard, visible in Achievements screen
- Completed goals excluded from salary preview (0% allocation, filtered out)
- Nav bar rebuilt: Home · Grow · [Scanner] · Discover · Profile (4-tab shell, Chat is push route)
- "View All" transactions button on spending chart → pushes /transactions
- Non-dismissible decision sheets — Goal Guardian, Active Pilot, vault picker, sweep sheet, onboarding vault summary all use `isDismissible: false` + `enableDrag: false`
- Sweep sheet `useRootNavigator: true` — renders above floating nav bar
- Proactive message format standardised to `{message}` JSON (matches chat format)
- Gemini chat context enriched — now includes proactive notifications + goal_guardian logs (transactions + warnings) alongside regular chat history
- Session summarisation includes proactive + goal_guardian logs
- Loading Skeletons / Shimmer (M27) — dashboard skeleton loading states
- Firebase Push Notifications (M6) — FCM token registration, proactive push, notification history bell
- P2P Transfer + Receive (M5) — send by phone number, receive QR, proactive notification to receiver
- Password Reset in Account Profile ✅ — OTP via email, in-app verification, change password bottom sheet
- Investment Planning (M8 + M12) ✅ — real volatility from Alpha Vantage/CoinGecko, Morningstar risk score, trader-friendly holdings editor (3 tabs: Crypto/Stocks/ETF), TradingView on separate page, Aion analysis with risk score + market context
- Continuous AI Financial Profile updates (#27) ✅ — profileUpdateService.js fires on every financial event (salary, debt, investment, bill, transfer, Goal Guardian override/cancel, Active Pilot)
- Financial Health Score (M10) ✅ — FHN FinHealth Score methodology, 8 sub-indicators, 4 dimensions (Spend/Save/Borrow/Plan), radial donut gauge with FHN colours, expandable dimension cards, hero card in Grow hub
- Deep Integration: Goal Guardian + spending velocity data, Active Pilot + vault warnings (bills, goals, emergency fund)
- Insurance checklist (5 types: medical, life, personal accident, motor, critical illness) in Protection screen, feeds into FHN health score + Aion recommendations
- Debt "Update Balance" button + debt_balance_snapshots for trending analysis
- Bill payment history logging (bill_payment_history table) for FHN on-time calculation
- News query broadened (finance/economy/stocks/investment/banking/inflation/cryptocurrency), 50 articles per fetch
- 4-tier cache architecture: Redis → MongoDB fresh → API → MongoDB stale
- LangGraph Agent — 16 tools (added get_health_score, get_investment_portfolio)
- Nav tab refresh on tap — Home + Profile reload data when tapped
- Login screen: overflow fix + user-friendly error messages

### Build Queue 🔴 (priority order — time-critical for FYP demo)

**HIGH PRIORITY — Core advisor experience:**
1. ~~LangGraph Agent + Aion tools~~ ✅
2. ~~Transaction page: back button + filter chips~~ ✅
3. ~~Debt Management (M7)~~ ✅
4. ~~Financial Health Score (M10)~~ ✅
5. ~~Vault Detail Screen (M30)~~ ✅
6. ~~Spending Forecast (M17)~~ ✅
7. ~~Timezone fix~~ ✅
8. ~~Deep integration audit~~ ✅

**MEDIUM PRIORITY — Feature completeness for demo:**
7. ~~Loan Calculator (M15)~~ ✅
9. ~~Financial News Feed (M14)~~ ✅
10. ~~FD + Savings Marketplace (M11)~~ ✅
11. ~~Smart Deals Page (M13)~~ ✅
12. ~~Password Reset in Account Profile~~ ✅

**LOWER PRIORITY — Polish and extras:**
13. ~~Financial Achievements (M24)~~ ✅
14. ~~Bill Reminders (M19)~~ ✅
15. ~~Protection Planning (M9)~~ ✅
16. ~~Investment Planning + TradingView (M8 + M12)~~ ✅ (waiting for Alpha Vantage daily reset to fully test)

**ARCHITECTURAL:**
24. ~~LangGraph Agent — 16 tools~~ ✅
25. ~~RAG Implementation~~ ✅
26. ~~4 data pipelines + 4-tier cache architecture~~ ✅
27. ~~Continuous AI Financial Profile updates~~ ✅
28. LangSmith 🔴— agent observability, traces every tool call (setup before demo)
29. Sentry 🔴— error monitoring backend + Flutter (setup before deployment)
30. Final🔴: Testing + Cloud Run Deployment + APK Build + Demo Video
