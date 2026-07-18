# FinWise — FYP Project
# Programmer : Lau Zheng Cheng (TP071393)
# Institution : Asia Pacific University (APU)

---

## Project Overview

**FinWise** is an AI-powered 24/7 personal financial advisor Android mobile app.
This is a simulation system — NOT a real banking app.
All financial operations use simulated/mock data.

**Core Concept:** Instead of one big bank balance, users have personalised
"vaults" (spending categories) and "funds" (saving goals). AI advisor named
Aion monitors spending, gives real-time advice, and intervenes when needed.

**Academic Context:** FYP for APU — demonstrating RAG architecture,
agentic AI behaviour, and positive friction design for impulse spending control.

**4 Core Modules:**
1. Traffic Controller — automated income allocation engine
2. Real-Time Dashboard — live vault balance visualisation
3. Active Pilot + Goal Guardian — transaction interception and AI advisory
4. AI Advisory Chat + Proactive Notifications — 24/7 financial advisor

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) — Android ONLY |
| State Management | Riverpod |
| Navigation | go_router |
| Backend | Node.js + Express.js |
| Database | Supabase (PostgreSQL) |
| Authentication | Supabase Auth |
| AI Model | Google Gemini 2.5 Flash via Vertex AI |
| AI SDK | @google/genai |
| AI Auth | Application Default Credentials (ADC) — NO JSON key file |
| QR Scanning | mobile_scanner Flutter package |
| Push Notifications | flutter_local_notifications + Firebase Cloud Messaging |
| API Testing | EchoAPI for Cursor |
| Version Control | GitHub (private repo: fyp-neobanking) |
| Deployment | Google Cloud Run — covered by $300 GCP credit |

---

## Project Structure

```
C:\fyp-neobanking\
  backend\
    config\
      supabase.js          — Supabase client singleton
      gemini.js            — Vertex AI Gemini client (ADC auth)
      aiWhitelist.js       — Allowed AI update fields whitelist
    controllers\
      aiController.js
      vaultController.js
      transactionController.js
      incomeController.js
      authController.js
    middleware\
      auth.js              — JWT verification via Supabase, sets req.user
      errorHandler.js      — Centralised error handler (registered LAST in server.js)
      aiValidator.js       — Validates AI request payloads
    routes\
      auth.js              — /api/auth/... incl. PATCH /api/auth/profile (update name + phone)
      ai.js                — /api/ai/...
      vaults.js            — /api/vaults/...
      transactions.js      — /api/transactions/...
      income.js            — /api/income/...
    services\
      geminiService.js     — safeGeminiCall(), buildOnboardingPrompt(), buildGoalGuardianPrompt(), buildChatPrompt(), buildCategorizationPrompt(), buildSummarizationPrompt()
      supabaseService.js   — getProfile(), getUserVaults(), getRecentTransactions(), getRecentChatMessages(), checkOnboardingComplete()
      validationService.js
      notificationService.js
    constants\
      index.js             — All enums and constants
    server.js              — Express entry point, port 3000
    .env                   — SUPABASE_URL, SUPABASE_ANON_KEY, GOOGLE_CLOUD_PROJECT, GOOGLE_CLOUD_LOCATION

  frontend\
    lib\
      main.dart            — Supabase init, ProviderScope, MaterialApp.router
      config\
        app_router.dart    — GoRouter — all routes + auth redirect logic
        app_theme.dart     — Material3 theme, colours, AppTheme class
      constants\
        app_constants.dart — All enums: TransactionStatus, VaultType, etc.
      models\
        vault_model.dart
        message_model.dart
      providers\
        auth_provider.dart
        onboarding_provider.dart
        vault_provider.dart
      screens\
        auth\
          welcome_screen.dart
          login_screen.dart
          register_screen.dart
        onboarding\
          onboarding_screen.dart
          widgets\
            chat_bubble.dart
            chat_input.dart
        dashboard\
          dashboard_screen.dart
          views\
          widgets\
            vault_card.dart
            fund_card.dart
            spending_chart.dart
        transaction\
          qr_scanner_screen.dart
          salary_deposit_screen.dart
          salary_preview_screen.dart
          merchant_pay_screen.dart
          widgets\
            active_pilot_popup.dart
            goal_guardian_popup.dart
        chat\
          chat_screen.dart
        profile\
          profile_screen.dart       — Financial Profile (read-only, pushed via name tap)
          account_profile_screen.dart — Account Profile (nav bar tab, editable)
        settings\
      services\
        api\
          auth_api.dart             — getProfile(), updateProfile()
          ai_api.dart
          vault_api.dart
          transaction_api.dart
          income_api.dart
      utils\
      widgets\
    android\
    pubspec.yaml

  database\
    schema.sql             — Complete SQL for all 10 tables
```

