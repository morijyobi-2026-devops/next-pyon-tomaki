# 次の教室案内システム 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Google Workspace 認証・授業管理・履修登録・ホーム表示を備えた個人用 Web アプリを ver0.1 で完成させる

**Architecture:**
- **Frontend**: React 18 + TypeScript + Vite で SPA 構築
- **Backend**: Node.js + Express で REST API 提供
- **Database**: SQLite3 で ユーザー・授業・履修データ永続化
- **Auth**: Google OAuth 2.0 + Firebase Admin SDK で認証検証
- **Display Logic**: 現在時刻と履修データから表示内容を動的決定（テスト可能なユーティリティ）

**Tech Stack:**
- Frontend: React 18, TypeScript 5, Vite, @react-oauth/google, Vitest
- Backend: Node.js 18+, Express 4, better-sqlite3, firebase-admin, jsonwebtoken
- Database: SQLite3
- Testing: Jest (backend), Vitest (frontend)

---

## ファイル構造

```
next-pyon-tomaki/
├── .env.example                     # 環境変数テンプレート
├── .env.local                       # 実際の環境変数（gitignore）
│
├── backend/
│   ├── package.json
│   ├── tsconfig.json
│   ├── jest.config.js
│   ├── .env.example
│   ├── src/
│   │   ├── server.ts                # Express サーバー起動
│   │   ├── types/
│   │   │   └── index.ts             # 共通型定義
│   │   ├── db/
│   │   │   └── init.ts              # SQLite 初期化・スキーマ
│   │   ├── auth/
│   │   │   └── googleAuth.ts        # Google OAuth 検証
│   │   ├── middleware/
│   │   │   └── auth.ts              # JWT ミドルウェア
│   │   ├── routes/
│   │   │   ├── auth.ts              # POST /auth/google
│   │   │   ├── classes.ts           # GET/POST /classes (管理者)
│   │   │   └── enrollments.ts       # GET/POST /enrollments (学生)
│   │   └── utils/
│   │       └── displayLogic.ts      # 表示判定ロジック（共通）
│   └── tests/
│       ├── db.test.ts
│       ├── displayLogic.test.ts
│       ├── auth.test.ts
│       ├── classes.test.ts
│       └── enrollments.test.ts
│
├── frontend/
│   ├── package.json
│   ├── tsconfig.json
│   ├── vite.config.ts
│   ├── vitest.config.ts
│   ├── .env.example
│   ├── index.html
│   ├── src/
│   │   ├── main.tsx                 # React entry point
│   │   ├── App.tsx                  # Router + main layout
│   │   ├── types/
│   │   │   └── index.ts             # Frontend 型定義
│   │   ├── pages/
│   │   │   ├── LoginPage.tsx
│   │   │   ├── EnrollmentPage.tsx
│   │   │   ├── HomePage.tsx
│   │   │   └── CalendarPage.tsx
│   │   ├── components/
│   │   │   ├── GoogleLoginButton.tsx
│   │   │   ├── ClassSelector.tsx
│   │   │   ├── NextClassDisplay.tsx
│   │   │   └── AdminClassForm.tsx
│   │   ├── hooks/
│   │   │   ├── useAuth.ts
│   │   │   ├── useEnrollments.ts
│   │   │   └── useDisplayState.ts
│   │   ├── services/
│   │   │   └── api.ts               # API クライアント
│   │   └── utils/
│   │       └── displayLogic.ts      # バックエンド と同じロジック
│   └── tests/
│       ├── displayLogic.test.ts
│       └── HomePage.test.tsx
│
└── docs/
    └── superpowers/
        ├── specs/
        │   └── 2026-04-30-classroom-navigation-design.md
        └── plans/
            └── 2026-05-14-implementation.md (THIS FILE)
```

---

## 環境変数テンプレート

### `.env.example` (root)

