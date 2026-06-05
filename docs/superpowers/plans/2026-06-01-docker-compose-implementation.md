# Docker Compose 開発環境セットアップ 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended)
> or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Docker Compose で Next.js 開発サーバーを完全に動作させる環境を構築する。Node.js をホストに インストール不要で、SQLite データベース永続化と Prisma マイグレーション自動実行を実現する

**Architecture:**

`next-pyon/` ディレクトリ内に Next.js アプリケーションを配置し、`compose.dev.yaml` で管理。
開発ファイル（src/, public/）はボリュームマウントでホットリロード対応。
SQLite ファイルはホスト側（./data/）に永続化。Dockerfile の CMD で起動時にマイグレーション自動実行。

**Tech Stack:**

Docker 20.10+, Docker Compose 1.29+, Node.js 24-alpine, Next.js 14+, pnpm 9.15.9, Prisma ORM, SQLite 3

---

## ファイル構造

作成・修正するファイル一覧：

| ファイル | 種別 | 説明 |
|---------|------|------|
| `compose.dev.yaml` | 新規 | Docker Compose 開発環境設定 |
| `next-pyon/dev.Dockerfile` | 新規 | 開発用 Dockerfile |
| `next-pyon/package.json` | 新規 | Next.js 用 package.json |
| `next-pyon/.gitignore` | 新規 | Next.js 用 .gitignore |
| `next-pyon/tsconfig.json` | 新規 | TypeScript 設定 |
| `next-pyon/next.config.js` | 新規 | Next.js 設定 |
| `.dockerignore` | 新規 | Docker ビルド除外設定 |
| `.env.local.example` | 新規 | 環境変数テンプレート |
| `scripts/init-docker.sh` | 新規 | Docker 初期化・起動スクリプト |
| `data/.gitkeep` | 新規 | SQLite 永続化ディレクトリ（git 追跡用） |

---

## タスク分割

### Task 1: Next.js プロジェクト ディレクトリ構造の初期化

**Files:**

- Create: `next-pyon/package.json`
- Create: `next-pyon/tsconfig.json`
- Create: `next-pyon/next.config.js`
- Create: `next-pyon/.gitignore`
- Create: `next-pyon/src/.gitkeep`
- Create: `next-pyon/public/.gitkeep`

**目的:** Next.js アプリケーションのベースディレクトリと設定ファイルを作成

- [ ] **Step 1: next-pyon/package.json を作成**

```json
{
  "name": "next-pyon-tomaki-app",
  "version": "0.1.0",
  "description": "Next.js application for next-pyon-tomaki",
  "private": true,
  "packageManager": "pnpm@9.15.9",
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "migrate": "prisma migrate deploy"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "next": "^14.0.0",
    "@prisma/client": "^5.0.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/node": "^20.0.0",
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "autoprefixer": "^10.4.0",
    "postcss": "^8.4.0",
    "tailwindcss": "^3.3.0",
    "prisma": "^5.0.0"
  }
}
```

- [ ] **Step 2: next-pyon/tsconfig.json を作成**

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "noEmit": true,
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    "skipDefaultLibCheck": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
```

- [ ] **Step 3: next-pyon/next.config.js を作成**

```ts
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
}

module.exports = nextConfig
```

- [ ] **Step 4: next-pyon/.gitignore を作成**

```text
# Dependencies
node_modules
.pnp
.pnp.js

# Testing
coverage

# Next.js
.next
out
dist

# Production
build

# Misc
.DS_Store
*.pem

# Debug
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Local env files
.env
.env.local
.env.*.local

# IDE
.vscode
.idea
*.swp
*.swo
*~

# OS
.DS_Store
```

- [ ] **Step 5: next-pyon/src/.gitkeep と public/.gitkeep を作成**

```bash
mkdir -p next-pyon/src next-pyon/public
touch next-pyon/src/.gitkeep next-pyon/public/.gitkeep
```

- [ ] **Step 6: コミット**

```bash
git add next-pyon/
git commit -m "feat: initialize Next.js project structure

- Create next-pyon directory with package.json
- Add TypeScript configuration
- Set up Next.js config with SWC minification
- Initialize src/ and public/ directories

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 2: dev.Dockerfile を作成

**Files:**

- Create: `next-pyon/dev.Dockerfile`

**目的:** Node.js 24-alpine ベースの開発用 Dockerfile を作成。Prisma マイグレーション自動実行対応

- [ ] **Step 1: next-pyon/dev.Dockerfile を作成**

