// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : supabaseService.js
// Description   : Supabase database service for FYP Neobanking.
//                 Centralises all database operations.
// First Written : 21-May-2026
// Edited on     : 21-May-2026
// ============================================

const supabase = require('../config/supabase');

// ── PROFILES ──────────────────────────────

// Get user profile by ID
const getProfile = async (userId) => {
    const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .single();

    if (error) throw error;
    return data;
};

// Update user profile
const updateProfile = async (userId, updates) => {
    const { data, error } = await supabase
        .from('profiles')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();

    if (error) throw error;
    return data;
};

// Check if onboarding is complete
const checkOnboardingComplete = async (userId) => {
    const { data, error } = await supabase
        .from('onboarding_profiles')
        .select('id')
        .eq('user_id', userId)
        .single();

    if (error && error.code === 'PGRST116') return false;
    if (error) throw error;
    return !!data;
};

// ── VAULTS ────────────────────────────────

// Get all active vaults for a user
const getUserVaults = async (userId) => {
    const { data, error } = await supabase
        .from('vaults')
        .select('*')
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('vault_type', { ascending: true });

    if (error) throw error;
    return data;
};

// ── TRANSACTIONS ──────────────────────────

// Get recent transactions for a user
const getRecentTransactions = async (userId, limit = 10) => {
    const { data, error } = await supabase
        .from('transactions')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(limit);

    if (error) throw error;
    return data;
};

// ── AI LOGS ───────────────────────────────

// Get recent chat messages for a user
const getRecentChatMessages = async (userId, limit = 20) => {
    const { data, error } = await supabase
        .from('ai_logs')
        .select('*')
        .eq('user_id', userId)
        .eq('interaction_type', 'chat')
        .order('created_at', { ascending: false })
        .limit(limit);

    if (error) throw error;
    return data.reverse();
};

module.exports = {
    getProfile,
    updateProfile,
    checkOnboardingComplete,
    getUserVaults,
    getRecentTransactions,
    getRecentChatMessages
};