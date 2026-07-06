import { getDb } from "../lib/db";

export const dynamic = "force-dynamic";

export default async function Home() {
  let currentCount = 0;
  let errorMsg = "";

  try {
    const db = getDb();

    // カウントをインクリメント（存在しない場合は 1 で初期化、存在すれば +1）
    await db.execute(`
      INSERT INTO counters (id, count) VALUES (1, 1)
      ON CONFLICT(id) DO UPDATE SET count = count + 1;
    `);

    // 最新のカウントを取得
    const result = await db.query<{ count: number }>(
      "SELECT count FROM counters WHERE id = 1;"
    );
    
    currentCount = result[0]?.count ?? 0;
  } catch (error) {
    console.error(error);
    errorMsg = error instanceof Error ? error.message : String(error);
  }

  if (errorMsg) {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center gap-4 bg-red-50 dark:bg-red-950 text-red-900 dark:text-red-50 p-6">
        <h1 className="text-2xl font-bold">Error occurred</h1>
        <pre className="p-4 bg-white dark:bg-zinc-900 rounded border border-red-200 dark:border-red-800 text-sm overflow-auto max-w-full">
          {errorMsg}
        </pre>
      </main>
    );
  }

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-4 bg-zinc-50 dark:bg-zinc-950 text-zinc-900 dark:text-zinc-50">
      <div className="p-8 bg-white dark:bg-zinc-900 rounded-2xl shadow-lg border border-zinc-200 dark:border-zinc-800 text-center max-w-sm w-full">
        <h1 className="text-4xl font-extrabold tracking-tight mb-2 bg-gradient-to-r from-violet-600 to-indigo-600 dark:from-violet-400 dark:to-indigo-400 bg-clip-text text-transparent">
          next-pyon
        </h1>
        <p className="text-sm text-zinc-500 dark:text-zinc-400 mb-6">
          Cloudflare D1 & Local SQLite Counter Demo
        </p>
        <div className="flex flex-col items-center justify-center p-6 bg-zinc-50 dark:bg-zinc-950 rounded-xl border border-zinc-100 dark:border-zinc-900">
          <span className="text-xs font-semibold text-zinc-400 uppercase tracking-wider mb-1">
            Total Visits
          </span>
          <span className="text-5xl font-black text-indigo-600 dark:text-indigo-400 tabular-nums">
            {currentCount}
          </span>
        </div>
      </div>
    </main>
  );
}
