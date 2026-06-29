# OpenNext + Cloudflare 導入 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `next-pyon` を OpenNext（`@opennextjs/cloudflare`）で Cloudflare Workers 上に載せ、Cloudflare Workers Builds のネイティブ連携で PR→ステージング / main→プロダクションのデプロイを自動化する。

**Architecture:** 同じ `next-pyon/` のソースから2つの独立したビルド経路を持つ。Docker 経路は `BUILD_STANDALONE=1` の Node standalone（既存・不変）、Cloudflare 経路は `opennextjs-cloudflare build` で workerd 用 Worker を生成。デプロイ制御は Cloudflare Workers Builds（GitHub App 連携）が担い、GitHub に API トークンは置かない。

**Tech Stack:** Next.js 16 / React 19 / TypeScript / Tailwind v4、pnpm workspace、mise、`@opennextjs/cloudflare` + `wrangler`、Cloudflare Workers Builds、R2（incremental cache）。

> **実装時の変更（2026-06-25）** — デプロイ立ち上げ時点でアカウントの R2 が未有効（現状アプリは全ページ static で永続キャッシュ不要）のため、R2 incremental cache は見送った。`open-next.config.ts` の R2 override と `wrangler.jsonc` の R2 binding を削除し、R2 バケット作成手順も省いている。最新の運用手順は `next-pyon/README.md` を参照。以下の R2 に関する記述は当初計画の記録。

## Global Constraints

すべてのタスクの要件に以下を暗黙的に含む。

- Node.js = `24.17.0`、pnpm = `11.8.0`（`mise.toml` / `package.json` engines）。
- インデント2スペース、UTF-8、LF。
- コミットは Conventional Commits（英語 type + 日本語タイトル）。co-author や生成署名は付けない。
- Markdown を編集したら `pnpm run lint:md` を実行し 0 error にしてからコミットする。
- 依存追加は `pnpm-workspace.yaml` の `minimumReleaseAge: 2880`（2日）に従う（`pnpm add` がこれを尊重する）。
- Cloudflare の API トークンをリポジトリにも GitHub にも保存しない（方式B / ネイティブ連携）。
- Docker 経路（`compose.*.yaml` / `*.Dockerfile` / `next.config.ts` の `BUILD_STANDALONE` ゲート）は変更しない。
- 作業ブランチは `feat/opennext-cloudflare`（設計ドキュメントが既にこのブランチにある）。

---

## File Structure

| ファイル | 区分 | 責務 |
| --- | --- | --- |
| `next-pyon/open-next.config.ts` | 新規 | OpenNext の Cloudflare 設定（R2 incremental cache） |
| `next-pyon/wrangler.jsonc` | 新規 | Worker 定義（main / assets / R2 binding / 自己参照 service） |
| `next-pyon/package.json` | 変更 | devDeps（opennext / wrangler）と cf スクリプト追加 |
| `next-pyon/.gitignore` | 変更 | `.open-next` / `.wrangler` / 生成 env 型を無視 |
| `mise.toml` | 変更 | `cf:build` / `cf:preview` / `cf:deploy` タスク追加 |
| `.dockerignore` | 変更 | Docker コンテキストから Cloudflare 生成物を除外 |
| `.github/workflows/ci.yml` | 変更 | OpenNext ビルド検証ステップ追加 |
| `next-pyon/README.md` | 変更 | cf タスクと Cloudflare デプロイ手順を追記 |
| `README.md` | 変更 | デプロイの位置づけを追記 |

---

## Task 1: OpenNext 依存とアプリ設定を追加し、ローカルで OpenNext ビルドを通す

**Files:**

- Modify: `next-pyon/package.json`（devDependencies + scripts）
- Create: `next-pyon/open-next.config.ts`
- Create: `next-pyon/wrangler.jsonc`
- Modify: `next-pyon/.gitignore`

**Interfaces:**

- Produces: `opennextjs-cloudflare` CLI（`cf:build` / `cf:preview` / `cf:deploy` スクリプト）、`.open-next/worker.js` ビルド成果物、Worker 名 `next-pyon`、R2 binding 名 `NEXT_INC_CACHE_R2_BUCKET`、R2 バケット名 `next-pyon-inc-cache`。後続タスクと手動セットアップがこれらの名前に依存する。

- [ ] **Step 1: OpenNext / wrangler を devDependencies に追加**

リポジトリルートで実行する。`pnpm add` が `minimumReleaseAge` を尊重し、解決された固定バージョンを `package.json` と `pnpm-lock.yaml` に書き込む。

Run:

```bash
pnpm --filter next-pyon add -D @opennextjs/cloudflare wrangler
```

