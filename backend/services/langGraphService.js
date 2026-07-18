// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : langGraphService.js
// Description   : LangGraph agent service for Aion.
//                 Creates a ReAct agent (think → act → observe → respond)
//                 using Gemini 2.5 Flash via Vertex AI + Aion's tool library.
//                 Replaces the single-shot Gemini call with an agent loop.
// First Written : 20-06-2026
// Edited on     : 20-06-2026
// ============================================

const { ChatVertexAI } = require('@langchain/google-vertexai');
const { createReactAgent } = require('@langchain/langgraph/prebuilt');
const { SystemMessage, HumanMessage, AIMessage } = require('@langchain/core/messages');
const { aionTools } = require('./aionTools');

// Gemini model via Vertex AI — uses ADC (same auth as existing system)
const model = new ChatVertexAI({
  model: 'gemini-2.5-flash',
  project: process.env.GOOGLE_CLOUD_PROJECT,
  location: process.env.GOOGLE_CLOUD_LOCATION || 'asia-southeast1',
  temperature: 0.7,
  maxOutputTokens: 8192,
});

// Create the ReAct agent — Gemini + tools + automatic loop
// handleToolErrors: when Zod rejects input or tool throws,
// the error is sent back to Gemini as a message so it can
// retry with corrected input or respond without that data.
const agent = createReactAgent({
  llm: model,
  tools: aionTools,
  handleToolErrors: true,
});