```text
# syntax=docker.io/docker/dockerfile:1

FROM node:24-alpine

WORKDIR /app

# Install pnpm globally
RUN corepack enable pnpm

# Copy package files
COPY package.json pnpm-lock.yaml ./

# Install dependencies with frozen lockfile
RUN pnpm install --frozen-lockfile

# Copy configuration files
COPY tsconfig.json .
COPY next.config.js .

# Copy Prisma schema
COPY prisma ./prisma

# Generate Prisma client
RUN pnpm prisma generate

# Copy source code
COPY src ./src
COPY public ./public

# Expose port 3000
EXPOSE 3000

# Start development server with Prisma migration
CMD sh -c "pnpm prisma migrate deploy && pnpm dev"
```

- [ ] **Step 2: コミット**

```bash
git add next-pyon/dev.Dockerfile
git commit -m "feat: add development Dockerfile for Next.js

- Base image: node:24-alpine
- Install pnpm and dependencies with frozen-lockfile
- Generate Prisma client during build
- Auto-run prisma migrate deploy on container startup
- Start Next.js dev server on port 3000

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 3: compose.dev.yaml を作成

**Files:**

- Create: `compose.dev.yaml`

**目的:** Docker Compose で Next.js サービスを定義。ボリュームマウント、環境変数、ネットワーク設定を含む

- [ ] **Step 1: compose.dev.yaml を作成**

```text
version: "3.8"

services:
  next-pyon:
    container_name: next-pyon-tomaki-dev
    build:
      context: ./next-pyon
      dockerfile: dev.Dockerfile
    
    environment:
      NODE_ENV: development
      NEXT_TELEMETRY_DISABLED: 1
      DATABASE_URL: file:./data/dev.db
      NEXT_PUBLIC_API_URL: http://localhost:3000
      SCHOOL_EMAIL_DOMAIN: ${SCHOOL_EMAIL_DOMAIN:-@school.ac.jp}
      ADMIN_EMAILS: ${ADMIN_EMAILS:-admin@school.ac.jp}
    
    env_file:
      - .env.local
    
    volumes:
      - ./next-pyon/src:/app/src
      - ./next-pyon/public:/app/public
      - ./data:/app/data
      - /app/node_modules
      - /app/.next
    
    ports:
      - "3000:3000"
    
    restart: always
    
    networks:
      - my_network

networks:
  my_network:
    external: true
```

- [ ] **Step 2: コミット**

```bash
git add compose.dev.yaml
git commit -m "feat: add Docker Compose development configuration

- Define next-pyon service with Node.js 24-alpine
- Volume mounts for hot-reload (src/, public/)
- SQLite persistence via ./data volume
- Environment variables from .env.local
- External network 'my_network' for multi-container support

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 4: .dockerignore を作成

**Files:**

- Create: `.dockerignore`

**目的:** Docker ビルドコンテキストから不要なファイルを除外。ビルド時間を短縮

- [ ] **Step 1: .dockerignore を作成**

```text
node_modules
.git
.gitignore
.github
.husky
.env
.env.local
.env.*.local
.next
dist
.DS_Store
Dockerfile
dev.Dockerfile
compose.dev.yaml
compose.prod.yaml
compose.prod-without-multistage.yaml
README.md
docs
.vscode
.idea
*.log
.cache
coverage
```

- [ ] **Step 2: コミット**

```bash
git add .dockerignore
git commit -m "feat: add Docker build exclusion rules

- Exclude node_modules for clean builds
- Ignore git, IDE, and log files
- Exclude Docker/Compose configs
- Reduce build context size and build time

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 5: .env.local.example を作成

**Files:**

- Create: `.env.local.example`

**目的:** 環境変数のテンプレート。開発者が設定時に参考にする

- [ ] **Step 1: .env.local.example を作成**

```bash
# Database
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

- [ ] **Step 2: .gitignore で .env.local を除外（確認）**

```bash
# 既存の .gitignore に .env.local が含まれているか確認
grep -q ".env.local" .gitignore && echo "Already present" || echo "Need to add"
```

- [ ] **Step 3: コミット**

```bash
git add .env.local.example
git commit -m "docs: add environment variables template

- DATABASE_URL for SQLite development database
- Google OAuth configuration placeholders
- Firebase Admin SDK credentials
- JWT secret and school configuration

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 6: scripts/init-docker.sh を作成

**Files:**

- Create: `scripts/init-docker.sh`

**目的:** Docker セットアップと起動を自動化するスクリプト

- [ ] **Step 1: scripts/init-docker.sh を作成**

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
  echo ""
  echo "⚠️  警告: .env.local が見つかりません"
  echo "   以下のコマンドで .env.local を作成してください："
  echo "   $ cp .env.local.example .env.local"
  echo ""
  echo "   その後、Google OAuth や Firebase の認証情報を設定してください"
  exit 1
fi

# 4. Docker イメージビルド
echo ""
echo "🔨 Docker イメージをビルド中..."
docker compose -f compose.dev.yaml build

# 5. Docker コンテナ起動
echo ""
echo "🚀 Docker コンテナを起動中..."
docker compose -f compose.dev.yaml up

echo ""
echo "✅ セットアップ完了！"
echo "   ブラウザで http://localhost:3000 にアクセスしてください"
```

