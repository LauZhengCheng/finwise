# FinWise — AI-Powered 24/7 Virtual Financial Advisor

> Final Year Project · Asia Pacific University (APU) · Lau Zheng Cheng (TP071393)

FinWise is an Android mobile application that acts as a personal financial advisor, available around the clock. Instead of one big bank balance, users manage their money through personalised **vaults** (spending categories) and **goals** (saving targets). An AI advisor named **Aion** monitors spending in real time, intercepts risky transactions before money leaves the account, and proactively guides users toward financial wellness — covering the seven roles of a human financial advisor.

> **Note:** FinWise is a simulation system built for academic demonstration. All financial operations use simulated data — no real money is involved.

---

## Key Features

**Money Management**
- 🚦 **Traffic Controller** — salary deposits are automatically split across vaults by personalised allocation percentages
- 💰 **Vaults & Goals** — real-time balances via Supabase Realtime, with carryover that never resets
- 📱 **QR Payments** — scan-to-pay flow with 21 seeded merchant QR codes
- 🔁 **P2P Transfers** — send and receive money by phone number

**AI Advisor (Aion)**
- 🤖 **Advisory Chat** — a LangGraph ReAct agent with 16 callable tools that autonomously fetches balances, debts, market data, and more before advising
- 🧠 **Long-Term Memory** — RAG over embedded session summaries (pgvector, cosine similarity) lets Aion recall conversations from weeks ago
- 🛡️ **Goal Guardian** — every payment is analysed against the user's goals, debts, and bills; risky purchases trigger a warning popup before money moves
- ✈️ **Active Pilot** — blocked payments open a guided vault-reallocation flow with context-aware warnings
- 🔔 **Proactive Outreach** — scheduled and event-driven advice via push notifications

**Financial Planning**
- 📊 **Financial Health Score** — FHN FinHealth methodology, 8 indicators across Spend/Save/Borrow/Plan
- 💳 **Debt Management** — avalanche vs snowball payoff strategy analysis
- 📈 **Investment Portfolio** — live prices, TradingView charts, and a risk score built on real 90-day volatility (PRIIPs mapping + HHI concentration + Morningstar bands)
- ☂️ **Protection Planning** — emergency fund analysis and insurance checklist
- 🔎 **Discover Hub** — live market tickers, AI-summarised financial news, scraped FD rates, and smart deals

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart), Riverpod, GoRouter, Dio |
| Backend | Node.js, Express.js |
| AI | Gemini 2.5 Flash via Google Vertex AI (ADC auth), LangGraph, Zod |
| Primary Database | Supabase (PostgreSQL + Auth + Realtime + pgvector + RLS) |
| Document Store | MongoDB Atlas (external/scraped data) |
| Cache & Jobs | Upstash Redis, BullMQ |
| Notifications | Firebase Cloud Messaging |
| Deployment | Google Cloud Run, Cloud Build, Cloud Scheduler |
| External Data | Alpha Vantage, CoinGecko, Finnhub, ExchangeRate-API, NewsAPI, Jina AI Reader |

---

## Architecture Highlights

- **AI never writes to the database directly** — every Gemini/agent output passes through schema validation, field whitelisting, and business-logic checks before any write
- **4-tier cache fallback** — Redis → MongoDB (fresh) → external API → MongoDB (stale): the app survives cache outages, API failures, and free-tier rate limits by degrading gracefully instead of failing
- **Positive friction by design** — deliberate interception at the moment of payment, grounded in behavioural finance research on impulse spending
- **Polyglot persistence** — PostgreSQL for the financial ledger (ACID, RLS), MongoDB for schema-flexible external data

---

## Project Structure

```
fyp-neobanking/
├── backend/          # Node.js + Express API
│   ├── controllers/  # Route handlers (transactions, AI, finance, ...)
│   ├── services/     # Gemini, LangGraph agent, RAG, caching, scraping
│   ├── workers/      # BullMQ background jobs (FD rates, deals, news)
│   ├── middleware/   # JWT auth, error handling
│   ├── models/       # Mongoose schemas (MongoDB collections)
│   └── __tests__/    # Jest unit test suites
├── frontend/         # Flutter Android app
│   ├── lib/screens/  # 31 screens across 4 tab shells + push routes
│   ├── lib/providers/# Riverpod state management
│   ├── lib/services/ # API clients (Dio with JWT injection)
│   └── test/         # Flutter widget tests
└── database/         # Supabase PostgreSQL schema (16 tables)
```

---

## Getting Started

### Prerequisites

- Node.js 18+, Flutter SDK 3.x, an Android device/emulator
- Accounts: Supabase, MongoDB Atlas, Upstash, Google Cloud (Vertex AI enabled), Firebase
- Google Cloud ADC for Gemini: `gcloud auth application-default login`

### Environment Variables

Create `backend/.env` with:

```
SUPABASE_URL=            SUPABASE_ANON_KEY=
GOOGLE_CLOUD_PROJECT=    GOOGLE_CLOUD_LOCATION=asia-southeast1
MONGODB_URI=             UPSTASH_REDIS_URL=        UPSTASH_REDIS_TOKEN=
ALPHA_VANTAGE_API_KEY=   COINGECKO_API_KEY=        EXCHANGERATE_API_KEY=
NEWS_API_KEY=            FINNHUB_API_KEY=
FIREBASE_SERVICE_ACCOUNT_PATH=                     JOB_TRIGGER_SECRET=
PORT=3000                NODE_ENV=development
```

### Run

```bash
# Backend
cd backend
npm install
node server.js

# Frontend (separate terminal)
cd frontend
flutter pub get
flutter run
```

### Test

```bash
cd backend && npm test          # Jest unit suites
cd frontend && flutter test     # Flutter widget tests
```

---

## Screenshots

<!-- Add app screenshots here -->
<!-- <p align="center"><img src="..." width="200"> <img src="..." width="200"> <img src="..." width="200"></p> -->

---

## Author

**Lau Zheng Cheng** (TP071393)
BSc (Hons) Software Engineering — Asia Pacific University of Technology & Innovation

*FinWise is an academic project. It does not provide licensed financial advice.*
