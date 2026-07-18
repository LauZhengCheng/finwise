// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : notificationService.js
// Description   : Proactive notification service — event-driven checks
//                 that ask Gemini whether Aria should message the user.
//                 All functions are fire-and-forget (never crash callers).
// First Written : 12-06-2026
// Edited on     : 12-06-2026
// ============================================

const supabase = require('../config/supabase');
const { getMessaging } = require('../config/firebase');
const { safeGeminiCall, buildProactivePrompt, buildGoalCompletionPrompt } = require('./geminiService');
const { getProfile, getUserVaults } = require('./supabaseService');

// ─────────────────────────────────────────────
// SEND FCM PUSH NOTIFICATION
// Looks up the user's FCM token and sends via Firebase.
// Fire-and-forget — never throws.
// ─────────────────────────────────────────────
const sendPushNotification = async (userId, title, body, route = '/chat') => {
  try {
    const { data: profile } = await supabase
      .from('profiles')
      .select('fcm_token')
      .eq('id', userId)
      .single();

    const token = profile?.fcm_token;
    if (!token) return;

    await getMessaging().send({
      token,
      notification: { title, body },
      data: { route },
      android: {
        priority: 'high',
        notification: { sound: 'default', clickAction: 'FLUTTER_NOTIFICATION_CLICK' },
      },
    });
  } catch (err) {
    console.error('[FCM] sendPushNotification failed:', err.message);
    if (err.code === 'messaging/registration-token-not-registered' ||
        err.code === 'messaging/invalid-registration-token') {
      await supabase.from('profiles').update({ fcm_token: null }).eq('id', userId);
      console.log(`[FCM] Cleared stale token for user ${userId}`);
    }
  }
};

// ─────────────────────────────────────────────
// SAVE PROACTIVE NOTIFICATION
// Writes an ai_logs row and sends an FCM push.
// ─────────────────────────────────────────────
const _saveNotification = async (userId, message) => {
  try {
    await supabase.from('ai_logs').insert({
      user_id: userId,
      interaction_type: 'proactive',
      user_message: null,
      ai_response: { message },
      is_proactive: true,
      notification_sent: true,
      notification_read: false,
      validation_status: 'passed',
    });

    await sendPushNotification(userId, 'Aion', message, '/chat');
  } catch (err) {
    console.error('[Notification] _saveNotification failed:', err.message);
  }
};

// ─────────────────────────────────────────────
// CHECK AFTER INCOME INJECTION
// Fires after Traffic Controller runs.
// Checks: carryover surplus, fund milestones.
// ─────────────────────────────────────────────
const checkProactiveAfterIncome = async (userId) => {
  try {
    const [profile, vaults, { data: onboarding }, { data: aiProfile }, { data: debts }, { data: bills }] = await Promise.all([
      getProfile(userId),
      getUserVaults(userId),
      supabase.from('onboarding_profiles').select('*').eq('user_id', userId).single(),
      supabase.from('ai_financial_profiles').select('behavioral_classification, key_insights').eq('user_id', userId).single(),
      supabase.from('debts').select('name, current_balance, current_monthly_payment, minimum_payment, due_date')
        .eq('user_id', userId).eq('is_active', true),
      supabase.from('bills').select('name, amount, due_date, is_paid')
        .eq('user_id', userId).eq('is_active', true).eq('is_paid', false),
    ]);

    const context = {
      trigger: 'after_income',
      profile,
      onboarding,
      aiProfile,
      vaults,
      debts,
      bills,
    };

    const prompt = buildProactivePrompt(context);
    const result = await safeGeminiCall(prompt);
    if (!result.success) return;

    const { level, message } = result.data;
    if (level === 'silent' || !message) return;

    await _saveNotification(userId, message);
  } catch (err) {
    console.error('[proactive] checkProactiveAfterIncome failed:', err.message);
  }
};

// ─────────────────────────────────────────────
// CHECK AFTER TRANSACTION
// Fires after an approved transaction.
// Checks: vault running low (< 15% remaining).
// ─────────────────────────────────────────────
const checkProactiveAfterTransaction = async (userId, vaultId) => {
  try {
    const { data: vault, error } = await supabase
      .from('vaults')
      .select('*')
      .eq('id', vaultId)
      .single();

    if (error || !vault) return;
    if (vault.vault_type !== 'vault') return;
    if (vault.allocated_amount <= 0) return;

    const remainingPercent = (vault.current_balance / vault.allocated_amount) * 100;
    if (remainingPercent >= 15) return;

    const [profile, vaults, { data: debts }] = await Promise.all([
      getProfile(userId),
      getUserVaults(userId),
      supabase.from('debts').select('name, current_balance, current_monthly_payment, minimum_payment, due_date')
        .eq('user_id', userId).eq('is_active', true),
    ]);

    const context = {
      trigger: 'vault_low',
      profile,
      vaults,
      debts,
      lowVault: vault,
      remainingPercent: Math.round(remainingPercent),
    };

    const prompt = buildProactivePrompt(context);
    const result = await safeGeminiCall(prompt);
    if (!result.success) return;

    const { level, message } = result.data;
    if (level === 'silent' || !message) return;

    await _saveNotification(userId, message);
  } catch (err) {
    console.error('[proactive] checkProactiveAfterTransaction failed:', err.message);
  }
};

