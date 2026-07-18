# FinWise — Use Case Diagram Reference
**Programmer:** Lau Zheng Cheng (TP071393) | **Institution:** Asia Pacific University (APU)
**Status:** Finalised — use as reference for UCS, Activity Diagrams, and Sequence Diagrams

---

## 1. System & Scope

- **System Name:** FinWise — AI-Powered 24/7 Virtual Financial Advisor
- **System Type:** Simulation (not real banking)
- **Platform:** Android mobile app

---

## 2. Actors

| Actor | Type | Role |
|---|---|---|
| **User** | Primary (initiator) | The app user who performs all financial management actions |
| **Aion (AI Advisor)** | Secondary (participates) | The AI financial advisor — joins AI-driven use cases as a co-participant |
| **Cloud Scheduler** | Secondary (initiator) | Google Cloud Scheduler — triggers all background data refresh jobs on a schedule |

> **NOT actors:** Supabase, Firebase, MongoDB, Redis, Alpha Vantage, CoinGecko, ExchangeRate-API, NewsAPI, Jina AI Reader. These are infrastructure/external services, not actors.

---

## 3. All Use Cases (50 total)

### 3.1 Authentication & Onboarding
| # | Use Case | Actor(s) |
|---|---|---|
| UC01 | Register Account | User |
| UC02 | Login | User |
| UC03 | Logout | User |
| UC04 | Reset Password | User |
| UC05 | Complete Onboarding Chat | User, Aion |
| UC06 | Get Aion Vault Recommendations | User, Aion |

### 3.2 Proactive AI Advisory
| # | Use Case | Actor(s) |
|---|---|---|
| UC07 | Get Aion Proactive Notification | User, Aion |

### 3.3 AI Advisory Chat
| # | Use Case | Actor(s) |
|---|---|---|
| UC08 | Chat with Aion | User, Aion |
| UC09 | Propose Vault Changes | User, Aion |

### 3.4 Transaction — QR-Based
| # | Use Case | Actor(s) |
|---|---|---|
| UC10 | Scan QR Code | User |
| UC11 | Deposit Salary | User |
| UC12 | Auto-Allocate Salary to Vaults | User, Aion |
| UC13 | Pay Merchant | User |
| UC14 | Review Goal Guardian Warning | User, Aion |
| UC15 | Reallocate Funds via Active Pilot | User |

### 3.5 Transfer & Goals
| # | Use Case | Actor(s) |
|---|---|---|
| UC16 | Send P2P Transfer | User |
| UC17 | Archive Completed Goal | User |

### 3.6 Dashboard & History
| # | Use Case | Actor(s) |
|---|---|---|
| UC18 | View Vault Detail | User |
| UC19 | View Transaction History | User |
| UC20 | View Financial Profile | User |

### 3.7 Financial Health
| # | Use Case | Actor(s) |
|---|---|---|
| UC21 | View Financial Health Score | User |
| UC22 | Get Aion Health Advice | User, Aion |

### 3.8 Debt Management
| # | Use Case | Actor(s) |
|---|---|---|
| UC23 | Manage Debts | User |
| UC24 | Get Aion Debt Payoff Strategy | User, Aion |

### 3.9 Investment Planning
| # | Use Case | Actor(s) |
|---|---|---|
| UC25 | View Investment Portfolio | User |
| UC26 | Assess Investment Risk | User |
| UC27 | Get Aion Investment Analysis | User, Aion |
| UC28 | Manage Investments | User |
| UC29 | View TradingView Chart | User |

### 3.10 Protection Planning
| # | Use Case | Actor(s) |
|---|---|---|
| UC30 | View Protection Planning | User |
| UC31 | View Emergency Fund Status | User |
| UC32 | Update Insurance Coverage | User |
| UC33 | Get Aion Protection Recommendations | User, Aion |

### 3.11 Bill Reminders
| # | Use Case | Actor(s) |
|---|---|---|
| UC34 | Manage Bill Reminders | User |
| UC35 | Mark Bill as Paid | User |

### 3.12 Discover — Market & Finance Data
| # | Use Case | Actor(s) |
|---|---|---|
| UC36 | View Market Tickers | User |
| UC37 | View Financial News | User |
| UC38 | View Smart Deals | User |
| UC39 | View FD Rates | User |

