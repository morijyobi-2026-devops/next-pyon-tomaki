# 次の教室案内システム Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ローカルでは SQLite で素早く ver0.1 を完成させつつ、後から Cloudflare Workers + D1 の `staging` / `production` に載せ替えられる構成で「次の教室案内」アプリを実装する。

**Architecture:** Next.js App Router を土台にし、Google ログインは Auth.js の JWT セッションで実装する。授業、履修、ユーザー管理は Drizzle ORM の SQLite スキーマで始め、UI や業務ロジックからデータアクセスを repository/service 境界で分離する。Cloudflare 対応では `@opennextjs/cloudflare` と Wrangler を追加し、同じサービス層のまま D1 バインディングへ差し替える。

**Tech Stack:** Next.js, TypeScript, Tailwind CSS, Auth.js, Drizzle ORM, better-sqlite3, Zod, Vitest, React Testing Library, `@opennextjs/cloudflare`, Wrangler

---

## File Structure

- `package.json` - アプリ、DB、Cloudflare preview/deploy 用スクリプト
- `next.config.ts` - Next.js 設定と Cloudflare ローカル開発の初期化
- `vitest.config.ts` - Vitest 設定
- `drizzle.config.ts` - Drizzle 設定
- `open-next.config.ts` - OpenNext Cloudflare 設定
- `wrangler.jsonc` - Worker、D1、環境別設定
- `scripts/write-wrangler-config.mjs` - D1 ID から `wrangler.jsonc` を生成するスクリプト
- `.env.example` - ローカル Node 開発用の環境変数例
- `.dev.vars.example` - Cloudflare preview 用のローカル変数例
- `.gitignore` - SQLite、OpenNext 出力、型生成物の除外
- `src/test/setup.ts` - Testing Library 共通初期化
- `src/app/layout.tsx` - 全体レイアウト
- `src/app/page.tsx` - ホーム画面
- `src/app/page.test.tsx` - ホーム画面の初期表示テスト
- `src/app/globals.css` - 共通スタイル
- `src/lib/time.ts` - 時刻計算ユーティリティ
- `src/lib/home/resolve-home-state.ts` - ホーム画面表示判定ロジック
- `src/lib/home/resolve-home-state.test.ts` - 表示判定ロジックのテスト
- `src/lib/home/home-types.ts` - ホーム画面で扱う型
- `src/db/schema.ts` - users / courses / course_slots / enrollments テーブル
- `src/db/types.ts` - SQLite と D1 で共有する DB 型
- `src/db/local.ts` - ローカル SQLite 接続
- `src/db/cloudflare.ts` - Cloudflare D1 接続
- `src/lib/env.ts` - Node 環境変数の検証
- `src/lib/repositories/course-repository.ts` - 授業と履修の repository 実装
- `src/lib/repositories/user-repository.ts` - ユーザー repository 実装
- `src/lib/repositories/server-repositories.ts` - 実行環境に応じた repository 生成
- `src/lib/courses/course-schema.ts` - 管理者フォーム入力の Zod スキーマ
- `src/lib/courses/course-service.ts` - 管理者向け授業管理サービス
- `src/lib/courses/course-service.test.ts` - 授業管理サービスのテスト
- `src/lib/enrollments/enrollment-service.ts` - 履修登録サービス
- `src/lib/enrollments/enrollment-service.test.ts` - 履修登録サービスのテスト
- `src/lib/calendar/build-weekly-calendar.ts` - 週間カレンダー生成
- `src/lib/calendar/build-weekly-calendar.test.ts` - 週間カレンダー生成テスト
- `src/lib/auth/policy.ts` - 学校ドメイン制限と管理者メール判定
- `src/lib/auth/policy.test.ts` - 認証ポリシーのテスト
- `src/lib/auth/require-user.ts` - ログイン必須ヘルパー
- `src/lib/auth/require-admin.ts` - 管理者必須ヘルパー
- `src/auth.ts` - Auth.js 設定
- `src/app/api/auth/[...nextauth]/route.ts` - Auth.js ルート
- `src/types/next-auth.d.ts` - Session / JWT 型拡張
- `src/app/admin/courses/page.tsx` - 管理者向け授業管理画面
- `src/app/admin/courses/actions.ts` - 授業保存の Server Actions
- `src/components/admin/course-form.tsx` - 管理者向け授業フォーム
- `src/components/home/next-class-card.tsx` - ホーム画面の主要カード
- `src/components/calendar/weekly-calendar.tsx` - 週間カレンダー表示
- `src/app/courses/page.tsx` - 学生向け履修登録画面
- `src/app/courses/actions.ts` - 履修登録の Server Actions
- `src/app/calendar/page.tsx` - 学生向け週間カレンダー画面
- `README.md` - ローカル開発、staging / production 配備手順

## Task 1: Next.js 基盤とローカルテスト環境を作る

**Files:**

- Create: `package.json`
- Create: `next.config.ts`
- Create: `vitest.config.ts`
- Create: `src/test/setup.ts`
- Create: `src/app/layout.tsx`
- Create: `src/app/page.tsx`
- Create: `src/app/page.test.tsx`
- Create: `src/app/globals.css`
- Modify: `README.md`

- [ ] **Step 1: Next.js アプリを生成し、依存関係を入れる**

```bash
npx create-next-app@latest .tmp-next-class --ts --tailwind --eslint --app --src-dir --use-npm --import-alias "@/*"
rsync -a .tmp-next-class/ ./
rm -rf .tmp-next-class
npm install next-auth zod drizzle-orm better-sqlite3
npm install -D drizzle-kit vitest jsdom @testing-library/react @testing-library/jest-dom @testing-library/user-event tsx @types/better-sqlite3 @opennextjs/cloudflare wrangler
```

- [ ] **Step 2: 失敗するホーム画面テストを書く**

`src/app/page.test.tsx`

```tsx
import { render, screen } from "@testing-library/react";
import HomePage from "./page";

describe("HomePage", () => {
  it("shows the app title and login guidance", () => {
    render(<HomePage />);

    expect(
      screen.getByRole("heading", { name: "次の教室案内" }),
    ).toBeInTheDocument();
    expect(
      screen.getByText("学校の Google アカウントでログインすると利用できます。"),
    ).toBeInTheDocument();
  });
});
```

- [ ] **Step 3: テストを実行して失敗を確認する**

Run: `npx vitest run src/app/page.test.tsx`  
Expected: FAIL with a message that the heading "次の教室案内" cannot be found.

- [ ] **Step 4: 最小のレイアウト、トップページ、Vitest 設定を書く**

`package.json`

```json
{
  "name": "next-pyon-suzuryo",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "test": "vitest run",
    "db:generate": "drizzle-kit generate",
    "db:push": "drizzle-kit push"
  }
}
```

`next.config.ts`

```ts
import type { NextConfig } from "next";

const nextConfig: NextConfig = {};

export default nextConfig;
```

`vitest.config.ts`

```ts
import path from "node:path";
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./src/test/setup.ts"],
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
```

`src/test/setup.ts`

```ts
import "@testing-library/jest-dom/vitest";
```

`src/app/layout.tsx`

```tsx
import "./globals.css";
import type { Metadata } from "next";
import type { ReactNode } from "react";

export const metadata: Metadata = {
  title: "次の教室案内",
  description: "次の授業の教室をすぐ確認できる学内向けアプリ",
};

export default function RootLayout({
  children,
}: {
  children: ReactNode;
}) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  );
}
```

`src/app/page.tsx`

```tsx
export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-3xl flex-col justify-center gap-4 px-6 py-16">
      <p className="text-sm font-semibold text-sky-300">ver0.1</p>
      <h1 className="text-4xl font-bold tracking-tight">次の教室案内</h1>
      <p className="text-lg text-slate-300">
        学校の Google アカウントでログインすると利用できます。
      </p>
    </main>
  );
}
```

`src/app/globals.css`

```css
@import "tailwindcss";

html {
  color-scheme: dark;
}

body {
  margin: 0;
  min-height: 100vh;
  background: #020617;
  color: #f8fafc;
  font-family: Arial, Helvetica, sans-serif;
}
```

