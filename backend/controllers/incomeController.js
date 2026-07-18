// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : incomeController.js
// Description   : Traffic Controller — salary staging (2-step) and
//                 general deposit. Stage saves pending without touching
//                 vaults; apply updates vaults after user's sweep choice.
// First Written : 06-06-2026
// Edited on     : 18-06-2026
// ============================================

const supabase = require('../config/supabase');
const { checkAfterIncome } = require('../services/notificationService');

// ─────────────────────────────────────────────
// INJECT INCOME
// POST /api/income/inject
// Splits salary into vaults by allocation_percentage,
// updates vault balances, resets spent_amount to 0,
// and saves an income_injections record.
// ─────────────────────────────────────────────
const injectIncome = async (req, res) => {
  try {
    const { amount } = req.body;
    const user_id = req.user.id;

    if (!amount || typeof amount !== 'number' || amount <= 0) {
      return res.status(400).json({ success: false, message: 'Valid amount is required' });
    }

    // Fetch all active vaults for this user
    const { data: vaults, error: vaultError } = await supabase
      .from('vaults')
      .select('*')
      .eq('user_id', user_id)
      .eq('is_active', true);

    if (vaultError) throw vaultError;
    if (!vaults || vaults.length === 0) {
      return res.status(400).json({ success: false, message: 'No active vaults found. Complete onboarding first.' });
    }

    // Calculate per-vault allocation (round to 2 decimal places)
    const allocations = vaults.map(vault => ({
      ...vault,
      new_allocated: Math.round(amount * (vault.allocation_percentage / 100) * 100) / 100,
    }));

    // Rounding correction: add any cent difference to the first vault
    const totalAllocated = allocations.reduce((sum, v) => sum + v.new_allocated, 0);
    const diff = Math.round((amount - totalAllocated) * 100) / 100;
    if (diff !== 0) {
      allocations[0].new_allocated = Math.round((allocations[0].new_allocated + diff) * 100) / 100;
    }

    // Build snapshots for the income_injections record
    const allocationSnapshot = {};
    const carryoverSnapshot = {};

    allocations.forEach(v => {
      allocationSnapshot[v.id] = {
        name: v.name,
        category_key: v.category_key,
        percentage: v.allocation_percentage,
        allocated: v.new_allocated,
      };
      carryoverSnapshot[v.id] = {
        name: v.name,
        category_key: v.category_key,
        balance_before: parseFloat(v.current_balance),
      };
    });

    // Update each vault: add allocation to current_balance, reset spent_amount
    for (const vault of allocations) {
      const newBalance = Math.round((parseFloat(vault.current_balance) + vault.new_allocated) * 100) / 100;
      const { error: updateError } = await supabase
        .from('vaults')
        .update({
          current_balance: newBalance,
          allocated_amount: vault.new_allocated,
          spent_amount: 0,
        })
        .eq('id', vault.id);

      if (updateError) throw updateError;
    }

    // Save income_injections record
    const { error: injectionError } = await supabase
      .from('income_injections')
      .insert({
        user_id,
        amount,
        allocation_snapshot: allocationSnapshot,
        carryover_snapshot: carryoverSnapshot,
      });

    if (injectionError) throw injectionError;

    checkAfterIncome(user_id).catch(() => {});

    return res.json({
      success: true,
      message: `RM ${amount.toFixed(2)} deposited and allocated across ${allocations.length} vaults`,
      allocations: allocations.map(v => ({
        vault_id: v.id,
        name: v.name,
        category_key: v.category_key,
        vault_type: v.vault_type,
        vault_colour: v.vault_colour,
        vault_icon: v.vault_icon,
        allocation_percentage: v.allocation_percentage,
        allocated_amount: v.new_allocated,
        new_balance: Math.round((parseFloat(v.current_balance) + v.new_allocated) * 100) / 100,
      })),
    });

  } catch (error) {
    console.error('injectIncome error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// GENERAL DEPOSIT
// POST /api/income/deposit
// Adds money to a specific vault (not Traffic Controller).
// Increases both current_balance AND allocated_amount for this cycle.
// ─────────────────────────────────────────────
const depositToVault = async (req, res) => {
  try {
    const user_id = req.user.id;
    const { vault_id, amount: rawAmount } = req.body;

    const amount = parseFloat(rawAmount);
    if (!vault_id || isNaN(amount) || amount <= 0) {
      return res.status(400).json({ success: false, message: 'vault_id and a valid amount are required' });
    }

    // Confirm vault belongs to this user
    const { data: vault, error: vaultError } = await supabase
      .from('vaults')
      .select('*')
      .eq('id', vault_id)
      .eq('user_id', user_id)
      .eq('is_active', true)
      .single();

    if (vaultError || !vault) {
      return res.status(404).json({ success: false, message: 'Vault not found' });
    }

    const newBalance = Math.round((parseFloat(vault.current_balance) + amount) * 100) / 100;
    const newAllocated = Math.round((parseFloat(vault.allocated_amount) + amount) * 100) / 100;

    // Update vault — both balance and allocated_amount increase
    const { error: updateError } = await supabase
      .from('vaults')
      .update({ current_balance: newBalance, allocated_amount: newAllocated })
      .eq('id', vault_id);

    if (updateError) throw updateError;

    // Write transaction record for history
    await supabase.from('transactions').insert({
      user_id,
      vault_id,
      amount,
      merchant_name: 'General Deposit',
      merchant_category: vault.category_key,
      transaction_type: 'income',
      status: 'approved',
      goal_conflict_detected: false,
      user_overrode_guardian: false,
      ai_categorisation_attempts: 0,
      ai_categorisation_failed: false,
    });

    const completed_goals = await checkAfterIncome(user_id);

    return res.json({
      success: true,
      message: `RM ${amount.toFixed(2)} deposited into ${vault.name}`,
      vault: { id: vault.id, name: vault.name, new_balance: newBalance, new_allocated: newAllocated },
      completed_goals,
    });

  } catch (error) {
    console.error('depositToVault error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// STAGE INCOME
// POST /api/income/stage
// Calculates allocations and saves a pending income_injection record.
// Does NOT update vault balances — user must call /apply after choosing
// carry-over or sweep via the dashboard Aion card.
// ─────────────────────────────────────────────
const stageIncome = async (req, res) => {
  try {
    const { amount } = req.body;
    const user_id = req.user.id;

    if (!amount || typeof amount !== 'number' || amount <= 0) {
      return res.status(400).json({ success: false, message: 'Valid amount is required' });
    }

    // Cancel any existing pending injection so user can re-stage cleanly
    await supabase
      .from('income_injections')
      .update({ status: 'cancelled' })
      .eq('user_id', user_id)
      .eq('status', 'pending');

    const { data: vaults, error: vaultError } = await supabase
      .from('vaults')
      .select('*')
      .eq('user_id', user_id)
      .eq('is_active', true);

    if (vaultError) throw vaultError;
    if (!vaults || vaults.length === 0) {
      return res.status(400).json({ success: false, message: 'No active vaults found. Complete onboarding first.' });
    }

    const allocations = vaults.map(vault => ({
      ...vault,
      new_allocated: Math.round(amount * (vault.allocation_percentage / 100) * 100) / 100,
    }));

    const totalAllocated = allocations.reduce((sum, v) => sum + v.new_allocated, 0);
    const diff = Math.round((amount - totalAllocated) * 100) / 100;
    if (diff !== 0) {
      allocations[0].new_allocated = Math.round((allocations[0].new_allocated + diff) * 100) / 100;
    }

    const allocationSnapshot = {};
    const carryoverSnapshot = {};

    allocations.forEach(v => {
      allocationSnapshot[v.id] = {
        name: v.name,
        category_key: v.category_key,
        percentage: v.allocation_percentage,
        allocated: v.new_allocated,
        vault_type: v.vault_type,
      };
      carryoverSnapshot[v.id] = {
        name: v.name,
        category_key: v.category_key,
        vault_type: v.vault_type,
        balance_before: parseFloat(v.current_balance),
      };
    });

    // Total unspent money sitting in spending vaults right now
    const totalCarryover = Math.round(
      allocations
        .filter(v => v.vault_type === 'vault')
        .reduce((sum, v) => sum + parseFloat(v.current_balance), 0)
      * 100) / 100;

    const { data: injection, error: injectionError } = await supabase
      .from('income_injections')
      .insert({
        user_id,
        amount,
        allocation_snapshot: allocationSnapshot,
        carryover_snapshot: carryoverSnapshot,
        status: 'pending',
      })
      .select()
      .single();

    if (injectionError) throw injectionError;

    return res.json({
      success: true,
      injection_id: injection.id,
      amount,
      total_carryover: totalCarryover,
    });

  } catch (error) {
    console.error('stageIncome error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// APPLY INCOME
// POST /api/income/apply
// Applies a staged income injection to vault balances.
// mode='carry_over' → add allocation on top of existing balance (old behaviour)
// mode='sweep'      → move all spending vault balances to goal_vault_id first,
//                     then spending vaults start fresh with new allocation only
// ─────────────────────────────────────────────
const applyIncome = async (req, res) => {
  try {
    const { injection_id, mode, goal_vault_id } = req.body;
    const user_id = req.user.id;

    if (!injection_id || !['carry_over', 'sweep'].includes(mode)) {
      return res.status(400).json({ success: false, message: 'injection_id and mode (carry_over or sweep) are required' });
    }
    if (mode === 'sweep' && !goal_vault_id) {
      return res.status(400).json({ success: false, message: 'goal_vault_id is required for sweep mode' });
    }

    const { data: injection, error: injErr } = await supabase
      .from('income_injections')
      .select('*')
      .eq('id', injection_id)
      .eq('user_id', user_id)
      .eq('status', 'pending')
      .single();

    if (injErr || !injection) {
      return res.status(404).json({ success: false, message: 'Pending income injection not found' });
    }

    const { allocation_snapshot, carryover_snapshot } = injection;
    const vaultIds = Object.keys(allocation_snapshot);

    if (mode === 'sweep') {
      // Sum up all spending vault carryover balances
      let sweepAmount = 0;
      for (const data of Object.values(carryover_snapshot)) {
        if (data.vault_type === 'vault') sweepAmount += parseFloat(data.balance_before);
      }
      sweepAmount = Math.round(sweepAmount * 100) / 100;

      if (sweepAmount > 0) {
        const { error: goalErr } = await supabase
          .from('vaults')
          .select('id')
          .eq('id', goal_vault_id)
          .eq('user_id', user_id)
          .single();

        if (goalErr) {
          return res.status(404).json({ success: false, message: 'Goal vault not found' });
        }
      }

      // Update each vault by type
      for (const vaultId of vaultIds) {
        const snap = allocation_snapshot[vaultId];
        const carry = carryover_snapshot[vaultId];

        if (carry.vault_type === 'vault') {
          // Spending vault: fresh start — balance = new allocation only
          await supabase.from('vaults').update({
            current_balance: snap.allocated,
            allocated_amount: snap.allocated,
            spent_amount: 0,
          }).eq('id', vaultId);
        } else {
          // Fund vault: carryover + allocation + sweep amount (if this is the selected goal)
          const extraSweep = (vaultId === goal_vault_id) ? sweepAmount : 0;
          await supabase.from('vaults').update({
            current_balance: Math.round((parseFloat(carry.balance_before) + snap.allocated + extraSweep) * 100) / 100,
            allocated_amount: snap.allocated,
            spent_amount: 0,
          }).eq('id', vaultId);
        }
      }

    } else {
      // carry_over: every vault gets allocation added on top of current balance
      for (const vaultId of vaultIds) {
        const snap = allocation_snapshot[vaultId];
        const carry = carryover_snapshot[vaultId];
        await supabase.from('vaults').update({
          current_balance: Math.round((parseFloat(carry.balance_before) + snap.allocated) * 100) / 100,
          allocated_amount: snap.allocated,
          spent_amount: 0,
        }).eq('id', vaultId);
      }
    }

    await supabase
      .from('income_injections')
      .update({ status: 'applied' })
      .eq('id', injection_id);

    const completed_goals = await checkAfterIncome(user_id);

    const { assessProfileUpdate } = require('../services/profileUpdateService');
    assessProfileUpdate(user_id, mode === 'salary' ? 'salary_deposit' : 'general_deposit', {
      amount: parseFloat(injection.amount), mode,
    }).catch(() => {});

    return res.json({ success: true, mode, amount: parseFloat(injection.amount), completed_goals });

  } catch (error) {
    console.error('applyIncome error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// GET PENDING INCOME
// GET /api/income/pending
// Returns any staged-but-not-yet-applied income injection for this user.
// ─────────────────────────────────────────────
const getPendingIncome = async (req, res) => {
  try {
    const user_id = req.user.id;

    const { data: injection } = await supabase
      .from('income_injections')
      .select('id, amount, carryover_snapshot, injection_date')
      .eq('user_id', user_id)
      .eq('status', 'pending')
      .order('injection_date', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!injection) return res.json({ success: true, pending: null });

    const totalCarryover = Math.round(
      Object.values(injection.carryover_snapshot)
        .filter(v => v.vault_type === 'vault')
        .reduce((sum, v) => sum + parseFloat(v.balance_before), 0)
      * 100) / 100;

    return res.json({
      success: true,
      pending: {
        id: injection.id,
        amount: parseFloat(injection.amount),
        total_carryover: totalCarryover,
      },
    });

  } catch (error) {
    console.error('getPendingIncome error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

module.exports = { injectIncome, depositToVault, stageIncome, applyIncome, getPendingIncome };
