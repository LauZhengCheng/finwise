// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : aiController.js
// Description   : AI controller for FinWise — handles onboarding 
//                 chat with Gemini and vault creation
// First Written : 23-May-2026
// Edited on     : 23-May-2026
// ============================================

const supabase = require('../config/supabase');
const { safeGeminiCall, buildOnboardingPrompt, buildReviewerPrompt, buildChatPrompt, buildSummarizationPrompt } = require('../services/geminiService');

// ─────────────────────────────────────────────
// ONBOARDING CHAT
// POST /api/ai/onboarding/chat
// ─────────────────────────────────────────────
const onboardingChat = async (req, res) => {
  try {
    const { message, conversation_history, current_vaults } = req.body;
    const user_id = req.user.id; // from authenticateToken middleware

    // Validate required fields
    if (!message) {
      return res.status(400).json({ success: false, message: 'Message is required' });
    }

    // Handle initial greeting trigger
    const isInit = message === '__INIT__';

    // Fetch user profile for context
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('full_name, email')
      .eq('id', user_id)
      .single();

    if (profileError) {
      return res.status(500).json({ success: false, message: 'Failed to fetch user profile' });
    }

    // Build user context to pass to Gemini
    const userContext = {
      name: profile.full_name,
      email: profile.email,
    };

    // Frontend already includes the latest user message in conversation_history
    const updatedHistory = isInit ? [] : (conversation_history || []);

    // Use Reviewer prompt when a vault plan already exists, Planner for fresh onboarding
    const prompt = current_vaults
      ? buildReviewerPrompt(updatedHistory, userContext, current_vaults)
      : buildOnboardingPrompt(updatedHistory, userContext, isInit);
    const geminiResponse = await safeGeminiCall(prompt);

    if (!geminiResponse.success) {
      return res.status(500).json({ success: false, message: 'AI service failed. Please try again.' });
    }

    const aiData = geminiResponse.data;

    // Log AI interaction to ai_logs table
    await supabase.from('ai_logs').insert({
      user_id,
      interaction_type: 'chat',
      user_message: message,
      ai_response: aiData,
      raw_ai_response: aiData,
    });

    // Vault plan is ready — return it to frontend for display
    if (aiData.vault_plan_ready === true) {
      return res.json({
        success: true,
        message: aiData.message,
        vault_plan_ready: true,
        vault_recommendations: aiData.vault_recommendations,
        profile_data: aiData.profile_data,
      });
    }

    // Still in conversation — return AI message only
    return res.json({
      success: true,
      message: aiData.message,
      vault_plan_ready: false,
      vault_recommendations: null,
      profile_data: null,
    });

  } catch (error) {
    console.error('onboardingChat error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// CONFIRM VAULTS
// POST /api/ai/onboarding/confirm-vaults
// Called after user confirms vault recommendations
// ─────────────────────────────────────────────
const confirmVaults = async (req, res) => {
  try {
    const { vault_recommendations, profile_data } = req.body;
    const user_id = req.user.id;

    if (!vault_recommendations || !profile_data) {
      return res.status(400).json({ success: false, message: 'Missing vault_recommendations or profile_data' });
    }

    const saveResult = await saveOnboardingData(user_id, {
      profile_data,
      vault_recommendations,
    });

    if (!saveResult.success) {
      return res.status(500).json({ success: false, message: saveResult.error });
    }

    return res.json({
      success: true,
      message: 'Vaults created successfully',
      vaults: saveResult.vaults,
    });

  } catch (error) {
    console.error('confirmVaults error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// SAVE ONBOARDING DATA (internal helper)
// Creates all DB rows after onboarding completes
// ─────────────────────────────────────────────
const saveOnboardingData = async (user_id, aiData) => {
  try {
    const { profile_data, vault_recommendations } = aiData;

    // Validate monthly_income is present
    if (!profile_data.monthly_income || profile_data.monthly_income <= 0) {
      return {
        success: false,
        error: 'Monthly budget is missing. Aria must ask for it before saving.'
      };
    }

    // Validate allocations sum to 100
    const totalPercentage = vault_recommendations.reduce(
      (sum, v) => sum + v.allocation_percentage, 0
    );
    if (totalPercentage !== 100) {
      return {
        success: false,
        error: `Allocation percentages sum to ${totalPercentage}, not 100`
      };
    }
    
    // Validate each vault
    for (const vault of vault_recommendations) {
      if (vault.vault_type === 'fund') {
        if (!vault.linked_goal || !vault.goal_target_amount) {
          return {
            success: false,
            error: `Fund vault ${vault.name} missing linked_goal or goal_target_amount`
          };
        }
      }
      if (!/^[a-z0-9_]+$/.test(vault.category_key)) {
        return {
          success: false,
          error: `Invalid category_key format: ${vault.category_key}`
        };
      }
    }

    // 1 — Save onboarding_profiles row
    const { error: onboardingError } = await supabase
      .from('onboarding_profiles')
      .upsert({
        user_id,
        monthly_income: profile_data.monthly_income,
        financial_goals: profile_data.financial_goals,
        spending_habit: profile_data.spending_habit,
        risk_level: profile_data.risk_level,
        life_situation: profile_data.life_situation,
        financial_challenges: profile_data.financial_challenges,
      });

    if (onboardingError) throw new Error('Failed to save onboarding profile: ' + onboardingError.message);

    // 2 — Save ai_financial_profiles row
    const allocationMap = {};
    vault_recommendations.forEach(v => {
      allocationMap[v.category_key] = v.allocation_percentage;
    });

    const { error: aiProfileError } = await supabase
      .from('ai_financial_profiles')
      .upsert({
        user_id,
        behavioral_classification: profile_data.spending_habit || null,
        recommended_allocation: allocationMap,
        ai_reasoning: 'Generated during onboarding conversation',
        key_insights: {
          summary: 'New user — insights will build over time',
          patterns: {}
        },
      });

    if (aiProfileError) throw new Error('Failed to save AI profile: ' + aiProfileError.message);

    // 3 — Create vault rows
    const vaultRows = vault_recommendations.map(v => ({
      user_id,
      name: v.name,
      category_key: v.category_key,
      vault_type: v.vault_type,
      allocation_percentage: v.allocation_percentage,
      allocated_amount: 0,
      current_balance: 0,
      spent_amount: 0,
      vault_colour: v.vault_colour,
      vault_icon: v.vault_icon,
      linked_goal: v.linked_goal || null,
      goal_target_amount: v.goal_target_amount || null,
      is_active: true,
    }));

    const { data: vaults, error: vaultError } = await supabase
      .from('vaults')
      .insert(vaultRows)
      .select();

    if (vaultError) throw new Error('Failed to create vaults: ' + vaultError.message);

    // 4 — Save allocation_history row
    const { error: historyError } = await supabase
      .from('allocation_history')
      .insert({
        user_id,
        previous_allocation: {},
        new_allocation: allocationMap,
        change_reason: 'Initial onboarding allocation',
        triggered_by: 'onboarding',
      });

    if (historyError) throw new Error('Failed to save allocation history: ' + historyError.message);

    return { success: true, vaults };

  } catch (error) {
    console.error('saveOnboardingData error:', error.message);
    return { success: false, error: error.message };
  }
};

// ─────────────────────────────────────────────
// ADVISORY CHAT
// POST /api/ai/chat
// Session-aware: sends all of today's messages + last 30 from past days
// ─────────────────────────────────────────────
const advisoryChat = async (req, res) => {
  try {
    const { message } = req.body;
    const user_id = req.user.id;

    if (!message || !message.trim()) {
      return res.status(400).json({ success: false, message: 'Message is required' });
    }

    // Load all user context in parallel
    const [
      { data: profile },
      { data: onboardingProfile },
      { data: aiProfile },
      { data: vaults },
    ] = await Promise.all([
      supabase.from('profiles').select('full_name, email').eq('id', user_id).single(),
      supabase.from('onboarding_profiles').select('*').eq('user_id', user_id).single(),
      supabase.from('ai_financial_profiles').select('*').eq('user_id', user_id).single(),
      supabase.from('vaults').select('*').eq('user_id', user_id).eq('is_active', true),
    ]);

    // Session boundary — set when user last opened the chat (via summarizeSession)
    // Falls back to midnight today for users who haven't triggered summarisation yet
    const sessionBoundary = aiProfile?.key_insights?.last_summarised_at
      ? new Date(aiProfile.key_insights.last_summarised_at)
      : (() => { const d = new Date(); d.setHours(0, 0, 0, 0); return d; })();

    // Current session — all messages since the session boundary
    let currentQuery = supabase
      .from('ai_logs')
      .select('user_message, ai_response')
      .eq('user_id', user_id)
      .eq('interaction_type', 'chat')
      .gt('created_at', sessionBoundary.toISOString())
      .order('created_at', { ascending: true });
    const { data: todayLogs } = await currentQuery;

    // Past sessions — last 5 rows (×2 turns = 10 messages) before the boundary.
    // Recency buffer only — keeps conversational continuity when user briefly
    // exits and re-enters the chat. Not for reading history.
    let pastQuery = supabase
      .from('ai_logs')
      .select('user_message, ai_response')
      .eq('user_id', user_id)
      .eq('interaction_type', 'chat')
      .lte('created_at', sessionBoundary.toISOString())
      .order('created_at', { ascending: false })
      .limit(5);
    const { data: pastLogs } = await pastQuery;

    const logsToHistory = (logs) => {
      const history = [];
      for (const log of (logs || [])) {
        if (log.user_message && log.user_message !== '__INIT__') {
          history.push({ role: 'user', content: log.user_message });
        }
        const aiMsg = log.ai_response?.message;
        if (aiMsg) history.push({ role: 'assistant', content: aiMsg });
      }
      return history;
    };

    const currentSessionHistory = logsToHistory(todayLogs);
    // Past logs fetched newest-first — reverse for chronological order
    const pastSessionHistory = logsToHistory((pastLogs || []).reverse());

    const userContext = { profile, onboardingProfile, aiProfile, vaults };
    const prompt = buildChatPrompt(message, userContext, currentSessionHistory, pastSessionHistory);
    const geminiResponse = await safeGeminiCall(prompt);

    if (!geminiResponse.success) {
      return res.status(500).json({ success: false, message: 'AI service unavailable. Please try again.' });
    }

    const aiData = geminiResponse.data;
    const aiMessage = aiData.message || "Sorry, I couldn't respond properly. Please try again.";

    // Save to ai_logs
    await supabase.from('ai_logs').insert({
      user_id,
      interaction_type: 'chat',
      user_message: message,
      ai_response: aiData,
      raw_ai_response: aiData,
    });

    // Apply silent profile update if AI flagged one
    if (aiData.profile_update?.update_needed) {
      const allowed = ['behavioral_classification', 'recommended_allocation', 'key_insights', 'ai_reasoning'];
      const safe = {};
      Object.keys(aiData.profile_update.updates || {}).forEach(key => {
        if (allowed.includes(key)) safe[key] = aiData.profile_update.updates[key];
      });
      if (Object.keys(safe).length > 0) {
        await supabase.from('ai_financial_profiles').update(safe).eq('user_id', user_id);
      }
    }

    // Return vault plan to Flutter for user confirmation — do NOT execute here.
    // Flutter shows a bottom sheet; only calls /apply-vault-changes after user confirms.
    if (aiData.vault_plan_update?.vaults?.length > 0) {
      return res.json({
        success: true,
        message: aiMessage,
        vault_plan_update: aiData.vault_plan_update,
      });
    }

    return res.json({ success: true, message: aiMessage });

  } catch (error) {
    console.error('advisoryChat error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// GET CHAT HISTORY
// GET /api/ai/chat/history
// Returns all chat messages for display in the chat screen
// ─────────────────────────────────────────────
const getChatHistory = async (req, res) => {
  try {
    const user_id = req.user.id;

    // Fetch last 40 rows (newest first) → 80 displayed messages max
    const { data: rawLogs, error } = await supabase
      .from('ai_logs')
      .select('id, user_message, ai_response, created_at')
      .eq('user_id', user_id)
      .eq('interaction_type', 'chat')
      .order('created_at', { ascending: false })
      .limit(40);

    if (error) throw error;

    // Reverse to chronological order for display
    const logs = (rawLogs || []).reverse();

    // Flatten each log row into individual user + AI message objects
    const messages = [];
    for (const log of (logs || [])) {
      if (log.user_message && log.user_message !== '__INIT__') {
        messages.push({
          id: `${log.id}_user`,
          content: log.user_message,
          is_user: true,
          created_at: log.created_at,
        });
      }
      const aiMsg = log.ai_response?.message;
      if (aiMsg) {
        messages.push({
          id: `${log.id}_ai`,
          content: aiMsg,
          is_user: false,
          created_at: log.created_at,
        });
      }
    }

    return res.json({ success: true, messages });

  } catch (error) {
    console.error('getChatHistory error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// SUMMARIZE SESSION
// POST /api/ai/chat/summarize
// Called when user opens the chat screen.
// Finds all messages since last_summarised_at,
// merges them into key_insights, updates the boundary.
// ─────────────────────────────────────────────
const summarizeSession = async (req, res) => {
  try {
    const user_id = req.user.id;

    const { data: aiProfile } = await supabase
      .from('ai_financial_profiles')
      .select('key_insights')
      .eq('user_id', user_id)
      .single();

    const existingSummary = aiProfile?.key_insights || null;
    const lastSummarisedAt = existingSummary?.last_summarised_at || null;

    // Fetch all messages since last summarisation
    let query = supabase
      .from('ai_logs')
      .select('user_message, ai_response, created_at')
      .eq('user_id', user_id)
      .eq('interaction_type', 'chat')
      .order('created_at', { ascending: true });

    if (lastSummarisedAt) {
      query = query.gt('created_at', lastSummarisedAt);
    }

    const { data: newLogs } = await query;

    // Nothing new to summarise — just update the boundary timestamp
    if (!newLogs || newLogs.length === 0) {
      const updatedInsights = {
        ...(existingSummary || {}),
        last_summarised_at: new Date().toISOString(),
      };
      await supabase
        .from('ai_financial_profiles')
        .update({ key_insights: updatedInsights })
        .eq('user_id', user_id);
      return res.json({ success: true, message: 'No new messages to summarise' });
    }

    // Convert logs to message list
    const sessionMessages = [];
    for (const log of newLogs) {
      if (log.user_message && log.user_message !== '__INIT__') {
        sessionMessages.push({ role: 'user', content: log.user_message });
      }
      const aiMsg = log.ai_response?.message;
      if (aiMsg) sessionMessages.push({ role: 'assistant', content: aiMsg });
    }

    if (sessionMessages.length === 0) {
      return res.json({ success: true, message: 'No meaningful messages to summarise' });
    }

    const prompt = buildSummarizationPrompt(existingSummary, sessionMessages);
    const result = await safeGeminiCall(prompt);

    if (!result.success) {
      return res.status(500).json({ success: false, message: 'Summarisation failed' });
    }

    // Backend sets the boundary timestamp — not Gemini
    const updatedInsights = {
      ...result.data,
      last_summarised_at: new Date().toISOString(),
    };

    await supabase
      .from('ai_financial_profiles')
      .update({ key_insights: updatedInsights })
      .eq('user_id', user_id);

    return res.json({ success: true, last_summarised_at: updatedInsights.last_summarised_at });

  } catch (error) {
    console.error('summarizeSession error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// GET MY PROFILE
// GET /api/ai/profile
// Returns everything the system knows about the user:
// identity, onboarding declarations, AI conclusions,
// and the full allocation history timeline.
// ─────────────────────────────────────────────
const getMyProfile = async (req, res) => {
  try {
    const user_id = req.user.id;

    const [
      { data: profile },
      { data: onboarding },
      { data: aiProfile },
      { data: allocationHistory },
    ] = await Promise.all([
      supabase.from('profiles').select('full_name, email').eq('id', user_id).single(),
      supabase.from('onboarding_profiles').select('*').eq('user_id', user_id).single(),
      supabase.from('ai_financial_profiles').select('*').eq('user_id', user_id).single(),
      supabase
        .from('allocation_history')
        .select('*')
        .eq('user_id', user_id)
        .order('created_at', { ascending: false }),
    ]);

    return res.json({
      success: true,
      profile,
      onboarding,
      ai_profile: aiProfile,
      allocation_history: allocationHistory || [],
    });

  } catch (error) {
    console.error('getMyProfile error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// APPLY VAULT PLAN UPDATE (internal helper)
// Called when advisoryChat receives a confirmed vault_plan_update.
// Syncs the full new vault plan to the DB:
//   — Existing vaults in the plan → update name + allocation
//   — New category_keys in the plan → create new vault rows
//   — Active vaults NOT in the plan → soft-delete (is_active = false)
// Transaction history is never touched — only vault config changes.
// ─────────────────────────────────────────────
const applyVaultPlanUpdate = async (user_id, vaultPlanUpdate) => {
  try {
    const { vaults: newPlan, change_reason, is_temporary } = vaultPlanUpdate;

    if (!newPlan || newPlan.length === 0) {
      return { success: false, error: 'vault_plan_update.vaults is empty' };
    }

    // Validate allocations sum to 100 (allow ±1 for floating point)
    const totalPct = newPlan.reduce((sum, v) => sum + (v.allocation_percentage || 0), 0);
    if (Math.round(totalPct) !== 100) {
      return { success: false, error: `Allocations sum to ${totalPct}, must be 100` };
    }

    // Validate category_key format and fund vault fields
    for (const vault of newPlan) {
      if (!vault.category_key || !/^[a-z0-9_]+$/.test(vault.category_key)) {
        return { success: false, error: `Invalid category_key: ${vault.category_key}` };
      }
      if (vault.vault_type === 'fund' && (!vault.linked_goal || !vault.goal_target_amount)) {
        return { success: false, error: `Fund vault "${vault.name}" missing linked_goal or goal_target_amount` };
      }
    }

    // Fetch current active vaults
    const { data: existingVaults, error: fetchError } = await supabase
      .from('vaults')
      .select('*')
      .eq('user_id', user_id)
      .eq('is_active', true);

    if (fetchError) throw fetchError;

    const existingMap = new Map((existingVaults || []).map(v => [v.category_key, v]));
    const newPlanKeys = new Set(newPlan.map(v => v.category_key));

    // 1 — Update or create each vault in the new plan
    for (const vault of newPlan) {
      const existing = existingMap.get(vault.category_key);
      if (existing) {
        await supabase.from('vaults').update({
          name: vault.name,
          allocation_percentage: vault.allocation_percentage,
          vault_type: vault.vault_type,
          vault_colour: vault.vault_colour || existing.vault_colour,
          vault_icon: vault.vault_icon || existing.vault_icon,
          linked_goal: vault.linked_goal !== undefined ? vault.linked_goal : existing.linked_goal,
          goal_target_amount: vault.goal_target_amount !== undefined
            ? vault.goal_target_amount : existing.goal_target_amount,
        }).eq('id', existing.id);
      } else {
        await supabase.from('vaults').insert({
          user_id,
          name: vault.name,
          category_key: vault.category_key,
          vault_type: vault.vault_type,
          allocation_percentage: vault.allocation_percentage,
          allocated_amount: 0,
          current_balance: 0,
          spent_amount: 0,
          vault_colour: vault.vault_colour || '#6366F1',
          vault_icon: vault.vault_icon || 'wallet',
          linked_goal: vault.linked_goal || null,
          goal_target_amount: vault.goal_target_amount || null,
          is_active: true,
        });
      }
    }

    // 2 — Soft-delete vaults not in the new plan (preserves all transaction history)
    for (const existing of (existingVaults || [])) {
      if (!newPlanKeys.has(existing.category_key)) {
        await supabase.from('vaults').update({ is_active: false }).eq('id', existing.id);
      }
    }

    // 3 — Build allocation maps for profile + history
    const oldAllocationMap = {};
    (existingVaults || []).forEach(v => { oldAllocationMap[v.category_key] = v.allocation_percentage; });

    const newAllocationMap = {};
    newPlan.forEach(v => { newAllocationMap[v.category_key] = v.allocation_percentage; });

    // 4 — Update recommended_allocation in ai_financial_profiles
    await supabase.from('ai_financial_profiles')
      .update({ recommended_allocation: newAllocationMap })
      .eq('user_id', user_id);

    // 5 — Append to allocation_history (append-only, never update)
    const reasonText = is_temporary
      ? `[TEMPORARY] ${change_reason || 'User requested temporary vault changes via chat'}`
      : (change_reason || 'User requested vault changes via chat');

    await supabase.from('allocation_history').insert({
      user_id,
      previous_allocation: oldAllocationMap,
      new_allocation: newAllocationMap,
      change_reason: reasonText,
      triggered_by: 'ai_chat',
    });

    return { success: true };

  } catch (error) {
    console.error('applyVaultPlanUpdate error:', error.message);
    return { success: false, error: error.message };
  }
};

// ─────────────────────────────────────────────
// APPLY VAULT CHANGES
// POST /api/ai/chat/apply-vault-changes
// Called after user confirms vault changes via the bottom sheet.
// Executes the vault plan update that was proposed by Aria.
// ─────────────────────────────────────────────
const applyVaultChanges = async (req, res) => {
  try {
    const { vault_plan_update } = req.body;
    const user_id = req.user.id;

    if (!vault_plan_update?.vaults?.length) {
      return res.status(400).json({ success: false, message: 'vault_plan_update with vaults is required' });
    }

    const result = await applyVaultPlanUpdate(user_id, vault_plan_update);
    if (!result.success) {
      return res.status(400).json({ success: false, message: result.error });
    }

    return res.json({ success: true });
  } catch (error) {
    console.error('applyVaultChanges error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

module.exports = { onboardingChat, confirmVaults, advisoryChat, getChatHistory, summarizeSession, getMyProfile, applyVaultChanges };