`README.md`

```md
# next-pyon-suzuryo

「次の教室案内」アプリの開発リポジトリ。
```

- [ ] **Step 5: テストと lint を実行して通す**

Run: `npm run test -- src/app/page.test.tsx && npm run lint`  
Expected: PASS for the homepage test and successful lint output.

- [ ] **Step 6: コミットする**

```bash
git add package.json next.config.ts vitest.config.ts src/test/setup.ts src/app/layout.tsx src/app/page.tsx src/app/page.test.tsx src/app/globals.css README.md
git commit -m "chore: bootstrap next class app"
```

## Task 2: ホーム画面の表示判定ロジックを純粋関数で固める

**Files:**

- Create: `src/lib/home/home-types.ts`
- Create: `src/lib/time.ts`
- Create: `src/lib/home/resolve-home-state.ts`
- Create: `src/lib/home/resolve-home-state.test.ts`

- [ ] **Step 1: 表示判定の失敗テストを書く**

`src/lib/home/resolve-home-state.test.ts`

```ts
import { describe, expect, it } from "vitest";
import { resolveHomeState } from "./resolve-home-state";
import type { ScheduledClass } from "./home-types";

const mondayClasses: ScheduledClass[] = [
  {
    courseId: "course-web",
    title: "Webプログラミング",
    dayOfWeek: 1,
    periodLabel: "1-2限",
    startTime: "09:00",
    endTime: "10:30",
    classroom: "301",
  },
  {
    courseId: "course-db",
    title: "データベース",
    dayOfWeek: 1,
    periodLabel: "3限",
    startTime: "13:00",
    endTime: "14:30",
    classroom: null,
  },
];

describe("resolveHomeState", () => {
  it("returns current during class when more than ten minutes remain", () => {
    expect(
      resolveHomeState({
        classes: mondayClasses,
        now: { dayOfWeek: 1, time: "09:40" },
      }),
    ).toEqual({
      kind: "current",
      title: "Webプログラミング",
      classroom: "301",
      periodLabel: "1-2限",
      startTime: "09:00",
    });
  });

  it("returns next class during the last ten minutes of the current class", () => {
    expect(
      resolveHomeState({
        classes: mondayClasses,
        now: { dayOfWeek: 1, time: "10:22" },
      }),
    ).toEqual({
      kind: "next",
      title: "データベース",
      classroom: "教室未設定",
      periodLabel: "3限",
      startTime: "13:00",
    });
  });

  it("returns gap state between classes", () => {
    expect(
      resolveHomeState({
        classes: mondayClasses,
        now: { dayOfWeek: 1, time: "11:00" },
      }),
    ).toEqual({
      kind: "gap",
      message: "空き時間中",
      nextTitle: "データベース",
      nextClassroom: "教室未設定",
      nextPeriodLabel: "3限",
      nextStartTime: "13:00",
    });
  });

  it("returns needs-enrollment when there are no classes for the day", () => {
    expect(
      resolveHomeState({
        classes: [],
        now: { dayOfWeek: 1, time: "09:00" },
      }),
    ).toEqual({
      kind: "needs-enrollment",
    });
  });
});
```

- [ ] **Step 2: テストを実行して失敗を確認する**

Run: `npx vitest run src/lib/home/resolve-home-state.test.ts`  
Expected: FAIL with a message that `resolveHomeState` cannot be imported.

- [ ] **Step 3: 型と時刻ユーティリティを書く**

`src/lib/home/home-types.ts`

```ts
export type ScheduledClass = {
  courseId: string;
  title: string;
  dayOfWeek: number;
  periodLabel: string;
  startTime: string;
  endTime: string;
  classroom: string | null;
};

export type HomeState =
  | {
      kind: "needs-enrollment";
    }
  | {
      kind: "current";
      title: string;
      classroom: string;
      periodLabel: string;
      startTime: string;
    }
  | {
      kind: "next";
      title: string;
      classroom: string;
      periodLabel: string;
      startTime: string;
    }
  | {
      kind: "gap";
      message: string;
      nextTitle: string;
      nextClassroom: string;
      nextPeriodLabel: string;
      nextStartTime: string;
    }
  | {
      kind: "done";
      message: string;
    };
```

`src/lib/time.ts`

```ts
export function toMinutes(value: string): number {
  const [hours, minutes] = value.split(":").map(Number);
  return hours * 60 + minutes;
}

export function classroomLabel(value: string | null): string {
  return value && value.length > 0 ? value : "教室未設定";
}
```

- [ ] **Step 4: 表示判定ロジックを書く**

`src/lib/home/resolve-home-state.ts`

```ts
import { classroomLabel, toMinutes } from "@/lib/time";
import type { HomeState, ScheduledClass } from "./home-types";

type Input = {
  classes: ScheduledClass[];
  now: {
    dayOfWeek: number;
    time: string;
  };
};

export function resolveHomeState({ classes, now }: Input): HomeState {
  const todaysClasses = classes
    .filter((item) => item.dayOfWeek === now.dayOfWeek)
    .sort((left, right) => toMinutes(left.startTime) - toMinutes(right.startTime));

  if (todaysClasses.length === 0) {
    return { kind: "needs-enrollment" };
  }

  const currentMinutes = toMinutes(now.time);

  for (let index = 0; index < todaysClasses.length; index += 1) {
    const current = todaysClasses[index];
    const next = todaysClasses[index + 1];
    const startMinutes = toMinutes(current.startTime);
    const endMinutes = toMinutes(current.endTime);

    if (currentMinutes >= startMinutes && currentMinutes < endMinutes) {
      const remainingMinutes = endMinutes - currentMinutes;

      if (remainingMinutes <= 10 && next) {
        return {
          kind: "next",
          title: next.title,
          classroom: classroomLabel(next.classroom),
          periodLabel: next.periodLabel,
          startTime: next.startTime,
        };
      }

      return {
        kind: "current",
        title: current.title,
        classroom: classroomLabel(current.classroom),
        periodLabel: current.periodLabel,
        startTime: current.startTime,
      };
    }

    if (currentMinutes < startMinutes) {
      return {
        kind: "gap",
        message: "空き時間中",
        nextTitle: current.title,
        nextClassroom: classroomLabel(current.classroom),
        nextPeriodLabel: current.periodLabel,
        nextStartTime: current.startTime,
      };
    }
  }

  return {
    kind: "done",
    message: "本日の授業は終了",
  };
}
```

- [ ] **Step 5: テストを実行して通す**

Run: `npx vitest run src/lib/home/resolve-home-state.test.ts`  
Expected: PASS with 4 tests passed.

- [ ] **Step 6: コミットする**

```bash
git add src/lib/home/home-types.ts src/lib/time.ts src/lib/home/resolve-home-state.ts src/lib/home/resolve-home-state.test.ts
git commit -m "feat: add home state resolver"
```

## Task 3: ローカル SQLite と repository 境界を作る

**Files:**

- Create: `drizzle.config.ts`
- Create: `.env.example`
- Create: `src/lib/env.ts`
- Create: `src/db/schema.ts`
- Create: `src/db/types.ts`
- Create: `src/db/local.ts`
- Create: `src/lib/repositories/course-repository.ts`
- Create: `src/lib/repositories/user-repository.ts`
- Create: `src/lib/repositories/server-repositories.ts`
- Create: `src/lib/repositories/course-repository.test.ts`

- [ ] **Step 1: 授業保存と履修取得の失敗テストを書く**

`src/lib/repositories/course-repository.test.ts`