Expected: `next-pyon/package.json` の devDependencies に `@opennextjs/cloudflare` と `wrangler` が追加され、`pnpm-lock.yaml` が更新される。

- [ ] **Step 2: `next-pyon/open-next.config.ts` を作成**

```typescript
import { defineCloudflareConfig } from "@opennextjs/cloudflare";
import r2IncrementalCache from "@opennextjs/cloudflare/overrides/incremental-cache/r2-incremental-cache";

export default defineCloudflareConfig({
  incrementalCache: r2IncrementalCache,
});
```

- [ ] **Step 3: `next-pyon/wrangler.jsonc` を作成**

```jsonc
{
  "$schema": "node_modules/wrangler/config-schema.json",
  "main": ".open-next/worker.js",
  "name": "next-pyon",
  "compatibility_date": "2025-03-25",
  "compatibility_flags": ["nodejs_compat", "global_fetch_strictly_public"],
  "assets": {
    "directory": ".open-next/assets",
    "binding": "ASSETS"
  },
  "services": [
    {
      "binding": "WORKER_SELF_REFERENCE",
      "service": "next-pyon"
    }
  ],
  "r2_buckets": [
    {
      "binding": "NEXT_INC_CACHE_R2_BUCKET",
      "bucket_name": "next-pyon-inc-cache"
    }
  ]
}
```

- [ ] **Step 4: `next-pyon/package.json` の scripts に cf 系を追加**

`scripts` を以下にする（既存4つを残し、4つ追加）。

```json
"scripts": {
  "dev": "next dev",
  "build": "next build",
  "start": "next start",
  "lint": "eslint",
  "cf:build": "opennextjs-cloudflare build",
  "cf:preview": "opennextjs-cloudflare build && opennextjs-cloudflare preview",
  "cf:deploy": "opennextjs-cloudflare build && opennextjs-cloudflare deploy",
  "cf-typegen": "wrangler types --env-interface CloudflareEnv cloudflare-env.d.ts"
}
```

- [ ] **Step 5: `next-pyon/.gitignore` に生成物を追加**

ファイル末尾に追記する。

```gitignore
# cloudflare / opennext
/.open-next/
/.wrangler/
cloudflare-env.d.ts
```

- [ ] **Step 6: OpenNext ビルドが通ることを確認**

Run:

```bash
pnpm --filter next-pyon exec opennextjs-cloudflare build
ls next-pyon/.open-next/worker.js
```

Expected: ビルドが正常終了し、`next-pyon/.open-next/worker.js` が存在する。

contingency: pnpm workspace（モノレポ）のため、ビルドが file tracing / ルート解決で失敗する場合は、`next.config.ts` の `outputFileTracingRoot`（現状 `BUILD_STANDALONE=1` 時のみ設定）を OpenNext ビルドでも有効になるよう、`process.env.BUILD_STANDALONE === "1"` の分岐の外側（共通設定）へ移す。例:

```typescript
const nextConfig: NextConfig = {
  outputFileTracingRoot: path.join(__dirname, ".."),
  ...standalone,
};
```

その後 Step 6 を再実行して成功を確認する。Docker 経路には影響しない（`outputFileTracingRoot` は standalone 専用設定ではなく常時設定して問題ない）。

- [ ] **Step 7: gitignore が効いていることを確認**

Run:

```bash
git status --short
```

Expected: `next-pyon/.open-next/` や `next-pyon/.wrangler/` が未追跡として現れない（無視されている）。表示されるのは `next-pyon/package.json`、`next-pyon/open-next.config.ts`、`next-pyon/wrangler.jsonc`、`next-pyon/.gitignore`、`pnpm-lock.yaml` のみ。

- [ ] **Step 8: コミット**

```bash
git add next-pyon/package.json next-pyon/open-next.config.ts next-pyon/wrangler.jsonc next-pyon/.gitignore pnpm-lock.yaml
git commit -m "feat: OpenNext で Cloudflare 向けビルドを可能にする"
```

---

## Task 2: ローカル cf タスクと Docker 経路の非回帰

**Files:**

- Modify: `mise.toml`（cf タスク追加）
- Modify: `.dockerignore`（Cloudflare 生成物を除外）

**Interfaces:**

- Consumes: Task 1 の `cf:build` / `cf:preview` / `cf:deploy` スクリプト。
- Produces: `mise run cf:build` / `cf:preview` / `cf:deploy` タスク。

- [ ] **Step 1: `mise.toml` に cf タスクを追加**

既存の docker タスク群と同じ流儀で、ファイル末尾に追記する。

