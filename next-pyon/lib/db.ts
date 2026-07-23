/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable @typescript-eslint/no-require-imports */

export interface DbClient {
  query<T>(sql: string, params?: any[]): Promise<T[]>;
  execute(sql: string, params?: any[]): Promise<void>;
}

export const getDb = (): DbClient => {
  const isCloudflare = (() => {
    try {
      const { getCloudflareContext } = require("@opennextjs/cloudflare");
      return !!getCloudflareContext()?.env;
    } catch {
      return false;
    }
  })();

  if (isCloudflare) {
    let d1: any = null;
    try {
      const { getCloudflareContext } = require("@opennextjs/cloudflare");
      const context = getCloudflareContext();
      d1 = context?.env?.DB;
    } catch (e: any) {
      throw new Error(`Failed to get D1 database context: ${e.message}`);
    }

    if (!d1) {
      let availableKeys: string[] = [];
      try {
        const { getCloudflareContext } = require("@opennextjs/cloudflare");
        const context = getCloudflareContext();
        if (context?.env) {
          availableKeys = Object.keys(context.env);
        }
      } catch {}
      throw new Error(`D1 database binding 'DB' is undefined. Available bindings: ${availableKeys.join(", ")}`);
    }

    return {
      async query<T>(sql: string, params: any[] = []): Promise<T[]> {
        const stmt = d1.prepare(sql).bind(...params);
        const result = await stmt.all();
        return (result.results || []) as T[];
      },
      async execute(sql: string, params: any[] = []): Promise<void> {
        const stmt = d1.prepare(sql).bind(...params);
        await stmt.run();
      },
    };
  } else {
    const dbUrl = process.env.DATABASE_URL || "";

    if (dbUrl.startsWith("postgresql://") || dbUrl.startsWith("postgres://")) {
      const { Pool } = require("pg");
      const poolCacheKey = `__local_pg_pool__:${dbUrl}`;
      const initCacheKey = `__local_pg_pool_inited__:${dbUrl}`;

      const pool = ((globalThis as any)[poolCacheKey] ??= new Pool({
        connectionString: dbUrl,
        ssl: dbUrl.includes("sslmode=disable") ? false : { rejectUnauthorized: false },
      }));

      // PostgreSQL向けの初期化（非同期）
      if (!(globalThis as any)[initCacheKey]) {
        pool.query(`
          CREATE TABLE IF NOT EXISTS counters (
            id INTEGER PRIMARY KEY,
            count INTEGER DEFAULT 0
          );
          INSERT INTO counters (id, count) VALUES (1, 0) ON CONFLICT (id) DO NOTHING;
        `).then(() => {
          console.log("PostgreSQL database initialized successfully.");
        }).catch((err: any) => {
          console.error("Failed to initialize PostgreSQL tables:", err);
        });
        (globalThis as any)[initCacheKey] = true;
      }

      return {
        async query<T>(sql: string, params: any[] = []): Promise<T[]> {
          const res = await pool.query(sql, params);
          return (res.rows || []) as T[];
        },
        async execute(sql: string, params: any[] = []): Promise<void> {
          await pool.query(sql, params);
        },
      };
    } else {
      const path = require("path");
      const fs = require("fs");
      const sqliteModule = "better-sqlite3";
      const Database = require(sqliteModule);
      
      const dbRelativePath = dbUrl.replace("file:", "") || "./data/dev.db";
      let dbPath = path.resolve(process.cwd(), dbRelativePath);
      
      // next-pyon ディレクトリ内で実行された時のパス調整
      if (path.basename(process.cwd()) === "next-pyon" && !path.isAbsolute(dbRelativePath)) {
        dbPath = path.resolve(process.cwd(), "..", dbRelativePath);
      }

      const dbDir = path.dirname(dbPath);
      if (!fs.existsSync(dbDir)) {
        fs.mkdirSync(dbDir, { recursive: true });
      }

      const dbCacheKey = `__local_better_sqlite3_db__:${dbPath}`;
      const initCacheKey = `__local_better_sqlite3_db_inited__:${dbPath}`;

      const localDb = ((globalThis as any)[dbCacheKey] ??= new Database(dbPath));

      // ローカル起動時の初期化（初回のみ）
      if (!(globalThis as any)[initCacheKey]) {
        localDb.exec(`
          CREATE TABLE IF NOT EXISTS counters (
            id INTEGER PRIMARY KEY,
            count INTEGER DEFAULT 0
          );
          INSERT OR IGNORE INTO counters (id, count) VALUES (1, 0);
        `);
        (globalThis as any)[initCacheKey] = true;
      }

      return {
        async query<T>(sql: string, params: any[] = []): Promise<T[]> {
          const stmt = localDb.prepare(sql);
          return stmt.all(...params) as T[];
        },
        async execute(sql: string, params: any[] = []): Promise<void> {
          const stmt = localDb.prepare(sql);
          stmt.run(...params);
        },
      };
    }
  }
};
