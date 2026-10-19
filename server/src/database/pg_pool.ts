import { Pool, PoolClient, QueryResult, QueryResultRow } from 'pg';
import fs from 'fs';
import path from 'path';

export interface DatabaseConfig {
  host?: string;
  port?: number;
  database?: string;
  user?: string;
  password?: string;
  ssl?: boolean | { rejectUnauthorized: boolean };
  connectionString?: string;
  max?: number;
  idleTimeoutMillis?: number;
  connectionTimeoutMillis?: number;
}

export class DatabasePool {
  private static instance: DatabasePool;
  private pool: Pool | null = null;
  private isConnected: boolean = false;
  private isShuttingDown: boolean = false;

  private constructor() {}

  public static getInstance(): DatabasePool {
    if (!DatabasePool.instance) {
      DatabasePool.instance = new DatabasePool();
    }
    return DatabasePool.instance;
  }

  /**
   * Initializes the PostgreSQL connection pool using environment variables or passed config.
   */
  public initialize(customPool?: Pool, customConfig?: DatabaseConfig): Pool {
    if (customPool) {
      this.pool = customPool;
      this.isConnected = true;
      return this.pool;
    }

    if (this.pool) {
      return this.pool;
    }

    const connectionString = process.env.DATABASE_URL || customConfig?.connectionString;
    const isSSL = process.env.DB_SSL === 'true' || customConfig?.ssl;

    const config: DatabaseConfig = connectionString
      ? {
          connectionString,
          ssl: isSSL ? { rejectUnauthorized: false } : undefined,
          max: customConfig?.max || 20,
          idleTimeoutMillis: customConfig?.idleTimeoutMillis || 30000,
          connectionTimeoutMillis: customConfig?.connectionTimeoutMillis || 5000,
        }
      : {
          host: customConfig?.host || process.env.DB_HOST || 'localhost',
          port: customConfig?.port || (process.env.DB_PORT ? parseInt(process.env.DB_PORT, 10) : 5432),
          database: customConfig?.database || process.env.DB_NAME || 'powerbid_prod',
          user: customConfig?.user || process.env.DB_USER || 'postgres',
          password: customConfig?.password || process.env.DB_PASSWORD || '',
          ssl: isSSL ? { rejectUnauthorized: false } : undefined,
          max: customConfig?.max || 20,
          idleTimeoutMillis: customConfig?.idleTimeoutMillis || 30000,
          connectionTimeoutMillis: customConfig?.connectionTimeoutMillis || 5000,
        };

    this.pool = new Pool(config as any);

    this.pool.on('error', (err: Error) => {
      console.error('[PostgreSQL Pool Error]', err.message);
    });

    return this.pool;
  }

  /**
   * Performs an active connection probe to ensure database is online.
   */
  public async checkConnection(): Promise<boolean> {
    if (!this.pool) {
      this.initialize();
    }

    try {
      const client = await this.pool!.connect();
      try {
        await client.query('SELECT 1 AS health_check');
        this.isConnected = true;
        return true;
      } finally {
        client.release();
      }
    } catch (err: any) {
      this.isConnected = false;
      const isProd = process.env.NODE_ENV === 'production' || process.env.DB_REQUIRED === 'true';
      const cleanMsg = `PostgreSQL connection check failed: ${err.message}`;
      if (isProd) {
        throw new Error(`[FATAL DATABASE ERROR] Production requires a persistent PostgreSQL database. ${cleanMsg}`);
      }
      console.warn(`[Database Warning] ${cleanMsg}. Development mode continuing.`);
      return false;
    }
  }

  public get isDatabaseConnected(): boolean {
    return this.isConnected;
  }

  /**
   * Executes a database query with parameter binding.
   */
  public async query<T extends QueryResultRow = any>(text: string, params?: any[]): Promise<QueryResult<T>> {
    if (!this.pool) {
      this.initialize();
    }

    try {
      return await this.pool!.query<T>(text, params);
    } catch (err: any) {
      // Sanitize database error messages to prevent leaking credentials
      throw new Error(`Database query error: ${err.message}`);
    }
  }

  /**
   * Runs a series of operations in a strict ACID transaction with automatic COMMIT and ROLLBACK.
   */
  public async withTransaction<T>(callback: (client: PoolClient) => Promise<T>): Promise<T> {
    if (!this.pool) {
      this.initialize();
    }

    const client = await this.pool!.connect();
    try {
      await client.query('BEGIN');
      const result = await callback(client);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackErr: any) {
        console.error('[Database Rollback Error]', rollbackErr.message);
      }
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Runs all pending SQL migrations idempotently in order.
   */
  public async runMigrations(migrationsDir?: string): Promise<string[]> {
    if (!this.pool) {
      this.initialize();
    }

    const dir = migrationsDir || path.resolve(__dirname, '../../migrations');
    if (!fs.existsSync(dir)) {
      console.warn(`[Migrations] Directory not found: ${dir}`);
      return [];
    }

    const executed: string[] = [];

    await this.withTransaction(async (client) => {
      // 1. Create schema_migrations tracking table if it does not exist
      const tableCheck = await client.query(
        "SELECT 1 FROM information_schema.tables WHERE table_name = 'schema_migrations'"
      );
      if (tableCheck.rows.length === 0) {
        await client.query(`
          CREATE TABLE schema_migrations (
            version VARCHAR(128) PRIMARY KEY,
            applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
          )
        `);
      }

      // 2. Fetch already executed migrations
      const res = await client.query('SELECT version FROM schema_migrations');
      const applied = new Set<string>(res.rows.map((r: any) => r.version));

      // 3. Read migration files sorted alphabetically
      const files = fs
        .readdirSync(dir)
        .filter((f) => f.endsWith('.sql'))
        .sort();

      for (const file of files) {
        if (!applied.has(file)) {
          const sqlPath = path.join(dir, file);
          const sql = fs.readFileSync(sqlPath, 'utf-8');
          await client.query(sql);
          await client.query('INSERT INTO schema_migrations (version) VALUES ($1)', [file]);
          executed.push(file);
          console.log(`[Migrations] Applied: ${file}`);
        }
      }
    });

    return executed;
  }

  /**
   * Gracefully drains the connection pool on application shutdown.
   */
  public async closePool(): Promise<void> {
    if (this.isShuttingDown || !this.pool) {
      return;
    }
    this.isShuttingDown = true;
    try {
      await this.pool.end();
      this.isConnected = false;
      this.pool = null;
      console.log('[PostgreSQL Pool] Connection pool closed successfully.');
    } catch (err: any) {
      console.error('[PostgreSQL Pool Close Error]', err.message);
    }
  }

  /**
   * Resets singleton pool state (for isolated unit tests).
   */
  public resetForTesting(): void {
    this.pool = null;
    this.isConnected = false;
    this.isShuttingDown = false;
  }
}

