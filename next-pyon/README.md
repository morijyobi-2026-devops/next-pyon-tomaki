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

OpenNext（`@opennextjs/cloudflare`）を使って Cloudflare Pages 向けにビルド・
デプロイするためのタスクをまとめてある。

```bash
mise run cf:build    # OpenNext で Cloudflare 向けビルド
mise run cf:preview  # workerd でローカル起動（http://localhost:8787）
mise run cf:deploy   # 手動デプロイ（要 wrangler login）
```

### デプロイの仕組み（GitHub Actions 連携）

デプロイは GitHub Actions ワークフロー（`ci.yml` / `cd.yml`）によって自動化されている。

- **プレビューデプロイ (Staging)**
  - PR 作成・更新時に `ci.yml` が走り、ビルドした `.open-next` 成果物を GitHub Actions が `wrangler pages deploy` で Cloudflare Pages のプレビュー環境へデプロイします。
  - デプロイ完了後、プレビュー URL が自動で PR にコメントされます。
- **本番デプロイ (Production)**
  - `main` ブランチへマージされた際に `cd.yml` が走り、本番 D1 データベースへのマイグレーション適用後、本番環境へデプロイされます。

### セットアップ（一度きり）

プロジェクトを初めて Cloudflare にデプロイする際の手順。

1. **Cloudflare アカウントの準備**
   - Cloudflare のアカウントを用意し、アカウント ID を取得します。
   - Cloudflare Pages の管理画面から、空の Pages プロジェクト `next-pyon` を作成します（または初回デプロイ時に自動作成されます）。

2. **API トークンの発行**
   - Cloudflare のダッシュボードから、以下の権限を持つ API トークンを発行します。
     - `Cloudflare Pages: 編集`
     - `D1: 編集`

3. **GitHub Secrets の設定**
   - GitHub リポジトリの `Settings -> Secrets and variables -> Actions` に以下を登録します。
     - `CLOUDFLARE_API_TOKEN` : 発行した API トークン
     - `CLOUDFLARE_ACCOUNT_ID` : Cloudflare アカウント ID

> **incremental cache（R2）について** — 現状このアプリは全ページ static のため、OpenNext の incremental cache（R2）は使っていません。将来 ISR / 動的ルートを追加して永続キャッシュが必要になったら、Cloudflare ダッシュボードで R2 を有効化し、R2 バケットを作成したうえで `open-next.config.ts` に `incrementalCache` を設定し直し、`wrangler.jsonc` に R2 binding を追加してください。

## 構成

- Next.js (App Router) + React 19 + TypeScript
- Tailwind CSS v4
- エントリーポイント: `app/page.tsx`、レイアウト: `app/layout.tsx`