```toml
[tasks."cf:build"]
description = "OpenNext で Cloudflare 向けにビルドする"
dir = "{{config_root}}"
run = "pnpm --filter next-pyon cf:build"

[tasks."cf:preview"]
description = "Cloudflare ランタイム(workerd)でローカル起動する"
dir = "{{config_root}}"
run = "pnpm --filter next-pyon cf:preview"

[tasks."cf:deploy"]
description = "Cloudflare へ手動デプロイする (要 wrangler login)"
dir = "{{config_root}}"
run = "pnpm --filter next-pyon cf:deploy"
```

- [ ] **Step 2: `.dockerignore` に Cloudflare 生成物を追加**

既存の `**/.next` / `**/out` / `**/build` の近く（ビルド成果物の除外セクション）に追記する。

```dockerignore
# OpenNext / wrangler の生成物
**/.open-next
**/.wrangler
```

- [ ] **Step 3: mise タスクが登録されたことを確認**

Run:

```bash
mise tasks | grep "cf:"
```

Expected: `cf:build` / `cf:preview` / `cf:deploy` の3つが一覧に出る。

- [ ] **Step 4: ローカル workerd プレビューが配信されることを確認**

`mise run cf:preview` は build 後に `wrangler dev`（workerd）を起動する長時間プロセス。1つ目の端末で起動し、2つ目の端末で疎通確認してから停止する。

端末A:

```bash
mise run cf:preview
```

端末B（起動ログに出る URL のポートを使う。既定は 8787）:

```bash
curl -sI http://localhost:8787/
```

Expected: 端末A に Worker のローカル URL が表示される。端末B の `curl` が `HTTP/1.1 200 OK`（または 200 系）を返す。確認後、端末A を Ctrl-C で停止する。

- [ ] **Step 5: Docker 経路の非回帰を確認**

Docker が使える環境で、本番イメージが従来通りビルドできることを確認する（`.dockerignore` 変更が Docker 経路を壊していないこと）。

Run:

```bash
mise run docker:prod:build
```

Expected: prod イメージのビルドが成功する。（Docker が使えない場合は最低限 `mise run build` が成功することを確認し、その旨をレビューで共有する。）

- [ ] **Step 6: コミット**

```bash
git add mise.toml .dockerignore
git commit -m "feat: ローカル用 cf タスクを追加し Docker コンテキストから生成物を除外"
```

---

## Task 3: CI に OpenNext ビルド検証を追加

**Files:**

- Modify: `.github/workflows/ci.yml`（`build` ジョブにステップ追加）

**Interfaces:**

- Consumes: Task 1 で検証済みの `pnpm --filter next-pyon exec opennextjs-cloudflare build`。

- [ ] **Step 1: `build` ジョブに OpenNext ビルド検証ステップを追加**

既存の `build` ジョブの最後（`Build` ステップの後）に追記する。シークレット不要・デプロイなし。`build` ジョブ全体は次の形になる。

```yaml
  build:
    needs: lint
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@df4cb1c069e1874edd31b4311f1884172cec0e10 # v6.0.3

      - name: Setup tools via mise
        uses: jdx/mise-action@dba19683ed58901619b14f395a24841710cb4925 # v4.1.0

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Build
        run: pnpm run build

      - name: Build (OpenNext for Cloudflare)
        run: pnpm --filter next-pyon exec opennextjs-cloudflare build
```

- [ ] **Step 2: 追加コマンドがローカルで通ることを再確認（CI の代理検証）**

Run:

```bash
pnpm --filter next-pyon exec opennextjs-cloudflare build
```

Expected: 成功する（Task 1 Step 6 と同じ）。CI でも同一コマンドのため、ローカル成功を CI 成功の代理確認とする。

