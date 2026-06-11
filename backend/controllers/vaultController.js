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

module.exports = { transferVault };
