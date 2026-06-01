# Docker Compose 開発環境設計

**作成日**: 2026-06-01  
**バージョン**: v0.1  
**プロジェクト**: next-pyon-tomaki

---

## 目的

開発者が Docker コンテナ内で Next.js アプリケーションを実行できる統一開発環境を構築する。Node.js のローカルインストール不要で、macOS / Windows / Linux で同一の開発体験を提供する。

---

## スコープ

### 対象

- Next.js 14+ 開発サーバー（ホットリロード機能）
- SQLite データベース（Prisma ORM）
- Prisma マイグレーション自動実行
- 環境変数管理

### スコープ外

- 本番環境用 Docker 設定（v0.2 以降）
- Kubernetes / Orchestration 対応（今後検討）
- マルチコンテナ設定（Nginx、Redis など）

---

## 全体構成

### ファイル構造

```text
next-pyon-tomaki/
├── compose.dev.yaml              # Docker Compose 開発環境設定
├── next-app/                      # Next.js アプリケーション
│   ├── dev.Dockerfile            # 開発用 Dockerfile
│   ├── package.json              # next-app パッケージ定義
│   ├── pnpm-lock.yaml            # 依存関係ロック
│   ├── tsconfig.json
│   ├── next.config.js
│   ├── src/                       # ボリュームマウント対象
│   │   ├── app/
│   │   ├── components/
│   │   ├── lib/
│   │   └── ...
│   ├── public/                    # ボリュームマウント対象
│   └── __tests__/
├── prisma/
│   ├── schema.prisma             # Prisma スキーマ
│   └── migrations/               # マイグレーション履歴
├── .env.local.example            # 環境変数テンプレート
├── .dockerignore                 # Docker ビルド除外設定
├── data/                         # SQLite 永続化ディレクトリ（ホスト側）
└── scripts/
    └── init-docker.sh            # Docker 初期化スクリプト
```

---

## ファイル仕様

### 1. **compose.dev.yaml**

```yaml
version: "3.8"

services:
  next-app:
    container_name: next-pyon-tomaki-dev
    build:
      context: ./next-app
      dockerfile: dev.Dockerfile
    
    environment:
      # Next.js 設定
      NODE_ENV: development
      NEXT_TELEMETRY_DISABLED: 1
      
      # Database
      DATABASE_URL: file:./data/dev.db
      
      # API
      NEXT_PUBLIC_API_URL: http://localhost:3000
      
      # School Config（.env.local から上書き可）
      SCHOOL_EMAIL_DOMAIN: ${SCHOOL_EMAIL_DOMAIN:-@school.ac.jp}
      ADMIN_EMAILS: ${ADMIN_EMAILS:-admin@school.ac.jp}
    
    # .env.local ファイルから環境変数をロード
    env_file:
      - .env.local
    
    # ボリュームマウント
    volumes:
      # ソースコードのホットリロード対応
      - ./next-app/src:/app/src
      - ./next-app/public:/app/public
      
      # SQLite 永続化（ホスト側）
      - ./data:/app/data
      
      # node_modules は コンテナ内のみ（上書きしない）
      - /app/node_modules
      - /app/.next
    
    # ポート設定
    ports:
      - 3000:3000
    
    # 自動再起動
    restart: always
    
    # ネットワーク
    networks:
      - my_network

# Docker ネットワーク定義
networks:
  my_network:
    external: true
```

### 2. **next-app/dev.Dockerfile**

```Dockerfile
# syntax=docker.io/docker/dockerfile:1

FROM node:24-alpine

WORKDIR /app

# Install pnpm
RUN corepack enable pnpm

# Install dependencies
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Copy source code
COPY src ./src
COPY public ./public
COPY tsconfig.json .
COPY next.config.js .
COPY prisma ./prisma

# Prisma generate
RUN pnpm prisma generate

# Start development server with migration
CMD sh -c "pnpm prisma migrate deploy && pnpm dev"
```

**重要**: `prisma migrate deploy` は本番・開発環境で安全に実行可能なコマンド。既に適用済みマイグレーションはスキップされる。

### 3. **.env.local.example**

```bash
# Database
```
DATABASE_URL="file:./data/dev.db"

# Google OAuth
GOOGLE_CLIENT_ID=YOUR_GOOGLE_CLIENT_ID_HERE
GOOGLE_CLIENT_SECRET=YOUR_GOOGLE_CLIENT_SECRET_HERE
GOOGLE_REDIRECT_URI=http://localhost:3000/api/auth/callback

# Firebase Admin SDK
FIREBASE_PROJECT_ID=your-firebase-project
FIREBASE_PRIVATE_KEY=YOUR_FIREBASE_PRIVATE_KEY_HERE
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@your-project.iam.gserviceaccount.com

# Application
NEXT_PUBLIC_API_URL=http://localhost:3000
JWT_SECRET=dev-jwt-secret-key-min-32-chars-for-development
SCHOOL_EMAIL_DOMAIN=@school.ac.jp
ADMIN_EMAILS=admin1@school.ac.jp,admin2@school.ac.jp
```

```bash

### 4. **.dockerignore**

