-- ============================================
-- FYP Neobanking System — Complete Database Schema
-- Author: Lau Zheng Cheng (TP071393)
-- Created: 2026
-- ============================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- FUNCTION: Auto-update updated_at timestamp
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- TABLE 1: profiles
-- Purpose: User identity linked to Supabase auth
-- ============================================
CREATE TABLE profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    full_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trigger_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- TABLE 2: onboarding_profiles
-- Purpose: User-declared financial facts
-- AI update rules:
--   Silent: financial_goals, life_situation, financial_challenges
--   Confirm first: monthly_income, risk_level, spending_habit
-- ============================================
CREATE TABLE onboarding_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
    monthly_income NUMERIC NOT NULL CHECK (monthly_income > 0),
    financial_goals JSONB NOT NULL DEFAULT '{"goals": []}',
    spending_habit TEXT NOT NULL,
    risk_level TEXT NOT NULL,
    life_situation TEXT NOT NULL,
    financial_challenges TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trigger_onboarding_profiles_updated_at
    BEFORE UPDATE ON onboarding_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- TABLE 3: ai_financial_profiles
-- Purpose: AI-concluded intelligence about user
-- Owned entirely by AI — updated through backend validator
-- ============================================
CREATE TABLE ai_financial_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
    behavioral_classification TEXT CHECK (
        behavioral_classification IN (
            'disciplined_saver',
            'balanced_spender',
            'impulse_spender',
            'risk_averse',
            'high_variability_spender',
            'goal_oriented_spender'
        )
    ),
    recommended_allocation JSONB,
    ai_reasoning TEXT,
    key_insights JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trigger_ai_financial_profiles_updated_at
    BEFORE UPDATE ON ai_financial_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- TABLE 4: vaults
-- Purpose: Personalised spending vaults and saving funds
-- vault_type = 'vault' → spending category
-- vault_type = 'fund'  → saving goal
-- ============================================
CREATE TABLE vaults (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category_key TEXT NOT NULL,
    vault_type TEXT NOT NULL CHECK (vault_type IN ('vault', 'fund')),
    allocation_percentage NUMERIC NOT NULL CHECK (
        allocation_percentage >= 0 AND allocation_percentage <= 100
    ),
    allocated_amount NUMERIC NOT NULL DEFAULT 0 CHECK (allocated_amount >= 0),
    current_balance NUMERIC NOT NULL DEFAULT 0 CHECK (current_balance >= 0),
    spent_amount NUMERIC NOT NULL DEFAULT 0 CHECK (spent_amount >= 0),
    vault_colour TEXT,
    vault_icon TEXT,
    linked_goal TEXT,
    goal_target_amount NUMERIC CHECK (goal_target_amount >= 0),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Each user cannot have two vaults with same category_key
    UNIQUE (user_id, category_key),

    -- Funds must have linked_goal and goal_target_amount
    CONSTRAINT fund_requires_goal CHECK (
        vault_type != 'fund' OR (
            linked_goal IS NOT NULL AND
            goal_target_amount IS NOT NULL
        )
    ),

    -- Spending vaults must NOT have goal fields
    CONSTRAINT vault_no_goal CHECK (
        vault_type != 'vault' OR (
            linked_goal IS NULL AND
            goal_target_amount IS NULL
        )
    )
);

CREATE TRIGGER trigger_vaults_updated_at
    BEFORE UPDATE ON vaults
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- TABLE 5: vault_transfers
-- Purpose: All money movements between vaults
-- transfer_type:
--   active_pilot   → emergency reallocation during blocked transaction
--   user_requested → user asked AI to move money
--   ai_suggested   → AI proactively suggested transfer
-- ============================================
CREATE TABLE vault_transfers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    from_vault_id UUID NOT NULL REFERENCES vaults(id) ON DELETE CASCADE,
    to_vault_id UUID NOT NULL REFERENCES vaults(id) ON DELETE CASCADE,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    transfer_type TEXT NOT NULL CHECK (
        transfer_type IN (
            'active_pilot',
            'user_requested',
            'ai_suggested'
        )
    ),
    reason TEXT,
    triggered_by_transaction_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT different_vaults CHECK (from_vault_id != to_vault_id)
);

-- ============================================
-- TABLE 6: merchant_qr_codes
-- Purpose: Simulated merchant QR database
-- qr_type = 'merchant'        → spending transaction
-- qr_type = 'salary_deposit'  → income injection
-- ============================================
CREATE TABLE merchant_qr_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    merchant_name TEXT NOT NULL,
    merchant_id TEXT NOT NULL UNIQUE,
    default_amount NUMERIC CHECK (default_amount >= 0),
    qr_payload TEXT NOT NULL UNIQUE,
    qr_type TEXT NOT NULL CHECK (
        qr_type IN ('merchant', 'salary_deposit')
    ),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================