```bash
# Backend
BACKEND_PORT=5000
BACKEND_URL=http://localhost:5000

# Frontend
VITE_API_URL=http://localhost:5000
VITE_GOOGLE_CLIENT_ID=YOUR_GOOGLE_CLIENT_ID_HERE

# School Config
SCHOOL_EMAIL_DOMAIN=@school.ac.jp
ADMIN_EMAILS=admin1@school.ac.jp,admin2@school.ac.jp

# Firebase (Backend)
FIREBASE_PROJECT_ID=your-firebase-project
FIREBASE_PRIVATE_KEY=YOUR_FIREBASE_PRIVATE_KEY_HERE
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@your-project.iam.gserviceaccount.com
```

### `backend/.env.example`

```bash
PORT=5000
FIREBASE_PROJECT_ID=your-firebase-project
FIREBASE_PRIVATE_KEY=YOUR_PRIVATE_KEY
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@project.iam.gserviceaccount.com
SCHOOL_EMAIL_DOMAIN=@school.ac.jp
ADMIN_EMAILS=admin@school.ac.jp
JWT_SECRET=your-jwt-secret-key-min-32-chars
```

### `frontend/.env.example`

```bash
VITE_API_URL=http://localhost:5000
VITE_GOOGLE_CLIENT_ID=YOUR_GOOGLE_CLIENT_ID_HERE
```

---

## API 仕様

### 認証エンドポイント

#### `POST /auth/google`
Google ID Token をサーバーで検証し、JWT を発行