---

## Database — 10 Tables in Supabase

All tables have RLS enabled. Users can only access their own data.

| # | Table | Purpose |
|---|---|---|
| 1 | `profiles` | User identity — linked to Supabase auth.users. Columns: id, full_name, email, phone_number, created_at, updated_at |
| 2 | `onboarding_profiles` | User-declared financial facts from onboarding conversation |
| 3 | `ai_financial_profiles` | AI-concluded intelligence — classification, insights, recommendations |
| 4 | `vaults` | Personalised spending vaults and saving funds |
| 5 | `vault_transfers` | All money movements between vaults |
| 6 | `transactions` | Every transaction attempt with full Goal Guardian data |
| 7 | `merchant_qr_codes` | 20 simulated merchant QRs + 1 salary deposit QR |
| 8 | `income_injections` | Salary deposit records with allocation snapshot |
| 9 | `ai_logs` | All AI interactions with validation tracking |
| 10 | `allocation_history` | Timeline of all AI recommendation changes — append only |

### Key Field Rules

**vaults table:**
- `vault_type` CHECK IN ('vault', 'fund')
  - `vault` = spending category — no goal fields
  - `fund` = saving goal — must have `linked_goal` and `goal_target_amount`
- `UNIQUE(user_id, category_key)` — unique per user not globally
- `current_balance` carries over each month — never resets
- `spent_amount` resets to 0 each income cycle
- `allocated_amount` updates each income cycle
- `category_key` must always be lowercase_underscore format

**onboarding_profiles — financial_goals JSONB format:**
```json
{
  "goals": [
    {
      "goal": "Trip to Japan",
      "timeline": "1 year",
      "priority": "short-term",
      "added_date": "2026-05-23"
    }
  ]
}
```

**ai_financial_profiles:**
- `behavioral_classification` ENUM — enforced at DB and backend level:
  `disciplined_saver`, `balanced_spender`, `impulse_spender`,
  `risk_averse`, `high_variability_spender`, `goal_oriented_spender`
- `recommended_allocation` JSONB — must always sum to 100%

**ai_logs:**
- `interaction_type` CHECK IN:
  `'chat'`, `'goal_guardian'`, `'background_analysis'`, `'proactive'`, `'system_notification'`
- `validation_status` CHECK IN:
  `'passed'`, `'schema_failed'`, `'business_logic_failed'`, `'fallback_used'`

**transactions:**
- `status` CHECK IN ('approved', 'blocked', 'cancelled')
- `transaction_type` CHECK IN ('expense', 'income', 'transfer')
- `ai_categorisation_attempts` max 2 retries — if both fail, user manually selects vault

---

## Authentication Flow

1. Supabase handles login/signup directly in Flutter — no backend call needed
2. After registration → auto-login → navigate to `/onboarding`
3. After login → check if `onboarding_profiles` row exists:
   - Yes → navigate to `/dashboard`
   - No → navigate to `/onboarding`
4. Session persists across app restarts (Instagram-like behaviour)
5. Logout clears session → shows Welcome screen on next open
6. Flutter stores JWT — Dio injects as `Authorization: Bearer <token>`
7. Backend `middleware/auth.js` validates JWT via `supabase.auth.getUser(token)`

**Supabase Auth Trigger:**
Auto-creates `profiles` row on registration.
Captures `full_name` and `phone_number` from `raw_user_meta_data` — both passed by Flutter during `signUp()`.
Uses `SET search_path = public` — critical for finding tables correctly.

---

## AI System Architecture

### AI Advisor: Aion
Warm, natural, real financial advisor personality.
Never robotic. Never uses system-like language.
Always speaks as if she knows the user personally.

### Three Profile Tables
- `profiles` = identity layer
- `onboarding_profiles` = user-declared truth (user says it)
- `ai_financial_profiles` = AI-concluded intelligence (AI observes it)