-- TABLE 7: transactions
-- Purpose: Every transaction attempt with full AI data
-- status:
--   approved  → transaction completed
--   blocked   → vault insufficient — Active Pilot fired
--   cancelled → user cancelled after Goal Guardian warning
-- ============================================
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    vault_id UUID REFERENCES vaults(id) ON DELETE SET NULL,
    merchant_qr_id UUID REFERENCES merchant_qr_codes(id) ON DELETE SET NULL,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    merchant_name TEXT,
    merchant_category TEXT,
    transaction_type TEXT NOT NULL CHECK (
        transaction_type IN ('expense', 'income', 'transfer')
    ),
    status TEXT NOT NULL CHECK (
        status IN ('approved', 'blocked', 'cancelled')
    ),
    block_reason TEXT,
    goal_conflict_detected BOOLEAN NOT NULL DEFAULT false,
    goal_guardian_message TEXT,
    user_overrode_guardian BOOLEAN NOT NULL DEFAULT false,
    ai_categorisation_attempts INTEGER NOT NULL DEFAULT 0,
    ai_categorisation_failed BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add foreign key from vault_transfers to transactions
ALTER TABLE vault_transfers
    ADD CONSTRAINT fk_triggered_by_transaction
    FOREIGN KEY (triggered_by_transaction_id)
    REFERENCES transactions(id)
    ON DELETE SET NULL;

-- ============================================
-- TABLE 8: income_injections
-- Purpose: Salary deposit records with full allocation snapshot
-- ============================================
CREATE TABLE income_injections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    allocation_snapshot JSONB NOT NULL,
    carryover_snapshot JSONB,
    injection_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes TEXT
);

-- ============================================
-- TABLE 9: ai_logs
-- Purpose: All AI interactions with validation tracking
-- interaction_type:
--   chat                → user-initiated conversation
--   goal_guardian       → transaction AI analysis
--   background_analysis → periodic profile update
--   proactive           → AI-initiated advisor message
--   system_notification → system failure or status update
-- ============================================
CREATE TABLE ai_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    interaction_type TEXT NOT NULL CHECK (
        interaction_type IN (
            'chat',
            'goal_guardian',
            'background_analysis',
            'proactive',
            'system_notification'
        )
    ),
    user_message TEXT,
    ai_response JSONB,
    raw_ai_response JSONB,
    context_snapshot JSONB,
    transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
    validation_status TEXT CHECK (
        validation_status IN (
            'passed',
            'schema_failed',
            'business_logic_failed',
            'fallback_used'
        )
    ),
    is_proactive BOOLEAN NOT NULL DEFAULT false,
    notification_sent BOOLEAN NOT NULL DEFAULT false,
    notification_read BOOLEAN NOT NULL DEFAULT false,
    tokens_used INTEGER,
    response_time_ms INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================
-- TABLE 10: allocation_history
-- Purpose: Timeline of all AI recommendation changes
-- Append-only — never updated or deleted
-- ============================================
CREATE TABLE allocation_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    previous_allocation JSONB,
    new_allocation JSONB NOT NULL,
    change_reason TEXT,
    triggered_by TEXT CHECK (
        triggered_by IN (
            'onboarding',
            'behaviour_change',
            'goal_change',
            'income_change',
            'conversation'
        )
    ),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================
-- ROW LEVEL SECURITY POLICIES
-- Ensures users can only access their own data
-- ============================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE onboarding_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_financial_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE vaults ENABLE ROW LEVEL SECURITY;
ALTER TABLE vault_transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE income_injections ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE allocation_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE merchant_qr_codes ENABLE ROW LEVEL SECURITY;

-- profiles
CREATE POLICY "Users can view own profile"
    ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE USING (auth.uid() = id);

-- onboarding_profiles
CREATE POLICY "Users can view own onboarding profile"
    ON onboarding_profiles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own onboarding profile"
    ON onboarding_profiles FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own onboarding profile"
    ON onboarding_profiles FOR UPDATE USING (auth.uid() = user_id);

-- ai_financial_profiles
CREATE POLICY "Users can view own ai profile"
    ON ai_financial_profiles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own ai profile"
    ON ai_financial_profiles FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own ai profile"
    ON ai_financial_profiles FOR UPDATE USING (auth.uid() = user_id);

-- vaults
CREATE POLICY "Users can view own vaults"
    ON vaults FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own vaults"
    ON vaults FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own vaults"
    ON vaults FOR UPDATE USING (auth.uid() = user_id);

-- vault_transfers
CREATE POLICY "Users can view own vault transfers"
    ON vault_transfers FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own vault transfers"
    ON vault_transfers FOR INSERT WITH CHECK (auth.uid() = user_id);

-- transactions
CREATE POLICY "Users can view own transactions"
    ON transactions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own transactions"
    ON transactions FOR INSERT WITH CHECK (auth.uid() = user_id);

-- income_injections
CREATE POLICY "Users can view own income injections"
    ON income_injections FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own income injections"
    ON income_injections FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ai_logs
CREATE POLICY "Users can view own ai logs"
    ON ai_logs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own ai logs"
    ON ai_logs FOR INSERT WITH CHECK (auth.uid() = user_id);

-- allocation_history
CREATE POLICY "Users can view own allocation history"
    ON allocation_history FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own allocation history"
    ON allocation_history FOR INSERT WITH CHECK (auth.uid() = user_id);

