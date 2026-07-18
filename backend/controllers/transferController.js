// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : transferController.js
// Description   : P2P transfer between users by phone number.
//                 Sender vault is deducted immediately.
//                 Receiver money stays pending — Aion notifies receiver
//                 and helps decide which vault to allocate it to.
// First Written : 18-06-2026
// Edited on     : 18-06-2026
// ============================================

const supabase = require('../config/supabase');
const { sendPushNotification } = require('../services/notificationService');

// GET /api/transfer/lookup?phone=xxx
// Returns { found, full_name } — always 200, never 404
const lookupRecipient = async (req, res) => {
  try {
    const phone = (req.query.phone || '').trim();
    if (!phone) return res.json({ found: false, full_name: null });

    const { data: user } = await supabase
      .from('profiles')
      .select('full_name')
      .eq('phone_number', phone)
      .single();

    return res.json({ found: !!user, full_name: user?.full_name ?? null });
  } catch (error) {
    console.error('lookupRecipient error:', error.message);
    res.status(500).json({ error: 'Failed to look up recipient' });
  }
};

// POST /api/transfer/send
const sendTransfer = async (req, res) => {
  try {
  const senderId = req.user.id;
  const { recipient_phone, amount, source_vault_id, note } = req.body;

  if (!recipient_phone || !amount || !source_vault_id) {
    return res.status(400).json({ error: 'recipient_phone, amount, and source_vault_id are required' });
  }
  if (amount <= 0) {
    return res.status(400).json({ error: 'Amount must be greater than 0' });
  }

  // 1. Find receiver by phone number
  const { data: receiver, error: receiverErr } = await supabase
    .from('profiles')
    .select('id, full_name, phone_number')
    .eq('phone_number', recipient_phone)
    .single();

  if (receiverErr || !receiver) {
    return res.status(404).json({ error: 'No FinWise user found with that phone number' });
  }
  if (receiver.id === senderId) {
    return res.status(400).json({ error: 'You cannot transfer to yourself' });
  }

  // 2. Get sender profile for name
  const { data: sender } = await supabase
    .from('profiles')
    .select('full_name')
    .eq('id', senderId)
    .single();

  // 3. Check sender vault has sufficient balance
  const { data: vaultRows, error: vaultErr } = await supabase
    .from('vaults')
    .select('id, name, current_balance, spent_amount, category_key')
    .eq('id', source_vault_id)
    .eq('user_id', senderId)
    .eq('is_active', true);

  const sourceVault = vaultRows?.[0] ?? null;

  if (vaultErr || !sourceVault) {
    console.error('[sendTransfer] vault not found | err:', vaultErr?.message ?? 'null', '| vault_id:', source_vault_id, '| sender:', senderId);
    return res.status(404).json({ error: 'Source vault not found' });
  }
  if (sourceVault.current_balance < amount) {
    return res.status(400).json({
      error: 'Insufficient balance',
      current_balance: sourceVault.current_balance,
      shortfall: amount - sourceVault.current_balance,
    });
  }

  // 4. Deduct from sender's vault immediately
  const { error: deductErr } = await supabase
    .from('vaults')
    .update({
      current_balance: sourceVault.current_balance - amount,
      spent_amount: (parseFloat(sourceVault.spent_amount) || 0) + amount,
    })
    .eq('id', source_vault_id)
    .eq('user_id', senderId);

  if (deductErr) {
    return res.status(500).json({ error: 'Failed to deduct from your vault' });
  }

  // 5. Write transaction record for sender's vault history
  await supabase.from('transactions').insert({
    user_id: senderId,
    vault_id: source_vault_id,
    amount,
    merchant_name: `To: ${receiver.full_name}`,
    merchant_category: sourceVault.category_key,
    transaction_type: 'transfer',
    status: 'approved',
    note: note || null,
    goal_conflict_detected: false,
    user_overrode_guardian: false,
    ai_categorisation_attempts: 0,
    ai_categorisation_failed: false,
  });

  // 6. Create transfer record — pending until receiver allocates to a vault
  const { data: transfer, error: transferErr } = await supabase
    .from('p2p_transfers')
    .insert({
      sender_id: senderId,
      receiver_id: receiver.id,
      amount,
      source_vault_id,
      note: note || null,
      status: 'pending',
    })
    .select()
    .single();

  if (transferErr) {
    console.error('[Transfer] Insert error:', transferErr.message);
    // Rollback sender deduction
    await supabase
      .from('vaults')
      .update({ current_balance: sourceVault.current_balance })
      .eq('id', source_vault_id);
    return res.status(500).json({ error: 'Failed to record transfer' });
  }

  // 7. Write proactive Aion notification for receiver
  const senderName = sender?.full_name || 'Someone';
  const noteText = note ? ` They left a note: "${note}".` : '';
  const proactiveMessage = `💸 You just received RM${parseFloat(amount).toFixed(2)} from ${senderName}!${noteText} I've set it aside safely for now. Let me know which vault you'd like to put it in and I'll take care of it right away.`;

  await supabase.from('ai_logs').insert({
    user_id: receiver.id,
    interaction_type: 'proactive',
    is_proactive: true,
    user_message: null,
    ai_response: { message: proactiveMessage },
    raw_ai_response: { message: proactiveMessage },
  });

  await sendPushNotification(receiver.id, 'Aion', proactiveMessage, '/chat');

  const { assessProfileUpdate } = require('../services/profileUpdateService');
  assessProfileUpdate(senderId, 'p2p_sent', {
    amount, receiver: receiver.full_name,
  }).catch(() => {});

  return res.json({
    success: true,
    receiver_name: receiver.full_name,
    amount,
    transfer_id: transfer.id,
  });
  } catch (error) {
    console.error('sendTransfer error:', error.message);
    res.status(500).json({ error: 'Transfer failed. Please try again.' });
  }
};