### AI Memory — 3 Layers
| Layer | Storage | Scope |
|---|---|---|
| Long-term personality | `onboarding_profiles` + `ai_financial_profiles` | Permanent |
| Behavioural memory | `ai_financial_profiles.key_insights` JSONB | Compressed session summaries |
| Short-term conversation | `ai_logs` — split by session boundary | Current session + recency buffer (last 10 messages) |

**onboarding_profiles vs key_insights — NOT the same thing:**
- `onboarding_profiles` = what the **user declared** about themselves (income, stated goals, life situation, risk level they chose, spending habits in their own words)
- `key_insights` = what **Aion observed and concluded** over sessions (behavioural patterns, how user responds to advice, spending habits observed, relationship notes, session summaries)
- Both are always sent to Gemini on every advisory chat call — they serve different roles and are not duplicates

**Session-Based Summarization:**
- `key_insights` has a special field `last_summarised_at` (ISO timestamp) — marks the session boundary
- When user opens the chat screen → `summarizeSession()` fires first (before history loads)
- `summarizeSession` finds all messages since `last_summarised_at`, calls `buildSummarizationPrompt`,
  Gemini merges them into existing `key_insights`, then `last_summarised_at` is updated to now
- This means each session is summarized exactly once — the next time the user opens chat
- Fire-and-forget — summarization failures are silently ignored, chat still works

**key_insights JSONB structure:**
```json
{
  "summary": "overall financial personality description",
  "financial_patterns": ["pattern 1", "pattern 2"],
  "goals_discussed": ["goal 1", "goal 2"],
  "behavioral_notes": ["note 1", "note 2"],
  "relationship_notes": ["note about user relationship with Aion"],
  "last_summarised_at": "2026-06-06T10:30:00.000Z"
}
```

**Chat context sent to Gemini (4 layers):**
1. `key_insights` + `onboarding_profiles` + vault balances — always included, full user understanding
2. Recency buffer — last 10 messages (5 rows) before the session boundary — bridges conversational continuity when user briefly exits and re-enters chat. NOT for reading history — purely so Aion understands vague references like "that thing we just discussed"
3. RAG — top 3 semantically relevant past sessions (pgvector similarity search) — **planned enhancement, not yet implemented**
4. Current session — all messages since `last_summarised_at` — entire current session verbatim

**Why recency buffer exists:**
Without it, if a user exits chat mid-conversation and immediately re-enters, `summarizeSession()` fires and moves the session boundary. The current session becomes empty. The user says "I checked that, can you fix it?" — Aion has no idea what "that" refers to. The 10-message buffer prevents this.

### Context Sent Per Gemini Call Type
| Call Type | Profile | Vault | Chat History | Transactions |
|---|---|---|---|---|
| Chat | Full (onboarding + AI profile) | Balances | 4-layer (see above) | None |
| Goal Guardian | Full | Balances | None | Last 10 |
| Categorisation | None | category_keys only | None | None |
| Proactive | Full | Balances | Last 5 | Last 10 |

---

## RAG Architecture — Planned Enhancement

**Current state:** FinWise uses context-augmented generation. Structured data is retrieved via SQL and injected into prompts. This works well for the current scale.

**True RAG** (Retrieval Augmented Generation) requires:
1. Vector embeddings of text content
2. Similarity search to retrieve semantically relevant records
3. Retrieved records injected into prompt context