```ts
import { beforeEach, describe, expect, it } from "vitest";
import { createLocalDb } from "@/db/local";
import { createCourseRepository } from "./course-repository";

describe("createCourseRepository", () => {
  const db = createLocalDb(":memory:");

  beforeEach(() => {
    db.$client.exec(`
      DROP TABLE IF EXISTS enrollments;
      DROP TABLE IF EXISTS course_slots;
      DROP TABLE IF EXISTS courses;

      CREATE TABLE courses (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL
      );

      CREATE TABLE course_slots (
        id TEXT PRIMARY KEY NOT NULL,
        course_id TEXT NOT NULL,
        day_of_week INTEGER NOT NULL,
        period_label TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        classroom TEXT
      );

      CREATE TABLE enrollments (
        user_id TEXT NOT NULL,
        course_id TEXT NOT NULL,
        PRIMARY KEY(user_id, course_id)
      );
    `);
  });

  it("stores one course with multiple slots", async () => {
    const repository = createCourseRepository(db);

    await repository.saveCourse({
      id: "course-web",
      title: "Webプログラミング",
      slots: [
        {
          id: "slot-mon",
          dayOfWeek: 1,
          periodLabel: "1-2限",
          startTime: "09:00",
          endTime: "10:30",
          classroom: "301",
        },
        {
          id: "slot-wed",
          dayOfWeek: 3,
          periodLabel: "2限",
          startTime: "10:40",
          endTime: "12:10",
          classroom: "302",
        },
      ],
    });

    const courses = await repository.listCourses();

    expect(courses).toHaveLength(1);
    expect(courses[0].slots).toHaveLength(2);
  });

  it("replaces enrollments for one user", async () => {
    const repository = createCourseRepository(db);

    await repository.saveCourse({
      id: "course-web",
      title: "Webプログラミング",
      slots: [
        {
          id: "slot-mon",
          dayOfWeek: 1,
          periodLabel: "1-2限",
          startTime: "09:00",
          endTime: "10:30",
          classroom: "301",
        },
      ],
    });

    await repository.replaceEnrollments("user-1", ["course-web"]);

    expect(await repository.listEnrollmentCourseIds("user-1")).toEqual(["course-web"]);
  });
});
```

- [ ] **Step 2: テストを実行して失敗を確認する**

Run: `npx vitest run src/lib/repositories/course-repository.test.ts`  
Expected: FAIL with a message that `createLocalDb` cannot be imported.

- [ ] **Step 3: 環境変数、Drizzle 設定、SQLite スキーマを書く**

`drizzle.config.ts`

```ts
import { defineConfig } from "drizzle-kit";

export default defineConfig({
  schema: "./src/db/schema.ts",
  out: "./drizzle",
  dialect: "sqlite",
  dbCredentials: {
    url: process.env.DATABASE_URL ?? "dev.sqlite",
  },
});
```

`.env.example`

```bash
DATABASE_URL=dev.sqlite
AUTH_SECRET=change-me-very-long-local-secret
GOOGLE_CLIENT_ID=local-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=local-client-secret
SCHOOL_GOOGLE_DOMAIN=morijyobi.ac.jp
ADMIN_EMAILS=teacher1@morijyobi.ac.jp,teacher2@morijyobi.ac.jp
```

`src/lib/env.ts`

```ts
import { z } from "zod";

const envSchema = z.object({
  DATABASE_URL: z.string().min(1),
  AUTH_SECRET: z.string().min(1),
  GOOGLE_CLIENT_ID: z.string().min(1),
  GOOGLE_CLIENT_SECRET: z.string().min(1),
  SCHOOL_GOOGLE_DOMAIN: z.string().min(1),
  ADMIN_EMAILS: z.string().min(1),
});

export const env = envSchema.parse({
  DATABASE_URL: process.env.DATABASE_URL,
  AUTH_SECRET: process.env.AUTH_SECRET,
  GOOGLE_CLIENT_ID: process.env.GOOGLE_CLIENT_ID,
  GOOGLE_CLIENT_SECRET: process.env.GOOGLE_CLIENT_SECRET,
  SCHOOL_GOOGLE_DOMAIN: process.env.SCHOOL_GOOGLE_DOMAIN,
  ADMIN_EMAILS: process.env.ADMIN_EMAILS,
});
```

`src/db/schema.ts`

```ts
import { integer, primaryKey, sqliteTable, text } from "drizzle-orm/sqlite-core";

export const users = sqliteTable("users", {
  id: text("id").primaryKey(),
  email: text("email").notNull().unique(),
  name: text("name").notNull(),
  role: text("role", { enum: ["student", "admin"] }).notNull(),
});

export const courses = sqliteTable("courses", {
  id: text("id").primaryKey(),
  title: text("title").notNull(),
});

export const courseSlots = sqliteTable("course_slots", {
  id: text("id").primaryKey(),
  courseId: text("course_id")
    .notNull()
    .references(() => courses.id, { onDelete: "cascade" }),
  dayOfWeek: integer("day_of_week").notNull(),
  periodLabel: text("period_label").notNull(),
  startTime: text("start_time").notNull(),
  endTime: text("end_time").notNull(),
  classroom: text("classroom"),
});

export const enrollments = sqliteTable(
  "enrollments",
  {
    userId: text("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    courseId: text("course_id")
      .notNull()
      .references(() => courses.id, { onDelete: "cascade" }),
  },
  (table) => ({
    pk: primaryKey({ columns: [table.userId, table.courseId] }),
  }),
);
```

`src/db/types.ts`

```ts
import type { BetterSQLite3Database } from "drizzle-orm/better-sqlite3";
import type { DrizzleD1Database } from "drizzle-orm/d1";
import * as schema from "./schema";

export type AppDb =
  | BetterSQLite3Database<typeof schema>
  | DrizzleD1Database<typeof schema>;
```

`src/db/local.ts`

```ts
import Database from "better-sqlite3";
import { drizzle } from "drizzle-orm/better-sqlite3";
import * as schema from "./schema";

export function createLocalDb(databaseUrl: string = "dev.sqlite") {
  const sqlite = new Database(databaseUrl);
  return drizzle(sqlite, { schema });
}
```

- [ ] **Step 4: repository 実装を書く**

`src/lib/repositories/course-repository.ts`

```ts
import { eq } from "drizzle-orm";
import { courseSlots, courses, enrollments } from "@/db/schema";
import type { AppDb } from "@/db/types";

export type CourseRecord = {
  id: string;
  title: string;
  slots: Array<{
    id: string;
    dayOfWeek: number;
    periodLabel: string;
    startTime: string;
    endTime: string;
    classroom: string | null;
  }>;
};

export function createCourseRepository(db: AppDb) {
  async function listEnrollmentCourseIds(userId: string) {
    const rows = await db
      .select()
      .from(enrollments)
      .where(eq(enrollments.userId, userId));

    return rows.map((row) => row.courseId);
  }

  async function listCourses(): Promise<CourseRecord[]> {
    const courseRows = await db.select().from(courses);
    const slotRows = await db.select().from(courseSlots);

    return courseRows.map((course) => ({
      id: course.id,
      title: course.title,
      slots: slotRows
        .filter((slot) => slot.courseId === course.id)
        .map((slot) => ({
          id: slot.id,
          dayOfWeek: Number(slot.dayOfWeek),
          periodLabel: slot.periodLabel,
          startTime: slot.startTime,
          endTime: slot.endTime,
          classroom: slot.classroom,
        })),
    }));
  }

  return {
    listCourses,

    async saveCourse(course: CourseRecord) {
      await db.insert(courses).values({
        id: course.id,
        title: course.title,
      }).onConflictDoUpdate({
        target: courses.id,
        set: { title: course.title },
      });

      await db.delete(courseSlots).where(eq(courseSlots.courseId, course.id));

      if (course.slots.length > 0) {
        await db.insert(courseSlots).values(
          course.slots.map((slot) => ({
            id: slot.id,
            courseId: course.id,
            dayOfWeek: String(slot.dayOfWeek),
            periodLabel: slot.periodLabel,
            startTime: slot.startTime,
            endTime: slot.endTime,
            classroom: slot.classroom,
          })),
        );
      }
    },

    async replaceEnrollments(userId: string, courseIds: string[]) {
      await db.delete(enrollments).where(eq(enrollments.userId, userId));

      if (courseIds.length > 0) {
        await db.insert(enrollments).values(
          courseIds.map((courseId) => ({
            userId,
            courseId,
          })),
        );
      }
    },

    listEnrollmentCourseIds,

    async listScheduledClassesForUser(userId: string) {
      const selectedCourseIds = await listEnrollmentCourseIds(userId);

      if (selectedCourseIds.length === 0) {
        return [];
      }

      const courseRows = await listCourses();

      return courseRows
        .filter((course) => selectedCourseIds.includes(course.id))
        .flatMap((course) =>
          course.slots.map((slot) => ({
            courseId: course.id,
            title: course.title,
            dayOfWeek: slot.dayOfWeek,
            periodLabel: slot.periodLabel,
            startTime: slot.startTime,
            endTime: slot.endTime,
            classroom: slot.classroom,
          })),
        );
    },
  };
}
```