// POST /api/transfer/allocate
// Called after receiver confirms vault with Aion in chat.
// Supports allocating one or multiple pending transfers at once.
const allocateTransfer = async (req, res) => {
  const receiverId = req.user.id;
  const { transfer_ids, vault_id } = req.body;

  if (!transfer_ids?.length || !vault_id) {
    return res.status(400).json({ error: 'transfer_ids (array) and vault_id are required' });
  }

  // 1. Fetch all pending transfers — must all belong to this receiver
  const { data: transfers, error: transferErr } = await supabase
    .from('p2p_transfers')
    .select('id, amount, status, note, sender:profiles!sender_id(full_name)')
    .in('id', transfer_ids)
    .eq('receiver_id', receiverId);

  console.log('[allocateTransfer] transfer_ids:', transfer_ids);
  console.log('[allocateTransfer] fetched:', transfers?.length, '| err:', transferErr?.message);

  if (transferErr) {
    return res.status(500).json({ error: 'Database error: ' + transferErr.message });
  }
  if (!transfers?.length) {
    return res.status(404).json({ error: 'No matching transfers found for your account' });
  }

  // Filter to only pending ones — skip already completed transfers
  const pendingOnly = transfers.filter((t) => t.status === 'pending');
  if (!pendingOnly.length) {
    return res.json({ success: true, already_allocated: true, message: 'All transfers already added to your vault' });
  }

  const totalAmount = pendingOnly.reduce((sum, t) => sum + parseFloat(t.amount), 0);
  const pendingIds = pendingOnly.map((t) => t.id);

  // 2. Get the target vault — must belong to this receiver
  console.log('[allocateTransfer] vault_id:', vault_id, '| receiverId:', receiverId);
  const { data: vaultRows2, error: vaultErr } = await supabase
    .from('vaults')
    .select('id, name, current_balance, allocated_amount, category_key')
    .eq('id', vault_id)
    .eq('user_id', receiverId)
    .eq('is_active', true);

  const vault = vaultRows2?.[0] ?? null;

  if (vaultErr || !vault) {
    return res.status(404).json({ error: 'Target vault not found' });
  }

  // 3. Credit the vault with combined total
  const { error: creditErr } = await supabase
    .from('vaults')
    .update({
      current_balance: parseFloat(vault.current_balance) + totalAmount,
      allocated_amount: parseFloat(vault.allocated_amount) + totalAmount,
    })
    .eq('id', vault_id);

  if (creditErr) {
    return res.status(500).json({ error: 'Failed to credit vault' });
  }

  // 4. Mark all transfers as completed
  await supabase
    .from('p2p_transfers')
    .update({ status: 'completed' })
    .in('id', pendingIds);

  // 5. Write a transaction record for each allocated transfer in the receiver's history
  const txRecords = pendingOnly.map((t) => ({
    user_id: receiverId,
    vault_id,
    amount: parseFloat(t.amount),
    merchant_name: `From: ${t.sender?.full_name || 'Someone'}`,
    merchant_category: vault.category_key,
    transaction_type: 'transfer',
    status: 'approved',
    note: t.note || null,
    goal_conflict_detected: false,
    user_overrode_guardian: false,
    ai_categorisation_attempts: 0,
    ai_categorisation_failed: false,
  }));
  await supabase.from('transactions').insert(txRecords);

  return res.json({
    success: true,
    vault_name: vault.name,
    amount: totalAmount,
  });
};

// GET /api/transfer/history
const getTransferHistory = async (req, res) => {
  try {
  const userId = req.user.id;

  const { data, error } = await supabase
    .from('p2p_transfers')
    .select(`
      id, amount, note, status, created_at,
      sender:profiles!sender_id(full_name, phone_number),
      receiver:profiles!receiver_id(full_name, phone_number),
      source_vault:vaults!source_vault_id(name)
    `)
    .or(`sender_id.eq.${userId},receiver_id.eq.${userId}`)
    .order('created_at', { ascending: false })
    .limit(50);

  if (error) return res.status(500).json({ error: error.message });

  return res.json({ transfers: data || [] });
  } catch (error) {
    console.error('getTransferHistory error:', error.message);
    res.status(500).json({ error: 'Failed to load transfer history' });
  }
};

module.exports = { lookupRecipient, sendTransfer, allocateTransfer, getTransferHistory };
