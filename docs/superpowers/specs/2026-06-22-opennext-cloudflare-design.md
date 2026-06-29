# OpenNext + Cloudflare 導入 Design

> **実装時の変更（2026-06-25）** — 本ドキュメントは当初 R2 incremental cache を
> 最初から有効化する設計だが、デプロイ立ち上げ時点でアカウントの R2 が未有効
> （現状アプリは全ページ static で永続キャッシュ不要）のため、R2 incremental cache
> は見送った。`open-next.config.ts` から R2 override を外し、`wrangler.jsonc` の
> R2 binding も削除している。最新の運用手順は `next-pyon/README.md` を参照。
> 以下の R2 に関する記述は当初設計の記録。

## 1. 目的

`next-pyon` の Next.js アプリを [OpenNext](https://opennext.js.org)
（`@opennextjs/cloudflare`）を用いて Cloudflare Workers 上で動かせるようにする。

併せて、Cloudflare へのデプロイを自動化する。

- プルリクエストの作成・更新でステージング（プレビュー）環境を用意する
- main へのマージでプロダクション環境へ反映する

既存の Docker / Docker Compose 環境（Node ランタイムでの開発・本番起動）は
これまで通り動かし続けられるようにし、Cloudflare 経路と互いに干渉させない。

## 2. 解決したい課題・前提

- `next-pyon/README.md` には「OpenNext で Cloudflare 上で動かすことを想定」と
  書かれているが、OpenNext 本体・Cloudflare 設定・デプロイ自動化はまだ無い。
- 既に地ならしは済んでいる。
  - `next.config.ts` は `output: "standalone"` を `BUILD_STANDALONE=1` の時だけ
    有効化しており、OpenNext のビルド（素の `next build`）に干渉しない。
  - `pnpm-workspace.yaml` は sharp / unrs-resolver のネイティブビルドを
    「Cloudflare では不要」として無効化済み。
- Docker は Node ランタイムの standalone サーバー、Cloudflare は workerd
  ランタイムの Worker と、成果物の形が根本的に異なる。両者を同じビルドに
  まとめることはできないため、ソースを共有しつつビルド経路を分ける必要がある。

### 2.1 確定済みの方針（ブレストでの決定事項）

- Cloudflare 側はアカウントのみ用意済み。Worker / R2 / トークンはこれから。
- デプロイ自動化は **Cloudflare Workers Builds（GitHub ネイティブ連携）** を採用。
  GitHub に Cloudflare の API トークンは登録しない。
- ステージングは **プレビューバージョン**方式（`wrangler versions upload`）。
- OpenNext のキャッシュは最初から **R2 incremental cache** を有効化する。
- ローカルでも Cloudflare ランタイム（workerd）での確認タスクを用意する。

## 3. 検討したアプローチ

### 3.1 デプロイ自動化の方式

#### 方式A: GitHub Actions が主役（API トークンを GitHub に登録）

- Cloudflare でスコープを絞った API トークンを発行し、GitHub Secrets に
  `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` を登録する。
- GitHub Actions の中で `wrangler` を実行してビルド・デプロイする。
- ビルドからデプロイまで GitHub 側で完結・可視化でき、既存 CI と並べて制御できる。
- ただし API トークン（シークレット）を GitHub に1つ持つ必要がある。

#### 方式B: Cloudflare ネイティブ連携 / Workers Builds（採用）

- Cloudflare ダッシュボードから GitHub App 連携（OAuth 認可）でリポジトリをつなぐ。
  GitHub に API トークンを置く必要がない。
- 以降は Cloudflare 自身がリポジトリを監視し、main への push で本番、
  非本番ブランチ（PR）への push でプレビューを自動生成する。
- PR へのプレビュー URL コメントもネイティブ機能で行われる。
- ビルドは Cloudflare のビルド環境で走るため、Node / pnpm バージョンやビルド
  コマンドはダッシュボードで設定する（mise は使われない）。

採用理由: 「GitHub にトークンを置きたくない」という要望を満たし、PR プレビューと
PR コメントが標準機能でまかなえる。GitHub Actions の追加ワークフローも不要になる。

### 3.2 ステージング（プレビュー）の単位

- 採用: **プレビューバージョン**。非本番ブランチの push ごとに
  `wrangler versions upload` で本番 Worker の新しいバージョンを作り、
  プレビュー URL を払い出す。Worker は1つ、クリーンアップ不要。
- 不採用: PR ごとの専用 Worker（分離は強いがクリーンアップ運用が増える）、
  単一の共有 staging（複数 PR が互いに上書きし合う）。

## 4. アーキテクチャ

### 4.1 2つの独立したビルド経路

同じ `next-pyon/` のソースから、用途の異なる2つの成果物を独立に作る。

| 経路 | ビルド | 成果物 / ランタイム | 実行・デプロイ |
| --- | --- | --- | --- |
| Docker | `BUILD_STANDALONE=1 next build` | `.next/standalone`（Node） | Docker / Compose（既存） |
| Cloudflare | `opennextjs-cloudflare build` | `.open-next/worker.js`（workerd） | Workers Builds が `wrangler` で実行 |

`next.config.ts` の `BUILD_STANDALONE` ゲートにより、OpenNext 経路は standalone
出力を有効化しない。Docker 側の設定・ファイルは**変更しない**。

### 4.2 デプロイのフロー

| トリガー | Workers Builds の動作 | 結果 |
| --- | --- | --- |
| PR 作成 / PR ブランチへ push | build → 非本番 deploy（`wrangler versions upload`） | プレビュー URL を生成し Cloudflare が PR にコメント = ステージング |
| main へ merge（push） | build → 本番 deploy（`wrangler deploy`） | プロダクションへ反映 |

## 5. 構成要素（リポジトリへの変更）

### 5.1 `next-pyon/open-next.config.ts`（新規）

```typescript
import { defineCloudflareConfig } from "@opennextjs/cloudflare";
import r2IncrementalCache from "@opennextjs/cloudflare/overrides/incremental-cache/r2-incremental-cache";

export default defineCloudflareConfig({
  incrementalCache: r2IncrementalCache,
});
```

### 5.2 `next-pyon/wrangler.jsonc`（新規）

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

- `compatibility_date` は `nodejs_compat` が要求する 2024-09-23 以降の日付。
  実装時点の妥当な近時日付を採用する（上記は目安）。
- `name` と `services[].service` は同一の Worker 名で揃える（自己参照）。

### 5.3 `next-pyon/package.json`（変更）

- devDependencies に追加: `@opennextjs/cloudflare`、`wrangler`。
- scripts に追加（pnpm 直接実行・mise タスクの実体として使う）:

```json
{
  "cf:build": "opennextjs-cloudflare build",
  "cf:preview": "opennextjs-cloudflare build && opennextjs-cloudflare preview",
  "cf:deploy": "opennextjs-cloudflare build && opennextjs-cloudflare deploy",
  "cf-typegen": "wrangler types --env-interface CloudflareEnv cloudflare-env.d.ts"
}
```

- バージョンは固定値で追加する（`pnpm-workspace.yaml` の `minimumReleaseAge`
  と Renovate の運用に従う）。

### 5.4 `next-pyon/.gitignore`（変更）

OpenNext / wrangler の生成物を無視に追加する。

```gitignore
# cloudflare / opennext
/.open-next/
/.wrangler/
cloudflare-env.d.ts
```

### 5.5 リポジトリルート `mise.toml`（変更）

Docker タスクと同じ流儀で cf タスクを追加する。実体は `pnpm --filter next-pyon`。

- `cf:build` — `pnpm --filter next-pyon cf:build`
- `cf:preview` — `pnpm --filter next-pyon cf:preview`（ローカル workerd で起動）
- `cf:deploy` — `pnpm --filter next-pyon cf:deploy`（手動デプロイ。要 `wrangler login`）

### 5.6 リポジトリルート `.dockerignore`（変更）

Docker ビルドコンテキストから Cloudflare 生成物を除外する。

```dockerignore
**/.open-next
**/.wrangler
```

### 5.7 `.github/workflows/ci.yml`（変更・任意だが推奨）

既存の `lint` / `build` / `docker` ジョブは維持する。加えて、Cloudflare に
行く前に GitHub 側で OpenNext ビルドの破綻を検知するため、OpenNext ビルドの
検証ステップを追加する。

- シークレット不要・デプロイなし（`opennextjs-cloudflare build` のみ）。
- 既存の `build` ジョブにステップ追加、または専用ジョブとして並べる。

### 5.8 README 更新

- `next-pyon/README.md` に cf タスク（ローカル workerd プレビュー）と
  Cloudflare デプロイの仕組み（Workers Builds 連携）を追記する。
- ルート `README.md` の GitHub Actions / 運用記述に Cloudflare デプロイの
  位置づけを追記する。

## 6. Cloudflare 側の一度きりのセットアップ手順（ドキュメント化する）

実装後、ユーザーが手動で行う。spec / README に手順を残す。

1. `wrangler login`（ローカル）またはダッシュボードで R2 バケットを作成する。
   `wrangler r2 bucket create next-pyon-inc-cache`
2. Workers Builds で対象の GitHub リポジトリを連携する（GitHub App 認可）。
3. Build 設定:
   - Root directory = リポジトリルート（`pnpm-lock.yaml` / `pnpm-workspace.yaml`
     がここにあり pnpm が検出される）。
   - Build command = `pnpm --filter next-pyon exec opennextjs-cloudflare build`
   - 本番 Deploy command = `pnpm --filter next-pyon exec wrangler deploy`
   - 非本番 Deploy command = `pnpm --filter next-pyon exec wrangler versions upload`
4. Branch control:
   - Production branch = `main`
   - 「非本番ブランチのビルド」を ON にする。
5. 環境変数（Workers Builds の既定は Node 22 / pnpm 10 のため上書き）:
   - `NODE_VERSION=24.17.0`
   - `PNPM_VERSION=11.8.0`

セットアップの順序は「R2 バケット作成 → wrangler.jsonc 反映 → リポジトリ連携 →
ビルド/ブランチ設定 → 初回デプロイ」とする（R2 バケットが存在しないと
binding を持つ Worker のデプロイに失敗するため）。

## 7. エラー処理・既知のトレードオフ

- プレビューは同一 Worker の「バージョン」なので、本番と同じ R2 バケット /
  binding を共有する。完全分離が必要になったら別環境・別 Worker へ分割する。
- fork からの PR でも Cloudflare 連携なら動作するが、production branch は `main`
  限定のため誤って本番へデプロイされることはない。
- R2 incremental cache は最初から有効化するが、時間ベースの revalidate
  （Durable Object Queue）や `revalidateTag` / `revalidatePath`（D1 / DO tag cache）
  は今回のスコープ外。必要になった時点で wrangler.jsonc に追加する。
- ローカルの `cf:deploy` / R2 バケット作成は `wrangler login`（OAuth）を使い、
  リポジトリにも GitHub にもトークンを保存しない。

## 8. テスト・検証方針

- ローカル: `mise run cf:preview` で workerd 上で起動し、トップページが
  表示されることを手動で確認する。
- ローカル: `mise run build`（既存）と `mise run docker:prod` が従来通り
  成功し、Docker 経路が壊れていないことを確認する。
- CI: `ci.yml` の OpenNext ビルド検証ステップが成功すること。
- Cloudflare: 初回セットアップ後、PR を1つ作ってプレビュー URL が PR に
  コメントされること、main マージで本番が更新されることを確認する。

## 9. スコープ外（YAGNI）

- Durable Object Queue / D1 / KV を使った高度なキャッシュ・revalidate。
- PR ごとの専用 Worker や独立 staging 環境。
- カスタムドメインの割り当て（必要になったら別途）。
- 方式A（GitHub Actions + API トークン）への切り替え。
