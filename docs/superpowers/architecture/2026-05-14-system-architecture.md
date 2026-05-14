# 次の教室案内システム - システムアーキテクチャ

> **確定版：ベストプラクティスアーキテクチャ**

**最終決定日:** 2026-05-14

---

## 1. 全体構成

このアーキテクチャは個人用アプリケーションの要件に対して、最小コスト・最大効率を実現するベストプラクティスです。

### フロントエンド

- **Cloudflare Pages** + React 18 SPA
- 静的ホスティング、グローバル CDN 配信
- GitHub との自動連携でデプロイ
- 無料プラン範囲内

### バックエンド

- **Cloudflare Workers** + Hono フレームワーク
- サーバーレス、冷起動なし、自動スケール
- REST API 提供
- 無料プラン範囲内（月 100 万リクエスト）

### データベース

- **Cloudflare D1** (SQLite ベース)
- 開発環境と同じ SQL 方言で完全互換
- 無料プラン範囲内（月 100 万読み取り、10 万書き込み）

### 認証

- **Google OAuth 2.0** + Firebase Admin SDK
- ドメイン検証は Workers 内で実施
- 学校ドメイン限定アクセス

---

## 2. 環境構成

### 開発環境 (Development)

```text
ローカルマシン (Linux/macOS/Windows)
├─ Frontend: npm run dev
│  └─ Vite dev server on :5173
├─ Backend: wrangler dev
│  └─ Hono on :8787
└─ Database: wrangler d1
   └─ D1 local emulation (SQLite)
```

**特徴：**

- `wrangler` CLI でローカルに Workers + D1 をフルエミュレート
- 本番環境と同じコードベース・同じ方言
- ホットリロード対応で高速開発

**初期化手順：**

```bash
npm install -g wrangler
npm install
cd frontend && npm install && cd ..
cd backend && npm install && cd ..

wrangler d1 create classroom-nav --local
wrangler d1 execute classroom-nav --local < backend/src/db/init.sql

cp backend/.env.example backend/.env.local
# → GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, ADMIN_EMAILS を設定

npm run dev
```

### ステージング環境 (Stage)

```text
Cloudflare
├─ Frontend: Cloudflare Pages
│  └─ https://stage-classroom.example.com
├─ Backend: Cloudflare Workers
│  └─ https://api-stage.example.com
└─ Database: Cloudflare D1
   └─ classroom-nav-stage
```

**特徴：**

- main ブランチへの push/merge で自動デプロイ
- 環境テスト、デプロイ検証用
- 本番に近い環境で動作確認

### 本番環境 (Production)

```text
Cloudflare
├─ Frontend: Cloudflare Pages
│  └─ https://classroom.example.com
├─ Backend: Cloudflare Workers
│  └─ https://api.example.com
└─ Database: Cloudflare D1
   └─ classroom-nav-production
```

**特徴：**

- git tag v0.1 自動デプロイで起動
- 本番用の独立したリソース
- ステージングとの完全分離

---

## 3. 技術スタック決定

| 層 | 選択技術 | 理由 |
|---|---|---|
| **Frontend** | React 18 + TypeScript + Vite | モダン、高速、型安全 |
| **Backend** | Hono（Cloudflare Workers） | Workers 最適化、低遅延、軽量 |
| **Database** | D1 (SQLite) | 開発との互換性、無料、シンプル |
| **ORM** | D1 native SQL + Drizzle ORM | SQLite 最適化、型安全 |
| **認証** | Google OAuth 2.0 | Google Workspace 統合 |
| **ホスティング** | Cloudflare Pages + Workers | 無料、自動デプロイ、CDN 統合 |

---

## 4. デプロイメントパイプライン

```text
feature/phase-N (開発ブランチ)
    ↓ git push
GitHub PR
    ↓ review & test
main ブランチ (merge)
    ↓ trigger GitHub Actions
Stage Auto Deploy
├─ Frontend: Cloudflare Pages デプロイ
├─ Backend: Cloudflare Workers デプロイ
└─ Database: D1 マイグレーション実行

ステージング環境で テスト確認
    ↓ OK
git tag v0.1 (push)
    ↓ trigger GitHub Actions
Production Auto Deploy
├─ Frontend: Cloudflare Pages デプロイ
├─ Backend: Cloudflare Workers デプロイ
└─ Database: D1 マイグレーション実行
```

**デプロイ詳細：**

### Stage デプロイ (main へのマージ時)

```bash
# GitHub Actions ワークフロー: .github/workflows/deploy-stage.yml
# トリガー: main へのマージ完了

# Frontend
cd frontend && npm run build && npm run deploy:stage

# Backend
cd backend && wrangler deploy --env stage
```

### Production デプロイ (タグ作成時)

```bash
# GitHub Actions ワークフロー: .github/workflows/deploy-production.yml
# トリガー: git tag v0.1 push

# Frontend
cd frontend && npm run build && npm run deploy:prod

# Backend
cd backend && wrangler deploy --env production
```

---

## 5. ディレクトリ構成

