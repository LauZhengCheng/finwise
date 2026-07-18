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
const { checkProactiveAfterTransaction } = require('../services/notificationService');
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
    // Only spending vaults (vault_type='vault') can receive merchant transactions.
    // Fund vaults are saving goals — they must never be deducted for spending.
    const spendingVaults = vaults.filter(v => v.vault_type === 'vault');
    let matchedVault = null;
    let categorizationAttempts = 0;

    if (manualVaultId) {
      matchedVault = spendingVaults.find(v => v.id === manualVaultId) || null;
    } else {
      while (!matchedVault && categorizationAttempts < 2) {
        categorizationAttempts++;
        const catResult = await safeGeminiCall(
          buildCategorizationPrompt(
            merchant.merchant_name,
            spendingVaults.map(v => ({ name: v.name, category_key: v.category_key }))
          )
        );
        if (catResult.success && catResult.data?.category_key) {
          matchedVault = spendingVaults.find(v => v.category_key === catResult.data.category_key) || null;
        }
      }
    }

    // Categorisation failed after both attempts → return spending vaults for manual selection
    if (!matchedVault) {
      return res.json({
        outcome: 'categorisation_failed',
        merchant_name: merchant.merchant_name,
        amount,
        ai_categorisation_attempts: categorizationAttempts,
        vaults: spendingVaults.map(v => ({
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
      // Fetch bills + debts for Active Pilot warnings
      const [{ data: apBills }, { data: apDebts }] = await Promise.all([
        supabase.from('bills').select('name, amount, due_date, vault_id, is_paid')
          .eq('user_id', user_id).eq('is_active', true).eq('is_paid', false),
        supabase.from('debts').select('name, current_monthly_payment, minimum_payment, due_date')
          .eq('user_id', user_id).eq('is_active', true),
      ]);

      const vaultsWithWarnings = vaults.map(v => {
        const balance = parseFloat(v.current_balance);
        const warnings = [];

        // Warning: vault is a saving goal
        if (v.vault_type === 'fund' && v.goal_target_amount) {
          const progress = Math.round((balance / parseFloat(v.goal_target_amount)) * 100);
          warnings.push(`Saving goal — ${progress}% complete`);
        }

        // Warning: bill linked to this vault
        const linkedBills = (apBills || []).filter(b => b.vault_id === v.id);
        for (const b of linkedBills) {
          const daysUntil = Math.ceil((new Date(b.due_date).getTime() - Date.now()) / 86400000);
          if (daysUntil <= 7) warnings.push(`${b.name} (RM ${parseFloat(b.amount).toFixed(0)}) due in ${daysUntil} days`);
        }

        // Warning: emergency fund coverage
        if (v.category_key?.includes('emergency')) {
          const onboarding = null;
          warnings.push(`Emergency fund — RM ${balance.toFixed(0)} remaining`);
        }

        // Warning: low balance after potential transfer
        if (balance > 0 && balance < amount) {
          warnings.push(`Would empty this vault`);
        }

        return {
          id: v.id,
          name: v.name,
          category_key: v.category_key,
          vault_type: v.vault_type,
          current_balance: balance,
          warnings,
        };
      });

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
        all_vaults: vaultsWithWarnings,
      });
    }

    // 5 — Balance sufficient → run Goal Guardian
    const [{ data: onboardingProfile }, { data: aiProfile }, { data: debts }, { data: bills }] = await Promise.all([
      supabase.from('onboarding_profiles').select('*').eq('user_id', user_id).single(),
      supabase.from('ai_financial_profiles').select('*').eq('user_id', user_id).single(),
      supabase.from('debts').select('name, debt_type, current_balance, interest_rate, minimum_payment, current_monthly_payment, due_date')
        .eq('user_id', user_id).eq('is_active', true),
      supabase.from('bills').select('name, amount, due_date, is_paid')
        .eq('user_id', user_id).eq('is_active', true).eq('is_paid', false),
    ]);

    const { getMonthContext } = require('../utils/dateUtils');
    const { day: dayOfMonth } = getMonthContext();

    const guardianResult = await safeGeminiCall(
      buildGoalGuardianPrompt(
        {
          merchant_name: merchant.merchant_name,
          amount,
          matched_vault: { name: matchedVault.name, category_key: matchedVault.category_key },
        },
        vaults.map(v => {
          const balance = parseFloat(v.current_balance);
          const spent = parseFloat(v.spent_amount);
          const avgDaily = dayOfMonth > 1 ? spent / (dayOfMonth - 1) : 0;
          const daysUntilEmpty = avgDaily > 0 ? Math.round(balance / avgDaily) : null;
          return {
            name: v.name,
            category_key: v.category_key,
            vault_type: v.vault_type,
            current_balance: balance,
            allocated_amount: parseFloat(v.allocated_amount),
            spent_amount: spent,
            allocation_percentage: v.allocation_percentage,
            avg_daily_spend: Math.round(avgDaily * 100) / 100,
            days_until_empty: daysUntilEmpty,
          };
        }),
        {
          monthly_income: onboardingProfile?.monthly_income,
          financial_goals: onboardingProfile?.financial_goals,
          spending_habit: onboardingProfile?.spending_habit,
          risk_level: onboardingProfile?.risk_level,
          behavioral_classification: aiProfile?.behavioral_classification,
          key_insights: aiProfile?.key_insights,
          debts: (debts || []).map(d => ({
            name: d.name, type: d.debt_type,
            balance: parseFloat(d.current_balance || 0),
            payment: parseFloat(d.current_monthly_payment || d.minimum_payment || 0),
            due_day: d.due_date,
          })),
          upcoming_bills: (bills || []).map(b => ({
            name: b.name,
            amount: parseFloat(b.amount || 0),
            due_date: b.due_date,
            days_until: Math.ceil((new Date(b.due_date).getTime() - Date.now()) / 86400000),
          })),
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

      // Fire-and-forget proactive check — never blocks the response
      checkProactiveAfterTransaction(user_id, matchedVault.id).catch(() => {});

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

    const { assessProfileUpdate } = require('../services/profileUpdateService');
    assessProfileUpdate(user_id, 'guardian_override', {
      merchant: merchant?.merchant_name, amount, alert_severity: goal_guardian_result?.alert_severity,
    }).catch(() => {});

    checkProactiveAfterTransaction(user_id, vault_id).catch(() => {});

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

    const { assessProfileUpdate } = require('../services/profileUpdateService');
    assessProfileUpdate(user_id, 'guardian_heeded', {
      merchant: merchant?.merchant_name, amount,
    }).catch(() => {});

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

    // Only spending vaults — fund vaults cannot be used for merchant payments
    const spendingVaults = vaults.filter(v => v.vault_type === 'vault');

    // Run categorisation — max 2 attempts
    let matchedVault = null;
    let attempts = 0;
    while (!matchedVault && attempts < 2) {
      attempts++;
      const catResult = await safeGeminiCall(
        buildCategorizationPrompt(
          merchant.merchant_name,
          spendingVaults.map(v => ({ name: v.name, category_key: v.category_key }))
        )
      );
      if (catResult.success && catResult.data?.category_key) {
        matchedVault = spendingVaults.find(v => v.category_key === catResult.data.category_key) || null;
      }
    }

    const allVaults = spendingVaults.map(v => ({
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
    const vault_id = req.query.vault_id;

    const [{ data: transactions, error }, { data: incomes }] = await Promise.all([
      supabase.from('transactions')
        .select('id, amount, status, transaction_type, merchant_name, merchant_category, created_at, vault_id, note')
        .eq('user_id', user_id)
        .order('created_at', { ascending: false }),
      supabase.from('income_injections')
        .select('id, amount, allocation_snapshot, status, injection_date, notes')
        .eq('user_id', user_id)
        .eq('status', 'applied')
        .order('injection_date', { ascending: false }),
    ]);

    if (error) throw error;

    // Fetch vault names for transactions
    const txResults = await Promise.all(
      (transactions ?? []).map(async (tx) => {
        if (vault_id && tx.vault_id !== vault_id) return null;
        if (!tx.vault_id) return { ...tx, vaults: null };
        const { data: vault } = await supabase
          .from('vaults')
          .select('name')
          .eq('id', tx.vault_id)
          .single();
        return { ...tx, vaults: vault ?? null };
      })
    );

    const filteredTx = txResults.filter(t => t !== null);

    // Merge income records into timeline
    const incomeRecords = [];
    for (const inc of (incomes || [])) {
      const snapshot = inc.allocation_snapshot || {};
      const isGeneralDeposit = inc.notes?.includes('general_deposit') || Object.keys(snapshot).length <= 1;

      if (vault_id) {
        // Vault-specific: find this vault's allocation from snapshot
        const vaultData = snapshot[vault_id];
        if (vaultData) {
          const allocatedAmount = typeof vaultData === 'object' ? (vaultData.allocated || 0) : vaultData;
          incomeRecords.push({
            id: `income_${inc.id}`,
            amount: parseFloat(allocatedAmount),
            status: 'approved',
            transaction_type: 'income',
            merchant_name: isGeneralDeposit ? 'General Deposit' : `Salary Allocation (${vaultData.percentage || 0}%)`,
            merchant_category: 'income',
            created_at: inc.injection_date,
            vault_id: vault_id,
            vaults: vaultData.name ? { name: vaultData.name } : null,
            is_income: true,
            total_income: parseFloat(inc.amount),
          });
        }
      } else {
        // General history: show 1 record per income
        incomeRecords.push({
          id: `income_${inc.id}`,
          amount: parseFloat(inc.amount),
          status: 'approved',
          transaction_type: 'income',
          merchant_name: isGeneralDeposit ? 'General Deposit' : 'Salary Deposit',
          merchant_category: 'income',
          created_at: inc.injection_date,
          vault_id: null,
          vaults: null,
          is_income: true,
        });
      }
    }

    // Combine and sort by date
    const combined = [...filteredTx, ...incomeRecords]
      .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());

    return res.json({ success: true, transactions: combined });
  } catch (error) {
    console.error('getTransactionHistory error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

module.exports = { initiateTransaction, executeTransaction, cancelTransaction, categorizeTransaction, getTransactionHistory };
