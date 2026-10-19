-- ====================================================================
-- PowerBid Migration: 001_friends_and_invitations.sql
-- Description: Adds Player Profiles with permanent public Player IDs,
-- friendships, friend requests, room invitations, and in-app notifications.
-- ====================================================================

-- 1. Player Profiles Table
CREATE TABLE IF NOT EXISTS player_profiles (
    id VARCHAR(64) PRIMARY KEY,
    public_player_id VARCHAR(16) NOT NULL UNIQUE,
    username VARCHAR(32) NOT NULL UNIQUE,
    avatar_text VARCHAR(8) NOT NULL DEFAULT '⚡',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    matches_played INT NOT NULL DEFAULT 0,
    matches_won INT NOT NULL DEFAULT 0,
    matches_tied INT NOT NULL DEFAULT 0,
    total_characters_purchased INT NOT NULL DEFAULT 0,
    total_team_points INT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_player_profiles_public_id ON player_profiles (public_player_id);
CREATE INDEX IF NOT EXISTS idx_player_profiles_username_lower ON player_profiles (LOWER(username));

-- 2. Friendships Table (Enforces single bidirectional row where user_a_id < user_b_id)
CREATE TABLE IF NOT EXISTS friendships (
    user_a_id VARCHAR(64) NOT NULL REFERENCES player_profiles(id) ON DELETE CASCADE,
    user_b_id VARCHAR(64) NOT NULL REFERENCES player_profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_a_id, user_b_id),
    CONSTRAINT chk_friendship_ordering CHECK (user_a_id < user_b_id)
);

CREATE INDEX IF NOT EXISTS idx_friendships_user_a ON friendships (user_a_id);
CREATE INDEX IF NOT EXISTS idx_friendships_user_b ON friendships (user_b_id);

-- 3. Friend Requests Table
CREATE TABLE IF NOT EXISTS friend_requests (
    request_id UUID PRIMARY KEY,
    sender_id VARCHAR(64) NOT NULL REFERENCES player_profiles(id) ON DELETE CASCADE,
    receiver_id VARCHAR(64) NOT NULL REFERENCES player_profiles(id) ON DELETE CASCADE,
    status VARCHAR(16) NOT NULL CHECK (status IN ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_no_self_requests CHECK (sender_id != receiver_id)
);

-- Partial unique index ensuring at most one active pending request in either direction
CREATE UNIQUE INDEX IF NOT EXISTS uq_pending_friend_request
ON friend_requests (sender_id, receiver_id)
WHERE status = 'PENDING';

CREATE INDEX IF NOT EXISTS idx_friend_requests_receiver_status ON friend_requests (receiver_id, status);
CREATE INDEX IF NOT EXISTS idx_friend_requests_sender_status ON friend_requests (sender_id, status);

-- 4. Room Invitations Table
CREATE TABLE IF NOT EXISTS room_invitations (
    invitation_id UUID PRIMARY KEY,
    room_code VARCHAR(16) NOT NULL,
    token_hash VARCHAR(64) NOT NULL UNIQUE, -- SHA-256 hash of unguessable random token
    host_id VARCHAR(64) NOT NULL REFERENCES player_profiles(id) ON DELETE CASCADE,
    target_player_id VARCHAR(64) REFERENCES player_profiles(id) ON DELETE SET NULL,
    status VARCHAR(16) NOT NULL CHECK (status IN ('PENDING', 'ACCEPTED', 'DECLINED', 'EXPIRED', 'REVOKED', 'JOINED')),
    invite_type VARCHAR(20) NOT NULL CHECK (invite_type IN ('DIRECT_FRIEND', 'SHAREABLE_LINK')),
    max_uses INT NOT NULL DEFAULT 8,
    used_count INT NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_uses_valid CHECK (used_count <= max_uses)
);

CREATE INDEX IF NOT EXISTS idx_room_invitations_token_hash ON room_invitations (token_hash);
CREATE INDEX IF NOT EXISTS idx_room_invitations_room_code ON room_invitations (room_code);
CREATE INDEX IF NOT EXISTS idx_room_invitations_target_player ON room_invitations (target_player_id, status);

-- 5. In-App Notifications Table
CREATE TABLE IF NOT EXISTS in_app_notifications (
    id UUID PRIMARY KEY,
    recipient_id VARCHAR(64) NOT NULL REFERENCES player_profiles(id) ON DELETE CASCADE,
    notification_type VARCHAR(32) NOT NULL CHECK (notification_type IN ('FRIEND_REQUEST', 'FRIEND_ACCEPTED', 'ROOM_INVITE')),
    title VARCHAR(128) NOT NULL,
    message VARCHAR(512) NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_in_app_notifications_recipient ON in_app_notifications (recipient_id, is_read, created_at DESC);
