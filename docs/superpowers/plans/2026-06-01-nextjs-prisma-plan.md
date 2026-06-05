# 次の教室案内システム 実装計画 (Next.js + Prisma スタック)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended)
> or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Next.js + Prisma ベースで、Google Workspace 認証・授業管理・履修登録・ホーム表示を備えた個人用 Web アプリを ver0.1 で完成させる

**Architecture:**

- **フロントエンド・バックエンド統合**: Next.js 14+ で API Routes/App Router を統合。フロントエンドとバックエンドを単一リポジトリで管理
- **Development 環境**: Node.js + SQLite + Prisma（ローカル開発）
- **Production 環境**: Cloudflare Functions + Cloudflare D1 + Prisma（エッジ実行）
- **ORM**: Prisma で両環境のマイグレーション・型安全性を統一管理
- **認証**: Google OAuth 2.0 + Firebase Admin SDK で認証検証、JWT トークン発行

**Tech Stack:**

- Frontend: Next.js 14+, TypeScript, React 18+, TailwindCSS
- Backend: Next.js API Routes, TypeScript, Prisma ORM
- Development DB: SQLite3 + better-sqlite3
- Production DB: Cloudflare D1 (SQLite-compatible)
- Auth: Google OAuth 2.0, Firebase Admin SDK, jsonwebtoken
- Testing: Vitest (frontend), Jest (backend/API)
- Deployment: Cloudflare Pages (frontend) + Cloudflare Functions (backend)

---

## ファイル構造

```text
next-pyon-tomaki/
├── .env.local.example              # 環境変数テンプレート
├── package.json                    # monorepo ルート
├── pnpm-workspace.yaml             # monorepo 設定
├── tsconfig.json                   # TypeScript 共通設定
├── prisma/
│   ├── schema.prisma               # データベーススキーマ定義
│   ├── migrations/                 # Prisma マイグレーション履歴
│   └── seed.ts                     # 開発用シード データ
├── app/
│   ├── app/
│   │   ├── page.tsx                # ホームページ (Next.js App Router)
│   │   ├── layout.tsx              # ルートレイアウト
│   │   ├── globals.css             # グローバルスタイル
│   │   ├── (auth)/
│   │   │   ├── login/
│   │   │   │   └── page.tsx        # ログインページ
│   │   │   └── callback/
│   │   │       └── page.tsx        # OAuth コールバック処理
│   │   ├── (dashboard)/
│   │   │   ├── enrollments/
│   │   │   │   └── page.tsx        # 履修登録ページ
│   │   │   ├── calendar/
│   │   │   │   └── page.tsx        # カレンダー表示ページ
│   │   │   └── layout.tsx          # ダッシュボードレイアウト
│   │   └── (admin)/
│   │       ├── classes/
│   │       │   └── page.tsx        # 授業管理ページ
│   │       └── layout.tsx          # 管理者レイアウト
│   ├── api/
│   │   ├── auth/
│   │   │   └── google/
│   │   │       └── route.ts        # POST /api/auth/google (OAuth検証・JWT発行)
│   │   ├── classes/
│   │   │   ├── route.ts            # GET/POST /api/classes
│   │   │   └── [id]/
│   │   │       ├── route.ts        # PUT/DELETE /api/classes/[id]
│   │   │       └── sync/
│   │   │           └── route.ts    # POST /api/classes/[id]/sync (D1同期)
│   │   ├── enrollments/
│   │   │   ├── route.ts            # GET/POST /api/enrollments
│   │   │   └── [id]/
│   │   │       └── route.ts        # DELETE /api/enrollments/[id]
│   │   └── display-state/
│   │       └── route.ts            # GET /api/display-state (表示判定)
│   ├── lib/
│   │   ├── auth.ts                 # 認証ユーティリティ (Google OAuth検証・JWT)
│   │   ├── prisma.ts               # Prisma クライアント
│   │   ├── display-logic.ts        # 表示判定ロジック
│   │   └── constants.ts            # 定数（スクール設定など）
│   ├── middleware.ts               # Next.js middleware (JWT検証)
│   ├── components/
│   │   ├── GoogleLoginButton.tsx   # Google ログインボタン
│   │   ├── ClassSelector.tsx       # 授業選択コンポーネント
│   │   ├── NextClassDisplay.tsx    # 次の授業表示
│   │   ├── AdminClassForm.tsx      # 授業登録フォーム
│   │   └── NavBar.tsx              # ナビゲーションバー
│   ├── hooks/
│   │   ├── useAuth.ts              # 認証フック
│   │   ├── useEnrollments.ts       # 履修情報フック
│   │   └── useDisplayState.ts      # 表示状態フック
│   ├── types/
│   │   └── index.ts                # 共通型定義
│   ├── __tests__/
│   │   ├── api/
│   │   │   ├── auth.test.ts
│   │   │   ├── classes.test.ts
│   │   │   └── enrollments.test.ts
│   │   ├── lib/
│   │   │   └── display-logic.test.ts
│   │   └── components/
│   │       └── NextClassDisplay.test.tsx
│   ├── public/                     # 静的ファイル
│   └── next.config.js              # Next.js 設定
│
├── scripts/
│   ├── setup-db.ts                 # データベース初期化スクリプト
│   └── seed-dev-data.ts            # 開発用シードデータ投入
│
├── docs/
│   └── superpowers/
│       ├── specs/
│       │   ├── 2026-04-30-classroom-navigation-design.md
│       │   └── 2026-05-28-supply-chain-security-design.md
│       ├── plans/
│       │   ├── 2026-05-14-implementation.md (旧 Express版)
│       │   └── 2026-06-01-nextjs-prisma-plan.md (THIS FILE)
│       └── architecture/
│           └── 2026-05-14-system-architecture.md
│
└── wrangler.toml                   # Cloudflare Workers 設定
```