### 3.13 Account & Extras
| # | Use Case | Actor(s) |
|---|---|---|
| UC40 | Edit Account Profile | User |
| UC41 | Change Password | User |
| UC42 | View Achievements | User |
| UC43 | Calculate Loan EMI | User |
| UC44 | View Amortisation Schedule | User |
| UC45 | View Spending Forecast | User |

### 3.14 Cloud Scheduler Jobs
| # | Use Case | Actor(s) |
|---|---|---|
| UC46 | Trigger Market Data Refresh | Cloud Scheduler |
| UC47 | Trigger News Fetch | Cloud Scheduler |
| UC48 | Trigger Deals Scraping | Cloud Scheduler |
| UC49 | Trigger FD Rate Scraping | Cloud Scheduler |
| UC50 | Trigger Bill Auto-Advance | Cloud Scheduler |

---

## 4. Relationships

### 4.1 <<include>> Relationships
`A <<include>> B` = When A is performed, B is ALWAYS performed as a mandatory sub-flow. Arrow: A → B (arrowhead at B).

| Including Use Case (A) | Included Use Case (B) | Meaning |
|---|---|---|
| Register Account | Complete Onboarding Chat | Every registration is always followed by onboarding chat |
| Complete Onboarding Chat | Get Aion Vault Recommendations | Onboarding always ends with Aion generating a vault plan |
| Deposit Salary | Auto-Allocate Salary to Vaults | Every salary deposit always triggers automatic allocation |
| View Investment Portfolio | Assess Investment Risk | Opening the portfolio screen always calculates the risk score |
| View Protection Planning | View Emergency Fund Status | Opening protection screen always shows emergency fund analysis |

### 4.2 <<extend>> Relationships
`C <<extend>> D` = C is an OPTIONAL behavior that conditionally adds to D. C is the extending use case, D is the base use case. Arrow goes FROM C TO D (arrowhead at D, the base).

| Extending Use Case (C) | Base Use Case (D) | Condition / Trigger |
|---|---|---|
| Propose Vault Changes | Chat with Aion | User chats with Aion specifically to adjust their vault plan |
| Deposit Salary | Scan QR Code | User scans the employer salary QR code |
| Pay Merchant | Scan QR Code | User scans a merchant payment QR code |
| Review Goal Guardian Warning | Pay Merchant | AI flags the transaction — Aion intercepts with a warning |
| Reallocate Funds via Active Pilot | Pay Merchant | Vault balance is insufficient — Active Pilot reallocation is triggered |
| Get Aion Health Advice | View Financial Health Score | User requests Aion's interpretation of their health score |
| Get Aion Debt Payoff Strategy | Manage Debts | User requests Aion's avalanche/snowball payoff strategy |
| Get Aion Investment Analysis | View Investment Portfolio | User requests Aion's investment commentary and advice |
| Manage Investments | View Investment Portfolio | User navigates to add/edit/delete their investment holdings |
| View TradingView Chart | View Investment Portfolio | User opens the full-screen TradingView chart for a specific asset |
| Update Insurance Coverage | View Protection Planning | User toggles their insurance coverage types on/off |
| Get Aion Protection Recommendations | View Protection Planning | User requests Aion's recommendations based on their coverage gaps |
| Mark Bill as Paid | Manage Bill Reminders | User marks a specific bill as paid in the current billing cycle |
| Change Password | Edit Account Profile | User specifically chooses to change their password via OTP flow |
| View Amortisation Schedule | Calculate Loan EMI | User expands the full amortisation schedule after entering loan details |

> **Arrow direction rule (consistent across ALL <<extend>> relationships):**
> All <<extend>> arrows in this diagram have the arrowhead AT the **Base Use Case (D)** — the optional/extending use case (C) points TOWARD the base. This applies to every row in the table above without exception.
> Explicitly confirmed by user: Scan QR Code, View Investment Portfolio, View Protection Planning, Pay Merchant, Chat with Aion, View Financial Health Score, Manage Debts, Manage Bill Reminders, Edit Account Profile, Calculate Loan EMI.

---

## 5. Actor-to-Use Case Summary