// ─────────────────────────────────────────────
// CHECK GOAL COMPLETION
// Checks fund vaults where completed_at IS NULL — if any hit their
// target, sets completed_at + allocation_percentage=0 on the vault,
// generates a Gemini message, and sends FCM push.
// completed_at IS NULL is the dedup — once set, this vault never
// fires again regardless of balance. Returns completed_goals array.
// ─────────────────────────────────────────────
const checkGoalCompletion = async (userId) => {
  try {
    // Only query uncelebrated funds — completed_at IS NULL is the dedup
    const { data: vaults } = await supabase
      .from('vaults')
      .select('id, name, vault_type, current_balance, goal_target_amount, linked_goal, allocation_percentage')
      .eq('user_id', userId)
      .eq('is_active', true)
      .eq('vault_type', 'fund')
      .is('completed_at', null);

    if (!vaults || vaults.length === 0) return [];

    const newlyCompleted = vaults.filter(v =>
      v.goal_target_amount > 0 &&
      parseFloat(v.current_balance) >= parseFloat(v.goal_target_amount)
    );

    if (newlyCompleted.length === 0) return [];

    const profile = await getProfile(userId);
    const results = [];

    for (const vault of newlyCompleted) {
      try {
        // Stamp completed_at + zero out allocation immediately — prevents
        // re-fire even if Gemini is slow, and stops Traffic Controller allocating to it
        await supabase.from('vaults')
          .update({ completed_at: new Date().toISOString(), allocation_percentage: 0 })
          .eq('id', vault.id);

        const prompt = buildGoalCompletionPrompt(vault, profile);
        const result = await safeGeminiCall(prompt);

        if (result.success && result.data?.message) {
          const message = result.data.message;

          await supabase.from('ai_logs').insert({
            user_id: userId,
            interaction_type: 'proactive',
            user_message: null,
            ai_response: { message },
            is_proactive: true,
            notification_sent: true,
            notification_read: false,
            validation_status: 'passed',
          });

          await sendPushNotification(userId, 'Goal Achieved! 🎉', message, '/chat');

          results.push({
            vault_id: vault.id,
            vault_name: vault.name,
            goal_target_amount: parseFloat(vault.goal_target_amount),
            allocation_percentage: vault.allocation_percentage, // original % before zeroing
          });
        }
      } catch (err) {
        console.error(`[goal] celebration failed for vault ${vault.id}:`, err.message);
      }
    }

    return results;
  } catch (err) {
    console.error('[goal] checkGoalCompletion failed:', err.message);
    return [];
  }
};

// ─────────────────────────────────────────────
// CHECK AFTER INCOME
// Single entry point for all post-income notifications.
// Goal completion takes priority: if any goal was just hit,
// send the celebration message and return completed_goals.
// Otherwise fall through to the standard proactive check.
// ─────────────────────────────────────────────
const checkAfterIncome = async (userId) => {
  const completed_goals = await checkGoalCompletion(userId);
  if (completed_goals.length === 0) {
    checkProactiveAfterIncome(userId).catch(() => {});
  }
  return completed_goals;
};

