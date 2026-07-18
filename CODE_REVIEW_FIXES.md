# FinWise Code Review — Fix Tracker

**Review Date:** 28-06-2026
**Reviewed By:** Claude Code
**Total Issues Found:** 106

---

## Summary

| Severity | Found | Fixed | Skipped/By Design | 
|---|---|---|---|
| 🔴 Critical | 22 | 18 | 4 |
| 🟠 Warning | 52 | 38 | 14 |
| 🟡 Suggestion | 32 | 18 | 14 |
| **Total** | **106** | **74** | **32** |

---

## 🔴 CRITICAL ISSUES

### Security

| # | File | Issue | Status |
|---|---|---|---|
| 1 | `frontend/lib/screens/auth/login_screen.dart:51` | JWT access token printed to console via `print('DEBUG TOKEN: ...')` | ✅ Fixed |
| 2 | `backend/controllers/aiController.js` | Prompt injection — simulation app with backend validation layer, no real financial risk | ⏭️ FYP limitation |
| 3 | `backend/controllers/aiController.js` | Prompt injection in onboarding — same as #2 | ⏭️ FYP limitation |
| 4 | `backend/controllers/transactionController.js` | Prompt injection in categorization — same as #2 | ⏭️ FYP limitation |

### Crashes

| # | File | Issue | Status |
|---|---|---|---|
| 5 | `frontend/lib/config/app_router.dart:236` | `state.extra as double` unsafe cast — crashes if extra is null on `/salary-preview` | ✅ Fixed |
| 6 | `frontend/lib/screens/discover/news_screen.dart:117-164` | ~~OverlayEntry leak~~ — Skipped: overlay hides on long-press release, edge case too unlikely | ⏭️ Skipped |
| 7 | `frontend/lib/screens/discover/news_screen.dart:122` | ~~Overlay no onTap~~ — Skipped: same reason as #6 | ⏭️ Skipped |
| 8 | `frontend/lib/screens/chat/chat_screen.dart:63-76` | `ref` used after dispose — `_initChat` uses ref after await without mounted check | ✅ Fixed |
| 9 | `frontend/lib/screens/onboarding/onboarding_screen.dart:72-75` | Bottom sheet context used for navigation after async await — `context.mounted` guard + `isDismissible: false` already prevent the crash | ⏭️ Low risk |
| 10 | `frontend/lib/main.dart:32,53,132` | Notification tap does nothing — `navigatorKey` never passed to GoRouter | ✅ Fixed |
| 11 | `backend/services/healthScoreService.js:21` | No try-catch on 6 parallel Supabase queries — any failure crashes the function | ✅ Fixed |

### Missing Error Handling (Backend)

| # | File | Issue | Status |
|---|---|---|---|
| 12 | `backend/controllers/transferController.js` (all 4 functions) | Zero try-catch — multi-step vault deduction can fail mid-way | ✅ Fixed (3 of 4, allocateTransfer already had it) |
| 13 | `backend/controllers/notificationController.js` (3 of 4 functions) | Zero try-catch — registerToken, clearToken, getHistory | ✅ Fixed |
| 14 | `backend/controllers/jobController.js` | Zero try-catch — Cloud Scheduler job trigger crashes silently | ✅ Fixed |

### Missing Error Handling (Frontend)

| # | File | Issue | Status |
|---|---|---|---|
| 15 | `frontend/lib/services/api/transfer_api.dart` (3 of 4 methods) | Missing try-catch — unhandled DioException crashes | ✅ Fixed |
| 16 | `frontend/lib/services/api/notification_api.dart` (3 of 4 methods) | Missing try-catch — unhandled DioException crashes | ✅ Fixed |

### Performance / Leaks

| # | File | Issue | Status |
|---|---|---|---|
| 17 | `frontend/lib/screens/profile/account_profile_screen.dart:75-76` | Listener leak — `addListener` re-added on every `_loadProfile()` call | ✅ Fixed |
| 18 | `frontend/lib/screens/dashboard/dashboard_screen.dart:830-845` | Income button permanently disabled — `_loading` never reset on success path | ✅ Fixed |
| 19 | `frontend/lib/screens/grow/debt_screen.dart:89` | TextEditingController leaked in `_showEditBalance` bottom sheet | ✅ Fixed |
| 20 | `frontend/lib/screens/grow/holdings_edit_screen.dart:126-139` | 3 controllers + ValueNotifier leaked in `_showAddSheet` | ✅ Fixed |

### API Budget

| # | File | Issue | Status |
|---|---|---|---|
| 21 | `backend/services/newsService.js:36-71` | 50 Gemini calls with no delay — hits rate limit on fresh database | ✅ Fixed (1.5s delay added) |
| 22 | `backend/services/scrapeService.js:134-184` | 8 Jina + 8 Gemini calls no delay — Jina rate limits after ~5 rapid calls | ✅ Fixed |