```text
next-pyon-tomaki/
├─ frontend/
│  ├─ src/
│  │  ├─ components/
│  │  │  ├─ HomeScreen.tsx
│  │  │  ├─ EnrollmentList.tsx
│  │  │  └─ Calendar.tsx
│  │  ├─ pages/
│  │  │  ├─ home.tsx
│  │  │  ├─ enrollments.tsx
│  │  │  ├─ admin/
│  │  │  │  └─ classes.tsx
│  │  │  └─ login.tsx
│  │  ├─ hooks/
│  │  │  ├─ useAuth.ts
│  │  │  └─ useEnrollments.ts
│  │  ├─ utils/
│  │  │  ├─ api.ts
│  │  │  └─ displayLogic.ts
│  │  ├─ App.tsx
│  │  └─ main.tsx
│  ├─ vite.config.ts
│  ├─ tsconfig.json
│  ├─ package.json
│  └─ .env.example
│
├─ backend/
│  ├─ src/
│  │  ├─ index.ts              # Worker entry point
│  │  ├─ middleware/
│  │  │  ├─ auth.ts
│  │  │  └─ errorHandler.ts
│  │  ├─ routes/
│  │  │  ├─ auth.ts
│  │  │  ├─ classes.ts
│  │  │  └─ enrollments.ts
│  │  ├─ db/
│  │  │  ├─ schema.ts
│  │  │  ├─ init.sql
│  │  │  └─ migrations/
│  │  ├─ utils/
│  │  │  ├─ displayLogic.ts
│  │  │  └─ validation.ts
│  │  └─ types/
│  │     └─ index.ts
│  ├─ wrangler.toml
│  ├─ tsconfig.json
│  ├─ package.json
│  └─ .env.example
│
├─ docs/
│  ├─ superpowers/
│  │  ├─ specs/
│  │  │  └─ 2026-04-30-classroom-navigation-design.md
│  │  ├─ plans/
│  │  │  └─ 2026-05-14-implementation.md
│  │  └─ architecture/
│  │     └─ 2026-05-14-system-architecture.md
│  └─ API.md
│
├─ .github/
│  ├─ workflows/
│  │  ├─ deploy-stage.yml
│  │  └─ deploy-production.yml
│  └─ pull_request_template.md
│
├─ .gitignore
├─ README.md
└─ package.json              # Monorepo root
```

---

## 6. 環境変数管理

### Backend (.env.example)

```env
# Google OAuth
GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=xxx
GOOGLE_WORKSPACE_DOMAIN=school.ac.jp

# Admin Management
ADMIN_EMAILS=admin@school.ac.jp,teacher@school.ac.jp

# Database
D1_DATABASE_ID=classroom-nav-local

# Environment
NODE_ENV=development
LOG_LEVEL=debug
```

### Frontend (.env.example)

```env
VITE_API_BASE_URL=http://localhost:8787
VITE_GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com
```

---

## 7. コスト試算（月額）

| サービス | 個人用 | 料金 |
|---|---|---|
| Cloudflare Pages | 無料プラン | ¥0 |
| Cloudflare Workers | 無料プラン（100 万リクエスト/月） | ¥0 |
| Cloudflare D1 | 無料プラン（100 万読み取り/月） | ¥0 |
| **合計** | **全て無料範囲内** | **¥0** |

---

## 8. 実装計画との関連

このアーキテクチャに基づき、実装計画を以下の通り更新：

### Phase 1: バックエンド基盤

1. Hono プロジェクト初期化 (wrangler)
2. D1 スキーマ定義・マイグレーション
3. Hono ルーティング基本設定
4. Google OAuth 認証実装
5. ユーザー管理 API

### Phase 2: フロントエンド基盤

1. React + Vite プロジェクト初期化
2. Google ログイン画面
3. API クライアント設定
4. 基本ルーティング

### Phase 3: 学生向け機能

1. 履修登録画面
2. 個人カレンダー生成
3. ホーム画面実装
4. 表示判定ロジック実装

### Phase 4: 管理者向け機能

1. 授業マスタ入力画面
2. 授業マスタ管理 API

### Phase 5: 検証・完成

1. 統合テスト
2. E2E テスト
3. パフォーマンステスト

---

## 9. セキュリティ考慮事項

- **CORS 設定** - Cloudflare Workers で動的 CORS 制御
- **HTTPS 強制** - Cloudflare Pages で自動 HTTPS
- **トークン管理** - JWT ベース、短命トークン
- **レート制限** - Cloudflare Workers で IP ベース制限
- **SQL インジェクション対策** - D1 パラメータ化クエリ
- **XSS 対策** - React の自動エスケープ

---

## 10. 今後のスケール対応

このアーキテクチャは以下への対応が容易：

- **ユーザー数増加** - Workers 水平スケール（自動）
- **データ量増加** - D1 は SQLite ベースで容量増加可能
- **複雑な機能追加** - Hono は Express 互換で拡張可能
- **モバイルアプリ化** - REST API は端末種別非依存

---

## 11. 参考リンク

- [Cloudflare Workers Documentation](https://developers.cloudflare.com/workers/)
- [Hono Framework](https://hono.dev/)
- [Cloudflare D1](https://developers.cloudflare.com/d1/)
- [Cloudflare Pages](https://pages.cloudflare.com/)

---

**決定事項：** このアーキテクチャをベストプラクティスとして確定し、実装を開始します。