- [ ] **Step 3: コミット**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: OpenNext ビルド検証ステップを追加"
```

---

## Task 4: ドキュメント整備（README + Cloudflare セットアップ手順）

**Files:**

- Modify: `next-pyon/README.md`
- Modify: `README.md`

**Interfaces:**

- Consumes: Task 1〜2 の cf タスク・Worker 名・R2 バケット名。

- [ ] **Step 1: `next-pyon/README.md` に Cloudflare セクションを追記**

既存の「Docker / Docker Compose」セクションの後に、以下の趣旨で追記する。

- ローカルの cf タスク:

```bash
mise run cf:build     # OpenNext で Cloudflare 向けビルド
mise run cf:preview   # workerd でローカル起動（http://localhost:8787）
mise run cf:deploy    # 手動デプロイ（要 wrangler login）
```

- デプロイの仕組み（Cloudflare Workers Builds ネイティブ連携。GitHub にトークンは置かない）:
  - PR 作成・更新 → Cloudflare が `wrangler versions upload` でプレビュー URL を生成し PR にコメント（ステージング）。
  - main へ merge → Cloudflare が `wrangler deploy` で本番反映。
- 初回セットアップ手順（後述の「Cloudflare 側セットアップ」を参照、と誘導）。

- [ ] **Step 2: `next-pyon/README.md` に「Cloudflare 側セットアップ（一度きり）」を追記**

設計ドキュメント `docs/superpowers/specs/2026-06-22-opennext-cloudflare-design.md` の第6章の手順を転記する。

1. R2 バケット作成: `pnpm --filter next-pyon exec wrangler r2 bucket create next-pyon-inc-cache`（事前に `wrangler login`）。
2. Cloudflare Workers Builds で対象 GitHub リポジトリを連携（GitHub App 認可）。
3. Build 設定:
   - Root directory = リポジトリルート。
   - Build command = `pnpm --filter next-pyon exec opennextjs-cloudflare build`
   - 本番 Deploy command = `pnpm --filter next-pyon exec wrangler deploy`
   - 非本番 Deploy command = `pnpm --filter next-pyon exec wrangler versions upload`
4. Branch control: production branch = `main`、「非本番ブランチのビルド」を ON。
5. 環境変数: `NODE_VERSION=24.17.0`、`PNPM_VERSION=11.8.0`。

順序は「R2 作成 → リポジトリ連携 → ビルド/ブランチ設定 → 初回デプロイ」。

- [ ] **Step 3: ルート `README.md` にデプロイの位置づけを追記**

「GitHub Actions」セクション付近に、CI（lint/build/docker + OpenNext ビルド検証）と、Cloudflare へのデプロイは Workers Builds が担当する旨を1〜2行で追記し、詳細は `next-pyon/README.md` を参照、とする。

- [ ] **Step 4: Markdown lint**

Run:

```bash
pnpm run lint:md
```

Expected: `0 error(s)`。エラーがあれば修正して再実行する。

- [ ] **Step 5: コミット**

```bash
git add README.md next-pyon/README.md
git commit -m "docs: Cloudflare デプロイ手順とローカル cf タスクを README に追記"
```

---

## Task 5（手動・ユーザー作業）: Cloudflare ダッシュボード設定と疎通確認

コードではなくユーザーの運用作業。`next-pyon/README.md`（Task 4）に手順がある。実装エージェントはここで停止し、ユーザーに以下を依頼する。

- [ ] R2 バケット `next-pyon-inc-cache` を作成（`wrangler login` 後）。
- [ ] Workers Builds でリポジトリ連携、Build / Branch control / 環境変数を設定。
- [ ] このブランチで PR を作成し、Cloudflare がプレビュー URL を PR にコメントすることを確認（要件1）。
- [ ] PR を main にマージし、本番 Worker が更新されることを確認（要件2）。

---

## Self-Review

**1. Spec coverage:**

- 第4.1 2経路分離 → Task 1（OpenNext ビルド）+ `next.config.ts` 不変方針（Global Constraints / Task 2 Step 5 非回帰）。
- 第4.2 デプロイフロー（PR→プレビュー / main→本番）→ Task 4 手順 + Task 5 手動設定。
- 第5.1 open-next.config.ts → Task 1 Step 2。
- 第5.2 wrangler.jsonc → Task 1 Step 3。
- 第5.3 package.json（devDeps + scripts）→ Task 1 Step 1, 4。
- 第5.4 .gitignore → Task 1 Step 5。
- 第5.5 mise cf タスク → Task 2 Step 1。
- 第5.6 .dockerignore → Task 2 Step 2。
- 第5.7 ci.yml OpenNext 検証 → Task 3。
- 第5.8 README → Task 4。
- 第6 Cloudflare 一度きりセットアップ → Task 4 Step 2 + Task 5。
- 第8 テスト・検証 → 各 Task の検証ステップ（cf:preview / docker:prod:build / lint:md / PR 疎通）。

ギャップなし。R2 incremental cache（第2.1）は wrangler.jsonc の R2 binding（Task 1 Step 3）+ open-next.config.ts（Task 1 Step 2）+ バケット作成（Task 4 Step 2 / Task 5）でカバー。

**2. Placeholder scan:** TBD / TODO / 「適切に」等の曖昧表現なし。各コード変更ステップに実内容を記載。

**3. Type / 名前整合性:** Worker 名 `next-pyon`、R2 binding `NEXT_INC_CACHE_R2_BUCKET`、R2 バケット `next-pyon-inc-cache`、ビルドコマンド `pnpm --filter next-pyon exec opennextjs-cloudflare build`、デプロイコマンド（`wrangler deploy` / `wrangler versions upload`）が Task 1・3・4・5 で一貫。