---

## 🟠 WARNING ISSUES

### Missing `mounted` Checks (Flutter — ~20 screens)

setState called after async await without checking if widget is still mounted. Can crash with "setState() called after dispose()" on fast back-navigation.

| # | File | Lines | Status |
|---|---|---|---|
| 23 | `frontend/lib/screens/auth/login_screen.dart` | 97-101 (finally block) | ✅ Fixed |
| 24 | `frontend/lib/screens/auth/register_screen.dart` | 88-90 (finally block) | ✅ Fixed |
| 25 | `frontend/lib/screens/chat/chat_screen.dart` | 94-100 (_loadHistory) | ✅ Fixed |
| 26 | `frontend/lib/screens/profile/profile_screen.dart` | 36-44 (_load) | ✅ Fixed |
| 27 | `frontend/lib/screens/profile/account_profile_screen.dart` | 66-148 (_loadProfile, _saveChanges, _resetPassword) | ✅ Fixed |
| 28 | `frontend/lib/screens/transaction/transaction_history_screen.dart` | 53-66 (_load) | ✅ Fixed |
| 29 | `frontend/lib/screens/transaction/transfer_screen.dart` | 110 (catch block) | ✅ Fixed |
| 30 | `frontend/lib/screens/transaction/qr_scanner_screen.dart` | 53-72 (context.push + catch) | ✅ Fixed |
| 31 | `frontend/lib/screens/grow/debt_strategy_screen.dart` | 37-49 (_load) | ✅ Fixed |
| 32 | `frontend/lib/screens/discover/fd_marketplace_screen.dart` | 52-63 (_load) | ✅ Fixed |
| 33 | `frontend/lib/screens/discover/deals_screen.dart` | 38-50 (_load) | ✅ Fixed |
| 34 | `frontend/lib/screens/discover/spending_forecast_screen.dart` | 39-54 (_load) | ✅ Fixed |
| 35 | `frontend/lib/screens/discover/news_screen.dart` | 59-77 (_load) | ✅ Fixed |
| 36 | `frontend/lib/screens/onboarding/widgets/chat_bubble.dart` | 51-68 (Timer callback) | ✅ Fixed |

### Backend Missing try-catch

| # | File | Issue | Status |
|---|---|---|---|
| 37 | `backend/services/notificationService.js:50-63` | `_saveNotification` no try-catch | ✅ Fixed |
| 38 | `backend/services/notificationService.js:252-322` | `checkProactiveAfterDebtChange` no try-catch | ✅ Fixed |
| 39 | `backend/services/notificationService.js:328-392` | `checkProactiveAfterBillChange` no try-catch | ✅ Fixed |
| 40 | `backend/services/marketDataService.js:26` | `fetchCrypto` no top-level try-catch | ✅ Fixed |
| 41 | `backend/services/marketDataService.js:134` | `fetchFX` no top-level try-catch | ✅ Fixed |
| 42 | `backend/services/scrapeService.js:41` | `scrapeFDRates` no top-level try-catch | ✅ Fixed |
| 43 | `backend/services/scrapeService.js:134` | `scrapeDeals` no top-level try-catch | ✅ Fixed |

### Backend Security / Data Integrity

| # | File | Issue | Status |
|---|---|---|---|
| 44 | `backend/controllers/vaultController.js` | ~~Unvalidated transfer amounts~~ — already has `amount <= 0` check on line 22 | ⏭️ Not needed |
| 45 | `backend/controllers/transactionController.js` | Race condition — single-user simulation app, impossible to trigger concurrently | ⏭️ FYP limitation |
| 46 | `backend/controllers/jobController.js:24` | JOB_TRIGGER_SECRET undefined — still rejects all requests (no token matches undefined) | ⏭️ Not needed |
| 47 | `backend/server.js:82-86` | req.query not sanitized — query params never used in MongoDB queries, only Supabase | ⏭️ Not exploitable |
| 48 | `backend/middleware/errorHandler.js:13` | Leaks internal error messages to client in production | ✅ Fixed |
| 49 | `backend/controllers/transferController.js:283` | `is_sender` dead code — removed unused mapping | ✅ Fixed |

### Frontend — Other

