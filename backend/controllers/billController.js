// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : billController.js
// Description   : CRUD operations for user bills table
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

const supabase = require('../config/supabase');
const { nowMYT } = require('../utils/dateUtils');

const VALID_FREQUENCIES = ['monthly', 'quarterly', 'annually'];

const getBills = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('bills')
      .select('*')
      .eq('user_id', req.user.id)
      .eq('is_active', true)
      .order('due_date', { ascending: true });

    if (error) throw error;

    // Auto-advance paid bills whose due date has passed
    await autoAdvanceBills(req.user.id, data);

    return res.json({ success: true, data });
  } catch (error) {
    console.error('getBills error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const createBill = async (req, res) => {
  try {
    const { name, amount, due_date, frequency, category, vault_id, notification_days_before } = req.body;

    if (!name || amount == null || !due_date || !frequency) {
      return res.status(400).json({ success: false, message: 'name, amount, due_date, and frequency are required' });
    }

    if (!VALID_FREQUENCIES.includes(frequency)) {
      return res.status(400).json({ success: false, message: `frequency must be one of: ${VALID_FREQUENCIES.join(', ')}` });
    }

    const { data, error } = await supabase
      .from('bills')
      .insert({
        user_id: req.user.id,
        name,
        amount,
        due_date,
        frequency,
        category: category || null,
        vault_id: vault_id || null,
        notification_days_before: notification_days_before ?? 3,
      })
      .select()
      .single();

    if (error) throw error;

    // Fire proactive notification for Aion to check bill coverage
    const { checkProactiveAfterBillChange } = require('../services/notificationService');
    checkProactiveAfterBillChange(req.user.id).catch(() => {});

    return res.status(201).json({ success: true, data });
  } catch (error) {
    console.error('createBill error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const updateBill = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, amount, due_date, frequency, category, vault_id, notification_days_before, is_paid, is_active } = req.body;

    const { data: existing, error: fetchError } = await supabase
      .from('bills')
      .select('id')
      .eq('id', id)
      .eq('user_id', req.user.id)
      .single();

    if (fetchError || !existing) {
      return res.status(404).json({ success: false, message: 'Bill not found' });
    }

    if (frequency && !VALID_FREQUENCIES.includes(frequency)) {
      return res.status(400).json({ success: false, message: `frequency must be one of: ${VALID_FREQUENCIES.join(', ')}` });
    }

    const updates = {};
    if (name !== undefined) updates.name = name;
    if (amount !== undefined) updates.amount = amount;
    if (due_date !== undefined) updates.due_date = due_date;
    if (frequency !== undefined) updates.frequency = frequency;
    if (category !== undefined) updates.category = category;
    if (vault_id !== undefined) updates.vault_id = vault_id;
    if (notification_days_before !== undefined) updates.notification_days_before = notification_days_before;
    if (is_paid !== undefined) updates.is_paid = is_paid;
    if (is_active !== undefined) updates.is_active = is_active;

    const { data, error } = await supabase
      .from('bills')
      .update(updates)
      .eq('id', id)
      .eq('user_id', req.user.id)
      .select()
      .single();

    if (error) throw error;

    if (updates.is_paid === true) {
      const dueDate = new Date(data.due_date);
      const wasOnTime = nowMYT() <= dueDate;
      supabase.from('bill_payment_history').insert({
        user_id: req.user.id,
        bill_id: id,
        bill_name: data.name,
        amount: parseFloat(data.amount),
        due_date: data.due_date,
        was_on_time: wasOnTime,
      }).then(() => {}).catch(() => {});

      const { assessProfileUpdate } = require('../services/profileUpdateService');
      assessProfileUpdate(req.user.id, 'bill_paid', {
        name: data.name, amount: parseFloat(data.amount), on_time: wasOnTime,
      }).catch(() => {});
    } else if (updates.is_paid === false) {
      const { assessProfileUpdate } = require('../services/profileUpdateService');
      assessProfileUpdate(req.user.id, 'bill_unpaid', {
        name: data.name, amount: parseFloat(data.amount),
      }).catch(() => {});
    }

    return res.json({ success: true, data });
  } catch (error) {
    console.error('updateBill error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const deleteBill = async (req, res) => {
  try {
    const { id } = req.params;

    const { data: existing, error: fetchError } = await supabase
      .from('bills')
      .select('id')
      .eq('id', id)
      .eq('user_id', req.user.id)
      .single();

    if (fetchError || !existing) {
      return res.status(404).json({ success: false, message: 'Bill not found' });
    }

    const { error } = await supabase
      .from('bills')
      .update({ is_active: false })
      .eq('id', id)
      .eq('user_id', req.user.id);

    if (error) throw error;

    return res.json({ success: true, message: 'Bill removed' });
  } catch (error) {
    console.error('deleteBill error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// Auto-advance paid bills whose due date has passed
// Called from getBills endpoint AND from startup check
const autoAdvanceBills = async (userId, bills) => {
  const now = nowMYT();
  const { _saveNotification } = require('../services/notificationService');

  // If no bills passed, fetch them
  if (!bills) {
    const { data } = await supabase
      .from('bills')
      .select('*')
      .eq('user_id', userId)
      .eq('is_active', true);
    bills = data || [];
  }

  for (const bill of bills) {
    if (!bill.is_paid) continue;
    const dueDate = new Date(bill.due_date);
    if (dueDate >= now) continue;

    let nextDue = new Date(dueDate);
    switch (bill.frequency) {
      case 'monthly':
        nextDue.setMonth(nextDue.getMonth() + 1);
        break;
      case 'quarterly':
        nextDue.setMonth(nextDue.getMonth() + 3);
        break;
      case 'annually':
        nextDue.setFullYear(nextDue.getFullYear() + 1);
        break;
    }

    const nextDueStr = nextDue.toISOString().split('T')[0];
    await supabase.from('bills').update({
      is_paid: false,
      due_date: nextDueStr,
    }).eq('id', bill.id);

    bill.is_paid = false;
    bill.due_date = nextDueStr;

    const freqLabel = bill.frequency === 'quarterly' ? 'quarterly' : bill.frequency === 'annually' ? 'annual' : 'monthly';
    _saveNotification(userId,
      `Your ${freqLabel} ${bill.name} bill (RM ${parseFloat(bill.amount).toFixed(2)}) has renewed — next due date is ${nextDueStr}. Make sure your vault has enough to cover it!`
    ).catch(() => {});
  }
};

// Check all users' bills on startup — auto-advance any overdue paid bills
const checkAllBillsOnStartup = async () => {
  try {
    const { data: paidOverdue } = await supabase
      .from('bills')
      .select('user_id')
      .eq('is_active', true)
      .eq('is_paid', true)
      .lt('due_date', nowMYT().toISOString().split('T')[0]);

    if (!paidOverdue?.length) return;

    const userIds = [...new Set(paidOverdue.map(b => b.user_id))];
    for (const userId of userIds) {
      await autoAdvanceBills(userId, null);
    }
    console.log(`[Bills] Auto-advanced bills for ${userIds.length} user(s)`);
  } catch (err) {
    console.error('[Bills] Startup check error:', err.message);
  }
};

module.exports = { getBills, createBill, updateBill, deleteBill, checkAllBillsOnStartup };