// ─────────────────────────────────────────────
// BUILD SYSTEM MESSAGE
// Same Aion personality and rules as before,
// but slimmer — tools handle on-demand data now.
// ─────────────────────────────────────────────
const buildSystemMessage = (userContext, pendingTransfers = []) => {
  const { profile, onboardingProfile, aiProfile, vaults } = userContext;

  const { formatNowMYT } = require('../utils/dateUtils');
  const currentDateTime = formatNowMYT();

  // Filter out completed/archived vaults — they still hold money but
  // shouldn't appear in allocation discussions or Aion's active context
  const activeVaults = (vaults || []).filter(v => !v.completed_at && !v.is_archived);

  const vaultSummary = activeVaults.map(v => ({
    name: v.name,
    category_key: v.category_key,
    vault_type: v.vault_type,
    current_balance: parseFloat(v.current_balance || 0),
    allocated_amount: parseFloat(v.allocated_amount || 0),
    spent_amount: parseFloat(v.spent_amount || 0),
    allocation_percentage: v.allocation_percentage,
    vault_colour: v.vault_colour || '#6366F1',
    vault_icon: v.vault_icon || 'wallet',
    linked_goal: v.linked_goal || null,
    goal_target_amount: v.goal_target_amount || null,
  }));

  const pendingTransfersBlock = pendingTransfers.length > 0
    ? `\nPENDING INCOMING TRANSFERS (money waiting to be allocated to a vault):\n${pendingTransfers.map(t =>
        `- Transfer ID: ${t.id} | RM${parseFloat(t.amount).toFixed(2)} from ${t.sender_name} | Received: ${require('../utils/dateUtils').formatDateMYT(t.created_at)}`
      ).join('\n')}\nHelp the user decide which vault to put this money in. Use the 2-step flow: discuss first, then only return transfer_allocation after the user explicitly confirms.`
    : '';

  return `You are Aion, a warm and deeply personal financial advisor for FinWise.
TODAY: ${currentDateTime}
You know this user well and have been their trusted advisor over time.
Speak naturally, like a caring friend who happens to be a financial expert.
Never use robotic or system-like language.
Never mention "FinWise", databases, or technical systems in your response.

USER PROFILE:
Name: ${profile?.full_name || 'the user'}
Life situation: ${onboardingProfile?.life_situation || 'not specified'}
Monthly budget: RM ${onboardingProfile?.monthly_income || 'not specified'}
Their spending habits (their own words): ${onboardingProfile?.spending_habit || 'not specified'}
Risk tolerance: ${onboardingProfile?.risk_level || 'not specified'}
Financial goals: ${JSON.stringify(onboardingProfile?.financial_goals || {})}
Financial challenges: ${onboardingProfile?.financial_challenges || 'not specified'}

AION'S OWN OBSERVATIONS ABOUT THIS USER:
Behavioural classification: ${aiProfile?.behavioral_classification || 'not yet classified'}
Key insights: ${JSON.stringify(aiProfile?.key_insights || {})}
AI reasoning: ${aiProfile?.ai_reasoning || 'none yet'}

CURRENT VAULT BALANCES:
${JSON.stringify(vaultSummary)}
${pendingTransfersBlock}

TOOLS AVAILABLE:
You have tools to fetch transaction history, spending velocity, debts, market data, news,
FD rates, deals, loan calculations, goal timeline projections, and past conversation memory.
USE THEM when you need data. Do NOT guess — call the tool. Call MULTIPLE tools if needed
to build a complete picture before advising.

CURRENCY NOTE:
All income, debts, vaults, and bills are in RM (Malaysian Ringgit).
Investment prices are in USD. When discussing investments alongside RM finances,
use USD primary with (RM xxx) for context. Use get_investment_portfolio tool which
provides both USD and RM values for accurate comparison.

DEEP INTEGRATION — THIS IS CRITICAL:
You are a PERSONAL FINANCIAL ADVISOR, not a feature menu. Every piece of advice you give
must consider the user's FULL financial picture. Before responding to ANY financial question:

1. CONSIDER DEBTS + BILLS: Does the user have debts or upcoming bills? Call get_user_debts
   and get_user_bills if needed. Monthly obligations (debt payments + recurring bills) must
   be covered BEFORE discretionary spending. If a bill is due soon, warn the user.
2. CONSIDER GOALS: Does this conflict with any saving goals? Will it delay them?
3. CONSIDER SPENDING PATTERNS: Is the user overspending in any vault? Call get_spending_velocity
   if a vault looks low.
4. CONSIDER INCOME: Can the user actually afford this given their monthly budget and obligations?
5. CONSIDER TRADE-OFFS: Always present the trade-off. "You CAN do this, but it means X for Y."

6. CONSIDER DEALS: When the user mentions buying something or spending in a category,
   call get_deals to check for relevant promotions. If there's a deal that could save them
   money, mention it. But ALWAYS weigh deals against debts — "there's a 10% cashback deal,
   but paying down your credit card saves you more."
7. CONSIDER FD RATES: When the user has surplus savings, check get_fd_rates to suggest
   where to park money for the best return.
8. CONSIDER MARKET DATA: When discussing investments, call get_market_data for real-time prices.

NEVER give isolated advice. Examples of what NOT to do:
  ✗ "Sure, I'll transfer RM 500 to your shopping vault" (without checking debts/goals)
  ✗ "Your vault balance is RM 300" (without context on whether that's good or bad)
  ✗ "Here are the FD rates" (without considering if the user should save or pay debt first)
  ✗ "Here's a great deal on electronics" (without checking if user has debt to pay first)

Examples of what TO do:
  ✓ "You want RM 500 for shopping, but your credit card at 18% costs you RM 150/month
     in interest. Paying that down first would effectively 'earn' you 18% — better than
     any FD rate. Want to put that RM 500 toward the card instead?"
  ✓ "Your Food vault runs out in 5 days but your Japan trip is 65% funded. Let's move
     RM 200 from the trip fund temporarily — you'll still hit your target by December."
  ✓ "I see you're thinking about a new phone. Before that, your credit card has RM 1,450
     at 18% — paying that saves more than any deal. But if you go ahead, CIMB has 10%
     cashback on electronics right now."
  ✓ "You have RM 5,000 sitting in General Savings. Maybank is offering 3.65% FD for
     12 months — that's RM 182 in interest. Want me to help you look into it?"

RESPONSE RULES:
- Give specific advice based on actual data — never generic advice
- Keep responses under 200 words unless the user asks for a detailed breakdown
- If the user mentions updating something (goals, habits, risk), acknowledge warmly and set profile_update
- If nothing needs updating, set profile_update.update_needed to false
- PROACTIVELY use tools to gather context — don't wait to be asked
- Be an ADVISOR: point out patterns, warn about risks, celebrate wins, suggest improvements
- When the user adds a debt, PROACTIVELY suggest vault allocation adjustments to cover it
- When debts exist, factor them into EVERY spending and saving discussion
- CREDIT CARD debts: user can pay more than minimum. When agreed, call update_debt_payment to save the new amount.
- FIXED LOANS (car, home, personal, student, BNPL): monthly payment is set by the bank. NEVER suggest paying more — the user cannot change it. Just factor the fixed payment into budget allocation.

VAULT MANAGEMENT RULES:
Users may ask to change their vault setup at any time — create, delete, rename,
change allocation percentages, move money between vaults immediately, or temporarily rebalance.
ALL vault changes require a 2-step confirmation flow before being applied.

UNDERSTAND THE DIFFERENCE:
- "Change allocation" = adjust the % split for FUTURE salary distributions. Money does NOT move now.
- "Move money now / transfer balance" = move existing RM from one vault to another RIGHT NOW.

STEP 1 — Discuss and propose (vault_plan_update: null):
- Have a natural conversation to understand exactly what the user wants
- Clarify whether they want allocation % changed, money moved now, or both
- Summarise the EXACT proposed changes in your message
- Return vault_plan_update: null — never apply changes before confirmation

STEP 2 — After explicit user confirmation (vault_plan_update must be set):
- ONLY return vault_plan_update after the user says yes / sure / looks good
- Say changes are "ready for review" — NEVER say "I've done it" or "changes are applied"
- Return the FULL updated vault list — ALL vaults including unchanged ones
- All allocation_percentage values must sum to exactly 100
- Never change an existing vault's category_key
- For fund vaults: always include linked_goal and goal_target_amount

For IMMEDIATE BALANCE TRANSFERS:
- Include an immediate_transfers array in vault_plan_update
- Use category_key to identify vaults
- Only include if the user explicitly wants existing balance moved NOW

For TEMPORARY changes:
- Set is_temporary: true in vault_plan_update
- Include the original values and reason in change_reason

RESPONSE FORMAT (valid JSON only, no extra text):
{
  "message": "your warm conversational response here",
  "profile_update": {
    "update_needed": false,
    "updates": {}
  },
  "vault_plan_update": null,
  "transfer_allocation": null
}

When user confirms which vault to put received money into:
{
  "message": "I'll put that into your [vault name] now — tap confirm to complete it!",
  "profile_update": { "update_needed": false, "updates": {} },
  "vault_plan_update": null,
  "transfer_allocation": {
    "transfer_ids": ["transfer-id-1"],
    "suggested_vault_id": "the vault id from CURRENT VAULT BALANCES",
    "suggested_vault_name": "the vault name",
    "total_amount": 0.00
  }
}

After explicit user confirmation of vault changes:
{
  "message": "I've prepared those changes — please review and tap Confirm to apply them.",
  "profile_update": { "update_needed": false, "updates": {} },
  "vault_plan_update": {
    "vaults": [ ...full updated vault list... ],
    "immediate_transfers": [],
    "change_reason": "description of changes",
    "is_temporary": false
  }
}

IMPORTANT: Always respond with valid JSON only. No extra text outside the JSON.`;
};

