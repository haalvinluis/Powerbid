import { randomBytes, scrypt, timingSafeEqual, createHash } from 'crypto';
import { DatabasePool } from './pg_pool';
import { ProfileManager } from './profile_manager';

export interface UserAccount {
  id: string;
  email: string;
  profileId: string;
  isGuest: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface AuthSession {
  id: string;
  accountId: string;
  tokenHash: string;
  expiresAt: string;
  isRevoked: boolean;
}

export class AuthManager {
  private static instance: AuthManager;
  private db: DatabasePool;

  // In-memory fallback stores for test isolation and offline development
  private memoryAccounts: Map<string, any> = new Map(); // id -> account
  private memoryEmailToId: Map<string, string> = new Map(); // email.toLowerCase() -> id
  private memorySessions: Map<string, AuthSession> = new Map(); // tokenHash -> session

  private constructor() {
    this.db = DatabasePool.getInstance();
  }

  public static getInstance(): AuthManager {
    if (!AuthManager.instance) {
      AuthManager.instance = new AuthManager();
    }
    return AuthManager.instance;
  }

  /**
   * Hashes a password using crypto.scrypt with a secure 16-byte random salt.
   */
  public async hashPassword(password: string): Promise<string> {
    return new Promise((resolve, reject) => {
      const salt = randomBytes(16).toString('hex');
      scrypt(password, salt, 64, { N: 16384, r: 8, p: 1 }, (err, derivedKey) => {
        if (err) return reject(err);
        resolve(`scrypt$16384$8$1$${salt}$${derivedKey.toString('hex')}`);
      });
    });
  }

  /**
   * Verifies a password against an scrypt hash in constant time.
   */
  public async verifyPassword(password: string, storedHash: string): Promise<boolean> {
    return new Promise((resolve) => {
      const parts = storedHash.split('$');
      if (parts.length !== 6 || parts[0] !== 'scrypt') {
        return resolve(false);
      }

      const N = parseInt(parts[1], 10);
      const r = parseInt(parts[2], 10);
      const p = parseInt(parts[3], 10);
      const salt = parts[4];
      const keyBuffer = Buffer.from(parts[5], 'hex');

      scrypt(password, salt, keyBuffer.length, { N, r, p }, (err, derivedKey) => {
        if (err) return resolve(false);
        try {
          resolve(timingSafeEqual(keyBuffer, derivedKey));
        } catch {
          resolve(false);
        }
      });
    });
  }

  /**
   * Hashes an auth token with SHA-256 before database storage.
   */
  public hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  /**
   * Creates an expiring session token (valid for 30 days).
   */
  public async createSession(accountId: string): Promise<{ token: string; expiresAt: string }> {
    const rawToken = 'pbt_' + randomBytes(32).toString('hex');
    const tokenHash = this.hashToken(rawToken);
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
    const sessionId = randomBytes(16).toString('hex');

    if (this.db.isDatabaseConnected) {
      await this.db.query(
        `INSERT INTO auth_sessions (id, account_id, token_hash, expires_at, is_revoked)
         VALUES ($1, $2, $3, $4, false)`,
        [sessionId, accountId, tokenHash, expiresAt]
      );
    } else {
      this.memorySessions.set(tokenHash, {
        id: sessionId,
        accountId,
        tokenHash,
        expiresAt,
        isRevoked: false,
      });
    }

    return { token: rawToken, expiresAt };
  }

  /**
   * Validates a session token, returning account and profile information if valid.
   */
  public async validateSession(
    token: string
  ): Promise<{ accountId: string; profileId: string; isGuest: boolean } | null> {
    if (!token || typeof token !== 'string') return null;
    const tokenHash = this.hashToken(token);

    if (this.db.isDatabaseConnected) {
      const res = await this.db.query(
        `SELECT s.id, s.account_id, s.expires_at, s.is_revoked, a.profile_id, a.is_guest
         FROM auth_sessions s
         JOIN user_accounts a ON s.account_id = a.id
         WHERE s.token_hash = $1`,
        [tokenHash]
      );

      if (res.rows.length === 0) return null;
      const row = res.rows[0];
      if (row.is_revoked) return null;
      if (new Date(row.expires_at).getTime() < Date.now()) return null;

      return {
        accountId: row.account_id,
        profileId: row.profile_id,
        isGuest: row.is_guest,
      };
    } else {
      const session = this.memorySessions.get(tokenHash);
      if (!session || session.isRevoked) return null;
      if (new Date(session.expiresAt).getTime() < Date.now()) return null;

      const account = this.memoryAccounts.get(session.accountId);
      if (!account) return null;

      return {
        accountId: account.id,
        profileId: account.profileId,
        isGuest: account.isGuest,
      };
    }
  }