**Why RAG only belongs in the advisory chat (not Goal Guardian, categorisation, or onboarding):**
- Goal Guardian: needs current transaction + profile — SQL is faster and more precise
- Categorisation: small fixed output space (user's vault list) — no large corpus to search
- Onboarding: no past history to retrieve from

**Planned implementation when RAG is added:**

| Step | What |
|---|---|
| Enable pgvector on Supabase | `CREATE EXTENSION vector` |
| Add embedding column to ai_logs | `embedding vector(768)` |
| Generate embedding after each session summary | Google `text-embedding-004` via Vertex AI (same ADC auth) |
| In advisoryChat: embed user's message → similarity search → top 3 sessions above threshold | Replaces recency buffer in Layer 3 |
| Update buildChatPrompt to include RAG context | New `ragContext` parameter |

**Session-level chunking (not message-level):**
Each summarised session = one embedding. Retrieving a session gives coherent conversation context, not disconnected fragments. Session boundary = `last_summarised_at` (same trigger as summarizeSession).

**Similarity threshold:** Only include sessions with cosine similarity > 0.72. If nothing is similar enough, Layer 3 is simply empty — key_insights + current session is sufficient.

### AI Update Rules — CRITICAL

**onboarding_profiles:**
| Field | Rule |
|---|---|
| `financial_goals` | Silent — add/remove based on explicit user statements only |
| `life_situation` | Silent — when user explicitly states change |
| `financial_challenges` | Silent — when user explicitly describes |
| `spending_habit` | Confirm first — extract from user's own words, map to ENUM value |
| `risk_level` | Confirm first — through natural conversation |
| `monthly_income` | Confirm first — detected via salary QR discrepancy |

**ai_financial_profiles — AI owns entirely, silent updates:**
- `behavioral_classification` — ENUM validated by backend before write
- `recommended_allocation` — must sum to 100%, validated before write
- `ai_reasoning` — always required when any update happens
- `key_insights` — append and summarise over time

**NEVER AI-updated:**
- `profiles` table
- `monthly_income` silently
- Any vault balances directly
- Any transaction records

### AI Safety Layer (Backend Validation — Every Gemini Response)
1. Schema validation — required fields exist, correct data types
2. Allowed field whitelist — only approved fields can be updated
3. Business logic validation — allocations sum to 100%, ENUM values correct
4. Fallback behaviour — if validation fails, graceful degradation not crash
5. Gemini NEVER writes to database directly — always through backend validator

---

## Complete Transaction Flow

```
User scans merchant QR → presses Pay
        ↓
Step 1  Flutter reads QR payload
Step 2  POST /api/transactions/initiate
Step 3  Instant vault balance check — READ vaults (no AI, ~50ms)

Outcome A — Vault insufficient:
  → Active Pilot block popup
  → WRITE transactions (status = 'blocked')
  → User reallocates → WRITE vault_transfers → retry

Outcome B — Vault sufficient:
Step 4  Fetch user context — READ onboarding_profiles + ai_financial_profiles + vaults
Step 5  Categorise merchant — Gemini call with merchant_name + user vault list
Step 6  Build Goal Guardian prompt with full context
Step 7  Flutter shows "Advisor reviewing..." — no cancel button during this
Step 8  Call Gemini API — no timeout (deliberate friction)
Step 9  Backend validates Gemini JSON response
Step 10 Deduct vault — WRITE vaults (ACID)
Step 11 WRITE transactions
Step 12 Silent WRITE ai_financial_profiles (behaviour update)
Step 13 WRITE ai_logs
        ↓
Return success → show success screen in Flutter (green checkmark + vault name + amount)
        ↓
User taps "Back to Dashboard" → Supabase real-time → dashboard updates
```

**Transaction outcomes in Flutter (merchant_pay_screen.dart):**
- `blocked` → show Active Pilot popup immediately
- `alert` → show "Advisor reviewing..." then Goal Guardian popup (proceed or cancel)
- `approved` → show success screen with vault name — user manually taps back
- No auto-navigation on approved — success screen is intentional confirmation moment

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
  "profile_update": {
    "update_needed": false,
    "updates": {}
  }
}
```

- `alert_user = true` → show Goal Guardian advisory popup → user chooses Proceed or Cancel
- `alert_user = false` → transaction confirmed instantly
- `status = 'cancelled'` → when user cancels after Goal Guardian popup

**Transaction Categorisation:**
- User vault category_keys ALWAYS included in categorisation prompt
- Max 2 retry attempts if invalid category returned
- If both fail → user manually selects vault once
- Record `ai_categorisation_failed = true` + dashboard notification

---

## Salary Deposit Flow (Traffic Controller)

```
Scan Employer QR (qr_type = 'salary_deposit')
        ↓
Popup: user enters salary amount
        ↓
POST /api/income/inject
        ↓
Traffic Controller: allocated_amount = salary × (percentage / 100) per vault
        ↓
Preview screen: shows each vault name + amount
        ↓
User confirms
        ↓
WRITE all vaults: current_balance += new allocation
WRITE income_injections with allocation_snapshot + carryover_snapshot
spent_amount resets to 0 for all vaults
        ↓
Supabase real-time → dashboard updates
        ↓
AI proactive notification about carryover surplus
```

---

## Onboarding AI Conversation Flow

```
New user → /onboarding screen
        ↓
Flutter sends __INIT__ → Aion greets warmly
        ↓
Natural conversation 8-12 exchanges
        ↓
Aion generates personalised vault structure as JSON
        ↓
Flutter shows BottomSheet vault summary
        ↓
User can adjust → Aion modifies → shows again
        ↓