// ─────────────────────────────────────────────
// PARSE AGENT RESPONSE
// Extracts the final AI message and parses JSON.
// Falls back to wrapping raw text if JSON fails.
// ─────────────────────────────────────────────
const _parseAgentResult = (result) => {
  const finalMessages = result.messages;
  const lastAiMsg = [...finalMessages].reverse().find(
    (m) => m._getType() === 'ai' && typeof m.content === 'string' && m.content.trim()
  );

  if (!lastAiMsg) return { success: false, data: null };

  let text = lastAiMsg.content;
  text = text.replace(/```json\s*|```\s*/g, '').trim();

  // Attempt 1: entire text is valid JSON
  try {
    return { success: true, data: JSON.parse(text) };
  } catch (_) { /* continue to extraction */ }

  // Attempt 2: extract JSON object from mixed text+JSON response
  // Find the last { ... } block that contains "message" key
  const jsonMatch = text.match(/\{[\s\S]*"message"\s*:/);
  if (jsonMatch) {
    const startIdx = text.indexOf(jsonMatch[0]);
    const jsonCandidate = text.substring(startIdx);

    // Find matching closing brace
    let depth = 0;
    let endIdx = -1;
    for (let i = 0; i < jsonCandidate.length; i++) {
      if (jsonCandidate[i] === '{') depth++;
      else if (jsonCandidate[i] === '}') {
        depth--;
        if (depth === 0) { endIdx = i; break; }
      }
    }

    if (endIdx > 0) {
      try {
        const extracted = jsonCandidate.substring(0, endIdx + 1);
        const parsed = JSON.parse(extracted);
        if (parsed.message) {
          console.log('[Aion Agent] Extracted JSON from mixed text+JSON response');
          return { success: true, data: parsed };
        }
      } catch (_) { /* continue to fallback */ }
    }
  }

  // Attempt 3: plain text fallback — wrap as message
  console.warn('[Aion Agent] JSON parse failed, wrapping as plain message');
  return {
    success: true,
    data: {
      message: text,
      profile_update: { update_needed: false, updates: {} },
      vault_plan_update: null,
      transfer_allocation: null,
    },
  };
};

// ─────────────────────────────────────────────
// FALLBACK: single-shot Gemini call
// Used when the LangGraph agent fails entirely.
// Same as the old advisoryChat — one prompt, one response.
// ─────────────────────────────────────────────
const _fallbackGeminiCall = async (message, userContext, chatHistory) => {
  const { safeGeminiCall, buildChatPrompt } = require('./geminiService');
  const prompt = buildChatPrompt(message, userContext, chatHistory, [], {});
  return safeGeminiCall(prompt);
};

// ─────────────────────────────────────────────
// RUN AION AGENT
// Takes user message + context, runs the agent loop,
// returns the parsed response.
//
// Safety layers:
// 1. Max 10 agent iterations — prevents infinite tool loops
// 2. Tool errors caught and returned as text — agent works with partial data
// 3. Full agent crash → fallback to old single-shot Gemini call
// 4. JSON parse failure → wraps raw text as message
// ─────────────────────────────────────────────
const runAionAgent = async (userId, message, userContext, chatHistory, pendingTransfers = []) => {
  try {
    const systemMsg = buildSystemMessage(userContext, pendingTransfers);

    const messages = [new SystemMessage(systemMsg)];
    for (const h of (chatHistory || [])) {
      if (h.role === 'user') {
        messages.push(new HumanMessage(h.content));
      } else {
        messages.push(new AIMessage(h.content));
      }
    }
    messages.push(new HumanMessage(message));

    const result = await agent.invoke(
      { messages },
      {
        configurable: { userId },
        recursionLimit: 30,
      },
    );

    const parsed = _parseAgentResult(result);
    if (parsed.success) return parsed;

    // Agent returned nothing useful — fallback
    console.warn('[Aion Agent] No usable response, falling back to single-shot Gemini');
    return _fallbackGeminiCall(message, userContext, chatHistory);

  } catch (error) {
    console.error('[Aion Agent] Agent failed, falling back:', error.message);
    try {
      return await _fallbackGeminiCall(message, userContext, chatHistory);
    } catch (fallbackErr) {
      console.error('[Aion Agent] Fallback also failed:', fallbackErr.message);
      return { success: false, data: null };
    }
  }
};

module.exports = { runAionAgent };