  /**
   * Revokes an active session token (Logout).
   */
  public async revokeSession(token: string): Promise<boolean> {
    if (!token) return false;
    const tokenHash = this.hashToken(token);

    if (this.db.isDatabaseConnected) {
      const res = await this.db.query(
        `UPDATE auth_sessions SET is_revoked = true WHERE token_hash = $1`,
        [tokenHash]
      );
      return (res.rowCount ?? 0) > 0;
    } else {
      const session = this.memorySessions.get(tokenHash);
      if (session) {
        session.isRevoked = true;
        return true;
      }
      return false;
    }
  }

  /**
   * Registers a new persistent email/password account.
   */
  public async registerAccount(
    email: string,
    password: string,
    requestedUsername?: string
  ): Promise<{ account: UserAccount; profile: any; token: string }> {
    const cleanEmail = email.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(cleanEmail)) {
      throw new Error('Please provide a valid email address.');
    }

    if (!password || password.length < 8) {
      throw new Error('Password must be at least 8 characters long.');
    }

    if (!/[A-Za-z]/.test(password) || !/[0-9]/.test(password)) {
      throw new Error('Password must contain both letters and numbers.');
    }

    // Check email uniqueness
    if (this.db.isDatabaseConnected) {
      const existing = await this.db.query('SELECT id FROM user_accounts WHERE LOWER(email) = $1', [cleanEmail]);
      if (existing.rows.length > 0) {
        throw new Error('An account with this email already exists.');
      }
    } else {
      if (this.memoryEmailToId.has(cleanEmail)) {
        throw new Error('An account with this email already exists.');
      }
    }

    const accountId = 'acc_' + randomBytes(16).toString('hex');
    const profileId = 'usr_' + randomBytes(16).toString('hex');
    const passwordHash = await this.hashPassword(password);

    // Create profile
    const profile = ProfileManager.getInstance().getOrCreateProfile(profileId, requestedUsername);

    const now = new Date().toISOString();
    const account: UserAccount = {
      id: accountId,
      email: cleanEmail,
      profileId,
      isGuest: false,
      createdAt: now,
      updatedAt: now,
    };

    if (this.db.isDatabaseConnected) {
      await this.db.withTransaction(async (client) => {
        await client.query(
          `INSERT INTO player_profiles (id, public_player_id, username, avatar_text, coin_balance, created_at)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (id) DO NOTHING`,
          [profile.id, profile.publicPlayerId, profile.username, profile.avatarText, profile.coinBalance || 500, now]
        );

        await client.query(
          `INSERT INTO user_accounts (id, email, password_hash, profile_id, is_guest, created_at, updated_at)
           VALUES ($1, $2, $3, $4, false, $5, $5)`,
          [accountId, cleanEmail, passwordHash, profileId, now]
        );
      });
    } else {
      this.memoryAccounts.set(accountId, { ...account, passwordHash });
      this.memoryEmailToId.set(cleanEmail, accountId);
    }

    const { token } = await this.createSession(accountId);
    return { account, profile, token };
  }