`src/lib/repositories/user-repository.ts`

```ts
import { eq } from "drizzle-orm";
import { users } from "@/db/schema";
import type { AppDb } from "@/db/types";

export function createUserRepository(db: AppDb) {
  return {
    async upsertUser(input: {
      id: string;
      email: string;
      name: string;
      role: "student" | "admin";
    }) {
      await db.insert(users).values(input).onConflictDoUpdate({
        target: users.email,
        set: {
          email: input.email,
          name: input.name,
          role: input.role,
        },
      });
    },

    async findByEmail(email: string) {
      const [user] = await db.select().from(users).where(eq(users.email, email));
      return user ?? null;
    },
  };
}
```

`src/lib/repositories/server-repositories.ts`

```ts
import { env } from "@/lib/env";
import { createLocalDb } from "@/db/local";
import { createCourseRepository } from "./course-repository";
import { createUserRepository } from "./user-repository";

let cached:
  | {
      courses: ReturnType<typeof createCourseRepository>;
      users: ReturnType<typeof createUserRepository>;
    }
  | undefined;

export function getServerRepositories() {
  if (!cached) {
    const db = createLocalDb(env.DATABASE_URL);
    cached = {
      courses: createCourseRepository(db),
      users: createUserRepository(db),
    };
  }

  return cached;
}
```

- [ ] **Step 5: テストとスキーマ生成を実行する**

Run: `npx vitest run src/lib/repositories/course-repository.test.ts && npx drizzle-kit generate`  
Expected: PASS for the repository test and a generated `drizzle/` migration output.

- [ ] **Step 6: コミットする**

```bash
git add drizzle.config.ts .env.example src/lib/env.ts src/db/schema.ts src/db/types.ts src/db/local.ts src/lib/repositories/course-repository.ts src/lib/repositories/user-repository.ts src/lib/repositories/server-repositories.ts src/lib/repositories/course-repository.test.ts
git commit -m "feat: add sqlite repositories"
```

## Task 4: Google ログインと権限制御を実装する

**Files:**

- Create: `src/lib/auth/policy.ts`
- Create: `src/lib/auth/policy.test.ts`
- Create: `src/lib/auth/require-user.ts`
- Create: `src/lib/auth/require-admin.ts`
- Create: `src/auth.ts`
- Create: `src/app/api/auth/[...nextauth]/route.ts`
- Create: `src/types/next-auth.d.ts`

- [ ] **Step 1: 認証ポリシーの失敗テストを書く**

`src/lib/auth/policy.test.ts`

```ts
import { describe, expect, it } from "vitest";
import {
  buildAdminEmailSet,
  isAllowedSchoolEmail,
  resolveRole,
} from "./policy";

describe("auth policy", () => {
  const adminEmails = buildAdminEmailSet(
    "teacher1@morijyobi.ac.jp,teacher2@morijyobi.ac.jp",
  );

  it("allows only school domain emails", () => {
    expect(isAllowedSchoolEmail("student@morijyobi.ac.jp", "morijyobi.ac.jp")).toBe(true);
    expect(isAllowedSchoolEmail("guest@gmail.com", "morijyobi.ac.jp")).toBe(false);
  });

  it("marks allowlisted emails as admins", () => {
    expect(resolveRole("teacher1@morijyobi.ac.jp", adminEmails)).toBe("admin");
    expect(resolveRole("student@morijyobi.ac.jp", adminEmails)).toBe("student");
  });
});
```

- [ ] **Step 2: テストを実行して失敗を確認する**

Run: `npx vitest run src/lib/auth/policy.test.ts`  
Expected: FAIL with a message that `buildAdminEmailSet` cannot be imported.

- [ ] **Step 3: 認証ポリシーと型拡張を書く**

`src/lib/auth/policy.ts`

```ts
export function buildAdminEmailSet(csv: string) {
  return new Set(
    csv
      .split(",")
      .map((item) => item.trim().toLowerCase())
      .filter(Boolean),
  );
}

export function isAllowedSchoolEmail(email: string, schoolDomain: string) {
  return email.toLowerCase().endsWith(`@${schoolDomain.toLowerCase()}`);
}

export function resolveRole(
  email: string,
  adminEmails: Set<string>,
): "student" | "admin" {
  return adminEmails.has(email.toLowerCase()) ? "admin" : "student";
}
```

`src/types/next-auth.d.ts`

```ts
import "next-auth";
import "next-auth/jwt";

declare module "next-auth" {
  interface Session {
    user: {
      id: string;
      email: string;
      name: string;
      role: "student" | "admin";
    };
  }
}

declare module "next-auth/jwt" {
  interface JWT {
    userId: string;
    role: "student" | "admin";
  }
}
```

- [ ] **Step 4: Auth.js 設定と権限ヘルパーを書く**

`src/auth.ts`

```ts
import NextAuth from "next-auth";
import Google from "next-auth/providers/google";
import { env } from "@/lib/env";
import {
  buildAdminEmailSet,
  isAllowedSchoolEmail,
  resolveRole,
} from "@/lib/auth/policy";
import { getServerRepositories } from "@/lib/repositories/server-repositories";

const adminEmails = buildAdminEmailSet(env.ADMIN_EMAILS);

export const { handlers, auth, signIn, signOut } = NextAuth({
  session: {
    strategy: "jwt",
  },
  providers: [
    Google({
      clientId: env.GOOGLE_CLIENT_ID,
      clientSecret: env.GOOGLE_CLIENT_SECRET,
    }),
  ],
  callbacks: {
    async signIn({ user, account }) {
      if (account?.provider !== "google" || !user.email || !user.name) {
        return false;
      }

      if (!isAllowedSchoolEmail(user.email, env.SCHOOL_GOOGLE_DOMAIN)) {
        return false;
      }

      const role = resolveRole(user.email, adminEmails);
      const repositories = getServerRepositories();

      await repositories.users.upsertUser({
        id: crypto.randomUUID(),
        email: user.email,
        name: user.name,
        role,
      });

      return true;
    },
    async jwt({ token, user }) {
      if (user?.email) {
        const repositories = getServerRepositories();
        const stored = await repositories.users.findByEmail(user.email);

        if (stored) {
          token.userId = stored.id;
          token.role = stored.role;
        }
      }

      return token;
    },
    async session({ session, token }) {
      session.user = {
        id: token.userId,
        email: session.user.email ?? "",
        name: session.user.name ?? "",
        role: token.role,
      };

      return session;
    },
  },
  secret: env.AUTH_SECRET,
});
```

`src/app/api/auth/[...nextauth]/route.ts`

```ts
import { handlers } from "@/auth";

export const { GET, POST } = handlers;
```

`src/lib/auth/require-user.ts`

```ts
import { redirect } from "next/navigation";
import { auth } from "@/auth";

export async function requireUser() {
  const session = await auth();

  if (!session?.user) {
    redirect("/api/auth/signin");
  }

  return session.user;
}
```

`src/lib/auth/require-admin.ts`

```ts
import { redirect } from "next/navigation";
import { requireUser } from "./require-user";

export async function requireAdmin() {
  const user = await requireUser();

  if (user.role !== "admin") {
    redirect("/");
  }

  return user;
}
```

- [ ] **Step 5: テストを実行して通す**

Run: `npx vitest run src/lib/auth/policy.test.ts`  
Expected: PASS with 2 tests passed.

- [ ] **Step 6: コミットする**

```bash
git add src/lib/auth/policy.ts src/lib/auth/policy.test.ts src/lib/auth/require-user.ts src/lib/auth/require-admin.ts src/auth.ts src/app/api/auth/[...nextauth]/route.ts src/types/next-auth.d.ts
git commit -m "feat: add google auth policy"
```