```
node_modules
.git
.gitignore
.github
.env
.env.local
.env.*.local
.next
dist
.DS_Store
Dockerfile
docker-compose*.yaml
README.md
docs
.husky
.vscode
```

### 5. **scripts/init-docker.sh**

```bash
#!/bin/bash

set -e

echo "🐳 Docker Compose 開発環境を初期化しています..."

# 1. Docker ネットワーク作成
echo "📡 Docker ネットワークを作成中..."
docker network create my_network 2>/dev/null || echo "  (ネットワークは既に存在します)"

# 2. data ディレクトリ作成
echo "📁 データディレクトリを作成中..."
mkdir -p ./data

# 3. .env.local の確認
if [ ! -f .env.local ]; then
  echo "⚠️  .env.local が見つかりません"
  echo "   .env.local.example をコピーして設定してください："
  echo "   $ cp .env.local.example .env.local"
  exit 1
fi

# 4. Docker イメージビルド
echo "🔨 Docker イメージをビルド中..."
docker compose -f compose.dev.yaml build

# 5. Docker コンテナ起動
echo "🚀 Docker コンテナを起動中..."
docker compose -f compose.dev.yaml up

echo "✅ セットアップ完了！"
echo "   http://localhost:3000 でアプリケーションを確認できます"
```

---

## 開発フロー

### 初回セットアップ

```bash
# 1. リポジトリをクローン
git clone https://github.com/morijyobi-2026-devops/next-pyon-tomaki.git
cd next-pyon-tomaki

# 2. 環境変数を設定
cp .env.local.example .env.local
# .env.local を編集（Google OAuth、Firebase などの認証情報を設定）

# 3. Docker セットアップを実行
chmod +x scripts/init-docker.sh
./scripts/init-docker.sh
```

### 開発時の作業

```bash
# コンテナが起動中の状態で、ホスト側でコード編集
# → ボリュームマウント経由で自動同期
# → Next.js ホットリロード

# 別ターミナル: コンテナシェルアクセス
docker compose -f compose.dev.yaml exec next-app sh

# コンテナ再起動（マイグレーション再実行など）
docker compose -f compose.dev.yaml restart

# コンテナ停止
docker compose -f compose.dev.yaml down
```

### Prisma マイグレーション追加時

```bash
# ホスト側で schema.prisma を編集後、コンテナ内でマイグレーション作成
docker compose -f compose.dev.yaml exec next-app \
  pnpm prisma migrate dev --name add_your_feature

# マイグレーションファイルが ./prisma/migrations に自動保存される
```

---

## ボリュームマウント戦略

### マウント対象

| パス | 目的 | 理由 |
|------|------|------|
| `./next-app/src:/app/src` | ホットリロード | ソースコード編集時にすぐ反映 |
| `./next-app/public:/app/public` | 静的ファイル | public/favicon など |
| `./data:/app/data` | SQLite 永続化 | コンテナ再起動後もデータ保持 |

### マウント非対象（コンテナ内のみ）

| パス | 理由 |
|------|------|
| `/app/node_modules` | ビルド時に再インストール（ホスト側との競合回避） |
| `/app/.next` | Next.js キャッシュ（コンテナ内のみ） |

---

## パフォーマンス最適化

### 1. **.dockerignore による除外**

- `node_modules` をビルドコンテキストから除外
- ビルド時間を短縮

### 2. **pnpm-lock.yaml の固定**

- `--frozen-lockfile` でロックファイル固定
- 開発環境の再現性向上

### 3. **Docker キャッシング**

- 各レイヤーがキャッシュされる
- 依存関係ファイルが変更されなければ再インストール不要

---

## トラブルシューティング

### ポート 3000 がすでに使用中

```bash
# 使用中のプロセスを確認
lsof -i :3000

# 別のポートを使用
# compose.dev.yaml の ports を変更: 3001:3000
```

### SQLite ファイルが見つからない

```bash
# data ディレクトリが存在するか確認
ls -la ./data

# 手動でディレクトリ作成
mkdir -p ./data

# コンテナ再起動（Prisma が db を自動作成）
docker compose -f compose.dev.yaml restart
```

### ホットリロードが機能しない

```bash
# src/ ディレクトリが正しくマウントされているか確認
docker compose -f compose.dev.yaml exec next-app ls -la /app/src

# Docker Desktop 設定を確認（macOS の場合）
# - Preferences → Resources → File Sharing で next-pyon-tomaki を追加
```

---

## セキュリティ考慮事項

### 開発環境

- `.env.local` には機密情報（API キー）を記載
- `.gitignore` に `.env.local` を追加（既存）
- 本番キーは絶対に開発環境に含めない

### 本番環境（v0.2 以降）

- Dockerfile マルチステージビルド
- `node_modules` プルーニング
- Cloudflare D1 への移行

---

## 次のステップ

このドキュメントをレビューして、以下の実装タスクに進みます：

1. `next-app/` ディレクトリ作成 & Next.js 初期化
2. `dev.Dockerfile` 作成
3. `compose.dev.yaml` 作成
4. `.dockerignore` 作成
5. `scripts/init-docker.sh` 作成
6. 環境変数テンプレート設定

---

## 設計完了
