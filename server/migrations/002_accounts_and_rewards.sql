-- ====================================================================
-- PowerBid Migration: 002_accounts_and_rewards.sql
-- Description: Adds persistent registered user accounts, expiring auth sessions,
-- coin wallet ledger with idempotent constraints, and completed matches tables.
-- ====================================================================

-- 1. Alter Player Profiles to include persistent virtual coin balance
ALTER TABLE player_profiles 
ADD COLUMN IF NOT EXISTS coin_balance INT NOT NULL DEFAULT 500;

-- 2. User Accounts Table (Supports both registered email accounts and guest accounts)
CREATE TABLE IF NOT EXISTS user_accounts (
    id VARCHAR(64) PRIMARY KEY,
    email VARCHAR(255) UNIQUE,
    password_hash VARCHAR(255),
    profile_id VARCHAR(64) NOT NULL UNIQUE REFERENCES player_profiles(id) ON DELETE CASCADE,
    is_guest BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_accounts_email ON user_accounts (LOWER(email));
CREATE INDEX IF NOT EXISTS idx_user_accounts_profile_id ON user_accounts (profile_id);

-- 3. Expiring Auth Sessions Table (Revocable SHA-256 hashed tokens)
CREATE TABLE IF NOT EXISTS auth_sessions (
    id VARCHAR(64) PRIMARY KEY,
    account_id VARCHAR(64) NOT NULL REFERENCES user_accounts(id) ON DELETE CASCADE,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    is_revoked BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auth_sessions_token_hash ON auth_sessions (token_hash);
CREATE INDEX IF NOT EXISTS idx_auth_sessions_account_id ON auth_sessions (account_id);

-- 4. Completed Matches Table
CREATE TABLE IF NOT EXISTS completed_matches (
    match_id VARCHAR(64) PRIMARY KEY,
    category VARCHAR(32) NOT NULL,
    game_mode VARCHAR(32) NOT NULL,
    item_count INT NOT NULL,
    winner_id VARCHAR(64) NOT NULL,
    winner_name VARCHAR(64) NOT NULL,
    is_tie BOOLEAN NOT NULL DEFAULT false,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_completed_matches_completed_at ON completed_matches (completed_at DESC);

-- 5. Match Participants Table (Stores server-side scores securely)
CREATE TABLE IF NOT EXISTS match_participants (
    id VARCHAR(64) PRIMARY KEY,
    match_id VARCHAR(64) NOT NULL REFERENCES completed_matches(match_id) ON DELETE CASCADE,
    player_id VARCHAR(64) NOT NULL REFERENCES player_profiles(id) ON DELETE CASCADE,
    username VARCHAR(64) NOT NULL,
    rank INT NOT NULL,
    items_won INT NOT NULL DEFAULT 0,
    total_team_points INT NOT NULL DEFAULT 0, -- Stored securely on server; never leaked to clients
    remaining_budget INT NOT NULL DEFAULT 0,
    coins_awarded INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_match_participants_player_id ON match_participants (player_id);
CREATE INDEX IF NOT EXISTS idx_match_participants_match_id ON match_participants (match_id);

-- 6. Coin Transactions Ledger (Idempotent coin credits and debits)
CREATE TABLE IF NOT EXISTS coin_transactions (
    id VARCHAR(64) PRIMARY KEY,
    player_id VARCHAR(64) NOT NULL REFERENCES player_profiles(id) ON DELETE CASCADE,
    amount INT NOT NULL,
    balance_after INT NOT NULL,
    reason VARCHAR(64) NOT NULL,
    reference_id VARCHAR(64),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_coin_tx_idempotent UNIQUE (player_id, reference_id, reason)
);

CREATE INDEX IF NOT EXISTS idx_coin_transactions_player ON coin_transactions (player_id, created_at DESC);