  /**
   * Logs into an existing account with email and password.
   */
  public async loginAccount(
    email: string,
    password: string
  ): Promise<{ account: UserAccount; profile: any; token: string }> {
    const cleanEmail = email.trim().toLowerCase();

    let accountRecord: any = null;

    if (this.db.isDatabaseConnected) {
      const res = await this.db.query(
        `SELECT id, email, password_hash, profile_id, is_guest, created_at, updated_at
         FROM user_accounts WHERE LOWER(email) = $1`,
        [cleanEmail]
      );
      if (res.rows.length > 0) accountRecord = res.rows[0];
    } else {
      const accId = this.memoryEmailToId.get(cleanEmail);
      if (accId) accountRecord = this.memoryAccounts.get(accId);
    }

    if (!accountRecord || !accountRecord.password_hash) {
      throw new Error('Invalid email or password.');
    }

    const isValid = await this.verifyPassword(password, accountRecord.password_hash);
    if (!isValid) {
      throw new Error('Invalid email or password.');
    }

    if (this.db.isDatabaseConnected) {
      const profileRes = await this.db.query(
        `SELECT id, public_player_id, username, avatar_text, coin_balance, matches_played, matches_won, matches_tied, total_characters_purchased
         FROM player_profiles WHERE id = $1`,
        [accountRecord.profile_id]
      );
      if (profileRes.rows.length > 0) {
        const pRow = profileRes.rows[0];
        const memProfile = ProfileManager.getInstance().getOrCreateProfile(pRow.id, pRow.username);
        memProfile.publicPlayerId = pRow.public_player_id;
        memProfile.avatarText = pRow.avatar_text || 'PB';
        memProfile.coinBalance = pRow.coin_balance ?? 500;
        memProfile.matchesPlayed = pRow.matches_played || 0;
        memProfile.matchesWon = pRow.matches_won || 0;
        memProfile.matchesTied = pRow.matches_tied || 0;
        memProfile.totalCharactersPurchased = pRow.total_characters_purchased || 0;
      }
    }

    const profile = ProfileManager.getInstance().getProfileDTO(accountRecord.profile_id);
    const { token } = await this.createSession(accountRecord.id);

    const account: UserAccount = {
      id: accountRecord.id,
      email: accountRecord.email,
      profileId: accountRecord.profile_id,
      isGuest: accountRecord.is_guest,
      createdAt: accountRecord.created_at,
      updatedAt: accountRecord.updated_at,
    };

    return { account, profile, token };
  }

  /**
   * Links an existing guest profile to an email and password account.
   * Atomically preserves all friendships, match history, and coin balance.
   */
  public async linkGuestAccount(
    guestProfileId: string,
    email: string,
    password: string
  ): Promise<{ account: UserAccount; profile: any; token: string }> {
    const cleanEmail = email.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(cleanEmail)) {
      throw new Error('Please provide a valid email address.');
    }

    if (!password || password.length < 8) {
      throw new Error('Password must be at least 8 characters long.');
    }

    const profile = ProfileManager.getInstance().getProfileDTO(guestProfileId);
    if (!profile) {
      throw new Error('Guest profile not found to link.');
    }

    // Check if email already registered
    if (this.db.isDatabaseConnected) {
      const existing = await this.db.query('SELECT id FROM user_accounts WHERE LOWER(email) = $1', [cleanEmail]);
      if (existing.rows.length > 0) {
        throw new Error('An account with this email already exists.');
      }
    } else {
      if (this.memoryEmailToId.has(cleanEmail)) {
        throw new Error('An account with this email already exists.');
      }
    }

    const accountId = 'acc_' + randomBytes(16).toString('hex');
    const passwordHash = await this.hashPassword(password);
    const now = new Date().toISOString();

    const account: UserAccount = {
      id: accountId,
      email: cleanEmail,
      profileId: guestProfileId,
      isGuest: false,
      createdAt: now,
      updatedAt: now,
    };

    if (this.db.isDatabaseConnected) {
      await this.db.withTransaction(async (client) => {
        await client.query(
          `INSERT INTO player_profiles (id, public_player_id, username, avatar_text, coin_balance, created_at)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (id) DO UPDATE SET coin_balance = $5`,
          [profile.id, profile.publicPlayerId, profile.username, profile.avatarText, profile.coinBalance || 500, now]
        );

        await client.query(
          `INSERT INTO user_accounts (id, email, password_hash, profile_id, is_guest, created_at, updated_at)
           VALUES ($1, $2, $3, $4, false, $5, $5)`,
          [accountId, cleanEmail, passwordHash, guestProfileId, now]
        );
      });
    } else {
      this.memoryAccounts.set(accountId, { ...account, passwordHash });
      this.memoryEmailToId.set(cleanEmail, accountId);
    }

    const { token } = await this.createSession(accountId);
    return { account, profile, token };
  }

  /**
   * Resets memory stores (for automated test isolation).
   */
  public clearAllData(): void {
    this.memoryAccounts.clear();
    this.memoryEmailToId.clear();
    this.memorySessions.clear();
  }
}