---

## 環境変数テンプレート

### `.env.local.example`

```bash
# Database
DATABASE_URL="file:./dev.db"          # Development: SQLite
# DATABASE_URL="postgresql://..."    # Production (不要 - D1使用)

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
JWT_SECRET=your-jwt-secret-key-min-32-chars-for-local-dev
SCHOOL_EMAIL_DOMAIN=@school.ac.jp
ADMIN_EMAILS=admin1@school.ac.jp,admin2@school.ac.jp

# Cloudflare (Production only)
CLOUDFLARE_ACCOUNT_ID=your-account-id
CLOUDFLARE_DATABASE_ID=your-d1-database-id
CLOUDFLARE_API_TOKEN=your-api-token
```

---

## Prisma スキーマ

### `prisma/schema.prisma`

```text
// This is your Prisma schema file,
// learn more about it in the docs: https://pris.ly/d/prisma-schema

generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "sqlite"  // Development; Cloudflare D1 対応
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String
  isAdmin   Boolean  @default(false)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  enrollments Enrollment[]

  @@map("users")
}

model Class {
  id        String   @id @default(cuid())
  name      String
  dayOfWeek Int      // 0: Sun, 1: Mon, ... 6: Sat
  period    Int      // 時限 (1-8)
  startTime String   // "HH:MM"
  endTime   String   // "HH:MM"
  room      String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  enrollments Enrollment[]

  @@unique([dayOfWeek, period, startTime, endTime])
  @@map("classes")
}

model Enrollment {
  id        String   @id @default(cuid())
  userId    String
  classId   String
  createdAt DateTime @default(now())

  user  User  @relation(fields: [userId], references: [id], onDelete: Cascade)
  class Class @relation(fields: [classId], references: [id], onDelete: Cascade)

  @@unique([userId, classId])
  @@map("enrollments")
}
```

---

## API 仕様

### 認証エンドポイント

#### `POST /api/auth/google`

Google ID Token をサーバーで検証し、JWT を発行

**リクエスト:**

```json
{
  "googleToken": "eyJhbGciOiJSUzI1NiIs...",
  "googleClientId": "YOUR_GOOGLE_CLIENT_ID"
}
```

**レスポンス (成功):**

```json
{
  "success": true,
  "jwt": "eyJhbGciOiJIUzI1NiIs...",
  "user": {
    "id": "user_123",
    "email": "student@school.ac.jp",
    "name": "山田太郎",
    "isAdmin": false
  }
}
```

**レスポンス (失敗):**

```json
{
  "success": false,
  "error": "Invalid Google token or domain not allowed"
}
```

---

### 授業マスタエンドポイント (管理者のみ)

#### `GET /api/classes`

全授業一覧を取得

**レスポンス:**

```json
{
  "classes": [
    {
      "id": "class_001",
      "name": "数学 I",
      "dayOfWeek": 0,
      "period": 1,
      "startTime": "09:00",
      "endTime": "10:30",
      "room": "A-101"
    }
  ]
}
```

#### `POST /api/classes` (管理者のみ)

新しい授業を登録

**リクエストボディ:**

```json
{
  "name": "数学 I",
  "dayOfWeek": 0,
  "period": 1,
  "startTime": "09:00",
  "endTime": "10:30",
  "room": "A-101"
}
```

