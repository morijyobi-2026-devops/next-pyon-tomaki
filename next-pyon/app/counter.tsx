import { getDb } from "../lib/db";

export async function Counter() {
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
      <span className="text-sm text-red-500 font-medium" title={errorMsg}>
        Error Loading Count
      </span>
    );
  }

  return (
    <span className="text-5xl font-black text-indigo-600 dark:text-indigo-400 tabular-nums">
      {currentCount}
    </span>
  );
}
