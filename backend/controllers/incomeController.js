// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : incomeController.js
// Description   : Traffic Controller — splits salary deposit into
//                 vault allocations by percentage and writes to DB
// First Written : 06-06-2026
// Edited on     : 06-06-2026
// ============================================

const supabase = require('../config/supabase');

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

module.exports = { injectIncome };
