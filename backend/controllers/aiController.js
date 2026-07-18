// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : aiController.js
// Description   : AI controller for FinWise — handles onboarding 
//                 chat with Gemini and vault creation
// First Written : 23-May-2026
// Edited on     : 23-May-2026
// ============================================

const supabase = require('../config/supabase');
const { safeGeminiCall, buildOnboardingPrompt, buildReviewerPrompt, buildSummarizationPrompt } = require('../services/geminiService');
const { runAionAgent } = require('../services/langGraphService');
const { embedText } = require('../services/embeddingService');
const { checkGoalCompletion } = require('../services/notificationService');

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
        error: 'Monthly budget is missing. Aion must ask for it before saving.'
      };
    }

    // Validate allocations sum to ~100 (±0.5 tolerance for Gemini rounding)
    const totalPercentage = vault_recommendations.reduce(
      (sum, v) => sum + v.allocation_percentage, 0
    );
    if (totalPercentage < 99.5 || totalPercentage > 100.5) {
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
    const { midnightTodayMYT } = require('../utils/dateUtils');
    const sessionBoundary = aiProfile?.key_insights?.last_summarised_at
      ? new Date(aiProfile.key_insights.last_summarised_at)
      : new Date(midnightTodayMYT());

    // Current session — all messages since the session boundary
    // Includes proactive notifications + goal guardian so Aion has full context
    let currentQuery = supabase
      .from('ai_logs')
      .select('user_message, ai_response')
      .eq('user_id', user_id)
      .in('interaction_type', ['chat', 'proactive', 'goal_guardian'])
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
      .in('interaction_type', ['chat', 'proactive', 'goal_guardian'])
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
        let aiMsg;
        if (typeof log.ai_response === 'string') {
          aiMsg = log.ai_response;
        } else if (log.ai_response?.alert_message) {
          aiMsg = log.ai_response.alert_message;
        } else if (log.ai_response?.alert_user === false) {
          aiMsg = '[Transaction approved — no concerns]';
        } else {
          aiMsg = log.ai_response?.message;
        }
        if (aiMsg) history.push({ role: 'assistant', content: aiMsg });
      }
      return history;
    };

    const currentSessionHistory = logsToHistory(todayLogs);
    // Past logs fetched newest-first — reverse for chronological order
    const pastSessionHistory = logsToHistory((pastLogs || []).reverse());

    const userContext = { profile, onboardingProfile, aiProfile, vaults };

    // Fetch pending P2P transfers for the transfer allocation flow
    const { data: pendingTransfersRaw } = await supabase
      .from('p2p_transfers')
      .select('id, amount, created_at, sender:profiles!sender_id(full_name)')
      .eq('receiver_id', user_id)
      .eq('status', 'pending');

    const pendingTransfers = (pendingTransfersRaw || []).map(t => ({
      id: t.id,
      amount: t.amount,
      created_at: t.created_at,
      sender_name: t.sender?.full_name || 'Someone',
    }));

    // Combine current + past session history for the agent
    const chatHistory = [...pastSessionHistory, ...currentSessionHistory];

    // Run the LangGraph agent — it will call tools as needed
    const agentResponse = await runAionAgent(user_id, message, userContext, chatHistory, pendingTransfers);

    if (!agentResponse.success) {
      return res.status(500).json({ success: false, message: 'AI service unavailable. Please try again.' });
    }

    const aiData = agentResponse.data;
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

    // Return transfer allocation to Flutter for confirmation bottom sheet.
    // Normalise: Gemini may return old singular transfer_id — coerce to array format.
    let transferAllocation = aiData.transfer_allocation ?? null;
    if (transferAllocation) {
      if (!Array.isArray(transferAllocation.transfer_ids) && transferAllocation.transfer_id) {
        transferAllocation = {
          ...transferAllocation,
          transfer_ids: [transferAllocation.transfer_id],
          total_amount: transferAllocation.amount ?? transferAllocation.total_amount ?? 0,
        };
      }
      // Validate every ID against real pending transfers — blocks hallucination.
      const ids = transferAllocation.transfer_ids || [];
      const allValid = ids.length > 0 && ids.every((id) => pendingTransfers.some((t) => t.id === id));
      if (allValid) {
        // Gemini sometimes returns category_key instead of UUID for suggested_vault_id — resolve it.
        const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        const suggestedId = transferAllocation.suggested_vault_id;
        if (suggestedId && !uuidPattern.test(suggestedId)) {
          const matched = (vaults || []).find(
            (v) => v.category_key === suggestedId || v.name.toLowerCase() === suggestedId.toLowerCase()
          );
          if (matched) {
            transferAllocation = {
              ...transferAllocation,
              suggested_vault_id: matched.id,
              suggested_vault_name: matched.name,
            };
          }
        }
        return res.json({
          success: true,
          message: aiMessage,
          transfer_allocation: transferAllocation,
        });
      }
      console.log('[advisoryChat] transfer_allocation blocked — ids:', ids, '| pendingTransfers:', pendingTransfers.map(t => t.id));
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

    // Fetch last 40 rows (newest first) — includes chat + proactive messages
    const { data: rawLogs, error } = await supabase
      .from('ai_logs')
      .select('id, user_message, ai_response, interaction_type, created_at')
      .eq('user_id', user_id)
      .in('interaction_type', ['chat', 'proactive'])
      .order('created_at', { ascending: false })
      .limit(40);

    if (error) throw error;

    // Reverse to chronological order for display
    const logs = (rawLogs || []).reverse();

    // Flatten each log row into individual user + AI message objects.
    // Proactive logs: ai_response is a plain string (no user message).
    // Chat logs: ai_response is { message: "..." }.
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
      const aiMsg = typeof log.ai_response === 'string'
        ? log.ai_response
        : log.ai_response?.message;
      if (aiMsg) {
        messages.push({
          id: `${log.id}_ai`,
          content: aiMsg,
          is_user: false,
          is_proactive: log.interaction_type === 'proactive',
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

    // Fetch all messages since last summarisation (chat + proactive + goal guardian)
    let query = supabase
      .from('ai_logs')
      .select('user_message, ai_response, created_at')
      .eq('user_id', user_id)
      .in('interaction_type', ['chat', 'proactive', 'goal_guardian'])
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

    // Convert logs to message list (handles chat, proactive, and goal_guardian formats)
    const sessionMessages = [];
    for (const log of newLogs) {
      if (log.user_message && log.user_message !== '__INIT__') {
        sessionMessages.push({ role: 'user', content: log.user_message });
      }
      let aiMsg;
      if (typeof log.ai_response === 'string') {
        aiMsg = log.ai_response;
      } else if (log.ai_response?.alert_message) {
        aiMsg = log.ai_response.alert_message;
      } else if (log.ai_response?.alert_user === false) {
        aiMsg = '[Transaction approved — no concerns]';
      } else {
        aiMsg = log.ai_response?.message;
      }
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
    // Strip session_summary — it's used for RAG embedding only, not stored in key_insights
    const { session_summary: sessionSummaryForRAG, ...cumulativeData } = result.data;
    const updatedInsights = {
      ...cumulativeData,
      last_summarised_at: new Date().toISOString(),
    };

    await supabase
      .from('ai_financial_profiles')
      .update({ key_insights: updatedInsights })
      .eq('user_id', user_id);

    // RAG: embed the SESSION-SPECIFIC summary (not cumulative key_insights).
    // Each session gets its own unique embedding for accurate retrieval.
    // Runs fire-and-forget — summarisation succeeds even if embedding fails.
    const summaryText = sessionSummaryForRAG || '';
    if (summaryText.trim().length > 20) {
      embedText(summaryText).then(async (vector) => {
        if (!vector) return;
        // Store on the LAST ai_logs row before the boundary — marks this session as embedded
        const { data: lastLog } = await supabase
          .from('ai_logs')
          .select('id')
          .eq('user_id', user_id)
          .in('interaction_type', ['chat', 'proactive', 'goal_guardian'])
          .lte('created_at', updatedInsights.last_summarised_at)
          .order('created_at', { ascending: false })
          .limit(1)
          .single();

        if (lastLog) {
          await supabase
            .from('ai_logs')
            .update({ session_summary: summaryText.trim(), embedding: JSON.stringify(vector) })
            .eq('id', lastLog.id);
          console.log(`[RAG] Session embedded on ai_logs ${lastLog.id}`);
        }
      }).catch(err => console.error('[RAG] Embedding failed (non-fatal):', err.message));
    }

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
      { data: activeVaults },
    ] = await Promise.all([
      supabase.from('profiles').select('full_name, email').eq('id', user_id).single(),
      supabase.from('onboarding_profiles').select('*').eq('user_id', user_id).single(),
      supabase.from('ai_financial_profiles').select('*').eq('user_id', user_id).single(),
      supabase
        .from('allocation_history')
        .select('*')
        .eq('user_id', user_id)
        .order('created_at', { ascending: false }),
      supabase.from('vaults').select('name, category_key, allocation_percentage, vault_type')
        .eq('user_id', user_id).eq('is_active', true)
        .is('completed_at', null).eq('is_archived', false),
    ]);

    // Build live allocation from active vaults only
    const liveAllocation = {};
    for (const v of (activeVaults || [])) {
      liveAllocation[v.name] = v.allocation_percentage;
    }
    if (aiProfile) aiProfile.recommended_allocation = liveAllocation;

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

    // Validate allocations sum to ~100 (±0.5 tolerance for Gemini rounding)
    const totalPct = newPlan.reduce((sum, v) => sum + (v.allocation_percentage || 0), 0);
    if (totalPct < 99.5 || totalPct > 100.5) {
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
      triggered_by: 'conversation',
    });

    // 6 — Process immediate vault balance transfers
    const { immediate_transfers } = vaultPlanUpdate;
    if (immediate_transfers?.length > 0) {
      // Re-fetch vaults after plan changes (new vaults may have just been created)
      const { data: freshVaults } = await supabase
        .from('vaults').select('*').eq('user_id', user_id).eq('is_active', true);
      const vaultByKey = new Map((freshVaults || []).map(v => [v.category_key, v]));

      for (const transfer of immediate_transfers) {
        const fromVault = vaultByKey.get(transfer.from_category_key);
        const toVault   = vaultByKey.get(transfer.to_category_key);
        if (!fromVault || !toVault) continue;

        const amount = parseFloat(transfer.amount);
        if (!amount || amount <= 0) continue;
        if (fromVault.current_balance < amount) continue; // never overdraft

        // Move balances
        await supabase.from('vaults')
          .update({ current_balance: fromVault.current_balance - amount })
          .eq('id', fromVault.id);
        await supabase.from('vaults')
          .update({ current_balance: toVault.current_balance + amount })
          .eq('id', toVault.id);

        // Audit trail in vault_transfers
        await supabase.from('vault_transfers').insert({
          user_id,
          from_vault_id: fromVault.id,
          to_vault_id:   toVault.id,
          amount,
          transfer_type: 'ai_suggested',
          reason: vaultPlanUpdate.change_reason || 'Aion advisory transfer',
        });

        // Transaction records so both vaults appear in transaction history
        await supabase.from('transactions').insert([
          {
            user_id,
            vault_id: fromVault.id,
            amount,
            merchant_name: `To: ${toVault.name}`,
            merchant_category: fromVault.category_key,
            transaction_type: 'transfer',
            status: 'approved',
            goal_conflict_detected: false,
            user_overrode_guardian: false,
            ai_categorisation_attempts: 0,
            ai_categorisation_failed: false,
          },
          {
            user_id,
            vault_id: toVault.id,
            amount,
            merchant_name: `From: ${fromVault.name}`,
            merchant_category: toVault.category_key,
            transaction_type: 'transfer',
            status: 'approved',
            goal_conflict_detected: false,
            user_overrode_guardian: false,
            ai_categorisation_attempts: 0,
            ai_categorisation_failed: false,
          },
        ]);
      }
    }

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
// Executes the vault plan update that was proposed by Aion.
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

    const completed_goals = await checkGoalCompletion(user_id);

    return res.json({ success: true, completed_goals });
  } catch (error) {
    console.error('applyVaultChanges error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// GET LATEST NOTIFICATION
// Returns the most recent unread proactive ai_logs row
// ─────────────────────────────────────────────
const getLatestNotification = async (req, res) => {
  try {
    const user_id = req.user.id;

    const { data, error } = await supabase
      .from('ai_logs')
      .select('id, ai_response, created_at')
      .eq('user_id', user_id)
      .eq('interaction_type', 'proactive')
      .eq('is_proactive', true)
      .eq('notification_read', false)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) throw error;

    res.json({ notification: data || null });
  } catch (error) {
    console.error('getLatestNotification error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// ─────────────────────────────────────────────
// MARK NOTIFICATION READ
// Sets notification_read = true for a given ai_logs id
// ─────────────────────────────────────────────
const markNotificationRead = async (req, res) => {
  try {
    const user_id = req.user.id;
    const { id } = req.params;

    const { error } = await supabase
      .from('ai_logs')
      .update({ notification_read: true })
      .eq('id', id)
      .eq('user_id', user_id);

    if (error) throw error;

    res.json({ success: true });
  } catch (error) {
    console.error('markNotificationRead error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

module.exports = { onboardingChat, confirmVaults, advisoryChat, getChatHistory, summarizeSession, getMyProfile, applyVaultChanges, getLatestNotification, markNotificationRead };