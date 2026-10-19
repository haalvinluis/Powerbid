export class SecurityMiddleware {
  private static creationAttempts: Map<string, number[]> = new Map();
  private static roomCodeAttempts: Map<string, number[]> = new Map();
  private static bidAttempts: Map<string, number[]> = new Map();

  /**
   * Enforce rate limit for room creation (Max 5 per minute per IP/socket)
   */
  public static checkRoomCreationLimit(identifier: string): { allowed: boolean; retryAfterSec?: number } {
    const now = Date.now();
    const windowMs = 60000;
    const maxAttempts = 5;

    let timestamps = this.creationAttempts.get(identifier) || [];
    timestamps = timestamps.filter((t) => now - t < windowMs);

    if (timestamps.length >= maxAttempts) {
      const oldest = timestamps[0];
      const retryAfterSec = Math.ceil((windowMs - (now - oldest)) / 1000);
      return { allowed: false, retryAfterSec };
    }

    timestamps.push(now);
    this.creationAttempts.set(identifier, timestamps);
    return { allowed: true };
  }

  /**
   * Enforce rate limit for room code guessing / join attempts (Max 10 per minute per IP/socket)
   */
  public static checkRoomCodeAttemptLimit(identifier: string): { allowed: boolean; retryAfterSec?: number } {
    const now = Date.now();
    const windowMs = 60000;
    const maxAttempts = 10;

    let timestamps = this.roomCodeAttempts.get(identifier) || [];
    timestamps = timestamps.filter((t) => now - t < windowMs);

    if (timestamps.length >= maxAttempts) {
      const oldest = timestamps[0];
      const retryAfterSec = Math.ceil((windowMs - (now - oldest)) / 1000);
      return { allowed: false, retryAfterSec };
    }

    timestamps.push(now);
    this.roomCodeAttempts.set(identifier, timestamps);
    return { allowed: true };
  }

  /**
   * Enforce rate limit for bidding actions (Max 5 per second per socket)
   */
  public static checkBiddingFrequencyLimit(socketId: string): { allowed: boolean } {
    const now = Date.now();
    const windowMs = 1000;
    const maxAttempts = 5;

    let timestamps = this.bidAttempts.get(socketId) || [];
    timestamps = timestamps.filter((t) => now - t < windowMs);

    if (timestamps.length >= maxAttempts) {
      return { allowed: false };
    }

    timestamps.push(now);
    this.bidAttempts.set(socketId, timestamps);
    return { allowed: true };
  }

  /**
   * Sanitize string input and enforce max length
   */
  public static sanitizeString(input: any, maxLen: number = 50): string {
    if (typeof input !== 'string') return '';
    return input.trim().substring(0, maxLen).replace(/[<>]/g, '');
  }

  /**
   * Validate integer currency values (reject floats, NaN, negative, infinity)
   */
  public static isValidIntegerCurrency(value: any): boolean {
    if (typeof value !== 'number') return false;
    if (!Number.isFinite(value)) return false;
    if (!Number.isInteger(value)) return false;
    if (value < 0) return false;
    return true;
  }

  /**
   * Validate 6-character room code format
   */
  public static isValidRoomCode(code: any): boolean {
    if (typeof code !== 'string') return false;
    const clean = code.trim().toUpperCase();
    return /^[A-Z0-9]{6}$/.test(clean);
  }

  private static apiAttempts: Map<string, number[]> = new Map();
  private static profileAttempts: Map<string, number[]> = new Map();

  /**
   * Enforce rate limit for general API requests (Max 30 per 10 seconds per socket)
   */
  public static checkGeneralApiLimit(socketId: string, maxRequests: number = 30, windowMs: number = 10000): { allowed: boolean; retryAfterSec?: number } {
    const now = Date.now();
    let timestamps = this.apiAttempts.get(socketId) || [];
    timestamps = timestamps.filter((t) => now - t < windowMs);

    if (timestamps.length >= maxRequests) {
      const oldest = timestamps[0];
      const retryAfterSec = Math.ceil((windowMs - (now - oldest)) / 1000);
      return { allowed: false, retryAfterSec };
    }

    timestamps.push(now);
    this.apiAttempts.set(socketId, timestamps);
    return { allowed: true };
  }

  /**
   * Enforce rate limit for username/profile modifications (Max 5 per minute per socket)
   */
  public static checkProfileUpdateLimit(socketId: string): { allowed: boolean; retryAfterSec?: number } {
    const now = Date.now();
    const windowMs = 60000;
    const maxAttempts = 5;

    let timestamps = this.profileAttempts.get(socketId) || [];
    timestamps = timestamps.filter((t) => now - t < windowMs);

    if (timestamps.length >= maxAttempts) {
      const oldest = timestamps[0];
      const retryAfterSec = Math.ceil((windowMs - (now - oldest)) / 1000);
      return { allowed: false, retryAfterSec };
    }

    timestamps.push(now);
    this.profileAttempts.set(socketId, timestamps);
    return { allowed: true };
  }

  private static friendSearchAttempts: Map<string, number[]> = new Map();

  /**
   * Enforce rate limit for Player ID searches to prevent enumeration attacks (Max 15 per 30s)
   */
  public static checkPlayerSearchLimit(identifier: string): { allowed: boolean; retryAfterSec?: number } {
    const now = Date.now();
    const windowMs = 30000;
    const maxAttempts = 15;

    let timestamps = this.friendSearchAttempts.get(identifier) || [];
    timestamps = timestamps.filter((t) => now - t < windowMs);

    if (timestamps.length >= maxAttempts) {
      const oldest = timestamps[0];
      const retryAfterSec = Math.ceil((windowMs - (now - oldest)) / 1000);
      return { allowed: false, retryAfterSec };
    }

    timestamps.push(now);
    this.friendSearchAttempts.set(identifier, timestamps);
    return { allowed: true };
  }

  /**
   * Clear all rate limiting state (used for testing)
   */
  public static resetRateLimits(): void {
    this.creationAttempts.clear();
    this.roomCodeAttempts.clear();
    this.bidAttempts.clear();
    this.apiAttempts.clear();
    this.profileAttempts.clear();
    this.friendSearchAttempts.clear();
  }
}
