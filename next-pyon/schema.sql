CREATE TABLE IF NOT EXISTS counters (
  id INTEGER PRIMARY KEY,
  count INTEGER DEFAULT 0
);

-- 初期レコードがない場合は挿入する
INSERT OR IGNORE INTO counters (id, count) VALUES (1, 0);
