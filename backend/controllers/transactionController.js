// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : transactionController.js
// Description   : Transaction flow — merchant categorisation,
//                 vault balance check, Goal Guardian AI analysis,
//                 vault deduction, and transaction record writing
// First Written : 06-06-2026
// Edited on     : 06-06-2026
// ============================================

const supabase = require('../config/supabase');
const {
  safeGeminiCall,
  buildGoalGuardianPrompt,
  buildCategorizationPrompt,
} = require('../services/geminiService');

// ─────────────────────────────────────────────
// INITIATE TRANSACTION
// POST /api/transactions/initiate
//
// Flow:
//   1. Look up merchant
//   2. Categorise merchant → matched vault (max 2 Gemini retries)
//   3. Check vault balance
//   4a. Insufficient → write blocked transaction → return blocked
//   4b. Sufficient   → run Goal Guardian
//       → alert_user false: write everything → return approved
//       → alert_user true:  return alert (Flutter shows popup)
// ─────────────────────────────────────────────
const initiateTransaction = async (req, res) => {
  try {
    const { merchant_id, amount, vault_id: manualVaultId } = req.body;
    const user_id = req.user.id;

    if (!merchant_id || !amount || amount <= 0) {
      return res.status(400).json({ success: false, message: 'merchant_id and amount are required' });
    }

    // 1 — Look up merchant
    const { data: merchant, error: merchantError } = await supabase
      .from('merchant_qr_codes')
      .select('*')
      .eq('merchant_id', merchant_id)
      .single();

    if (merchantError || !merchant) {
      return res.status(404).json({ success: false, message: 'Merchant not found' });
    }

    // 2 — Fetch user's active vaults
    const { data: vaults, error: vaultError } = await supabase
      .from('vaults')
      .select('*')
      .eq('user_id', user_id)
      .eq('is_active', true);

    if (vaultError || !vaults?.length) {
      return res.status(400).json({ success: false, message: 'No active vaults found' });
    }

    // 3 — Categorise merchant (or use manual vault_id override)
    let matchedVault = null;
    let categorizationAttempts = 0;

    if (manualVaultId) {
      matchedVault = vaults.find(v => v.id === manualVaultId) || null;
    } else {
      while (!matchedVault && categorizationAttempts < 2) {
        categorizationAttempts++;
        const catResult = await safeGeminiCall(
          buildCategorizationPrompt(
            merchant.merchant_name,
            vaults.map(v => ({ name: v.name, category_key: v.category_key }))
          )
        );
        if (catResult.success && catResult.data?.category_key) {
          matchedVault = vaults.find(v => v.category_key === catResult.data.category_key) || null;
        }
      }
    }

    // Categorisation failed after both attempts → return for manual vault selection
    if (!matchedVault) {
      return res.json({
        outcome: 'categorisation_failed',
        merchant_name: merchant.merchant_name,
        amount,
        ai_categorisation_attempts: categorizationAttempts,
        vaults: vaults.map(v => ({
          id: v.id,
          name: v.name,
          category_key: v.category_key,
          vault_type: v.vault_type,
          current_balance: parseFloat(v.current_balance),
        })),
      });
    }

    // 4 — Balance check
    const currentBalance = parseFloat(matchedVault.current_balance);
    if (currentBalance < amount) {
      // Write blocked transaction
      const { data: blockedTx } = await supabase
        .from('transactions')
        .insert({
          user_id,
          vault_id: matchedVault.id,
          merchant_qr_id: merchant.id,
          amount,
          merchant_name: merchant.merchant_name,
          merchant_category: matchedVault.category_key,
          transaction_type: 'expense',
          status: 'blocked',
          block_reason: `Balance RM ${currentBalance.toFixed(2)} insufficient for RM ${parseFloat(amount).toFixed(2)}`,
          goal_conflict_detected: false,
          ai_categorisation_attempts: categorizationAttempts,
          ai_categorisation_failed: false,
        })
        .select('id')
        .single();

      return res.json({
        outcome: 'blocked',
        transaction_id: blockedTx?.id,
        merchant_name: merchant.merchant_name,
        merchant_id,
        amount,
        matched_vault: {
          id: matchedVault.id,
          name: matchedVault.name,
          category_key: matchedVault.category_key,
          current_balance: currentBalance,
        },
        shortfall: Math.round((amount - currentBalance) * 100) / 100,
        all_vaults: vaults.map(v => ({
          id: v.id,
          name: v.name,
          category_key: v.category_key,
          vault_type: v.vault_type,
          current_balance: parseFloat(v.current_balance),
        })),
      });
    }

    // 5 — Balance sufficient → run Goal Guardian
    const [{ data: onboardingProfile }, { data: aiProfile }] = await Promise.all([
      supabase.from('onboarding_profiles').select('*').eq('user_id', user_id).single(),
      supabase.from('ai_financial_profiles').select('*').eq('user_id', user_id).single(),
    ]);

    const guardianResult = await safeGeminiCall(
      buildGoalGuardianPrompt(
        {
          merchant_name: merchant.merchant_name,
          amount,
          matched_vault: { name: matchedVault.name, category_key: matchedVault.category_key },
        },
        vaults.map(v => ({
          name: v.name,
          category_key: v.category_key,
          vault_type: v.vault_type,
          current_balance: parseFloat(v.current_balance),
          allocated_amount: parseFloat(v.allocated_amount),
          spent_amount: parseFloat(v.spent_amount),
          allocation_percentage: v.allocation_percentage,
        })),
        {
          monthly_income: onboardingProfile?.monthly_income,
          financial_goals: onboardingProfile?.financial_goals,
          spending_habit: onboardingProfile?.spending_habit,
          risk_level: onboardingProfile?.risk_level,
          behavioral_classification: aiProfile?.behavioral_classification,
          key_insights: aiProfile?.key_insights,
        }
      )
    );

    // Fallback if Guardian Gemini call fails
    const guardian = guardianResult.success ? guardianResult.data : {
      alert_user: false,
      alert_message: null,
      alert_severity: null,
      matched_vault_category: matchedVault.category_key,
      profile_update: { update_needed: false, updates: {} },
    };

    // Log Goal Guardian analysis
    await supabase.from('ai_logs').insert({
      user_id,
      interaction_type: 'goal_guardian',
      user_message: `Transaction: ${merchant.merchant_name} RM ${amount}`,
      ai_response: guardian,
      raw_ai_response: guardian,
    });

    // 6a — Auto-approved (no alert) → write everything now
    if (!guardian.alert_user) {
      const newBalance = Math.round((currentBalance - amount) * 100) / 100;
      const newSpent = Math.round((parseFloat(matchedVault.spent_amount) + amount) * 100) / 100;

      await supabase.from('vaults').update({
        current_balance: newBalance,
        spent_amount: newSpent,
      }).eq('id', matchedVault.id);

      await supabase.from('transactions').insert({
        user_id,
        vault_id: matchedVault.id,
        merchant_qr_id: merchant.id,
        amount,
        merchant_name: merchant.merchant_name,
        merchant_category: matchedVault.category_key,
        transaction_type: 'expense',
        status: 'approved',
        goal_conflict_detected: false,
        goal_guardian_message: null,
        user_overrode_guardian: false,
        ai_categorisation_attempts: categorizationAttempts,
        ai_categorisation_failed: false,
      });

      await _applyProfileUpdate(user_id, guardian.profile_update);

      return res.json({
        outcome: 'approved',
        merchant_name: merchant.merchant_name,
        amount,
        matched_vault: { id: matchedVault.id, name: matchedVault.name },
      });
    }

    // 6b — Alert → return analysis, Flutter shows popup
    return res.json({
      outcome: 'alert',
      merchant_name: merchant.merchant_name,
      merchant_id,
      amount,
      vault_id: matchedVault.id,
      vault_name: matchedVault.name,
      alert_message: guardian.alert_message,
      alert_severity: guardian.alert_severity || 'medium',
      goal_guardian_result: guardian,
      categorisation_attempts: categorizationAttempts,
    });

  } catch (error) {
    console.error('initiateTransaction error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// EXECUTE TRANSACTION
// POST /api/transactions/execute
// Called when user presses "Proceed" on Goal Guardian popup.
// Deducts vault and writes approved transaction.
// ─────────────────────────────────────────────
const executeTransaction = async (req, res) => {
  try {
    const { merchant_id, vault_id, amount, goal_guardian_result, categorisation_attempts = 1 } = req.body;
    const user_id = req.user.id;

    if (!merchant_id || !vault_id || !amount) {
      return res.status(400).json({ success: false, message: 'merchant_id, vault_id, and amount are required' });
    }

    const [{ data: merchant }, { data: vault }] = await Promise.all([
      supabase.from('merchant_qr_codes').select('id, merchant_name').eq('merchant_id', merchant_id).single(),
      supabase.from('vaults').select('*').eq('id', vault_id).eq('user_id', user_id).single(),
    ]);

    if (!vault) {
      return res.status(404).json({ success: false, message: 'Vault not found' });
    }

    // Deduct vault
    await supabase.from('vaults').update({
      current_balance: Math.round((parseFloat(vault.current_balance) - amount) * 100) / 100,
      spent_amount: Math.round((parseFloat(vault.spent_amount) + amount) * 100) / 100,
    }).eq('id', vault_id);

    // Write approved transaction — user overrode Goal Guardian warning
    await supabase.from('transactions').insert({
      user_id,
      vault_id,
      merchant_qr_id: merchant?.id || null,
      amount,
      merchant_name: merchant?.merchant_name,
      merchant_category: vault.category_key,
      transaction_type: 'expense',
      status: 'approved',
      goal_conflict_detected: true,
      goal_guardian_message: goal_guardian_result?.alert_message,
      user_overrode_guardian: true,
      ai_categorisation_attempts: categorisation_attempts,
      ai_categorisation_failed: false,
    });

    await _applyProfileUpdate(user_id, goal_guardian_result?.profile_update);

    return res.json({ success: true, outcome: 'approved' });

  } catch (error) {
    console.error('executeTransaction error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// CANCEL TRANSACTION
// POST /api/transactions/cancel
// Called when user presses "Cancel" on Goal Guardian popup.
// Writes a cancelled transaction record.
// ─────────────────────────────────────────────
const cancelTransaction = async (req, res) => {
  try {
    const { merchant_id, vault_id, amount, goal_guardian_message } = req.body;
    const user_id = req.user.id;

    const [{ data: merchant }, { data: vault }] = await Promise.all([
      supabase.from('merchant_qr_codes').select('id, merchant_name').eq('merchant_id', merchant_id).single(),
      supabase.from('vaults').select('category_key').eq('id', vault_id).single(),
    ]);

    await supabase.from('transactions').insert({
      user_id,
      vault_id,
      merchant_qr_id: merchant?.id || null,
      amount,
      merchant_name: merchant?.merchant_name,
      merchant_category: vault?.category_key,
      transaction_type: 'expense',
      status: 'cancelled',
      goal_conflict_detected: true,
      goal_guardian_message,
      user_overrode_guardian: false,
      ai_categorisation_attempts: 1,
      ai_categorisation_failed: false,
    });

    return res.json({ success: true, outcome: 'cancelled' });

  } catch (error) {
    console.error('cancelTransaction error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// PROFILE UPDATE HELPER
// Applies AI-suggested profile updates safely
// Only allows whitelisted fields
// ─────────────────────────────────────────────
const _applyProfileUpdate = async (user_id, profileUpdate) => {
  if (!profileUpdate?.update_needed || !profileUpdate?.updates) return;

  const allowed = ['behavioral_classification', 'recommended_allocation', 'key_insights', 'ai_reasoning'];
  const safe = {};
  Object.keys(profileUpdate.updates).forEach(key => {
    if (allowed.includes(key)) safe[key] = profileUpdate.updates[key];
  });

  if (Object.keys(safe).length > 0) {
    await supabase.from('ai_financial_profiles').update(safe).eq('user_id', user_id);
  }
};

// ─────────────────────────────────────────────
// CATEGORIZE TRANSACTION
// POST /api/transactions/categorize
// Lightweight pre-step: looks up merchant, runs AI categorisation,
// returns the suggested vault + all vaults so the user can review
// or change before the full transaction is committed.
// No money is moved. No transaction record is written.
// ─────────────────────────────────────────────
const categorizeTransaction = async (req, res) => {
  try {
    const { merchant_id, amount } = req.body;
    const user_id = req.user.id;

    if (!merchant_id || !amount || amount <= 0) {
      return res.status(400).json({ success: false, message: 'merchant_id and amount are required' });
    }

    const { data: merchant, error: merchantError } = await supabase
      .from('merchant_qr_codes')
      .select('*')
      .eq('merchant_id', merchant_id)
      .single();

    if (merchantError || !merchant) {
      return res.status(404).json({ success: false, message: 'Merchant not found' });
    }

    const { data: vaults, error: vaultError } = await supabase
      .from('vaults')
      .select('id, name, category_key, vault_type, current_balance')
      .eq('user_id', user_id)
      .eq('is_active', true);

    if (vaultError || !vaults?.length) {
      return res.status(400).json({ success: false, message: 'No active vaults found' });
    }

    // Run categorisation — max 2 attempts
    let matchedVault = null;
    let attempts = 0;
    while (!matchedVault && attempts < 2) {
      attempts++;
      const catResult = await safeGeminiCall(
        buildCategorizationPrompt(
          merchant.merchant_name,
          vaults.map(v => ({ name: v.name, category_key: v.category_key }))
        )
      );
      if (catResult.success && catResult.data?.category_key) {
        matchedVault = vaults.find(v => v.category_key === catResult.data.category_key) || null;
      }
    }

    const allVaults = vaults.map(v => ({
      id: v.id,
      name: v.name,
      category_key: v.category_key,
      vault_type: v.vault_type,
      current_balance: parseFloat(v.current_balance),
    }));

    return res.json({
      success: true,
      merchant_name: merchant.merchant_name,
      merchant_id,
      amount,
      categorization_failed: !matchedVault,
      suggested_vault: matchedVault ? {
        id: matchedVault.id,
        name: matchedVault.name,
        category_key: matchedVault.category_key,
        vault_type: matchedVault.vault_type,
        current_balance: parseFloat(matchedVault.current_balance),
      } : null,
      all_vaults: allVaults,
    });

  } catch (error) {
    console.error('categorizeTransaction error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// GET TRANSACTION HISTORY
// GET /api/transactions/history
// Returns all transactions for the user, newest first
// ─────────────────────────────────────────────
const getTransactionHistory = async (req, res) => {
  try {
    const user_id = req.user.id;
    console.log('[history] fetching for user_id:', user_id);

    const { data: transactions, error } = await supabase
      .from('transactions')
      .select('id, amount, status, transaction_type, merchant_name, merchant_category, created_at, vault_id')
      .eq('user_id', user_id)
      .order('created_at', { ascending: false });

    console.log('[history] rows:', transactions?.length, '| error:', error?.message);

    if (error) throw error;

    // Fetch vault names separately to avoid PostgREST join hint issues
    const results = await Promise.all(
      (transactions ?? []).map(async (tx) => {
        if (!tx.vault_id) return { ...tx, vaults: null };
        const { data: vault } = await supabase
          .from('vaults')
          .select('name')
          .eq('id', tx.vault_id)
          .single();
        return { ...tx, vaults: vault ?? null };
      })
    );

    return res.json({ success: true, transactions: results });
  } catch (error) {
    console.error('getTransactionHistory error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

module.exports = { initiateTransaction, executeTransaction, cancelTransaction, categorizeTransaction, getTransactionHistory };