### User is an associated actor for:
All use cases in sections 3.1–3.13 are associated with the User — either initiated by the User, or received/viewed by the User.
> **Exception:** UC07 (Get Aion Proactive Notification) is **Aion-initiated**, not User-initiated. The User is the passive recipient. Aion is the primary initiator.

### Aion (AI Advisor) participates in (direct association line in diagram):
UC05, UC06, UC07, UC08, UC09, UC12, UC14, UC22, UC24, UC27, UC33

| UC | Use Case | Why Aion is a direct actor |
|---|---|---|
| UC05 | Complete Onboarding Chat | Aion IS the chatbot conducting the onboarding conversation |
| UC06 | Get Aion Vault Recommendations | Aion generates the personalised vault plan |
| UC07 | Get Aion Proactive Notification | Aion initiates and sends the proactive message |
| UC08 | Chat with Aion | Aion is the AI advisor being conversed with |
| UC09 | Propose Vault Changes | Aion proposes the vault restructure within chat |
| UC12 | Auto-Allocate Salary to Vaults | Aion's Traffic Controller performs the allocation |
| UC14 | Review Goal Guardian Warning | Aion generated the warning and intercepts the transaction |
| UC22 | Get Aion Health Advice | Aion provides per-dimension health score commentary |
| UC24 | Get Aion Debt Payoff Strategy | Aion generates the avalanche/snowball strategy |
| UC27 | Get Aion Investment Analysis | Aion analyses portfolio risk and provides investment commentary |
| UC33 | Get Aion Protection Recommendations | Aion recommends missing insurance based on coverage gaps |

> Use cases like Deposit Salary, Pay Merchant, View Financial Health Score, Manage Debts, View Investment Portfolio, View Protection Planning — these are **User-only** at the top level. Aion's involvement is through their included/extended sub-use cases only.

### Cloud Scheduler initiates:
UC46, UC47, UC48, UC49, UC50 (all background job triggers)

---

## 6. Removed / Excluded Use Cases (Design Decisions)

These were considered but deliberately excluded from the final UCD:

| Removed Use Case | Reason |
|---|---|
| Confirm Vault Setup | User-visible bottom sheet within the Complete Onboarding Chat flow — modelled as a sub-step of the onboarding use case, not a separate top-level use case in the UCD |
| Request Vault Plan Adjustments | A conversational sub-step within Complete Onboarding Chat where user asks Aion to adjust the vault plan before confirming (`buildReviewerPrompt`). Distinct from Propose Vault Changes (which is post-onboarding, within Chat with Aion). Excluded because it is modelled inside the onboarding use case, not as a standalone use case |
| Session Summarisation | Internal AI system action — not a user goal |
| RAG Search | Internal backend mechanism — not visible to user |
| Categorise Transaction | Internal AI step within Pay Merchant — not user-initiated |
| Receive P2P Transfer | Not a user-initiated action — it's a system event triggered by sender |
| General Deposit via QR | Treated as part of Scan QR Code flow, not a separate top-level use case |
| View Spending Velocity | Subsumed under View Spending Forecast |

---

## 7. Key System Notes (for UCS, Activity & Sequence Diagrams)

**Onboarding flow:**
- Triggered once, immediately after Register Account
- Aion conducts a natural conversation (8–12 exchanges) to collect: income, goals, spending habits, risk level
- Ends with Aion generating a vault plan (5–8 vaults, allocations summing to 100%)
- User can request adjustments before confirming
- Only after confirmation are `onboarding_profiles`, `ai_financial_profiles`, and `vaults` written to DB

**Scan QR Code flow:**
- QR payload contains `qr_type` field: `salary_deposit`, `general_deposit`, or a merchant ID
- `salary_deposit` → routes to Deposit Salary
- Merchant ID → routes to Pay Merchant

**Pay Merchant (transaction interception) flow — critical for Sequence Diagram:**
1. Check vault balance instantly (no AI)
2. If insufficient → block → trigger Reallocate Funds via Active Pilot (3-step popup)
3. If sufficient → AI categorises merchant → build Goal Guardian prompt → call Gemini
4. No cancel button during AI loading (deliberate positive friction — user committed)
5. If `alert_user = true` → show Review Goal Guardian Warning popup
6. User proceeds or cancels
7. If proceeds → deduct vault → write transaction → update AI financial profile silently