// ─────────────────────────────────────────────
// PROACTIVE CHECK: After debt change
// Triggers when user adds/updates a debt.
// Aion sends a message to discuss the debt situation.
// ─────────────────────────────────────────────
const checkProactiveAfterDebtChange = async (userId) => {
  try {
  const { data: debts } = await supabase
    .from('debts')
    .select('name, debt_type, current_balance, interest_rate, minimum_payment')
    .eq('user_id', userId)
    .eq('is_active', true);

  if (!debts?.length) return;

  const [{ data: profile }, { data: vaults }] = await Promise.all([
    supabase.from('onboarding_profiles').select('monthly_income').eq('user_id', userId).single(),
    supabase.from('vaults').select('name, category_key, vault_type, allocation_percentage, current_balance, completed_at, is_archived')
      .eq('user_id', userId).eq('is_active', true),
  ]);

  const income = parseFloat(profile?.monthly_income || 0);
  const totalMonthlyPayment = debts.reduce((s, d) => s + parseFloat(d.minimum_payment || 0), 0);
  const debtToIncomeRatio = income > 0 ? Math.round(totalMonthlyPayment / income * 100) : 0;
  const monthlyInterest = debts.reduce((s, d) => {
    return s + parseFloat(d.current_balance || 0) * (parseFloat(d.interest_rate || 0) / 100 / 12);
  }, 0);
  const activeVaults = (vaults || []).filter(v => !v.completed_at && !v.is_archived);
  const hasDebtVault = activeVaults.some(v => v.category_key?.includes('debt'));

  const vaultSummary = activeVaults.map(v =>
    `${v.name}: ${v.allocation_percentage}%`
  ).join('\n');

  const prompt = `
You are Aion, a warm and direct financial advisor. The user just added or updated their debts.
Give SPECIFIC, ACTIONABLE advice — not a vague invitation to chat.

USER'S MONTHLY INCOME: RM ${income.toFixed(2)}

CURRENT DEBTS:
${debts.map(d => `- ${d.name} (${d.debt_type}): RM ${parseFloat(d.current_balance).toFixed(2)} at ${d.interest_rate || 0}% p.a., payment RM ${parseFloat(d.minimum_payment || 0).toFixed(2)}/month`).join('\n')}

TOTAL MONTHLY DEBT OBLIGATION: RM ${totalMonthlyPayment.toFixed(2)} (${debtToIncomeRatio}% of income)
MONTHLY INTEREST COST: RM ${monthlyInterest.toFixed(2)} (money lost to interest each month)

CURRENT VAULT ALLOCATION:
${vaultSummary}
${hasDebtVault ? 'User already has a debt-related vault.' : 'User does NOT have a debt repayment vault yet.'}

Write a proactive message using this EXACT structure with line breaks (use \\n for newlines):

Line 1: "Your total monthly debt obligation is RM X, with RM Y going to interest each month."
Line 2: blank line
Line 3: "Here's your current allocation:"
Lines 4+: list each vault as "• VaultName: X%" (one per line)
Line after list: blank line
Line next: ${hasDebtVault ? 'Suggest adjusting the existing debt vault percentage' : 'Suggest creating a Debt Repayment vault with a specific percentage and RM amount'}
Line next: Which debt to prioritise and why (mention the interest rate)
Line next: Which specific vaults to reduce (show old% → new%) to fund the debt vault
Line last: "Want me to set this up for you?"

IMPORTANT FORMATTING RULES:
- Use \\n for every line break
- Keep each section separated by a blank line (\\n\\n)
- Use • for bullet points
- Use → for allocation changes (e.g. "15% → 8%")
- Be warm but direct. Use actual RM numbers.

Respond in JSON: { "message": "your formatted message here with \\n line breaks" }`;

  const result = await safeGeminiCall(prompt);
  if (result.success && result.data?.message) {
    await _saveNotification(userId, result.data.message);
  }
  } catch (err) {
    console.error('[Notification] checkProactiveAfterDebtChange failed:', err.message);
  }
};

// ─────────────────────────────────────────────
// PROACTIVE CHECK: After bill change
// Checks if user's vaults cover their recurring bills.
// ─────────────────────────────────────────────
const checkProactiveAfterBillChange = async (userId) => {
  try {
  const { data: bills } = await supabase
    .from('bills')
    .select('name, amount, frequency')
    .eq('user_id', userId)
    .eq('is_active', true);

  if (!bills?.length) return;

  const [{ data: profile }, { data: vaults }] = await Promise.all([
    supabase.from('onboarding_profiles').select('monthly_income').eq('user_id', userId).single(),
    supabase.from('vaults').select('name, category_key, allocation_percentage, current_balance, completed_at, is_archived')
      .eq('user_id', userId).eq('is_active', true),
  ]);

  const income = parseFloat(profile?.monthly_income || 0);
  const activeVaults = (vaults || []).filter(v => !v.completed_at && !v.is_archived);
  const hasBillsVault = activeVaults.some(v =>
    v.category_key?.includes('bill') || v.category_key?.includes('utilit'));

  const totalMonthly = bills.reduce((s, b) => {
    const amt = parseFloat(b.amount || 0);
    switch (b.frequency) {
      case 'quarterly': return s + amt / 3;
      case 'annually': return s + amt / 12;
      default: return s + amt;
    }
  }, 0);

  const billsList = bills.map(b =>
    `${b.name}: RM ${parseFloat(b.amount).toFixed(2)} (${b.frequency})`
  ).join('\n');

  const vaultSummary = activeVaults.map(v =>
    `${v.name}: ${v.allocation_percentage}%`
  ).join('\n');

  const prompt = `
You are Aion, a warm financial advisor. The user just added or updated their recurring bills.

BILLS:
${billsList}
Total monthly bills: RM ${totalMonthly.toFixed(2)}

Monthly income: RM ${income.toFixed(2)}
${hasBillsVault ? 'User has a bills/utilities vault.' : 'User does NOT have a bills or utilities vault yet.'}

Current vault allocation:
${vaultSummary}

Write a SHORT proactive message (under 100 words) using \\n for line breaks:
${hasBillsVault
    ? '- Check if the bills vault allocation covers the total monthly bills. If yes, confirm. If not, suggest increasing it.'
    : '- Suggest creating a Bills/Utilities vault with a specific percentage to cover RM ' + totalMonthly.toFixed(2) + '/month.'}
- Mention the total monthly bill amount
- Be warm and helpful, not alarming

Respond in JSON: { "message": "your message here with \\n line breaks" }`;

  const result = await safeGeminiCall(prompt);
  if (result.success && result.data?.message) {
    await _saveNotification(userId, result.data.message);
  }
  } catch (err) {
    console.error('[Notification] checkProactiveAfterBillChange failed:', err.message);
  }
};

