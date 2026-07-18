// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : profileUpdateService.js
// Description   : Continuous AI Financial Profile updates.
//                 Called after every financial event — Gemini
//                 assesses if user's profile should evolve.
// First Written : 25-06-2026
// Edited on     : 25-06-2026
// ============================================

const supabase = require('../config/supabase');
const { safeGeminiCall } = require('./geminiService');

const ALLOWED_FIELDS = ['behavioral_classification', 'key_insights', 'ai_reasoning'];
const VALID_CLASSIFICATIONS = [
  'disciplined_saver', 'balanced_spender', 'impulse_spender',
  'risk_averse', 'high_variability_spender', 'goal_oriented_spender',
];

async function assessProfileUpdate(userId, eventType, eventData) {
  try {
    const [{ data: aiProfile }, { data: onboarding }] = await Promise.all([
      supabase.from('ai_financial_profiles').select('behavioral_classification, key_insights, ai_reasoning')
        .eq('user_id', userId).single(),
      supabase.from('onboarding_profiles').select('monthly_income, risk_level, spending_habit, financial_goals')
        .eq('user_id', userId).single(),
    ]);

    if (!aiProfile) return;

    const prompt = `
You are Aion, analysing a user's financial event to decide if their AI profile should be updated.

CURRENT AI PROFILE:
Classification: ${aiProfile.behavioral_classification || 'not set'}
Key insights: ${JSON.stringify(aiProfile.key_insights || {})}

USER BACKGROUND:
Monthly income: RM ${onboarding?.monthly_income || 'unknown'}
Risk level: ${onboarding?.risk_level || 'unknown'}
Spending habit: ${onboarding?.spending_habit || 'unknown'}
Goals: ${JSON.stringify(onboarding?.financial_goals || {})}

EVENT THAT JUST HAPPENED:
Type: ${eventType}
Details: ${JSON.stringify(eventData)}

Based on this event, decide:
1. Should behavioral_classification change? Only if this event clearly shifts the pattern (e.g. consistently disciplined user suddenly impulse spending, or impulse spender paying off debt consistently)
2. Should key_insights be updated? Add new observations, patterns, or notes. MERGE with existing — never delete old insights, only append or refine.
3. If nothing meaningful changed, set update_needed to false.

RULES:
- behavioral_classification must be one of: disciplined_saver, balanced_spender, impulse_spender, risk_averse, high_variability_spender, goal_oriented_spender
- key_insights must keep the existing structure: { summary, financial_patterns[], goals_discussed[], behavioral_notes[], relationship_notes[] }
- Only update what changed — don't rewrite everything
- Small routine events (normal daily spending within budget) = no update needed
- Significant events (debt paid off, goal completed, unusual spending, income change) = likely update

Respond in JSON:
{
  "update_needed": false,
  "updates": {}
}

Or if update needed:
{
  "update_needed": true,
  "updates": {
    "behavioral_classification": "...",
    "key_insights": { ... merged insights ... },
    "ai_reasoning": "brief reason for the update"
  }
}`;

    const result = await safeGeminiCall(prompt);
    if (!result.success || !result.data?.update_needed) return;

    const updates = result.data.updates || {};
    const safe = {};

    for (const key of ALLOWED_FIELDS) {
      if (updates[key] === undefined) continue;
      if (key === 'behavioral_classification' && !VALID_CLASSIFICATIONS.includes(updates[key])) continue;
      safe[key] = updates[key];
    }

    if (Object.keys(safe).length > 0) {
      await supabase.from('ai_financial_profiles').update(safe).eq('user_id', userId);
      console.log(`[ProfileUpdate] ${eventType} → updated: ${Object.keys(safe).join(', ')}`);
    }
  } catch (err) {
    console.error(`[ProfileUpdate] ${eventType} error:`, err.message);
  }
}

module.exports = { assessProfileUpdate };