**Auto-Allocate Salary to Vaults:**
- `allocated_amount = salary × (allocation_percentage / 100)` per vault
- `spent_amount` resets to 0 for all vaults
- `current_balance` always carries over (never resets)
- Completed/archived goals receive 0% allocation

**Propose Vault Changes (via Chat with Aion):**
- Aion proposes changes in chat message as JSON
- Flutter shows a bottom sheet for user to review and confirm
- Only after user taps "Confirm" does Flutter POST to `/api/ai/chat/apply-vault-changes`
- Swipe away bottom sheet = no changes applied

**Reallocate Funds via Active Pilot:**
- 3-step popup: (1) block notification + options, (2) show all vaults/goals for source selection, (3) confirm with before/after balances
- Transfers between vaults via `POST /api/vaults/transfer`
- Goals shown with a warning about impact on saving progress

**Review Goal Guardian Warning:**
- Aion sends `alert_message` + `alert_severity` (low/medium/high)
- User can proceed (transaction continues) or cancel
- Cancel → writes transaction with `status = 'cancelled'`
- Profile update happens silently regardless of user's choice

**Get Aion Proactive Notification:**
- Aion-initiated (not user-triggered)
- Stored as `ai_logs` with `is_proactive = true` and `interaction_type = 'proactive'`
- Delivered via FCM push + appears in chat history + notification bell on dashboard
- Triggers: after salary deposit, goal deadline, repeated overrides, bill due, P2P transfer received

**View Investment Portfolio:**
- Always calculates risk score on open (`<<include>> Assess Investment Risk`)
- Risk score uses PRIIPs volatility mapping + HHI concentration penalty
- Morningstar thresholds: 0–23 Conservative, 24–47 Moderate, 48–78 Aggressive, 79–100 Very Aggressive
- USD/MYR toggle uses live FX rate

**View Protection Planning:**
- Always shows emergency fund analysis on open (`<<include>> View Emergency Fund Status`)
- Emergency fund target = 6 months of monthly expenses (sum of vault allocated amounts)
- Insurance checklist: 5 types (medical_health, life_takaful, personal_accident, motor_vehicle, critical_illness)
- Checklist status feeds into FHN Financial Health Score (Plan dimension)

**Cloud Scheduler Jobs:**
- All go through `POST /api/jobs/trigger` with bearer token
- Workers only run in production (`NODE_ENV = 'production'`)
- Schedules: Market Data every 15 min, News every 2h, FD Scrape daily 06:00, Deals daily 07:00, Bill Auto-Advance daily 08:00

---

## 8. Routes Reference (for Sequence Diagrams)