User confirms → POST /api/ai/onboarding/confirm-vaults
        ↓
Backend saves: onboarding_profiles + ai_financial_profiles + vaults + allocation_history
        ↓
Navigate to /dashboard
```

**Vault Category Rules:**
- AI creates categories from conversation — NO fixed list
- `category_key` must be lowercase_underscore format
- 5-8 vaults total always
- Always include emergency and savings
- All allocation_percentage values must sum to exactly 100
- Similar vaults use specific keys: `travel_fund_japan` not `travel_fund`
- `vault_type = 'vault'` for spending, `vault_type = 'fund'` for saving goals
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

When ready to finalise — `vault_plan_ready: true` with full `profile_data` and `vault_recommendations`.

---

## Dashboard Design

Sections top to bottom:
1. Greeting + tappable first name with gold chevron `›` → pushes `/profile` (Financial Profile, no nav bar)
2. Bell icon → `/chat`
3. Total Safe-to-Spend — sum of vault balances ONLY, excludes fund balances
4. Quick actions: Transfer | AI Advisor | Receive
5. MY FUNDS — saving goals PageView with dot indicators
6. MY VAULTS — spending vaults container with progress bars
7. Spending donut chart

**No AppBar** — header is custom built inside body.

---

## Active Pilot Popup — 3 Steps

```
Step 1: Block notification + [Transfer from another vault] [Cancel]
Step 2: Show all vaults AND funds — if user picks Fund show warning about goal impact
Step 3: Confirm transfer — shows amounts before/after
```

---

## App Screens

| Screen | Route | Type | Purpose |
|---|---|---|---|
| Welcome | `/` | Action | Get Started + Login |
| Login | `/login` | Action | Email + password |
| Register | `/register` | Action | Name, email, phone, password — auto-login after |
| Onboarding Chat | `/onboarding` | Action | AI conversation — creates profile and vaults |
| Dashboard | `/dashboard` | Read-only | Live vault balances — name tap → Financial Profile |
| QR Scanner | `/qr-scanner` | Action | Scan merchant or salary QR |
| Transaction History | `/transactions` | Read-only | All past transactions |
| AI Advisor Chat | `/chat` | Action | Ongoing financial advisor relationship |
| Financial Profile | `/profile` | Read-only | What AI knows about user — pushed via name tap, no nav bar |
| Account Profile | `/account-profile` | Action | Edit name, phone; reset password; logout — nav bar tab |
| Goal Guardian Popup | — | Action | Proceed or cancel |
| Active Pilot Popup | — | Action | 3-step reallocation |
| Salary Preview | `/salary-preview` | Action | Confirm income allocation |

**No UI for editing financial data — ALL changes through AI chatbox conversation.**
**Account Profile is the only exception — name and phone number are editable there.**

---

## Gemini Service — 7 Functions

| Function | Purpose |
|---|---|
| `safeGeminiCall(prompt)` | Wraps every call — strips markdown, parses JSON, returns success/error |
| `buildOnboardingPrompt(history, context, isInit)` | New user onboarding conversation — collects profile + builds vault plan |
| `buildReviewerPrompt(history, context, currentVaults)` | Onboarding vault refinement — called when a vault plan already exists and user wants to adjust before confirming |
| `buildGoalGuardianPrompt(transaction, vaults, profile)` | Transaction analysis prompt |
| `buildChatPrompt(message, userContext, currentSessionHistory, pastSessionHistory)` | Advisory chat — session-aware 4-layer context |
| `buildCategorizationPrompt(merchantName, userVaults)` | Merchant categorisation — ALWAYS includes user vault list |
| `buildSummarizationPrompt(existingSummary, sessionMessages)` | Merges session messages into key_insights JSON — backend injects last_summarised_at, NOT Gemini |

---

## Coding Rules — ALWAYS FOLLOW

### File Header (every single file)
```javascript
// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : filename.js
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

---

## Run Commands

```bash
# Backend
cd C:\fyp-neobanking\backend
node server.js

# Frontend
cd C:\fyp-neobanking\frontend
flutter run

# Gemini ADC auth (run once per machine)
gcloud auth application-default login

# Git commit
git add .
git commit -m "Week X Day Y - description"
git push origin main
```

---

## Key Architectural Decisions