- [ ] **Step 2: スクリプトに実行権限を付与**

```bash
chmod +x scripts/init-docker.sh
```

- [ ] **Step 3: コミット**

```bash
git add scripts/init-docker.sh
git commit -m "feat: add Docker initialization script

- Create Docker network (my_network)
- Create data directory for SQLite persistence
- Validate .env.local exists
- Build and start Docker Compose services
- Provide helpful error messages

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 7: SQLite 永続化ディレクトリの初期化

**Files:**

- Create: `data/.gitkeep`

**目的:** SQLite データベースファイルを永続化するディレクトリを git で追跡可能にする

- [ ] **Step 1: data ディレクトリと .gitkeep を作成**

```bash
mkdir -p data
touch data/.gitkeep
```

- [ ] **Step 2: コミット**

```bash
git add data/.gitkeep
git commit -m "feat: create data directory for SQLite persistence

- SQLite database files will be stored here
- .gitkeep ensures directory is tracked by git
- Database files are excluded from git (.gitignore)

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 8: セットアップ検証と動作確認

**Files:**

- Verify: `compose.dev.yaml`
- Verify: `next-pyon/dev.Dockerfile`
- Verify: `scripts/init-docker.sh`

**目的:** Docker Compose セットアップが正しく動作することを確認

- [ ] **Step 1: Docker がインストール・実行中か確認**

```bash
docker --version
docker compose version
```

**Expected output:**

```text
Docker version 20.10.0+
Docker Compose version 1.29.0+
```

- [ ] **Step 2: .env.local を作成**

```bash
cp .env.local.example .env.local
```

- [ ] **Step 3: Docker ネットワークを手動作成**

```bash
docker network create my_network 2>/dev/null || true
```

- [ ] **Step 4: docker-compose build で Dockerfile をテスト**

```bash
docker compose -f compose.dev.yaml build
```

**Expected:** ビルドが成功し、Node.js 24-alpine イメージが作成される

- [ ] **Step 5: docker-compose up で起動テスト（タイムアウト 30 秒）**

```bash
timeout 30 docker compose -f compose.dev.yaml up || true
```

**Expected:** コンテナが起動し、以下のログが表示される：

```text
next-pyon | > next-pyon-tomaki-app@0.1.0 dev
next-pyon | > next dev
next-pyon | ▲ Next.js 14.x.x
next-pyon | - Local: http://localhost:3000
```

- [ ] **Step 6: コンテナの状態を確認（別ターミナル）**

```bash
docker ps | grep next-pyon-tomaki-dev
```

**Expected:** コンテナが `up` 状態で実行中

- [ ] **Step 7: 動作確認（curl テスト）**

```bash
# コンテナが実行中の場合のみ実行
curl -s http://localhost:3000 | head -20
```

**Expected:** Next.js の HTML レスポンスが返される（または接続タイムアウト）

- [ ] **Step 8: コンテナを停止**

```bash
docker compose -f compose.dev.yaml down
```

- [ ] **Step 9: 確認レポートをコミット**

```bash
# テスト成功時のみコミット
git status
```

---

## Spec カバレッジチェック

| Spec要件 | 実装タスク | 状態 |
|---------|----------|------|
| Next.js アプリケーション構造 | Task 1 | ✅ |
| 開発用 Dockerfile（Node.js 24） | Task 2 | ✅ |
| Docker Compose 設定（ボリュームマウント） | Task 3 | ✅ |
| Docker ビルド最適化（.dockerignore） | Task 4 | ✅ |
| 環境変数管理テンプレート | Task 5 | ✅ |
| Docker 初期化スクリプト | Task 6 | ✅ |
| SQLite 永続化ディレクトリ | Task 7 | ✅ |
| セットアップ検証 | Task 8 | ✅ |

✅ **Spec カバレッジ 100%**

---

## 実装完了後の確認項目

```bash
# セットアップ実行
./scripts/init-docker.sh

# ブラウザで確認
# http://localhost:3000

# 開発時のコンテナアクセス
docker compose -f compose.dev.yaml exec next-pyon sh

# ホットリロード確認
# src/ 内のファイルを編集してブラウザを見る

# Prisma マイグレーション確認
docker compose -f compose.dev.yaml exec next-pyon pnpm prisma migrate status
```

---

## 次のステップ

このプランで実装を進めますか？以下から選択してください：

1. **Subagent-Driven（推奨）** - タスクごとに独立した subagent で実行、タスク間でレビュー
2. **Inline Execution** - 当セッションで executing-plans で実行、checkpoint ごとにレビュー
