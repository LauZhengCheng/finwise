// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : debtController.js
// Description   : CRUD operations for comprehensive debt management.
//                 Supports full real-world debt fields — principal,
//                 interest, APR, collateral, term, payment schedule.
// First Written : 17-06-2026
// Edited on     : 20-06-2026
// ============================================

const supabase = require('../config/supabase');

const VALID_DEBT_TYPES = ['personal_loan', 'credit_card', 'car_loan', 'home_loan', 'student_loan', 'bnpl', 'other'];
const VALID_INTEREST_TYPES = ['fixed', 'variable', 'promotional'];

const getDebts = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('debts')
      .select('*')
      .eq('user_id', req.user.id)
      .eq('is_active', true)
      .order('interest_rate', { ascending: false, nullsFirst: false });

    if (error) throw error;

    // Enrich each debt with calculated fields
    const enriched = (data || []).map(d => {
      const balance = parseFloat(d.current_balance || 0);
      const principal = parseFloat(d.principal_amount || 0);
      const rate = parseFloat(d.interest_rate || 0);
      const monthlyRate = rate / 100 / 12;
      const payment = parseFloat(d.minimum_payment || 0);

      const monthlyInterestCost = Math.round(balance * monthlyRate * 100) / 100;
      const paidPercentage = principal > 0 ? Math.round((1 - balance / principal) * 100) : 0;
      const totalRepayment = payment > 0 && d.term_months
        ? Math.round(payment * d.term_months * 100) / 100 : null;
      const totalInterest = totalRepayment ? Math.round((totalRepayment - principal) * 100) / 100 : null;
      const remainingInterest = d.remaining_months && monthlyRate > 0
        ? Math.round(
            (payment * d.remaining_months - balance) * 100
          ) / 100
        : null;

      return {
        ...d,
        calculated: {
          monthly_interest_cost: monthlyInterestCost,
          paid_percentage: paidPercentage,
          total_repayment: totalRepayment,
          total_interest: totalInterest,
          remaining_interest: remainingInterest > 0 ? remainingInterest : null,
        },
      };
    });

    const totalBalance = enriched.reduce((sum, d) => sum + parseFloat(d.current_balance || 0), 0);
    const totalMinimum = enriched.reduce((sum, d) => sum + parseFloat(d.minimum_payment || 0), 0);
    const monthlyInterest = enriched.reduce((sum, d) => sum + (d.calculated.monthly_interest_cost || 0), 0);

    return res.json({
      success: true,
      data: enriched,
      summary: {
        total_debts: enriched.length,
        total_balance: Math.round(totalBalance * 100) / 100,
        total_minimum_monthly: Math.round(totalMinimum * 100) / 100,
        monthly_interest_cost: Math.round(monthlyInterest * 100) / 100,
      },
    });
  } catch (error) {
    console.error('getDebts error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const createDebt = async (req, res) => {
  try {
    const {
      name, debt_type, lender,
      principal_amount, current_balance,
      interest_rate, interest_type, promotional_rate_until,
      minimum_payment, current_monthly_payment,
      term_months, remaining_months, start_date, maturity_date,
      due_date, is_secured, collateral, notes,
    } = req.body;

    if (!name || !debt_type || principal_amount == null || current_balance == null) {
      return res.status(400).json({ success: false, message: 'name, debt_type, principal_amount, and current_balance are required' });
    }
    if (!interest_rate && interest_rate !== 0) {
      return res.status(400).json({ success: false, message: 'interest_rate is required' });
    }
    if (!VALID_DEBT_TYPES.includes(debt_type)) {
      return res.status(400).json({ success: false, message: `debt_type must be one of: ${VALID_DEBT_TYPES.join(', ')}` });
    }
    if (interest_type && !VALID_INTEREST_TYPES.includes(interest_type)) {
      return res.status(400).json({ success: false, message: `interest_type must be one of: ${VALID_INTEREST_TYPES.join(', ')}` });
    }
    if (due_date != null && (due_date < 1 || due_date > 31)) {
      return res.status(400).json({ success: false, message: 'due_date must be between 1 and 31' });
    }

    // ── Type-specific calculations ─────────────────────────
    let calcMonthlyPayment = null;  // fixed EMI for loans, installment for BNPL
    let calcMinPayment = null;      // floor for credit cards only
    let calcRemainingMonths = null;
    let autoInterestType = interest_type || 'fixed';
    const autoSecured = is_secured ?? ['car_loan', 'home_loan'].includes(debt_type);

    if (debt_type === 'credit_card') {
      // Credit card: no fixed term, user provides minimum, Aion decides actual payment later
      calcMinPayment = minimum_payment ?? Math.max(current_balance * 0.05, 50);
      calcMonthlyPayment = current_monthly_payment ?? calcMinPayment;
      // No remaining months calc — revolving debt
    } else if (debt_type === 'bnpl') {
      // BNPL: equal installments, usually 0% promo
      autoInterestType = interest_type || 'promotional';
      if (term_months && principal_amount > 0) {
        calcMonthlyPayment = Math.round(principal_amount / term_months * 100) / 100;
      }
      if (calcMonthlyPayment > 0 && current_balance > 0) {
        calcRemainingMonths = Math.ceil(current_balance / calcMonthlyPayment);
      }
    } else {
      // Fixed loans (personal, car, home, student): calculate EMI
      if (term_months && principal_amount > 0) {
        if (interest_rate > 0) {
          const r = interest_rate / 100 / 12;
          calcMonthlyPayment = Math.round(
            (principal_amount * r * Math.pow(1 + r, term_months)) /
            (Math.pow(1 + r, term_months) - 1) * 100
          ) / 100;
        } else {
          calcMonthlyPayment = Math.round(principal_amount / term_months * 100) / 100;
        }
      }
      // Override with user-provided payment if given
      if (minimum_payment) calcMonthlyPayment = minimum_payment;

      // Calculate remaining months from current balance
      if (calcMonthlyPayment > 0 && current_balance > 0) {
        if (interest_rate > 0) {
          const r = interest_rate / 100 / 12;
          const monthlyInterest = current_balance * r;
          if (calcMonthlyPayment > monthlyInterest) {
            const numer = Math.log(calcMonthlyPayment / (calcMonthlyPayment - monthlyInterest));
            const denom = Math.log(1 + r);
            calcRemainingMonths = denom > 0 ? Math.ceil(numer / denom) : null;
          }
        } else {
          calcRemainingMonths = Math.ceil(current_balance / calcMonthlyPayment);
        }
      }
    }

    const { data, error } = await supabase
      .from('debts')
      .insert({
        user_id: req.user.id,
        name,
        debt_type,
        lender: lender || null,
        principal_amount,
        current_balance,
        interest_rate: interest_rate ?? 0,
        interest_type: autoInterestType,
        promotional_rate_until: promotional_rate_until || null,
        minimum_payment: debt_type === 'credit_card' ? calcMinPayment : calcMonthlyPayment,
        current_monthly_payment: current_monthly_payment ?? calcMonthlyPayment ?? calcMinPayment,
        term_months: term_months ?? null,
        remaining_months: calcRemainingMonths,
        start_date: start_date || null,
        maturity_date: maturity_date || null,
        due_date: due_date ?? null,
        is_secured: autoSecured,
        collateral: collateral || null,
        notes: notes || null,
      })
      .select()
      .single();

    if (error) throw error;

    const { checkProactiveAfterDebtChange } = require('../services/notificationService');
    checkProactiveAfterDebtChange(req.user.id).catch(() => {});

    const { assessProfileUpdate } = require('../services/profileUpdateService');
    assessProfileUpdate(req.user.id, 'debt_added', {
      name: data.name, type: data.debt_type, balance: parseFloat(data.current_balance), interest_rate: data.interest_rate,
    }).catch(() => {});

    return res.status(201).json({ success: true, data });
  } catch (error) {
    console.error('createDebt error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const updateDebt = async (req, res) => {
  try {
    const { id } = req.params;

    const { data: existing, error: fetchError } = await supabase
      .from('debts')
      .select('id, current_balance')
      .eq('id', id)
      .eq('user_id', req.user.id)
      .single();

    if (fetchError || !existing) {
      return res.status(404).json({ success: false, message: 'Debt not found' });
    }

    const allowed = [
      'name', 'debt_type', 'lender', 'current_balance',
      'interest_rate', 'interest_type', 'promotional_rate_until',
      'minimum_payment', 'current_monthly_payment',
      'remaining_months', 'maturity_date', 'due_date',
      'is_secured', 'collateral', 'is_active', 'paid_off_date', 'notes',
    ];

    const updates = {};
    for (const key of allowed) {
      if (req.body[key] !== undefined) updates[key] = req.body[key];
    }

    if (updates.debt_type && !VALID_DEBT_TYPES.includes(updates.debt_type)) {
      return res.status(400).json({ success: false, message: `Invalid debt_type` });
    }

    const { data, error } = await supabase
      .from('debts')
      .update(updates)
      .eq('id', id)
      .eq('user_id', req.user.id)
      .select()
      .single();

    if (error) throw error;

    // Record debt balance snapshot if balance changed
    if (updates.current_balance !== undefined) {
      const prevBalance = parseFloat(existing.current_balance || 0);
      const newBalance = parseFloat(updates.current_balance);
      const change = newBalance - prevBalance;
      const direction = change < 0 ? 'decrease' : change > 0 ? 'increase' : 'no_change';
      supabase.from('debt_balance_snapshots').insert({
        user_id: req.user.id,
        debt_id: id,
        previous_balance: prevBalance,
        new_balance: newBalance,
        change_amount: Math.abs(change),
        direction,
      }).then(() => {}).catch(() => {});
    }

    const { assessProfileUpdate } = require('../services/profileUpdateService');
    assessProfileUpdate(req.user.id, 'debt_updated', {
      name: data.name, balance: parseFloat(data.current_balance),
    }).catch(() => {});

    return res.json({ success: true, data });
  } catch (error) {
    console.error('updateDebt error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

const deleteDebt = async (req, res) => {
  try {
    const { id } = req.params;

    const { data: existing, error: fetchError } = await supabase
      .from('debts')
      .select('id')
      .eq('id', id)
      .eq('user_id', req.user.id)
      .single();

    if (fetchError || !existing) {
      return res.status(404).json({ success: false, message: 'Debt not found' });
    }

    const { error } = await supabase
      .from('debts')
      .update({ is_active: false })
      .eq('id', id)
      .eq('user_id', req.user.id);

    if (error) throw error;

    const { assessProfileUpdate } = require('../services/profileUpdateService');
    assessProfileUpdate(req.user.id, 'debt_removed', { debt_id: id }).catch(() => {});

    return res.json({ success: true, message: 'Debt removed' });
  } catch (error) {
    console.error('deleteDebt error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// GET DEBT STRATEGY
// Returns avalanche vs snowball comparison + priority breakdown
// ─────────────────────────────────────────────
const getStrategy = async (req, res) => {
  try {
    const { data: debts } = await supabase
      .from('debts')
      .select('name, debt_type, current_balance, interest_rate, minimum_payment, current_monthly_payment, remaining_months')
      .eq('user_id', req.user.id)
      .eq('is_active', true)
      .order('interest_rate', { ascending: false, nullsFirst: false });

    if (!debts?.length) {
      return res.json({ success: true, strategy: null, message: 'No active debts' });
    }

    const [{ data: profile }, { data: vaults }, { data: aiProfile }] = await Promise.all([
      supabase.from('onboarding_profiles').select('monthly_income').eq('user_id', req.user.id).single(),
      supabase.from('vaults').select('name, category_key, allocation_percentage')
        .eq('user_id', req.user.id).eq('is_active', true),
      supabase.from('ai_financial_profiles').select('behavioral_classification').eq('user_id', req.user.id).single(),
    ]);

    const income = parseFloat(profile?.monthly_income || 0);
    const classification = aiProfile?.behavioral_classification || 'balanced_spender';
    const debtVault = (vaults || []).find(v => v.category_key?.includes('debt'));

    const totalBalance = debts.reduce((s, d) => s + parseFloat(d.current_balance || 0), 0);
    const totalMonthly = debts.reduce((s, d) => s + parseFloat(d.current_monthly_payment || d.minimum_payment || 0), 0);
    const totalMinimum = debts.reduce((s, d) => s + parseFloat(d.minimum_payment || 0), 0);
    const extraPayment = Math.max(0, totalMonthly - totalMinimum);
    const monthlyInterest = debts.reduce((s, d) => {
      return s + parseFloat(d.current_balance || 0) * (parseFloat(d.interest_rate || 0) / 100 / 12);
    }, 0);

    // Simulate avalanche (highest rate first)
    const avalanche = _simulate([...debts].sort((a, b) => parseFloat(b.interest_rate || 0) - parseFloat(a.interest_rate || 0)), extraPayment);
    // Simulate snowball (smallest balance first)
    const snowball = _simulate([...debts].sort((a, b) => parseFloat(a.current_balance || 0) - parseFloat(b.current_balance || 0)), extraPayment);

    const interestSaved = Math.max(0, Math.round((snowball.totalInterest - avalanche.totalInterest) * 100) / 100);

    // Priority list built after strategy decision (below) so sort order matches recommendation

    // Debt-free date calculated after strategy decision (uses simulation result)

    // Decide strategy based on interest savings + user's behavioural profile
    const snowballTypes = ['impulse_spender', 'high_variability_spender', 'risk_averse'];
    let recommendedType, recommendedReason;
    if (interestSaved > 500) {
      recommendedType = 'avalanche';
      recommendedReason = `Avalanche saves RM ${interestSaved.toFixed(2)} in interest — too significant to pass up, even if progress feels slower at first.`;
    } else if (interestSaved < 50) {
      recommendedType = 'snowball';
      recommendedReason = `Interest difference is only RM ${interestSaved.toFixed(2)} — negligible. Snowball clears debts faster for quick wins and motivation.`;
    } else if (snowballTypes.includes(classification)) {
      recommendedType = 'snowball';
      recommendedReason = `Based on your spending profile, clearing smaller debts first gives you visible progress and motivation to keep going.`;
    } else {
      recommendedType = 'avalanche';
      recommendedReason = `You have the discipline to stick with a plan. Paying highest interest first saves RM ${interestSaved.toFixed(2)} over time.`;
    }

    const recommended = recommendedType === 'avalanche' ? avalanche : snowball;

    const debtFreeDate = recommended.months > 0
      ? require('../utils/dateUtils').formatDateMYT(Date.now() + recommended.months * 30 * 86400000, { month: 'long', year: 'numeric' })
      : null;

    // Build priority list sorted by recommended strategy
    const sortedDebts = recommendedType === 'avalanche'
      ? [...debts].sort((a, b) => parseFloat(b.interest_rate || 0) - parseFloat(a.interest_rate || 0))
      : [...debts].sort((a, b) => parseFloat(a.current_balance || 0) - parseFloat(b.current_balance || 0));

    const priorityList = sortedDebts.map((d, i) => {
      const rate = parseFloat(d.interest_rate || 0);
      const balance = parseFloat(d.current_balance || 0);
      const payment = parseFloat(d.current_monthly_payment || d.minimum_payment || 0);
      const minPay = parseFloat(d.minimum_payment || 0);
      const extra = payment - minPay;
      const monthlyInt = balance * (rate / 100 / 12);

      let reason;
      if (recommendedType === 'avalanche') {
        if (i === 0 && rate > 0) reason = `Highest interest rate at ${rate}%. Every extra RM goes here first — saves the most money.`;
        else if (rate > 10) reason = `High interest at ${rate}%. Will become priority after #${i} is cleared.`;
        else if (rate > 0) reason = `Lower rate at ${rate}%. Keep paying the fixed amount, no rush.`;
        else reason = `0% interest — no urgency. Pay the fixed installment.`;
      } else {
        if (i === 0) reason = `Smallest balance at RM ${balance.toFixed(2)}. Clear this first for a quick win.`;
        else if (i === 1) reason = `Next smallest at RM ${balance.toFixed(2)}. Tackle this once #1 is cleared.`;
        else reason = `RM ${balance.toFixed(2)} remaining. Keep paying the fixed amount until earlier debts are cleared.`;
      }

      return {
        priority: i + 1,
        name: d.name,
        type: d.debt_type,
        balance: Math.round(balance * 100) / 100,
        interest_rate: rate,
        monthly_payment: Math.round(payment * 100) / 100,
        minimum_payment: Math.round(minPay * 100) / 100,
        extra_payment: Math.round(extra * 100) / 100,
        monthly_interest: Math.round(monthlyInt * 100) / 100,
        remaining_months: d.remaining_months,
        reason,
      };
    });

    return res.json({
      success: true,
      strategy: {
        type: recommendedType,
        description: recommendedType === 'avalanche'
          ? 'Pay highest interest rate first — saves the most money'
          : 'Pay smallest balance first — quick wins keep you motivated',
        recommendation_reason: recommendedReason,
        total_balance: Math.round(totalBalance * 100) / 100,
        total_monthly_payment: Math.round(totalMonthly * 100) / 100,
        total_minimum: Math.round(totalMinimum * 100) / 100,
        extra_payment: Math.round(extraPayment * 100) / 100,
        monthly_interest_cost: Math.round(monthlyInterest * 100) / 100,
        interest_saved_vs_minimum: interestSaved > 0 ? interestSaved : 0,
        avalanche_months: avalanche.months,
        snowball_months: snowball.months,
        months_to_debt_free: recommended.months,
        debt_free_date: debtFreeDate,
        debt_vault: debtVault ? {
          name: debtVault.name,
          allocation: debtVault.allocation_percentage,
          monthly_amount: Math.round(income * debtVault.allocation_percentage / 100 * 100) / 100,
        } : null,
        priority_list: priorityList,
      },
    });
  } catch (error) {
    console.error('getStrategy error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

function _simulate(debts, extraMonthly) {
  const balances = debts.map(d => parseFloat(d.current_balance || 0));
  const rates = debts.map(d => parseFloat(d.interest_rate || 0) / 100 / 12);
  const mins = debts.map(d => parseFloat(d.minimum_payment || 0));
  let months = 0, totalInterest = 0;
  while (balances.some(b => b > 0.01) && months < 360) {
    months++;
    let extra = extraMonthly;
    for (let i = 0; i < balances.length; i++) {
      if (balances[i] <= 0) continue;
      const interest = balances[i] * rates[i];
      totalInterest += interest;
      balances[i] += interest;
      balances[i] -= Math.min(balances[i], mins[i]);
    }
    for (let i = 0; i < balances.length; i++) {
      if (balances[i] <= 0 || extra <= 0) continue;
      const apply = Math.min(balances[i], extra);
      balances[i] -= apply;
      extra -= apply;
      break;
    }
  }
  return { months, totalInterest: Math.round(totalInterest * 100) / 100 };
}

module.exports = { getDebts, createDebt, updateDebt, deleteDebt, getStrategy };