1. No timeout on Gemini calls — deliberate friction is intentional product design
2. Vault balance carries over monthly — `spent_amount` resets, `current_balance` carries
3. No manual UI to edit financial data — ALL changes through AI chatbox
4. AI never writes directly to DB — always through backend validation layer
5. Transaction categorisation uses user's specific vault list — no global category list
6. Three transaction statuses only — approved, blocked, cancelled
7. No cancel button during AI loading screen — user committed when they pressed Pay
8. Gemini 2.5 Flash via Vertex AI — ADC auth, no API key in .env
9. Deployment: Google Cloud Run — automatic Vertex AI auth, no JSON key file
10. Total Safe-to-Spend excludes Fund balances — Fund money is not for spending
11. Onboarding_complete is determined by existence of onboarding_profiles row — no separate boolean field
12. spending_habit in onboarding_profiles = extracted from user's own words — AI does not independently conclude it
13. behavioral_classification in ai_financial_profiles = AI's own observation from transaction patterns
14. allocation_history table is append-only — never updated or deleted
15. No salary deposit frequency restriction — user can deposit multiple times for FYP demo flexibility
16. Session summarization fires on chat OPEN (not on close) — avoids missed summarization from force-close; summarizes the previous session, not the current one
17. `last_summarised_at` is injected by backend after Gemini returns — Gemini never sets timestamps
18. Profile screen is read-only — 3 sections: what user declared, what Aion concluded, allocation history timeline
19. ALL vault changes after onboarding go through Aion in the advisory chat — no manual UI for vault editing
20. Vault changes in chat use a 2-step confirmation flow: Aion proposes specific changes → user confirms explicitly → backend executes via `applyVaultPlanUpdate`
21. `applyVaultPlanUpdate` syncs the full vault plan: update existing, create new, soft-delete removed (is_active=false, never hard-delete — transaction history preserved)
22. Vault changes include: create, delete, rename, change allocation %, temporary rebalance — all handled by the same `vault_plan_update` response field
23. Temporary changes use `is_temporary: true` in `vault_plan_update` — stored in allocation_history change_reason with [TEMPORARY] prefix for future revert reference
24. Transaction flow now has a pre-step: `POST /api/transactions/categorize` → AI suggests vault (no money moved) → user can change vault → then full `initiate` runs with chosen vault_id
25. FinWise uses context-augmented generation, NOT true RAG — SQL queries inject structured context into prompts. True RAG (pgvector embeddings + similarity search) is a planned future enhancement for the advisory chat only
26. RAG when implemented: embed at SESSION level (one vector per summarised session, not per message) — session boundary = user opens chat. Retrieve top 3 sessions with cosine similarity threshold (~0.72). Replace recency buffer with RAG layer once implemented
27. Vault confirmation bottom sheet: `advisoryChat` must NOT execute vault changes immediately — it returns `vault_plan_update` data to Flutter, which shows a confirmation bottom sheet. Only after user taps "Confirm Changes" does Flutter call `POST /api/ai/chat/apply-vault-changes`. Swipe/dismiss = nothing applied
28. Recency buffer is 10 messages (5 ai_logs rows, each row = 1 user + 1 AI turn) — purpose is conversational continuity, not history browsing. Sized small deliberately so it doesn't pollute the context with irrelevant older content
29. Proactive notifications deferred — requires Firebase Cloud Messaging setup. Dashboard AI notification card covers the same concept visually for the FYP demo (user opens app to see it rather than receiving a push notification)
30. `profiles` table includes `phone_number TEXT` (nullable) — collected at registration via Flutter `signUp()` metadata, stored via auth trigger, editable in Account Profile screen
31. Financial Profile (`/profile`) and Account Profile (`/account-profile`) are two completely different screens — Financial Profile is AI data (read-only, pushed from dashboard name tap, no nav bar); Account Profile is user settings (editable, nav bar 4th tab)
32. Nav bar has 4 shell tabs: Dashboard · Chat · Transactions · Account Profile. Scanner is a push route elevated above the pill. Financial Profile is a standalone push route outside the shell — nav bar never shows when viewing it
33. P2P transfer uses phone number as recipient identifier — phone numbers are unique per user (enforced at registration). Transfer and Receive buttons on dashboard are Coming Soon pending transfer feature implementation

---

## Seeded Merchant QR Codes (20 merchants + 1 salary)

Food: McDonald's Sunway Pyramid, KFC IOI City Mall, Tealive Mid Valley,
      GrabFood Delivery, Village Grocer Bangsar