## Task 5: 管理者向けの授業登録画面を作る

**Files:**

- Create: `src/lib/courses/course-schema.ts`
- Create: `src/lib/courses/course-service.ts`
- Create: `src/lib/courses/course-service.test.ts`
- Create: `src/app/admin/courses/actions.ts`
- Create: `src/app/admin/courses/page.tsx`
- Create: `src/components/admin/course-form.tsx`

- [ ] **Step 1: 授業サービスの失敗テストを書く**

`src/lib/courses/course-service.test.ts`

```ts
import { describe, expect, it, vi } from "vitest";
import { createCourseService } from "./course-service";

describe("createCourseService", () => {
  it("normalizes a course with multiple slots", async () => {
    const repository = {
      saveCourse: vi.fn(),
      listCourses: vi.fn(),
    };

    const service = createCourseService(repository);

    await service.saveFromForm({
      courseId: "course-web",
      title: "Webプログラミング",
      slots: [
        {
          dayOfWeek: 1,
          periodLabel: "1-2限",
          startTime: "09:00",
          endTime: "10:30",
          classroom: "301",
        },
        {
          dayOfWeek: 3,
          periodLabel: "2限",
          startTime: "10:40",
          endTime: "12:10",
          classroom: "",
        },
      ],
    });

    expect(repository.saveCourse).toHaveBeenCalledWith({
      id: "course-web",
      title: "Webプログラミング",
      slots: [
        {
          id: expect.any(String),
          dayOfWeek: 1,
          periodLabel: "1-2限",
          startTime: "09:00",
          endTime: "10:30",
          classroom: "301",
        },
        {
          id: expect.any(String),
          dayOfWeek: 3,
          periodLabel: "2限",
          startTime: "10:40",
          endTime: "12:10",
          classroom: null,
        },
      ],
    });
  });
});
```

- [ ] **Step 2: テストを実行して失敗を確認する**

Run: `npx vitest run src/lib/courses/course-service.test.ts`  
Expected: FAIL with a message that `createCourseService` cannot be imported.

- [ ] **Step 3: Zod スキーマとサービスを書く**

`src/lib/courses/course-schema.ts`

```ts
import { z } from "zod";

export const courseSlotInputSchema = z.object({
  dayOfWeek: z.coerce.number().int().min(0).max(6),
  periodLabel: z.string().min(1),
  startTime: z.string().regex(/^\d{2}:\d{2}$/),
  endTime: z.string().regex(/^\d{2}:\d{2}$/),
  classroom: z.string(),
});

export const courseInputSchema = z.object({
  courseId: z.string().optional(),
  title: z.string().min(1),
  slots: z.array(courseSlotInputSchema).min(1),
});

export type CourseInput = z.infer<typeof courseInputSchema>;
```

`src/lib/courses/course-service.ts`

```ts
import { courseInputSchema } from "./course-schema";

export function createCourseService(repository: {
  saveCourse: (course: {
    id: string;
    title: string;
    slots: Array<{
      id: string;
      dayOfWeek: number;
      periodLabel: string;
      startTime: string;
      endTime: string;
      classroom: string | null;
    }>;
  }) => Promise<void>;
  listCourses: () => Promise<unknown>;
}) {
  return {
    async saveFromForm(input: unknown) {
      const parsed = courseInputSchema.parse(input);

      await repository.saveCourse({
        id: parsed.courseId ?? crypto.randomUUID(),
        title: parsed.title,
        slots: parsed.slots.map((slot) => ({
          id: crypto.randomUUID(),
          dayOfWeek: slot.dayOfWeek,
          periodLabel: slot.periodLabel,
          startTime: slot.startTime,
          endTime: slot.endTime,
          classroom: slot.classroom.trim() === "" ? null : slot.classroom.trim(),
        })),
      });
    },

    async listCourses() {
      return repository.listCourses();
    },
  };
}
```

- [ ] **Step 4: 管理画面と Server Action を書く**

`src/app/admin/courses/actions.ts`

```ts
"use server";

import { requireAdmin } from "@/lib/auth/require-admin";
import { createCourseService } from "@/lib/courses/course-service";
import { getServerRepositories } from "@/lib/repositories/server-repositories";

export async function saveCourseAction(formData: FormData) {
  await requireAdmin();

  const rawSlots = [0, 1, 2]
    .map((index) => ({
      dayOfWeek: formData.get(`slots.${index}.dayOfWeek`),
      periodLabel: formData.get(`slots.${index}.periodLabel`),
      startTime: formData.get(`slots.${index}.startTime`),
      endTime: formData.get(`slots.${index}.endTime`),
      classroom: formData.get(`slots.${index}.classroom`),
    }))
    .filter((slot) => {
      return (
        typeof slot.dayOfWeek === "string" &&
        typeof slot.periodLabel === "string" &&
        typeof slot.startTime === "string" &&
        typeof slot.endTime === "string" &&
        typeof slot.classroom === "string" &&
        slot.periodLabel.trim() !== ""
      );
    });

  const repositories = getServerRepositories();
  const service = createCourseService(repositories.courses);

  await service.saveFromForm({
    courseId: formData.get("courseId"),
    title: formData.get("title"),
    slots: rawSlots,
  });
}
```

`src/components/admin/course-form.tsx`

```tsx
import { saveCourseAction } from "@/app/admin/courses/actions";

type CourseFormProps = {
  course?: {
    id: string;
    title: string;
    slots: Array<{
      id: string;
      dayOfWeek: number;
      periodLabel: string;
      startTime: string;
      endTime: string;
      classroom: string | null;
    }>;
  };
};

export function CourseForm({ course }: CourseFormProps) {
  return (
    <form action={saveCourseAction} className="grid gap-6 rounded-2xl border border-slate-800 p-6">
      <input type="hidden" name="courseId" value={course?.id ?? ""} />
      <label className="grid gap-2">
        <span className="text-sm font-medium">授業名</span>
        <input
          name="title"
          defaultValue={course?.title ?? ""}
          className="rounded-md bg-slate-900 px-3 py-2"
        />
      </label>

      {[0, 1, 2].map((index) => (
        <fieldset key={index} className="grid gap-3 rounded-xl border border-slate-800 p-4">
          <legend className="px-2 text-sm text-slate-300">授業コマ {index + 1}</legend>
          <input
            name={`slots.${index}.dayOfWeek`}
            placeholder="1"
            defaultValue={course?.slots[index]?.dayOfWeek ?? ""}
            className="rounded-md bg-slate-900 px-3 py-2"
          />
          <input
            name={`slots.${index}.periodLabel`}
            placeholder="1-2限"
            defaultValue={course?.slots[index]?.periodLabel ?? ""}
            className="rounded-md bg-slate-900 px-3 py-2"
          />
          <input
            name={`slots.${index}.startTime`}
            placeholder="09:00"
            defaultValue={course?.slots[index]?.startTime ?? ""}
            className="rounded-md bg-slate-900 px-3 py-2"
          />
          <input
            name={`slots.${index}.endTime`}
            placeholder="10:30"
            defaultValue={course?.slots[index]?.endTime ?? ""}
            className="rounded-md bg-slate-900 px-3 py-2"
          />
          <input
            name={`slots.${index}.classroom`}
            placeholder="301"
            defaultValue={course?.slots[index]?.classroom ?? ""}
            className="rounded-md bg-slate-900 px-3 py-2"
          />
        </fieldset>
      ))}

      <button type="submit" className="rounded-md bg-sky-500 px-4 py-2 font-semibold text-slate-950">
        {course ? "授業を更新" : "授業を保存"}
      </button>
    </form>
  );
}
```

`src/app/admin/courses/page.tsx`