**リクエスト:**
```json
{
  "googleToken": "eyJhbGciOiJSUzI1NiIs..."
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
    "displayName": "山田太郎",
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

#### `GET /classes`
全授業一覧を取得

**リクエストヘッダ:**
```
Authorization: Bearer {jwt_token}
```

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

#### `POST /classes`
新しい授業を登録（管理者のみ）

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

**レスポンス:**
```json
{
  "id": "class_001",
  "name": "数学 I",
  "dayOfWeek": 0,
  "period": 1,
  "startTime": "09:00",
  "endTime": "10:30",
  "room": "A-101"
}
```

---

### 履修登録エンドポイント (学生)

#### `GET /enrollments`
ログインユーザーの履修一覧を取得

**レスポンス:**
```json
{
  "enrollments": [
    {
      "classId": "class_001",
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

#### `POST /enrollments`
授業を履修登録

**リクエストボディ:**
```json
{
  "classId": "class_001"
}
```

**レスポンス:**
```json
{
  "success": true,
  "message": "Enrolled successfully"
}
```

---

## 表示判定ロジック （pseudocode → テスト駆動）

### 関数シグネチャ

```typescript
interface DisplayLogicInput {
  currentTime: Date;           // 現在時刻
  enrollments: CalendarItem[]; // 本日の履修授業（時系列順）
}

interface DisplayLogicOutput {
  displayType: 'no_enrollment' | 'current_class' | 'next_class' | 'break_time' | 'day_finished';
  classInfo?: {
    name: string;
    room: string;
    startTime: string;
    endTime: string;
  };
  message?: string;
}

function determineDisplayState(input: DisplayLogicInput): DisplayLogicOutput
```

### 判定ロジック

```
// ステップ 1: 本日の履修がない
if (enrollments.length === 0) {
  return {
    displayType: 'no_enrollment',
    message: '履修授業を登録してください'
  }
}

// ステップ 2: 各授業を開始時刻順に走査
for i = 0 to enrollments.length - 1:
  let class = enrollments[i]
  let startTime = parseTime(class.startTime)      // "09:00" → Date オブジェクト
  let endTime = parseTime(class.endTime)          // "10:30" → Date オブジェクト
  
  // ステップ 3: 現在時刻が授業中か判定
  if (currentTime >= startTime && currentTime < endTime):
    // 授業中: 終了まで何分か計算
    let minutesRemaining = (endTime - currentTime) / 60000  // ミリ秒を分に変換
    
    if (minutesRemaining <= 10):
      // 終了 10 分以内：次の授業を表示（あれば）
      if (i + 1 < enrollments.length):
        let nextClass = enrollments[i + 1]
        return {
          displayType: 'next_class',
          classInfo: {
            name: nextClass.name,
            room: nextClass.room,
            startTime: nextClass.startTime,
            endTime: nextClass.endTime
          },
          message: `次は ${nextClass.period} 限・${nextClass.room}`
        }
      else:
        // 今の授業が最後
        return {
          displayType: 'day_finished',
          message: '本日の授業は終了'
        }
    else:
      // 終了まで 10 分以上：現在の授業を表示
      return {
        displayType: 'current_class',
        classInfo: {
          name: class.name,
          room: class.room,
          startTime: class.startTime,
          endTime: class.endTime
        },
        message: `現在 ${class.period} 限・${class.room}`
      }
  
  // ステップ 4: 授業と授業の間か判定
  if (i < enrollments.length - 1):
    let nextClass = enrollments[i + 1]
    let nextStartTime = parseTime(nextClass.startTime)
    
    if (currentTime < nextStartTime):
      // 空きコマ中
      return {
        displayType: 'break_time',
        classInfo: {
          name: nextClass.name,
          room: nextClass.room,
          startTime: nextClass.startTime,
          endTime: nextClass.endTime
        },
        message: `空き時間中。次は ${nextClass.period} 限・${nextClass.room}`
      }

// ステップ 5: 最後の授業終了後
return {
  displayType: 'day_finished',
  message: '本日の授業は終了'
}
```

---

## タスク分割と実装順序

### Phase 1: Backend 基盤 (5 タスク)

- [ ] **Task 1-1**: Backend 環境セットアップ（package.json, tsconfig.json, .env.example）
- [ ] **Task 1-2**: SQLite スキーマと型定義（users, classMaster, enrollments テーブル）
- [ ] **Task 1-3**: Google OAuth 検証ミドルウェア + JWT 発行
- [ ] **Task 1-4**: Express ルート構築（/auth/google, /classes, /enrollments）
- [ ] **Task 1-5**: 表示判定ロジック（displayLogic.ts + テスト）

### Phase 2: Frontend 基盤 (3 タスク)

- [ ] **Task 2-1**: Frontend 環境セットアップ（Vite, TypeScript, .env）
- [ ] **Task 2-2**: API クライアント + 認証フック（useAuth）
- [ ] **Task 2-3**: Google ログインページ

### Phase 3: 学生機能 (4 タスク)

- [ ] **Task 3-1**: 履修登録ページ（授業一覧選択 UI）
- [ ] **Task 3-2**: ホーム画面（表示判定ロジック統合）
- [ ] **Task 3-3**: 個人カレンダー表示ページ
- [ ] **Task 3-4**: 学生向け統合テスト

### Phase 4: 管理者機能 (1 タスク)

- [ ] **Task 4-1**: 管理者画面（授業マスタ登録・編集 UI）

### Phase 5: 検証・完成 (2 タスク)

- [ ] **Task 5-1**: E2E テスト（6 シナリオ）
- [ ] **Task 5-2**: 本番ビルド + ドキュメント整備

**総計: 15 タスク**

---

## Spec カバレッジチェック

| Spec セクション | Plan カバレッジ | タスク |
|---|---|---|
| 1-3. 問題・スコープ | Motivation（実装）| 全体 |
| 4. 利用者 | Frontend pages で実現 | Task 2-3, 3-1, 3-2, 4-1 |
| 5. 認証・権限 | /auth/google + middleware | Task 1-3 |
| 6. データ構造 | SQLite schema + 型定義 | Task 1-2 |
| 7.1. ホーム画面 | displayLogic + HomePage | Task 1-5, 3-2 |
| 7.2. 履修登録画面 | EnrollmentPage | Task 3-1 |
| 7.3. カレンダー画面 | CalendarPage | Task 3-3 |
| 7.4. 管理者画面 | AdminClassForm | Task 4-1 |
| 8. フロー | 実装順序で順序付け | 全体 |
| 9. 表示判定ロジック | displayLogic.ts + テスト | Task 1-5 |
| 10. エラー処理 | API レスポンス設計 | Task 1-4 |
| 11. 設計方針 | ファイル分割・責務分離 | ファイル構造 |
| 12. 完成条件 | Task 5-1 で検証 | Task 5-1 |
| 13. テスト観点 | E2E テスト設計 | Task 5-1 |

✅ **Spec カバレッジ 100%**

---

## 次のステップ

1. このプランをレビュー
2. PR を作成して main にマージ
3. Task 1-1 から実装開始