Transport: Shell Petrol Station PJ, Grab Transport, Touch n Go Reload
Entertainment: TGV Cinemas 1 Utama, Steam Online Gaming, Spotify Premium
Shopping: H&M Pavilion KL, Uniqlo Suria KLCC
Health: Caring Pharmacy SS2, Fitness First Monthly
Education: Popular Bookstore, Udemy Online Course
Large purchases: Yamaha Motor Showroom PJ, Harvey Norman Electronics
Salary: Simulated Employer Sdn Bhd (qr_type: salary_deposit)

---

## 6-Week Development Plan

### Week 1 — Project Setup + Authentication
**Goal:** Working app with login before touching any feature.

- Environment setup — Cursor, Flutter, Node.js, Git, GitHub, Supabase, EchoAPI
- Database — 10 tables, RLS policies, auth trigger, seed data
- Flutter app skeleton — proper folder structure
- Welcome, Login, Register, Dashboard placeholder, Onboarding placeholder screens
- Authentication — Register → auto-login → Onboarding, Login → Dashboard
- Session persistence — stays logged in across app restarts
- Backend — server.js running, 5 routes tested, Supabase connected

**End checkpoint:** User can register, login, reach placeholder dashboard. Supabase tables created. Flutter and Node.js running and connected.

---

### Week 2 — Module 1: Traffic Controller + Onboarding AI
**Goal:** User completes AI onboarding and salary injection works.

**Part 1 — Gemini Service Setup:**
- Install @google/genai package
- Set up backend/config/gemini.js with Vertex AI ADC auth
- Create geminiService.js with 5 functions:
  - safeGeminiCall()
  - buildOnboardingPrompt()
  - buildGoalGuardianPrompt()
  - buildChatPrompt()
  - buildCategorizationPrompt()

**Part 2 — Onboarding Backend Routes:**
- POST /api/ai/onboarding/chat — receives message + history, calls Gemini, returns AI response
- POST /api/ai/onboarding/confirm-vaults — saves all onboarding data to DB
- aiController.js with onboardingChat() and confirmVaults()
- saveOnboardingData() — creates rows in onboarding_profiles, ai_financial_profiles, vaults, allocation_history
- AI output validation — sum to 100%, ENUM check, category_key format

**Part 3 — Flutter Onboarding Screen:**
- Replace onboarding_screen.dart placeholder with full AI chatbox UI
- Chat bubble interface — AI messages left, user messages right
- Loading indicator — "Advisor reviewing..." while waiting
- onboarding_provider.dart — Riverpod state for conversation
- message_model.dart, vault_model.dart
- When onboarding_complete=true → show vault summary BottomSheet → user confirms → navigate to dashboard

**Part 4 — Traffic Controller (Salary Deposit):**
- POST /api/income/inject — splits salary into vaults by percentage
- salary_deposit_screen.dart — user enters salary amount after scanning Employer QR
- salary_preview_screen.dart — shows each vault allocation before confirming
- vault_provider.dart

**Part 5 — QR Scanner Setup:**
- qr_scanner_screen.dart using mobile_scanner package
- Detect qr_type: salary_deposit → salary flow, merchant → transaction flow
- Android camera permission in AndroidManifest.xml

**End checkpoint:** User completes AI onboarding conversation. Personalised vaults created in Supabase. User can scan Employer QR, enter salary, see preview, confirm. All vault balances updated.

---

### Week 3 — Module 2: Real-Time Dashboard
**Goal:** User sees all vault balances updating live.

- Dashboard UI design using Galileo AI for inspiration
- Vault cards — name, allocated amount, remaining balance, progress bar
- Spending vault cards vs Fund/saving cards — different UI design
- MY VAULTS section (spending) and MY FUNDS section (saving goals)
- Total Safe-to-Spend — sum of vault balances only, excludes funds
- Spending donut chart using fl_chart
- Supabase real-time subscriptions — vault cards update automatically
- Riverpod StreamProvider for live state
- Transaction history list — last 5 transactions
- AI advisor notification card at TOP of dashboard if unread proactive message
- Notification badge on advisor card

**End checkpoint:** Dashboard shows all vault balances live. Updates automatically without manual refresh. Transaction history displays correctly. Advisor notification card works.

---

### Week 4 — Module 3: Active Pilot + Goal Guardian
**Goal:** Transactions intercepted and AI analyses every purchase.