```tsx
import { requireAdmin } from "@/lib/auth/require-admin";
import { createCourseService } from "@/lib/courses/course-service";
import { getServerRepositories } from "@/lib/repositories/server-repositories";
import { CourseForm } from "@/components/admin/course-form";

export default async function AdminCoursesPage() {
  await requireAdmin();

  const repositories = getServerRepositories();
  const service = createCourseService(repositories.courses);
  const courses = await service.listCourses();

  return (
    <main className="mx-auto grid max-w-5xl gap-8 px-6 py-10">
      <h1 className="text-3xl font-bold">授業管理</h1>
      <CourseForm />
      <section className="grid gap-3">
        {Array.isArray(courses) &&
          courses.map((course) => (
            <article key={course.id} className="rounded-xl border border-slate-800 p-4">
              <h2 className="mb-4 font-semibold">{course.title}</h2>
              <CourseForm course={course} />
            </article>
          ))}
      </section>
    </main>
  );
}
```

- [ ] **Step 5: テストを実行して通す**

Run: `npx vitest run src/lib/courses/course-service.test.ts`  
Expected: PASS with 1 test passed.

- [ ] **Step 6: コミットする**

```bash
git add src/lib/courses/course-schema.ts src/lib/courses/course-service.ts src/lib/courses/course-service.test.ts src/app/admin/courses/actions.ts src/app/admin/courses/page.tsx src/components/admin/course-form.tsx
git commit -m "feat: add admin course management"
```

## Task 6: 学生の履修登録、週間カレンダー、ホーム画面を作る

**Files:**

- Create: `src/lib/enrollments/enrollment-service.ts`
- Create: `src/lib/enrollments/enrollment-service.test.ts`
- Create: `src/lib/calendar/build-weekly-calendar.ts`
- Create: `src/lib/calendar/build-weekly-calendar.test.ts`
- Create: `src/components/home/next-class-card.tsx`
- Create: `src/components/calendar/weekly-calendar.tsx`
- Create: `src/app/courses/actions.ts`
- Create: `src/app/courses/page.tsx`
- Create: `src/app/calendar/page.tsx`
- Modify: `src/app/page.tsx`

- [ ] **Step 1: 履修サービスと週間カレンダーの失敗テストを書く**

`src/lib/enrollments/enrollment-service.test.ts`

```ts
import { describe, expect, it, vi } from "vitest";
import { createEnrollmentService } from "./enrollment-service";

describe("createEnrollmentService", () => {
  it("replaces selected course ids for a user", async () => {
    const repository = {
      replaceEnrollments: vi.fn(),
      listEnrollmentCourseIds: vi.fn(),
      listCourses: vi.fn(),
      listScheduledClassesForUser: vi.fn(),
    };

    const service = createEnrollmentService(repository);

    await service.saveSelection("user-1", ["course-web", "course-db"]);

    expect(repository.replaceEnrollments).toHaveBeenCalledWith("user-1", [
      "course-web",
      "course-db",
    ]);
  });
});
```

`src/lib/calendar/build-weekly-calendar.test.ts`

```ts
import { describe, expect, it } from "vitest";
import { buildWeeklyCalendar } from "./build-weekly-calendar";

describe("buildWeeklyCalendar", () => {
  it("groups classes by day of week", () => {
    const calendar = buildWeeklyCalendar([
      {
        courseId: "course-web",
        title: "Webプログラミング",
        dayOfWeek: 1,
        periodLabel: "1-2限",
        startTime: "09:00",
        endTime: "10:30",
        classroom: "301",
      },
      {
        courseId: "course-db",
        title: "データベース",
        dayOfWeek: 3,
        periodLabel: "2限",
        startTime: "10:40",
        endTime: "12:10",
        classroom: null,
      },
    ]);

    expect(calendar[0].label).toBe("月");
    expect(calendar[0].entries).toHaveLength(1);
    expect(calendar[2].entries[0].classroom).toBe("教室未設定");
  });
});
```

- [ ] **Step 2: テストを実行して失敗を確認する**

Run: `npx vitest run src/lib/enrollments/enrollment-service.test.ts src/lib/calendar/build-weekly-calendar.test.ts`  
Expected: FAIL because `createEnrollmentService` and `buildWeeklyCalendar` do not exist yet.

- [ ] **Step 3: サービスとカレンダー生成を書く**

`src/lib/enrollments/enrollment-service.ts`

```ts
export function createEnrollmentService(repository: {
  replaceEnrollments: (userId: string, courseIds: string[]) => Promise<void>;
  listEnrollmentCourseIds: (userId: string) => Promise<string[]>;
  listCourses: () => Promise<Array<{ id: string; title: string; slots: unknown[] }>>;
  listScheduledClassesForUser: (userId: string) => Promise<
    Array<{
      courseId: string;
      title: string;
      dayOfWeek: number;
      periodLabel: string;
      startTime: string;
      endTime: string;
      classroom: string | null;
    }>
  >;
}) {
  return {
    async saveSelection(userId: string, courseIds: string[]) {
      await repository.replaceEnrollments(userId, courseIds);
    },

    async getCourseSelection(userId: string) {
      const [selectedCourseIds, courses] = await Promise.all([
        repository.listEnrollmentCourseIds(userId),
        repository.listCourses(),
      ]);

      return { selectedCourseIds, courses };
    },

    async getScheduledClasses(userId: string) {
      return repository.listScheduledClassesForUser(userId);
    },
  };
}
```

`src/lib/calendar/build-weekly-calendar.ts`

```ts
import { classroomLabel } from "@/lib/time";

const dayLabels = ["日", "月", "火", "水", "木", "金", "土"];

export function buildWeeklyCalendar(
  classes: Array<{
    courseId: string;
    title: string;
    dayOfWeek: number;
    periodLabel: string;
    startTime: string;
    endTime: string;
    classroom: string | null;
  }>,
) {
  return dayLabels.map((label, dayOfWeek) => ({
    label,
    entries: classes
      .filter((item) => item.dayOfWeek === dayOfWeek)
      .map((item) => ({
        ...item,
        classroom: classroomLabel(item.classroom),
      })),
  }));
}
```

- [ ] **Step 4: 画面コンポーネントと Server Actions を書く**

`src/components/home/next-class-card.tsx`

```tsx
import type { HomeState } from "@/lib/home/home-types";

export function NextClassCard({ state }: { state: HomeState }) {
  if (state.kind === "needs-enrollment") {
    return <p>履修授業を登録してください。</p>;
  }

  if (state.kind === "done") {
    return <p>{state.message}</p>;
  }

  if (state.kind === "gap") {
    return (
      <div className="grid gap-2 rounded-2xl border border-slate-800 p-6">
        <p className="text-sm text-slate-400">{state.message}</p>
        <h2 className="text-2xl font-bold">{state.nextTitle}</h2>
        <p>{state.nextPeriodLabel}</p>
        <p>{state.nextClassroom}</p>
        <p>{state.nextStartTime}</p>
      </div>
    );
  }

  return (
    <div className="grid gap-2 rounded-2xl border border-slate-800 p-6">
      <p className="text-sm text-slate-400">
        {state.kind === "current" ? "現在の授業" : "次の授業"}
      </p>
      <h2 className="text-2xl font-bold">{state.title}</h2>
      <p>{state.periodLabel}</p>
      <p>{state.classroom}</p>
      <p>{state.startTime}</p>
    </div>
  );
}
```

`src/components/calendar/weekly-calendar.tsx`

```tsx
export function WeeklyCalendar({
  days,
}: {
  days: Array<{
    label: string;
    entries: Array<{
      courseId: string;
      title: string;
      periodLabel: string;
      startTime: string;
      endTime: string;
      classroom: string;
    }>;
  }>;
}) {
  return (
    <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
      {days.map((day) => (
        <article key={day.label} className="rounded-2xl border border-slate-800 p-4">
          <h2 className="text-lg font-semibold">{day.label}</h2>
          <ul className="mt-3 grid gap-3">
            {day.entries.length === 0 ? (
              <li className="text-sm text-slate-400">授業なし</li>
            ) : (
              day.entries.map((entry) => (
                <li key={`${entry.courseId}-${entry.periodLabel}`} className="grid gap-1">
                  <strong>{entry.title}</strong>
                  <span>{entry.periodLabel}</span>
                  <span>
                    {entry.startTime} - {entry.endTime}
                  </span>
                  <span>{entry.classroom}</span>
                </li>
              ))
            )}
          </ul>
        </article>
      ))}
    </section>
  );
}
```

