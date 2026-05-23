// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : index.js
// Description   : Global constants for FYP Neobanking backend.
//                 Centralises all enum values and status codes.
// First Written : 21-May-2026
// Edited on     : 21-May-2026
// ============================================

const TRANSACTION_STATUS = {
    APPROVED: 'approved',
    BLOCKED: 'blocked',
    CANCELLED: 'cancelled'
};

const TRANSACTION_TYPE = {
    EXPENSE: 'expense',
    INCOME: 'income',
    TRANSFER: 'transfer'
};

const VAULT_TYPE = {
    VAULT: 'vault',
    FUND: 'fund'
};

const TRANSFER_TYPE = {
    ACTIVE_PILOT: 'active_pilot',
    USER_REQUESTED: 'user_requested',
    AI_SUGGESTED: 'ai_suggested'
};

const BEHAVIORAL_CLASSIFICATION = {
    DISCIPLINED_SAVER: 'disciplined_saver',
    BALANCED_SPENDER: 'balanced_spender',
    IMPULSE_SPENDER: 'impulse_spender',
    RISK_AVERSE: 'risk_averse',
    HIGH_VARIABILITY_SPENDER: 'high_variability_spender',
    GOAL_ORIENTED_SPENDER: 'goal_oriented_spender'
};

const AI_INTERACTION_TYPE = {
    CHAT: 'chat',
    GOAL_GUARDIAN: 'goal_guardian',
    BACKGROUND_ANALYSIS: 'background_analysis',
    PROACTIVE: 'proactive',
    SYSTEM_NOTIFICATION: 'system_notification'
};

const VALIDATION_STATUS = {
    PASSED: 'passed',
    SCHEMA_FAILED: 'schema_failed',
    BUSINESS_LOGIC_FAILED: 'business_logic_failed',
    FALLBACK_USED: 'fallback_used'
};

const ALLOCATION_TRIGGER = {
    ONBOARDING: 'onboarding',
    BEHAVIOUR_CHANGE: 'behaviour_change',
    GOAL_CHANGE: 'goal_change',
    INCOME_CHANGE: 'income_change',
    CONVERSATION: 'conversation'
};

const MAX_AI_CATEGORISATION_ATTEMPTS = 2;
const CHAT_HISTORY_LIMIT = 20;
const TRANSACTION_CONTEXT_LIMIT = 10;

module.exports = {
    TRANSACTION_STATUS,
    TRANSACTION_TYPE,
    VAULT_TYPE,
    TRANSFER_TYPE,
    BEHAVIORAL_CLASSIFICATION,
    AI_INTERACTION_TYPE,
    VALIDATION_STATUS,
    ALLOCATION_TRIGGER,
    MAX_AI_CATEGORISATION_ATTEMPTS,
    CHAT_HISTORY_LIMIT,
    TRANSACTION_CONTEXT_LIMIT
};