**Active Pilot:**
- QR scanner reads merchant QR payload
- Instant vault balance check — no AI
- If insufficient → Active Pilot block popup (3-step UI)
  - Step 1: Block notification
  - Step 2: Select source vault including funds (with warning if fund selected)
  - Step 3: Confirm transfer
- WRITE vault_transfers on reallocation

**Goal Guardian:**
- If vault sufficient → call Gemini for transaction analysis
- Flutter shows "Advisor reviewing..." — no cancel button
- Gemini returns alert_user true/false
- If true → Goal Guardian advisory popup → user proceeds or cancels
- If false → transaction confirmed instantly
- Transaction categorisation — 2 attempts max, then user manually selects
- WRITE transactions, WRITE vaults (balance deduct), WRITE ai_financial_profiles, WRITE ai_logs

**End checkpoint:** Transactions approved when vault sufficient. Blocked with popup when insufficient. User can reallocate and retry. Goal Guardian advisory shows when conflict detected.

**Bug fixes applied post-completion:**
- active_pilot_popup.dart: `matched_vault` is a nested object in backend response — getters now read from `matched_vault.name` / `matched_vault.current_balance`, not flat fields
- merchant_pay_screen.dart: approved outcome now shows a success screen (green checkmark, vault name, amount) instead of navigating immediately — user taps "Back to Dashboard"

---

### Week 5 — Module 4: AI Advisory Chat + Proactive Notifications
**Goal:** User can chat with Aion anytime and receives proactive advice.

**Part 1 — AI Advisory Chat: ✅ COMPLETE**
- chat_screen.dart — WhatsApp-style persistent conversation, full history always visible
- Session-aware context — 4-layer Gemini context (key_insights + recency buffer 10 msgs + current session; RAG layer planned)
- `summarizeSession()` fires on chat open — summarizes previous session into key_insights
- Date dividers between days, typing indicator "Aion is thinking...", empty state for new users
- Reuses ChatBubble and ChatInput widgets from onboarding
- Routes: POST /api/ai/chat, GET /api/ai/chat/history, POST /api/ai/chat/summarize, POST /api/ai/chat/apply-vault-changes
- aiController: advisoryChat(), getChatHistory(), summarizeSession(), applyVaultChanges()
- Vault confirmation bottom sheet: Aion returns vault_plan_update → Flutter shows bottom sheet with NEW/UPDATED/DELETED badges → user taps Confirm → POST /api/ai/chat/apply-vault-changes → vaults refresh. Swipe away = nothing applied.

**Part 2 — Proactive Notifications: ⏳ DEFERRED**
- Firebase Cloud Messaging setup for background push notifications
- Notification triggers:
  - After income injection — carryover surplus detected
  - Income QR amount differs from stored monthly_income
  - Goal Guardian override pattern detected (user ignoring advice repeatedly)
  - Goal deadline approaching
- Notification tapped → opens chatbox → shows latest AI message
- ai_logs fields: is_proactive, notification_sent, notification_read

**Part 3 — My Financial Profile Screen: ✅ COMPLETE**
- profile_screen.dart — 3 sections:
  - "What You Told Aion" — monthly budget, life situation, spending habit, risk level, challenges, goals list
  - "What Aion Knows" — behavioural classification badge (colour-coded), key_insights notes, recommended allocation bars
  - "Allocation History" — vertical timeline with date, reason, triggered-by, allocation chips
- Route: GET /api/ai/profile → aiController.getMyProfile()
- Financial Profile accessed by tapping first name on dashboard (context.push — no nav bar shown)
- key_insights card hidden if empty (no sessions summarised yet — expected for fresh accounts)

**End checkpoint:** User can ask financial questions. AI responds with personalised advice. Profile screen shows AI knowledge. Proactive notifications deferred.

---

### Week 6 — Testing + Deployment
**Goal:** Polished, demo-ready system.

- Unit testing — vault allocation logic, transaction validation
- Integration testing — full Flutter to Node.js to Supabase to Gemini flow
- UAT — 3 to 5 users, collect feedback, document results
- Bug fixing and UI polish
- Deploy Node.js backend to Google Cloud Run (covered by $300 GCP credit)
- Update Flutter to point to deployed URL instead of localhost
- Build APK for real Android device demo
- Record backup demo video in case of technical issues on demo day
- Final GitHub commit — clean code, all files commented

**End checkpoint:** All testing documented. System deployed and accessible. Demo-ready on real Android device. Backup video recorded.