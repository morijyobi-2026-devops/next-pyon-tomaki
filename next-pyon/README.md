# next-pyon

[Next.js](https://nextjs.org) を使った Web アプリケーション。
[OpenNext](https://opennext.js.org) を用いて Cloudflare 上で動かすことを想定している。

このディレクトリはリポジトリルートの pnpm workspace の 1 パッケージとして管理されている。

## 開発

よく使うコマンドはリポジトリルートの mise タスクとして用意してある。
どのディレクトリからでも実行できる。

```bash
mise run dev      # 開発サーバー (http://localhost:3000)
mise run build    # 本番ビルド
mise run start    # ビルド成果物の起動
mise run lint     # ESLint
```

タスクの実体は `mise-tasks/` 配下のスクリプトで、内部では
`pnpm --filter next-pyon <script>` を呼んでいる。pnpm を直接使ってもよい。

```bash
pnpm --filter next-pyon dev   # ルートから
cd next-pyon && pnpm dev      # このディレクトリから
```

## Docker / Docker Compose

ローカルに Node.js / pnpm を用意せずに、コンテナで開発・本番起動を試せる。
これらも mise タスクにまとめてある（どのディレクトリからでも実行可）。

```bash
mise run docker:dev          # dev サーバー起動 (http://localhost:3000)
mise run docker:dev:build    # dev イメージをビルド
mise run docker:prod         # prod サーバー起動（standalone, --build 込み）
mise run docker:prod:build   # prod イメージをビルド
mise run docker:down         # dev / prod のコンテナを停止・削除
```

- `compose.dev.yaml` / `compose.prod.yaml` と各 `*.Dockerfile` はリポジトリルートと
  この `next-pyon/` に置いてある。
- ビルドコンテキストはリポジトリルート。pnpm workspace のロックファイル
  （`pnpm-lock.yaml`）と `pnpm-workspace.yaml` がルートにあるため。
- dev は `next-pyon/` を bind mount してホットリロードする。`node_modules` と
  `.next` は匿名ボリュームでコンテナ内のものを保持する。
- prod は `next.config.ts` の `output: "standalone"` を使った軽量イメージ。
- 環境変数が必要な場合はリポジトリルートに `.env` を置けば自動で読み込まれる
  （無くてもエラーにはならない）。

## Cloudflare

OpenNext（`@opennextjs/cloudflare`）を使って Cloudflare Workers 向けにビルド・
デプロイするためのタスクをまとめてある。

```bash
mise run cf:build    # OpenNext で Cloudflare 向けビルド
mise run cf:preview  # workerd でローカル起動（http://localhost:8787）
mise run cf:deploy   # 手動デプロイ（要 wrangler login）
```

### デプロイの仕組み（Cloudflare Workers Builds）

デプロイは **Cloudflare Workers Builds** のネイティブ連携で自動化されている。
GitHub に API トークンは登録しない。

- PR 作成・更新 → Cloudflare が `wrangler versions upload` でプレビュー URL を生成し、
  PR にコメント（ステージング）。
- main へ merge → Cloudflare が `wrangler deploy` で本番に反映。

### Cloudflare 側セットアップ（一度きり）

リポジトリに初めて Cloudflare 連携を行う際の手順。
順序は リポジトリ連携 → ビルド/ブランチ設定 → 初回デプロイ。

1. **リポジトリ連携** — Cloudflare ダッシュボードの Workers Builds から
   GitHub App 連携（OAuth 認可）でこのリポジトリを追加する。

2. **ビルド / ブランチ設定** — Workers Builds のビルド設定画面で以下の通り設定する。

   - Root directory = リポジトリルート
   - Build command = `pnpm --filter next-pyon exec opennextjs-cloudflare build`
   - 本番 Deploy command = `pnpm --filter next-pyon exec wrangler deploy`
   - 非本番 Deploy command = `pnpm --filter next-pyon exec wrangler versions upload`
   - Production branch = `main`、「非本番ブランチのビルド」を ON にする
   - 環境変数: `NODE_VERSION=24.17.0`、`PNPM_VERSION=11.8.0`

3. **初回デプロイ** — 設定完了後、main ブランチへ push または Workers Builds
   ダッシュボードから手動でビルドをトリガーする。

> **incremental cache（R2）について** — 現状このアプリは全ページ static のため、
> OpenNext の incremental cache（R2）は使っていない。将来 ISR / 動的ルートを追加して
> 永続キャッシュが必要になったら、Cloudflare ダッシュボードで R2 を有効化し、R2 バケット
> を作成（`wrangler r2 bucket create next-pyon-inc-cache`）したうえで、
> `open-next.config.ts` に `incrementalCache` を、`wrangler.jsonc` に R2 binding を戻す。

## 構成

- Next.js (App Router) + React 19 + TypeScript
- Tailwind CSS v4
- エントリーポイント: `app/page.tsx`、レイアウト: `app/layout.tsx`