`src/app/courses/actions.ts`

```ts
"use server";

import { requireUser } from "@/lib/auth/require-user";
import { createEnrollmentService } from "@/lib/enrollments/enrollment-service";
import { getServerRepositories } from "@/lib/repositories/server-repositories";

export async function saveEnrollmentsAction(formData: FormData) {
  const user = await requireUser();
  const repositories = getServerRepositories();
  const service = createEnrollmentService(repositories.courses);

  const selectedCourseIds = formData.getAll("courseIds").map(String);

  await service.saveSelection(user.id, selectedCourseIds);
}
```

`src/app/courses/page.tsx`

```tsx
import { requireUser } from "@/lib/auth/require-user";
import { createEnrollmentService } from "@/lib/enrollments/enrollment-service";
import { getServerRepositories } from "@/lib/repositories/server-repositories";
import { saveEnrollmentsAction } from "./actions";

export default async function CoursesPage() {
  const user = await requireUser();
  const repositories = getServerRepositories();
  const service = createEnrollmentService(repositories.courses);
  const { selectedCourseIds, courses } = await service.getCourseSelection(user.id);

  return (
    <main className="mx-auto grid max-w-4xl gap-8 px-6 py-10">
      <h1 className="text-3xl font-bold">履修登録</h1>
      <form action={saveEnrollmentsAction} className="grid gap-4">
        {courses.map((course) => (
          <label key={course.id} className="flex items-start gap-3 rounded-xl border border-slate-800 p-4">
            <input
              type="checkbox"
              name="courseIds"
              value={course.id}
              defaultChecked={selectedCourseIds.includes(course.id)}
            />
            <span className="grid gap-2">
              <strong>{course.title}</strong>
              <span className="text-sm text-slate-400">
                {course.slots
                  .map((slot) => `${slot.dayOfWeek} ${slot.periodLabel} ${slot.startTime}-${slot.endTime}`)
                  .join(" / ")}
              </span>
            </span>
          </label>
        ))}
        <button type="submit" className="rounded-md bg-sky-500 px-4 py-2 font-semibold text-slate-950">
          保存
        </button>
      </form>
    </main>
  );
}
```

`src/app/calendar/page.tsx`

```tsx
import { requireUser } from "@/lib/auth/require-user";
import { buildWeeklyCalendar } from "@/lib/calendar/build-weekly-calendar";
import { createEnrollmentService } from "@/lib/enrollments/enrollment-service";
import { getServerRepositories } from "@/lib/repositories/server-repositories";
import { WeeklyCalendar } from "@/components/calendar/weekly-calendar";

export default async function CalendarPage() {
  const user = await requireUser();
  const repositories = getServerRepositories();
  const service = createEnrollmentService(repositories.courses);
  const classes = await service.getScheduledClasses(user.id);
  const days = buildWeeklyCalendar(classes);

  return (
    <main className="mx-auto grid max-w-6xl gap-8 px-6 py-10">
      <h1 className="text-3xl font-bold">自分用カレンダー</h1>
      <WeeklyCalendar days={days} />
    </main>
  );
}
```

`src/app/page.tsx`

```tsx
import Link from "next/link";
import { auth } from "@/auth";
import { resolveHomeState } from "@/lib/home/resolve-home-state";
import { createEnrollmentService } from "@/lib/enrollments/enrollment-service";
import { getServerRepositories } from "@/lib/repositories/server-repositories";
import { NextClassCard } from "@/components/home/next-class-card";

export default async function HomePage() {
  const session = await auth();

  if (!session?.user) {
    return (
      <main className="mx-auto flex min-h-screen max-w-3xl flex-col justify-center gap-4 px-6 py-16">
        <p className="text-sm font-semibold text-sky-300">ver0.1</p>
        <h1 className="text-4xl font-bold tracking-tight">次の教室案内</h1>
        <p className="text-lg text-slate-300">
          学校の Google アカウントでログインすると利用できます。
        </p>
        <Link href="/api/auth/signin" className="w-fit rounded-md bg-sky-500 px-4 py-2 font-semibold text-slate-950">
          Google でログイン
        </Link>
      </main>
    );
  }

  const repositories = getServerRepositories();
  const service = createEnrollmentService(repositories.courses);
  const classes = await service.getScheduledClasses(session.user.id);
  const now = new Date();

  const state = resolveHomeState({
    classes,
    now: {
      dayOfWeek: now.getDay(),
      time: `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`,
    },
  });

  return (
    <main className="mx-auto grid max-w-4xl gap-6 px-6 py-10">
      <p className="text-sm font-semibold text-sky-300">次の教室案内</p>
      <NextClassCard state={state} />
    </main>
  );
}
```

- [ ] **Step 5: テストを実行して通す**

Run: `npx vitest run src/lib/enrollments/enrollment-service.test.ts src/lib/calendar/build-weekly-calendar.test.ts src/lib/home/resolve-home-state.test.ts`  
Expected: PASS with all enrollment, calendar, and home state tests passing.

- [ ] **Step 6: コミットする**

```bash
git add src/lib/enrollments/enrollment-service.ts src/lib/enrollments/enrollment-service.test.ts src/lib/calendar/build-weekly-calendar.ts src/lib/calendar/build-weekly-calendar.test.ts src/components/home/next-class-card.tsx src/components/calendar/weekly-calendar.tsx src/app/courses/actions.ts src/app/courses/page.tsx src/app/calendar/page.tsx src/app/page.tsx
git commit -m "feat: add student scheduling flows"
```

## Task 7: Cloudflare Workers + D1 の staging / production 基盤を追加する

**Files:**

- Modify: `package.json`
- Modify: `next.config.ts`
- Create: `open-next.config.ts`
- Create: `wrangler.jsonc`
- Create: `scripts/write-wrangler-config.mjs`
- Create: `.dev.vars.example`
- Modify: `.gitignore`
- Create: `src/db/cloudflare.ts`
- Create: `src/lib/runtime/database-config.ts`
- Create: `src/lib/runtime/database-config.test.ts`
- Modify: `src/lib/repositories/server-repositories.ts`

- [ ] **Step 1: 実行環境切替の失敗テストを書く**

`src/lib/runtime/database-config.test.ts`

```ts
import { describe, expect, it } from "vitest";
import { resolveDatabaseConfig } from "./database-config";

describe("resolveDatabaseConfig", () => {
  it("prefers D1 when Cloudflare mode is enabled", () => {
    expect(
      resolveDatabaseConfig({
        databaseUrl: "dev.sqlite",
        cloudflareTarget: "1",
      }),
    ).toEqual({
      kind: "d1",
    });
  });

  it("uses sqlite when no Cloudflare binding is available", () => {
    expect(
      resolveDatabaseConfig({
        databaseUrl: "dev.sqlite",
        cloudflareTarget: undefined,
      }),
    ).toEqual({
      kind: "sqlite",
      databaseUrl: "dev.sqlite",
    });
  });
});
```

- [ ] **Step 2: テストを実行して失敗を確認する**

Run: `npx vitest run src/lib/runtime/database-config.test.ts`  
Expected: FAIL because `resolveDatabaseConfig` does not exist yet.

- [ ] **Step 3: D1 接続と repository 切替を書き、ローカルと Cloudflare の両方を支える**

`src/lib/runtime/database-config.ts`

```ts
export function resolveDatabaseConfig(input: {
  databaseUrl: string;
  cloudflareTarget: string | undefined;
}) {
  if (input.cloudflareTarget === "1") {
    return { kind: "d1" as const };
  }

  return {
    kind: "sqlite" as const,
    databaseUrl: input.databaseUrl,
  };
}
```

`src/db/cloudflare.ts`

```ts
import { getCloudflareContext } from "@opennextjs/cloudflare";
import { drizzle } from "drizzle-orm/d1";
import * as schema from "./schema";

export function createCloudflareDb() {
  const { env } = getCloudflareContext();
  return drizzle(env.DB, { schema });
}
```