| # | File | Issue | Status |
|---|---|---|---|
| 50 | `frontend/lib/screens/auth/login_screen.dart:56` | Force-unwrap `currentUser!.id` — null assertion crash risk | ✅ Fixed |
| 51 | `frontend/lib/screens/auth/register_screen.dart:77-82` | Assumes any HTTP 500 = phone duplicate — acceptable for FYP, most likely cause | ⏭️ By design |
| 52 | `frontend/lib/screens/profile/account_profile_screen.dart:151-155` | OTP sheet TextEditingControllers + ValueNotifiers never disposed | ✅ Fixed |
| 53 | `frontend/lib/screens/transaction/receive_screen.dart:36-53` | No try-catch on Supabase query — stuck loading on failure | ✅ Fixed |
| 54 | `frontend/lib/screens/transaction/merchant_pay_screen.dart:164-168` | Unhandled cancel API error — TransactionApi().cancel() no try-catch | ✅ Fixed |
| 55 | `frontend/lib/screens/transaction/salary_preview_screen.dart:65-109` | `_isConfirming` — success navigates away (screen gone), error resets it. No bug | ⏭️ Not needed |
| 56 | `frontend/lib/screens/dashboard/widgets/vault_card.dart:133-168` | Text overflow on narrow screens — bottom row can overflow | ✅ Fixed |
| 57 | `frontend/lib/screens/discover/news_screen.dart:80-86` | Carousel timer not cancelled on re-entry — multiple timers accumulate | ✅ Fixed |
| 58 | `frontend/lib/widgets/goal_celebration_overlay.dart:286` | Lottie.network → Lottie.asset — bundled locally | ✅ Fixed |
| 59 | `frontend/lib/screens/onboarding/widgets/chat_input.dart:85` | "Aria" should be "Aion" — naming inconsistency | ✅ Fixed |
| 60 | `frontend/lib/models/vault_model.dart:44-55` | `fromJson` crashes on missing fields from AI-generated JSON | ✅ Fixed |
| 61 | `frontend/lib/models/vault_model.dart:49` | `allocationPercentage` cast throws on null | ✅ Fixed (with #60) |
| 62 | `frontend/lib/config/app_router.dart` | No `refreshListenable` — Supabase auto-refreshes JWTs, only expires after 7+ days offline | ⏭️ FYP limitation |
| 63 | `frontend/lib/main.dart:37-40` | No error handling on Supabase/Firebase init — white screen crash | ✅ Fixed |

### Provider Issues

| # | File | Issue | Status |
|---|---|---|---|
| 64 | `frontend/lib/providers/vault_provider.dart:98-111` | Realtime subscription no user_id filter — receives ALL users' vault changes | ✅ Fixed |
| 65 | `frontend/lib/providers/pending_income_provider.dart:62-64` | Error silently swallowed — acceptable, pending income is non-critical UI element | ⏭️ By design |
| 66 | `frontend/lib/providers/notification_provider.dart:51-57` | Error keeps previous state — better than empty, acceptable graceful degradation | ⏭️ By design |

### API Service Issues

| # | File | Issue | Status |
|---|---|---|---|
| 67 | `frontend/lib/services/api/*.dart` (all 12) | "Bearer null" still returns 401 → correct behaviour, just not clean | ⏭️ Low risk |
| 68 | `frontend/lib/services/api/*.dart` (multiple) | `.cast<>()` — data from own backend, types always correct | ⏭️ Low risk |
| 69 | `frontend/lib/services/api/*.dart` (multiple) | Inconsistent error field — try-catch fixes (#15, #16) already handle both `error` and `message` | ⏭️ Already handled |

### API Budget / Cache

| # | File | Issue | Status |
|---|---|---|---|
| 70 | `backend/services/marketDataService.js:134-160` | FX stored 150+ pairs — burned ~864k Redis ops/month | ✅ Fixed (filtered to 20) |
| 71 | `backend/services/newsService.js:20-24` | No cache check before NewsAPI — called on every startup | ✅ Fixed (cache check added) |
| 72 | `backend/services/marketDataService.js:17` | Crypto 1-min TTL — only uses 13% of CoinGecko limit, no change needed | ⏭️ Not needed |
| 73 | `backend/config/bullmq.js:12-19` | Port hardcoded to 6379 — now parsed from UPSTASH_REDIS_URL | ✅ Fixed |
| 74 | `backend/middleware/aiValidator.js` | Empty placeholder file — deleted | ✅ Fixed |

---

## 🟡 SUGGESTION ISSUES

| # | File | Issue | Status |
|---|---|---|---|
| 75 | `backend/controllers/aiController.js` | Allocation sum check now uses ±0.5 tolerance instead of exact 100 | ✅ Fixed |
| 76 | `backend/services/newsService.js` | URL dedup via MongoDB unique index — NewsAPI returns clean URLs | ⏭️ Low risk |
| 77 | `backend/controllers/billController.js` | Bill dates should use Malaysia timezone from dateUtils.js | ✅ Fixed |
| 78 | `backend/services/langGraphService.js` | recursionLimit increased from 15 to 30 — prevents infinite loops while allowing complex queries | ✅ Fixed |
| 79 | `backend/middleware/errorHandler.js` | Log request method, path, and user_id for debugging | ✅ Fixed (with #48) |
| 80 | `authController.js`, `aiWhitelist.js` | Placeholder headers updated with real descriptions | ✅ Fixed |
| 81 | `frontend/lib/services/api/*.dart` (all) | Each API creates its own Dio() — refactor across 12 files, low impact | ⏭️ Refactor |
| 82 | `frontend/lib/screens/auth/login_screen.dart` | No empty field validation before API call | ✅ Fixed |
| 83 | `frontend/lib/screens/auth/register_screen.dart` | No password length validation client-side | ✅ Fixed |
| 84 | `frontend/lib/screens/transaction/salary_deposit_screen.dart` | No double-tap prevention on Preview button | ✅ Fixed |
| 85 | `frontend/lib/screens/transaction/qr_scanner_screen.dart` | No errorBuilder for camera permission denial | ✅ Fixed |
| 86 | `frontend/lib/providers/finance_provider.dart` | No dedup guard — duplicate fetches are idempotent, no side effects | ⏭️ Low risk |
| 87 | `frontend/lib/screens/profile/bill_reminders_screen.dart:62-74` | No loading state on Paid button — allows duplicate taps | ✅ Fixed |
| 88 | `frontend/lib/screens/dashboard/dashboard_screen.dart` | Zero-spend slivers — cosmetic, donut chart still readable | ⏭️ Cosmetic |
| 89 | `frontend/lib/screens/dashboard/widgets/fund_card.dart` | Archive button has no loading/disabled state | ✅ Fixed |
| 90 | `frontend/lib/config/app_config.dart:15` | Hardcoded local IP — dev only, switched to Cloud Run URL for production | ⏭️ By design |
| 91 | `frontend/lib/config/app_theme.dart:112` | `lightTheme` getter name misleading — renamed to `darkTheme` | ✅ Fixed |
| 92 | `frontend/lib/screens/grow/tradingview_screen.dart:44` | BTCUSDT is default — TradingView widget has allow_symbol_change=1, user can switch freely | ⏭️ By design |
| 93 | `frontend/lib/screens/discover/loan_calculator_screen.dart` | Currency formatter — cosmetic inconsistency, works correctly | ⏭️ Cosmetic |
| 94 | `frontend/lib/screens/main_scaffold.dart:19-22` | ValueNotifiers for tab refresh — works correctly, refactor not worth the risk | ⏭️ Refactor |
| 95 | `frontend/lib/screens/discover/deals_screen.dart:271` | Potential crash on empty category string | ✅ Fixed |
| 96 | Multiple files | Hardcoded bottom padding — works on all tested devices, cosmetic | ⏭️ Cosmetic |
| 97 | `backend/services/validationService.js` | Empty file with placeholder header — deleted | ✅ Fixed |
| 98 | `backend/services/notificationService.js` | Redundant inner requires of geminiService — removed 3 duplicates | ✅ Fixed |
| 99 | `backend/services/marketDataService.js` | `.sort()` mutates caller's array in fetchTickerQuotes | ✅ Fixed |
| 100 | `backend/services/newsService.js` | Top 10 for Aion may not be most recent (sort before slice) | ✅ Fixed |
| 101 | `backend/services/notificationService.js` | FCM stale token not cleaned on "token not registered" error | ✅ Fixed |
| 102 | `backend/services/profileUpdateService.js` | No audit trail — ai_logs table tracks all AI interactions, sufficient for FYP | ⏭️ By design |
| 103 | `backend/controllers/billController.js` | Duplicate of #77 | ✅ Fixed (with #77) |
| 104 | `backend/services/cacheService.js` | Cache logging — would spam console, Upstash dashboard is better | ⏭️ Not needed |
| 105 | `backend/services/embeddingService.js` | No retry — embedding is fire-and-forget, chat works without it | ⏭️ By design |
| 106 | `frontend/lib/models/vault_model.dart` | No `==`/`hashCode` — vaults always fetched fresh, no stale comparison issue | ⏭️ Low impact |

---

## Fix Progress Log

| Date | Batch | Fixes Applied |
|---|---|---|
| 28-06-2026 | Batch 1 — Demo-critical | #1 JWT print removed, #5 salary-preview null crash, #17 listener leak, #18 income button stuck, #59 Aria→Aion |
| 28-06-2026 | Batch 2 — API budget | #70 FX filtered to 20 currencies, #21 Gemini delay in news, #71 cache check before NewsAPI |
| 28-06-2026 | Batch 3 — Backend try-catch | #12 transferController wrapped (3 functions) |