const checkProactiveAfterInvestmentChange = async (userId) => {
  try {
    const [{ data: investments }, { data: onboarding }, { data: debts }] = await Promise.all([
      supabase.from('investments').select('asset_name, category, units, purchase_price, current_price')
        .eq('user_id', userId).eq('is_active', true),
      supabase.from('onboarding_profiles').select('risk_level, monthly_income').eq('user_id', userId).single(),
      supabase.from('debts').select('name, current_balance, interest_rate')
        .eq('user_id', userId).eq('is_active', true),
    ]);

    if (!investments?.length) return;

    // Get USD→MYR rate: Redis → MongoDB
    const { cacheGet } = require('./cacheService');
    let usdToMyr = null;
    const fxCached = await cacheGet('market:MYRUSD');
    if (fxCached?.price) {
      usdToMyr = 1 / fxCached.price;
    } else {
      try {
        const { connectMongo } = require('../config/mongodb');
        const MarketDataCache = require('../models/MarketDataCache');
        await connectMongo();
        const doc = await MarketDataCache.findOne({ symbol: 'MYRUSD' }).lean();
        if (doc?.price) usdToMyr = 1 / doc.price;
      } catch (_) {}
    }

    const totalValueUsd = investments.reduce((s, i) => s + parseFloat(i.units) * parseFloat(i.current_price || i.purchase_price), 0);
    const rmSuffix = (usd) => usdToMyr ? ` (RM ${(usd * usdToMyr).toFixed(2)})` : '';
    const holdingsList = investments.map(i => {
      const valUsd = parseFloat(i.units) * parseFloat(i.current_price || i.purchase_price);
      return `${i.asset_name} (${i.category}): $${valUsd.toFixed(2)}${rmSuffix(valUsd)}`;
    }).join('\n');
    const debtInfo = (debts || []).length > 0
      ? `User has debts: ${debts.map(d => `${d.name} RM ${parseFloat(d.current_balance).toFixed(2)} at ${d.interest_rate}%`).join(', ')}`
      : 'No debts';

    const prompt = `
You are Aion. The user just updated their investment holdings.
Investment values are in USD. User's income and debts are in RM. Use USD primary with (RM xxx) when discussing.

Holdings (total $${totalValueUsd.toFixed(2)}${rmSuffix(totalValueUsd)}):
${holdingsList}

Risk tolerance: ${onboarding?.risk_level || 'not specified'}
Monthly income: RM ${onboarding?.monthly_income || 'unknown'}
${debtInfo}

Write a SHORT proactive message (under 80 words):
- Acknowledge the portfolio update
- One key observation (concentration risk, risk mismatch, or debt vs investment priority)
- Be warm and specific

Respond in JSON: { "message": "your message here" }`;

    const result = await safeGeminiCall(prompt);
    if (result.success && result.data?.message) {
      await _saveNotification(userId, result.data.message);
    }
  } catch (err) {
    console.error('[proactive] investment change failed:', err.message);
  }
};

module.exports = {
  checkProactiveAfterIncome,
  checkProactiveAfterTransaction,
  sendPushNotification,
  checkGoalCompletion,
  checkAfterIncome,
  checkProactiveAfterDebtChange,
  checkProactiveAfterBillChange,
  checkProactiveAfterInvestmentChange,
  _saveNotification,
};