-- merchant_qr_codes — public read
CREATE POLICY "Anyone can view merchant qr codes"
    ON merchant_qr_codes FOR SELECT USING (true);

-- ============================================
-- AUTH TRIGGER
-- Auto-creates profiles row when user registers
-- ============================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, email, full_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', '')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

-- ============================================
-- SEED DATA: Merchant QR Codes
-- 20 simulated merchants + 1 salary deposit QR
-- ============================================
INSERT INTO merchant_qr_codes
    (merchant_name, merchant_id, default_amount, qr_payload, qr_type)
VALUES
    ('McDonald''s Sunway Pyramid', 'SIM-MCF-001', 15.90,
    '{"merchant_name":"McDonald''s Sunway Pyramid","merchant_id":"SIM-MCF-001","default_amount":15.90}',
    'merchant'),
    ('KFC IOI City Mall', 'SIM-KFC-001', 18.50,
    '{"merchant_name":"KFC IOI City Mall","merchant_id":"SIM-KFC-001","default_amount":18.50}',
    'merchant'),
    ('Tealive Mid Valley', 'SIM-TEA-001', 9.90,
    '{"merchant_name":"Tealive Mid Valley","merchant_id":"SIM-TEA-001","default_amount":9.90}',
    'merchant'),
    ('GrabFood Delivery', 'SIM-GRF-001', 35.00,
    '{"merchant_name":"GrabFood Delivery","merchant_id":"SIM-GRF-001","default_amount":35.00}',
    'merchant'),
    ('Village Grocer Bangsar', 'SIM-VGR-001', 85.00,
    '{"merchant_name":"Village Grocer Bangsar","merchant_id":"SIM-VGR-001","default_amount":85.00}',
    'merchant'),
    ('Shell Petrol Station PJ', 'SIM-SHL-001', 80.00,
    '{"merchant_name":"Shell Petrol Station PJ","merchant_id":"SIM-SHL-001","default_amount":80.00}',
    'merchant'),
    ('Grab Transport', 'SIM-GRB-001', 18.00,
    '{"merchant_name":"Grab Transport","merchant_id":"SIM-GRB-001","default_amount":18.00}',
    'merchant'),
    ('Touch n Go Reload', 'SIM-TNG-001', 50.00,
    '{"merchant_name":"Touch n Go Reload","merchant_id":"SIM-TNG-001","default_amount":50.00}',
    'merchant'),
    ('TGV Cinemas 1 Utama', 'SIM-TGV-001', 25.00,
    '{"merchant_name":"TGV Cinemas 1 Utama","merchant_id":"SIM-TGV-001","default_amount":25.00}',
    'merchant'),
    ('Steam Online Gaming', 'SIM-STM-001', 60.00,
    '{"merchant_name":"Steam Online Gaming","merchant_id":"SIM-STM-001","default_amount":60.00}',
    'merchant'),
    ('Spotify Premium', 'SIM-SPT-001', 17.90,
    '{"merchant_name":"Spotify Premium","merchant_id":"SIM-SPT-001","default_amount":17.90}',
    'merchant'),
    ('H&M Pavilion KL', 'SIM-HNM-001', 120.00,
    '{"merchant_name":"H&M Pavilion KL","merchant_id":"SIM-HNM-001","default_amount":120.00}',
    'merchant'),
    ('Uniqlo Suria KLCC', 'SIM-UNQ-001', 150.00,
    '{"merchant_name":"Uniqlo Suria KLCC","merchant_id":"SIM-UNQ-001","default_amount":150.00}',
    'merchant'),
    ('Caring Pharmacy SS2', 'SIM-CAR-001', 45.00,
    '{"merchant_name":"Caring Pharmacy SS2","merchant_id":"SIM-CAR-001","default_amount":45.00}',
    'merchant'),
    ('Fitness First Monthly', 'SIM-FIT-001', 180.00,
    '{"merchant_name":"Fitness First Monthly","merchant_id":"SIM-FIT-001","default_amount":180.00}',
    'merchant'),
    ('Popular Bookstore', 'SIM-POP-001', 55.00,
    '{"merchant_name":"Popular Bookstore","merchant_id":"SIM-POP-001","default_amount":55.00}',
    'merchant'),
    ('Udemy Online Course', 'SIM-UDM-001', 89.00,
    '{"merchant_name":"Udemy Online Course","merchant_id":"SIM-UDM-001","default_amount":89.00}',
    'merchant'),
    ('Yamaha Motor Showroom PJ', 'SIM-YMH-001', 800.00,
    '{"merchant_name":"Yamaha Motor Showroom PJ","merchant_id":"SIM-YMH-001","default_amount":800.00}',
    'merchant'),
    ('Harvey Norman Electronics', 'SIM-HVN-001', 2500.00,
    '{"merchant_name":"Harvey Norman Electronics","merchant_id":"SIM-HVN-001","default_amount":2500.00}',
    'merchant'),
    ('Simulated Employer Sdn Bhd', 'SIM-SAL-001', NULL,
    '{"merchant_name":"Simulated Employer Sdn Bhd","merchant_id":"SIM-SAL-001","qr_type":"salary_deposit"}',
    'salary_deposit');