/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable @typescript-eslint/no-require-imports */

export interface DbClient {
  query<T>(sql: string, params?: any[]): Promise<T[]>;
  execute(sql: string, params?: any[]): Promise<void>;
}

export const getDb = (): DbClient => {
  const isCloudflare = process.env.IS_CLOUDFLARE === "true" || !!process.env.DB;

  if (isCloudflare) {
    let d1: any = null;
    try {
      if (process.env.DB) {
        d1 = process.env.DB;
      } else {
        const { getCloudflareContext } = require("@opennextjs/cloudflare");
        const context = getCloudflareContext();
        d1 = context?.env?.DB;
      }
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
    const path = require("path");
    const fs = require("fs");
    const sqliteModule = "better-sqlite3";
    const Database = require(sqliteModule);
    
    const dbRelativePath = process.env.DATABASE_URL?.replace("file:", "") || "./data/dev.db";
    let dbPath = path.resolve(process.cwd(), dbRelativePath);
    
    // next-pyon ディレクトリ内で実行された時のパス調整
    if (!fs.existsSync(dbPath)) {
      const parentDbPath = path.resolve(process.cwd(), "..", dbRelativePath);
      if (fs.existsSync(parentDbPath)) {
        dbPath = parentDbPath;
      }
    }

    const dbDir = path.dirname(dbPath);
    if (!fs.existsSync(dbDir)) {
      fs.mkdirSync(dbDir, { recursive: true });
    }

    const localDb = new Database(dbPath);
    
    // ローカル起動時の初期化
    localDb.exec(`
      CREATE TABLE IF NOT EXISTS counters (
        id INTEGER PRIMARY KEY,
        count INTEGER DEFAULT 0
      );
      INSERT OR IGNORE INTO counters (id, count) VALUES (1, 0);
    `);

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
};