`src/lib/repositories/server-repositories.ts`

```ts
import { env } from "@/lib/env";
import { createCloudflareDb } from "@/db/cloudflare";
import { createLocalDb } from "@/db/local";
import { createCourseRepository } from "./course-repository";
import { createUserRepository } from "./user-repository";
import { resolveDatabaseConfig } from "@/lib/runtime/database-config";

let cached:
  | {
      courses: ReturnType<typeof createCourseRepository>;
      users: ReturnType<typeof createUserRepository>;
    }
  | undefined;

export function getServerRepositories() {
  if (!cached) {
    const config = resolveDatabaseConfig({
      databaseUrl: env.DATABASE_URL,
      cloudflareTarget: process.env.CLOUDFLARE_TARGET,
    });

    const db =
      config.kind === "d1"
        ? createCloudflareDb()
        : createLocalDb(config.databaseUrl);

    cached = {
      courses: createCourseRepository(db),
      users: createUserRepository(db),
    };
  }

  return cached;
}
```

- [ ] **Step 4: OpenNext / Wrangler 設定と scripts を書く**

Create the three D1 databases first:

```bash
npx wrangler d1 create next-class-local-preview
npx wrangler d1 create next-class-staging
npx wrangler d1 create next-class-production
```

Set `PREVIEW_ID`, `STAGING_ID`, and `PRODUCTION_ID` to the three IDs returned above, then write the config files:

`package.json`

```json
{
  "name": "next-pyon-suzuryo",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "test": "vitest run",
    "db:generate": "drizzle-kit generate",
    "db:push": "drizzle-kit push",
    "cf-typegen": "wrangler types --env-interface CloudflareEnv",
    "preview": "opennextjs-cloudflare build && opennextjs-cloudflare preview",
    "deploy:staging": "opennextjs-cloudflare build && opennextjs-cloudflare deploy --env staging",
    "deploy:production": "opennextjs-cloudflare build && opennextjs-cloudflare deploy --env production"
  }
}
```

`next.config.ts`

```ts
import { initOpenNextCloudflareForDev } from "@opennextjs/cloudflare";
import type { NextConfig } from "next";

initOpenNextCloudflareForDev();

const nextConfig: NextConfig = {};

export default nextConfig;
```

`open-next.config.ts`

```ts
import type { OpenNextConfig } from "@opennextjs/cloudflare";

const config: OpenNextConfig = {};

export default config;
```

`scripts/write-wrangler-config.mjs`

```js
import { writeFileSync } from "node:fs";

const [previewId, stagingId, productionId] = process.argv.slice(2);

if (!previewId || !stagingId || !productionId) {
  throw new Error("previewId, stagingId, productionId are required");
}

const config = {
  $schema: "node_modules/wrangler/config-schema.json",
  name: "next-pyon-suzuryo",
  main: ".open-next/worker.js",
  compatibility_date: "2026-05-14",
  compatibility_flags: ["nodejs_compat"],
  assets: {
    binding: "ASSETS",
    directory: ".open-next/assets",
  },
  vars: {
    CLOUDFLARE_TARGET: "1",
  },
  d1_databases: [
    {
      binding: "DB",
      database_name: "next-class-local-preview",
      database_id: previewId,
      migrations_dir: "drizzle",
    },
  ],
  env: {
    staging: {
      name: "next-pyon-suzuryo-staging",
      vars: {
        CLOUDFLARE_TARGET: "1",
      },
      d1_databases: [
        {
          binding: "DB",
          database_name: "next-class-staging",
          database_id: stagingId,
          migrations_dir: "drizzle",
        },
      ],
    },
    production: {
      name: "next-pyon-suzuryo-production",
      vars: {
        CLOUDFLARE_TARGET: "1",
      },
      d1_databases: [
        {
          binding: "DB",
          database_name: "next-class-production",
          database_id: productionId,
          migrations_dir: "drizzle",
        },
      ],
    },
  },
};

writeFileSync("wrangler.jsonc", `${JSON.stringify(config, null, 2)}\n`);
```

`wrangler.jsonc`

```bash
node scripts/write-wrangler-config.mjs "$PREVIEW_ID" "$STAGING_ID" "$PRODUCTION_ID"
```

`.dev.vars.example`

```bash
NEXTJS_ENV=development
CLOUDFLARE_TARGET=1
AUTH_SECRET=local-preview-secret
GOOGLE_CLIENT_ID=preview-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=preview-client-secret
SCHOOL_GOOGLE_DOMAIN=morijyobi.ac.jp
ADMIN_EMAILS=teacher1@morijyobi.ac.jp,teacher2@morijyobi.ac.jp
```

`.gitignore`

```gitignore
node_modules
.next
.open-next
coverage
data
.env
.dev.vars
worker-configuration.d.ts
```

- [ ] **Step 5: Cloudflare 用の型生成と preview を確認する**

Run: `npm run cf-typegen && npx wrangler d1 migrations apply next-class-local-preview --local && npm run preview`  
Expected: a generated `worker-configuration.d.ts` file and a local Worker preview that starts without configuration errors.

- [ ] **Step 6: コミットする**

```bash
git add package.json next.config.ts open-next.config.ts wrangler.jsonc scripts/write-wrangler-config.mjs .dev.vars.example .gitignore src/db/cloudflare.ts src/lib/runtime/database-config.ts src/lib/runtime/database-config.test.ts src/lib/repositories/server-repositories.ts
git commit -m "feat: add cloudflare deployment foundation"
```

## Task 8: README を整え、ローカル完成から staging / production までの手順を固定する

**Files:**

- Modify: `README.md`

- [ ] **Step 1: README を更新する**

`README.md`

```md
# next-pyon-suzuryo

「次の教室案内」アプリの開発リポジトリ。

## ローカル開発

1. `.env.example` を `.env` にコピーする
2. `npm install` を実行する
3. `npm run db:push` で SQLite を作る
4. `npm run dev` を実行する

## テスト

- `npm run test`
- `npm run lint`

## Cloudflare preview

1. `.dev.vars.example` を `.dev.vars` にコピーする
2. `wrangler d1 create next-class-local-preview`
3. `wrangler d1 create next-class-staging`
4. `wrangler d1 create next-class-production`
5. 返ってきた D1 ID を `PREVIEW_ID` / `STAGING_ID` / `PRODUCTION_ID` に控える
6. `node scripts/write-wrangler-config.mjs "$PREVIEW_ID" "$STAGING_ID" "$PRODUCTION_ID"`
7. `npm run cf-typegen`
8. `wrangler d1 migrations apply next-class-local-preview --local`
9. `npm run preview`

## staging デプロイ

1. Cloudflare 側で Google OAuth の staging 用リダイレクト URL を登録する
2. `wrangler secret put AUTH_SECRET --env staging`
3. `wrangler secret put GOOGLE_CLIENT_ID --env staging`
4. `wrangler secret put GOOGLE_CLIENT_SECRET --env staging`
5. `wrangler secret put SCHOOL_GOOGLE_DOMAIN --env staging`
6. `wrangler secret put ADMIN_EMAILS --env staging`
7. `wrangler d1 migrations apply next-class-staging --env staging`
8. `npm run deploy:staging`

## production デプロイ

1. Cloudflare 側で Google OAuth の production 用リダイレクト URL を登録する
2. `wrangler secret put AUTH_SECRET --env production`
3. `wrangler secret put GOOGLE_CLIENT_ID --env production`
4. `wrangler secret put GOOGLE_CLIENT_SECRET --env production`
5. `wrangler secret put SCHOOL_GOOGLE_DOMAIN --env production`
6. `wrangler secret put ADMIN_EMAILS --env production`
7. `wrangler d1 migrations apply next-class-production --env production`
8. `npm run deploy:production`
```

- [ ] **Step 2: 全体の確認コマンドを実行する**

Run: `npm run test && npm run lint && npm run build`  
Expected: PASS for the test suite, successful lint output, and a successful Next.js build.

- [ ] **Step 3: コミットする**

```bash
git add README.md
git commit -m "docs: document local and cloudflare workflows"
```