| Use Case | Frontend Screen | Backend Route |
|---|---|---|
| **— Authentication & Onboarding —** | | |
| Register Account | register_screen.dart | Supabase Auth — supabase.auth.signUp() |
| Login | login_screen.dart | Supabase Auth — supabase.auth.signInWithPassword() |
| Logout | account_profile_screen.dart | Supabase Auth — supabase.auth.signOut() |
| Reset Password | account_profile_screen.dart | Supabase Auth — resetPasswordForEmail → verifyOtp → updateUser |
| Complete Onboarding Chat | onboarding_screen.dart | POST /api/ai/onboarding/chat |
| Get Aion Vault Recommendations | onboarding_screen.dart (confirm sheet) | POST /api/ai/onboarding/confirm-vaults |
| **— AI Advisory —** | | |
| Get Aion Proactive Notification | dashboard_screen.dart (bell icon) | GET /api/notifications/history |
| Chat with Aion | chat_screen.dart | POST /api/ai/chat |
| Propose Vault Changes | chat_screen.dart (confirmation bottom sheet) | POST /api/ai/chat/apply-vault-changes |
| **— QR-Based Transactions —** | | |
| Scan QR Code | qr_scanner_screen.dart | — (reads QR payload only, no backend call) |
| Deposit Salary | salary_deposit_screen.dart → salary_preview_screen.dart | POST /api/income/inject |
| Auto-Allocate Salary to Vaults | salary_preview_screen.dart (happens inside Deposit Salary) | Executed inside POST /api/income/inject |
| Pay Merchant | merchant_pay_screen.dart | POST /api/transactions/categorize → POST /api/transactions/initiate → POST /api/transactions/execute |
| Review Goal Guardian Warning | merchant_pay_screen.dart (Goal Guardian popup) | Response from POST /api/transactions/initiate (when alert_user = true) |
| Reallocate Funds via Active Pilot | merchant_pay_screen.dart (Active Pilot bottom sheet) | POST /api/vaults/transfer |
| **— Transfers & Goals —** | | |
| Send P2P Transfer | transfer_screen.dart | POST /api/transfer/send |
| Archive Completed Goal | dashboard_screen.dart (goal card) | POST /api/vaults/:id/archive |
| **— Dashboard & History —** | | |
| View Vault Detail | vault_detail_screen.dart | GET /api/vaults/status + GET /api/transactions/history |
| View Transaction History | transaction_history_screen.dart | GET /api/transactions/history |
| View Financial Profile | profile_screen.dart | GET /api/ai/profile |
| **— Financial Health —** | | |
| View Financial Health Score | health_score_screen.dart | GET /api/finance/health-score |
| Get Aion Health Advice | health_score_screen.dart (expandable dimension cards) | Included in GET /api/finance/health-score response |
| **— Debt Management —** | | |
| Manage Debts | debt_screen.dart | GET / POST / PATCH / DELETE /api/debt |
| Get Aion Debt Payoff Strategy | debt_strategy_screen.dart | GET /api/debt/strategy |
| **— Investment Planning —** | | |
| View Investment Portfolio | investment_screen.dart | GET /api/invest/risk + GET /api/invest/analysis |
| Assess Investment Risk | investment_screen.dart (risk score card) | GET /api/invest/risk (called on screen open) |
| Get Aion Investment Analysis | investment_screen.dart (Aion commentary) | GET /api/invest/analysis |
| Manage Investments | holdings_edit_screen.dart | POST /api/invest/save-all |
| View TradingView Chart | tradingview_screen.dart | — (WebView only, no backend) |
| **— Protection Planning —** | | |
| View Protection Planning | protection_screen.dart | GET /api/finance/protection |
| View Emergency Fund Status | protection_screen.dart (emergency fund card) | Included in GET /api/finance/protection response |
| Update Insurance Coverage | protection_screen.dart (insurance checklist) | PATCH /api/finance/insurance |
| Get Aion Protection Recommendations | protection_screen.dart (Aion recs section) | Included in GET /api/finance/protection response |
| **— Bill Reminders —** | | |
| Manage Bill Reminders | bill_reminders_screen.dart | GET / POST / PATCH / DELETE /api/bills |
| Mark Bill as Paid | bill_reminders_screen.dart (mark paid button) | PATCH /api/bills/:id |
| **— Discover —** | | |
| View Market Tickers | discover_screen.dart | GET /api/finance/ticker |
| View Financial News | news_screen.dart | GET /api/finance/news |
| View Smart Deals | deals_screen.dart | GET /api/finance/deals |
| View FD Rates | fd_marketplace_screen.dart | GET /api/finance/fd-rates |
| **— Account & Extras —** | | |
| Edit Account Profile | account_profile_screen.dart | PATCH /api/auth/profile |
| Change Password | account_profile_screen.dart (password section) | Supabase Auth — verifyOtp(recovery) → updateUser |
| View Achievements | achievements_screen.dart | GET /api/achievements |
| Calculate Loan EMI | loan_calculator_screen.dart | — (local calculation only, no backend) |
| View Amortisation Schedule | loan_calculator_screen.dart (expanded section) | — (local calculation only, no backend) |
| View Spending Forecast | spending_forecast_screen.dart | GET /api/finance/spending-forecast |
| **— Cloud Scheduler Jobs —** | | |
| Trigger Market Data Refresh | — (no Flutter screen) | POST /api/jobs/trigger { jobType: 'market_data' } |
| Trigger News Fetch | — (no Flutter screen) | POST /api/jobs/trigger { jobType: 'news_fetch' } |
| Trigger Deals Scraping | — (no Flutter screen) | POST /api/jobs/trigger { jobType: 'deals_scrape' } |
| Trigger FD Rate Scraping | — (no Flutter screen) | POST /api/jobs/trigger { jobType: 'fd_scrape' } |
| Trigger Bill Auto-Advance | — (no Flutter screen) | POST /api/jobs/trigger { jobType: 'bill_advance' } |
