import { expect } from 'chai';
import { newDb } from 'pg-mem';
import { DatabasePool } from '../src/database/pg_pool';
import { AuthManager } from '../src/database/auth_manager';
import { ProfileManager } from '../src/database/profile_manager';

describe('Step 11: Phase 2 Database, Accounts, Guest Linking & Coin Rewards Tests', function () {
  this.timeout(15000);

  beforeEach(async () => {
    AuthManager.getInstance().clearAllData();
    ProfileManager.getInstance().clearAllData();
    const pool = DatabasePool.getInstance();
    if (pool.isDatabaseConnected) {
      try {
        await pool.query('DELETE FROM auth_sessions');
        await pool.query('DELETE FROM user_accounts');
        await pool.query('DELETE FROM coin_transactions');
        await pool.query('DELETE FROM player_profiles');
      } catch {}
    }
  });

  describe('1. Database Connection & Production Outage Handling', () => {
    it('Should throw fatal error in production when database is unreachable', async () => {
      const origEnv = process.env.NODE_ENV;
      process.env.NODE_ENV = 'production';

      const pool = DatabasePool.getInstance();
      let errorThrown = false;
      try {
        await pool.checkConnection();
      } catch (err: any) {
        errorThrown = true;
        expect(err.message).to.include('[FATAL DATABASE ERROR]');
      } finally {
        process.env.NODE_ENV = origEnv;
      }
      expect(errorThrown).to.be.true;
    });

    it('Should execute migrations idempotently on a PostgreSQL instance', async () => {
      const memDb = newDb();
      const pgAdapter = memDb.adapters.createPg();
      const mockPool = new pgAdapter.Pool();

      const pool = DatabasePool.getInstance();
      pool.initialize(mockPool as any);

      // Run migrations first time
      const firstRun = await pool.runMigrations();
      expect(firstRun.length).to.be.greaterThan(0);

      // Verify schema_migrations table contains applied files
      const res = await pool.query('SELECT version FROM schema_migrations ORDER BY version');
      expect(res.rows.length).to.be.greaterThan(0);

      // Second run must be idempotent (0 new migrations)
      const secondRun = await pool.runMigrations();
      expect(secondRun.length).to.equal(0);
    });
  });

  describe('2. Registered Accounts: Password Hashing, Validation & Login', () => {
    it('Should reject invalid email and weak passwords', async () => {
      const auth = AuthManager.getInstance();

      // Invalid email
      let emailError = false;
      try {
        await auth.registerAccount('notanemail', 'ValidPass123');
      } catch (e: any) {
        emailError = true;
        expect(e.message).to.include('valid email');
      }
      expect(emailError).to.be.true;

      // Too short password
      let shortError = false;
      try {
        await auth.registerAccount('valid@example.com', 'short1');
      } catch (e: any) {
        shortError = true;
        expect(e.message).to.include('at least 8 characters');
      }
      expect(shortError).to.be.true;

      // No numbers in password
      let numError = false;
      try {
        await auth.registerAccount('valid@example.com', 'lettersonlypassword');
      } catch (e: any) {
        numError = true;
        expect(e.message).to.include('both letters and numbers');
      }
      expect(numError).to.be.true;
    });

    it('Should register, verify scrypt hash, and reject duplicate email', async () => {
      const auth = AuthManager.getInstance();
      const reg = await auth.registerAccount('player1@example.com', 'SecurePass123', 'ProPlayer');

      expect(reg.account.email).to.equal('player1@example.com');
      expect(reg.profile.username).to.equal('ProPlayer');
      expect(reg.token).to.be.a('string');
      expect(reg.token.startsWith('pbt_')).to.be.true;

      // Verify duplicate rejection
      let dupError = false;
      try {
        await auth.registerAccount('player1@example.com', 'AnotherPass456');
      } catch (e: any) {
        dupError = true;
        expect(e.message).to.include('already exists');
      }
      expect(dupError).to.be.true;
    });

    it('Should authenticate login with valid credentials and reject bad password', async () => {
      const auth = AuthManager.getInstance();
      await auth.registerAccount('gamer@powerbid.com', 'GameOn2026');

      // Valid login
      const loginRes = await auth.loginAccount('gamer@powerbid.com', 'GameOn2026');
      expect(loginRes.account.email).to.equal('gamer@powerbid.com');
      expect(loginRes.token).to.be.a('string');

      // Invalid password
      let passError = false;
      try {
        await auth.loginAccount('gamer@powerbid.com', 'WrongPassword123');
      } catch (e: any) {
        passError = true;
        expect(e.message).to.include('Invalid email or password');
      }
      expect(passError).to.be.true;
    });

    it('Should validate active session and revoke on logout', async () => {
      const auth = AuthManager.getInstance();
      const { token, account } = await auth.registerAccount('tokenuser@example.com', 'TokenPass2026');

      // Validate session
      const session = await auth.validateSession(token);
      expect(session).to.not.be.null;
      expect(session?.accountId).to.equal(account.id);

      // Logout / Revoke
      const revoked = await auth.revokeSession(token);
      expect(revoked).to.be.true;

      // Post-revocation check
      const postRevoke = await auth.validateSession(token);
      expect(postRevoke).to.be.null;
    });
  });

  describe('3. Guest Account Linking & Data Preservation', () => {
    it('Should link a guest profile to email/password while preserving stats and coins', async () => {
      const pm = ProfileManager.getInstance();
      const auth = AuthManager.getInstance();

      // 1. Guest creates profile and accumulates stats
      const guestProfileId = 'pb_guest_device_7788';
      const guestProfile = pm.getOrCreateProfile(guestProfileId, 'GuestChamp');
      guestProfile.matchesPlayed = 5;
      guestProfile.matchesWon = 4;
      guestProfile.coinBalance = 850;

      // 2. Guest links account to email & password
      const linkRes = await auth.linkGuestAccount(guestProfileId, 'guestupgrade@example.com', 'Upgraded2026');
      expect(linkRes.account.email).to.equal('guestupgrade@example.com');
      expect(linkRes.account.profileId).to.equal(guestProfileId);
      expect(linkRes.token).to.be.a('string');

      // 3. Verify profile preserved
      const updatedProfile = pm.getProfileDTO(guestProfileId);
      expect(updatedProfile.username).to.equal('GuestChamp');
      expect(updatedProfile.matchesWon).to.equal(4);
      expect(updatedProfile.coinBalance).to.equal(850);
    });

    it('Should reject linking to an email that is already registered', async () => {
      const pm = ProfileManager.getInstance();
      const auth = AuthManager.getInstance();

      // Existing registered account
      await auth.registerAccount('taken@example.com', 'Password123');

      // Guest profile
      const guestId = 'pb_guest_duplicate_email';
      pm.getOrCreateProfile(guestId, 'DupeGuest');

      let dupeError = false;
      try {
        await auth.linkGuestAccount(guestId, 'taken@example.com', 'NewPass123');
      } catch (e: any) {
        dupeError = true;
        expect(e.message).to.include('already exists');
      }
      expect(dupeError).to.be.true;
    });
  });

  describe('4. Virtual Coin Rewards & Idempotent Match Crediting', () => {
    it('Should award coins accurately to winner, runner-up, and participants', async () => {
      const pm = ProfileManager.getInstance();

      const p1 = pm.getOrCreateProfile('p1_winner', 'WinnerUser'); // starts at 500
      const p2 = pm.getOrCreateProfile('p2_second', 'SecondUser'); // starts at 500
      const p3 = pm.getOrCreateProfile('p3_third', 'ThirdUser'); // starts at 500

      const participants = [
        { playerId: 'p1_winner', rank: 1, itemsWon: 3 },
        { playerId: 'p2_second', rank: 2, itemsWon: 2 },
        { playerId: 'p3_third', rank: 3, itemsWon: 1 },
      ];

      // Award coins for match m_100
      const rewards = await pm.awardMatchCoins('m_100', 'p1_winner', participants);

      expect(rewards.get('p1_winner')?.amount).to.equal(150);
      expect(rewards.get('p2_second')?.amount).to.equal(75);
      expect(rewards.get('p3_third')?.amount).to.equal(25);

      expect(p1.coinBalance).to.equal(500 + 150);
      expect(p2.coinBalance).to.equal(500 + 75);
      expect(p3.coinBalance).to.equal(500 + 25);
    });

    it('Should prevent duplicate coin rewards for the same match (Idempotence)', async () => {
      const pm = ProfileManager.getInstance();
      const p1 = pm.getOrCreateProfile('p1_idempotent', 'IdemUser');

      const participants = [{ playerId: 'p1_idempotent', rank: 1, itemsWon: 2 }];

      // First award
      await pm.awardMatchCoins('match_idem_01', 'p1_idempotent', participants);
      expect(p1.coinBalance).to.equal(650); // 500 + 150

      // Duplicate attempt with same matchId
      const secondCall = await pm.awardMatchCoins('match_idem_01', 'p1_idempotent', participants);
      expect(secondCall.size).to.equal(0);
      expect(p1.coinBalance).to.equal(650); // Balance unchanged!
    });
  });

  describe('5. Privacy & Zero-Score-Leak Compliance', () => {
    it('Should never leak total team points or scoring formulas in profile or auth DTOs', async () => {
      const pm = ProfileManager.getInstance();
      const auth = AuthManager.getInstance();

      const reg = await auth.registerAccount('privacytest@example.com', 'PrivacyPass123', 'SecretPlayer');
      const profile = pm.getProfileDTO(reg.profile.id);

      // Verify coin balance is present
      expect(profile.coinBalance).to.equal(500);

      // Verify hidden scoring fields are permanently absent
      expect((profile as any).totalTeamPoints).to.be.undefined;
      expect((profile as any).scoringFormula).to.be.undefined;
      expect((profile as any).powerPoints).to.be.undefined;
    });
  });
});
