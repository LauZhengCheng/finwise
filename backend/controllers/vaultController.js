// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : vaultController.js
// Description   : Vault operations — Active Pilot vault transfer
// First Written : 06-06-2026
// Edited on     : 06-06-2026
// ============================================

const supabase = require('../config/supabase');

// ─────────────────────────────────────────────
// TRANSFER VAULT
// POST /api/vaults/transfer
// Active Pilot: moves money between vaults so user
// can cover an insufficient transaction vault.
// ─────────────────────────────────────────────
const transferVault = async (req, res) => {
  try {
    const { from_vault_id, to_vault_id, amount, triggered_by_transaction_id } = req.body;
    const user_id = req.user.id;

    if (!from_vault_id || !to_vault_id || !amount || amount <= 0) {
      return res.status(400).json({ success: false, message: 'from_vault_id, to_vault_id, and amount are required' });
    }

    if (from_vault_id === to_vault_id) {
      return res.status(400).json({ success: false, message: 'Cannot transfer to the same vault' });
    }

    // Fetch both vaults — must belong to this user
    const [{ data: fromVault, error: fromError }, { data: toVault, error: toError }] = await Promise.all([
      supabase.from('vaults').select('*').eq('id', from_vault_id).eq('user_id', user_id).single(),
      supabase.from('vaults').select('*').eq('id', to_vault_id).eq('user_id', user_id).single(),
    ]);

    if (fromError || !fromVault || toError || !toVault) {
      return res.status(404).json({ success: false, message: 'One or both vaults not found' });
    }

    const fromBalance = parseFloat(fromVault.current_balance);
    if (fromBalance < amount) {
      return res.status(400).json({
        success: false,
        message: `${fromVault.name} only has RM ${fromBalance.toFixed(2)}`,
      });
    }

    const newFromBalance = Math.round((fromBalance - amount) * 100) / 100;
    const newToBalance = Math.round((parseFloat(toVault.current_balance) + amount) * 100) / 100;

    // Deduct source and add to target
    await Promise.all([
      supabase.from('vaults').update({ current_balance: newFromBalance }).eq('id', from_vault_id),
      supabase.from('vaults').update({ current_balance: newToBalance }).eq('id', to_vault_id),
    ]);

    // Write vault_transfers record
    await supabase.from('vault_transfers').insert({
      user_id,
      from_vault_id,
      to_vault_id,
      amount,
      transfer_type: 'active_pilot',
      reason: `Active Pilot: ${fromVault.name} → ${toVault.name}`,
      triggered_by_transaction_id: triggered_by_transaction_id || null,
    });

    const { assessProfileUpdate } = require('../services/profileUpdateService');
    assessProfileUpdate(user_id, 'active_pilot_transfer', {
      from: fromVault.name, to: toVault.name, amount: parseFloat(amount),
    }).catch(() => {});

    return res.json({
      success: true,
      message: `RM ${parseFloat(amount).toFixed(2)} transferred from ${fromVault.name} to ${toVault.name}`,
      from_vault: { id: fromVault.id, name: fromVault.name, new_balance: newFromBalance },
      to_vault: { id: toVault.id, name: toVault.name, new_balance: newToBalance },
    });

  } catch (error) {
    console.error('transferVault error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// ARCHIVE GOAL
// POST /api/vaults/:id/archive
// Hides a completed fund vault from the dashboard.
// Only completed goals (completed_at IS NOT NULL) can be archived.
// ─────────────────────────────────────────────
const archiveGoal = async (req, res) => {
  try {
    const { id } = req.params;
    const user_id = req.user.id;

    const { data: vault, error } = await supabase
      .from('vaults')
      .select('vault_type, completed_at')
      .eq('id', id)
      .eq('user_id', user_id)
      .eq('is_active', true)
      .single();

    if (error || !vault) {
      return res.status(404).json({ success: false, message: 'Vault not found' });
    }
    if (vault.vault_type !== 'fund') {
      return res.status(400).json({ success: false, message: 'Only saving goals can be archived' });
    }
    if (!vault.completed_at) {
      return res.status(400).json({ success: false, message: 'Only completed goals can be archived' });
    }

    await supabase.from('vaults').update({ is_archived: true }).eq('id', id);

    return res.json({ success: true });
  } catch (error) {
    console.error('archiveGoal error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// UNARCHIVE GOAL
// POST /api/vaults/:id/unarchive
// Restores an archived goal to the dashboard.
// ─────────────────────────────────────────────
const unarchiveGoal = async (req, res) => {
  try {
    const { id } = req.params;
    const user_id = req.user.id;

    const { data: vault, error } = await supabase
      .from('vaults')
      .select('vault_type, is_archived')
      .eq('id', id)
      .eq('user_id', user_id)
      .eq('is_active', true)
      .single();

    if (error || !vault) {
      return res.status(404).json({ success: false, message: 'Vault not found' });
    }
    if (vault.vault_type !== 'fund') {
      return res.status(400).json({ success: false, message: 'Only saving goals can be unarchived' });
    }

    await supabase.from('vaults').update({ is_archived: false }).eq('id', id);

    return res.json({ success: true });
  } catch (error) {
    console.error('unarchiveGoal error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

module.exports = { transferVault, archiveGoal, unarchiveGoal };