#### `PUT /api/classes/[id]` (管理者のみ)

授業を更新

#### `DELETE /api/classes/[id]` (管理者のみ)

授業を削除

---

### 履修登録エンドポイント (学生)

#### `GET /api/enrollments`

ログインユーザーの履修一覧を取得

**レスポンス:**

```json
{
  "enrollments": [
    {
      "id": "enrollment_001",
      "classId": "class_001",
      "className": "数学 I",
      "dayOfWeek": 0,
      "period": 1,
      "startTime": "09:00",
      "endTime": "10:30",
      "room": "A-101"
    }
  ]
}
```

#### `POST /api/enrollments`

授業を履修登録

**リクエストボディ:**

```json
{
  "classId": "class_001"
}
```

#### `DELETE /api/enrollments/[id]`

履修を削除

---

### 表示状態エンドポイント

#### `GET /api/display-state`

現在の表示状態を取得（本日の履修に基づいて次の授業などを判定）

**レスポンス:**

```json
{
  "displayType": "current_class",
  "classInfo": {
    "name": "数学 I",
    "room": "A-101",
    "startTime": "09:00",
    "endTime": "10:30"
  },
  "message": "現在 1限・A-101"
}
```

---

## 表示判定ロジック

### 関数シグネチャ

```ts
interface DisplayLogicInput {
  currentTime: Date;
  enrollments: Array<{
    classId: string;
    className: string;
    dayOfWeek: number;
    period: number;
    startTime: string;
    endTime: string;
    room: string;
  }>;
  dayOfWeek: number; // 0: Sun, 1: Mon, ... 6: Sat
}

interface ClassInfo {
  id: string;
  name: string;
  room: string;
  startTime: string;
  endTime: string;
}

interface DisplayLogicOutput {
  displayType: 'no_enrollment' | 'current_class' | 'next_class' | 'break_time' | 'day_finished';
  classInfo?: ClassInfo;
  message?: string;
}

function determineDisplayState(input: DisplayLogicInput): DisplayLogicOutput
```

### 判定ロジック詳細

```ts
// ステップ 1: 本日の曜日に該当する履修を取得
let todayEnrollments = enrollments.filter(e => e.dayOfWeek === dayOfWeek)
  .sort((a, b) => parseTime(a.startTime) - parseTime(b.startTime))

if (todayEnrollments.length === 0) {
  return {
    displayType: 'no_enrollment',
    message: '本日の履修授業はありません'
  }
}

// ステップ 2: 各授業を走査
for (let i = 0; i < todayEnrollments.length; i++) {
  const cls = todayEnrollments[i]
  const startTime = parseTime(cls.startTime, currentTime)
  const endTime = parseTime(cls.endTime, currentTime)

  // ステップ 3: 授業中か判定
  if (currentTime >= startTime && currentTime < endTime) {
    const minutesRemaining = (endTime - currentTime) / 60000

    if (minutesRemaining <= 10) {
      // 終了 10 分以内：次の授業を表示
      if (i + 1 < todayEnrollments.length) {
        const nextCls = todayEnrollments[i + 1]
        return {
          displayType: 'next_class',
          classInfo: {
            id: nextCls.classId,
            name: nextCls.className,
            room: nextCls.room,
            startTime: nextCls.startTime,
            endTime: nextCls.endTime
          },
          message: `次は ${nextCls.period} 限・${nextCls.room}`
        }
      } else {
        return {
          displayType: 'day_finished',
          message: '本日の授業は終了'
        }
      }
    } else {
      // 授業中（開始 10 分以上）
      return {
        displayType: 'current_class',
        classInfo: {
          id: cls.classId,
          name: cls.className,
          room: cls.room,
          startTime: cls.startTime,
          endTime: cls.endTime
        },
        message: `現在 ${cls.period} 限・${cls.room}`
      }
    }
  }

  // ステップ 4: 次の授業との間隔を確認
  if (i < todayEnrollments.length - 1) {
    const nextCls = todayEnrollments[i + 1]
    const nextStartTime = parseTime(nextCls.startTime, currentTime)

    if (currentTime < nextStartTime) {
      return {
        displayType: 'break_time',
        classInfo: {
          id: nextCls.classId,
          name: nextCls.className,
          room: nextCls.room,
          startTime: nextCls.startTime,
          endTime: nextCls.endTime
        },
        message: `空き時間中。次は ${nextCls.period} 限・${nextCls.room}`
      }
    }
  }
}

// ステップ 5: すべての授業が終了
return {
  displayType: 'day_finished',
  message: '本日の授業は終了'
}
```

---

## タスク分割と実装順序

### Phase 1: プロジェクト基盤セットアップ (3 タスク)

- [ ] **Task 1-1**: Next.js プロジェクト初期化 & パッケージ設定
- [ ] **Task 1-2**: Prisma セットアップ & SQLite 初期化
- [ ] **Task 1-3**: 環境変数テンプレート & .env.local セットアップ

### Phase 2: Backend API 基盤 (5 タスク)

- [ ] **Task 2-1**: Google OAuth 検証ユーティリティ実装
- [ ] **Task 2-2**: JWT 生成・検証ミドルウェア実装
- [ ] **Task 2-3**: 認証 API エンドポイント実装 (`POST /api/auth/google`)
- [ ] **Task 2-4**: 表示判定ロジック実装 & ユニットテスト
- [ ] **Task 2-5**: 授業マスタ API エンドポイント実装 (GET/POST/PUT/DELETE)

### Phase 3: Frontend - 認証・基盤 (3 タスク)

- [ ] **Task 3-1**: Layout & ナビゲーション構造構築
- [ ] **Task 3-2**: Google ログインページ実装
- [ ] **Task 3-3**: useAuth フック実装

### Phase 4: Frontend - 学生機能 (3 タスク)

- [ ] **Task 4-1**: 履修登録ページ実装
- [ ] **Task 4-2**: ホームページ（表示判定ロジック統合）
- [ ] **Task 4-3**: カレンダー表示ページ実装

### Phase 5: Frontend - 管理者機能 & 統合 (2 タスク)

- [ ] **Task 5-1**: 管理者ページ（授業管理 UI）
- [ ] **Task 5-2**: API ルーティング & 履修 API エンドポイント

### Phase 6: テスト・デプロイ準備 (2 タスク)

- [ ] **Task 6-1**: E2E テスト & 統合テスト
- [ ] **Task 6-2**: Cloudflare Functions へのマイグレーション準備 & ドキュメント

## 総計: 18 タスク

---

## 技術的考慮事項

### Prisma + SQLite → Cloudflare D1 マイグレーション

- **開発環境**: SQLite ファイルベース（better-sqlite3）
- **本番環境**: Cloudflare D1（SQLite-compatible）
- **マイグレーション戦略**: Prisma migrations を git で管理し、dev と prod で同じマイグレーション実行
- **型安全性**: Prisma Client の型定義は両環境で統一

### JWT 検証

- **HS256** アルゴリズム使用（symmetric key）
- トークン有効期限: 24 時間
- リフレッシュ戦略は v0.2 以降

### Google OAuth フロー

1. フロントエンド: Google の ID Token 取得
2. フロントエンド: `POST /api/auth/google` に送信
3. バックエンド: Firebase Admin SDK で ID Token 検証
4. バックエンド: 学校ドメイン確認 & ユーザー作成/更新
5. バックエンド: JWT 発行
6. フロントエンド: JWT を localStorage に保存（HttpOnly Cookie 推奨は v0.2）

---

## Spec カバレッジチェック

| Spec セクション | Plan カバレッジ | タスク |
|---|---|---|
| 1-3. 問題・スコープ | Next.js/Prisma 構成 | 全体 |
| 4. 利用者 | Frontend pages で実現 | Task 3-2, 4-1, 4-2, 5-1 |
| 5. 認証・権限 | Google OAuth + JWT | Task 2-1, 2-2, 2-3 |
| 6. データ構造 | Prisma schema | Task 1-2 |
| 7.1. ホーム画面 | display-logic + HomePage | Task 2-4, 4-2 |
| 7.2. 履修登録 | EnrollmentPage | Task 4-1 |
| 7.3. カレンダー | CalendarPage | Task 4-3 |
| 7.4. 管理者 | AdminPage + Classes API | Task 5-1, 2-5 |
| 8. フロー | 実装順序で順序付け | 全体 |
| 9. 表示判定 | display-logic.ts | Task 2-4 |
| 10. エラー処理 | API レスポンス設計 | Task 2-3, 2-5 |
| 11. 設計方針 | Next.js コンベンション | ファイル構造 |
| 12. 完成条件 | E2E テスト設計 | Task 6-1 |

✅ **Spec カバレッジ 100%**

---

## 次のステップ

このプランをレビューしたら、以下の実行方法を選択してください：

1. **Subagent-Driven（推奨）** - 各タスクごとに独立した subagent を実行、タスク間でレビュー
2. **Inline Execution** - 当セッションで executing-plans スキルを使い、checkpoint ごとにレビュー
