import { Suspense } from "react";
import { Counter } from "./counter";

export const dynamic = "force-dynamic";

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-4 bg-zinc-50 dark:bg-zinc-950 text-zinc-900 dark:text-zinc-50">
      <div className="p-8 bg-white dark:bg-zinc-900 rounded-2xl shadow-lg border border-zinc-200 dark:border-zinc-800 text-center max-w-sm w-full">
        <h1 className="text-4xl font-extrabold tracking-tight mb-2 bg-gradient-to-r from-violet-600 to-indigo-600 dark:from-violet-400 dark:to-indigo-400 bg-clip-text text-transparent">
          next-pyon
        </h1>
        <p className="text-sm text-zinc-500 dark:text-zinc-400 mb-6">
          Cloudflare D1 & Local SQLite Counter Demo
        </p>
        <div className="flex flex-col items-center justify-center p-6 bg-zinc-50 dark:bg-zinc-950 rounded-xl border border-zinc-100 dark:border-zinc-900">
          <span className="text-xs font-semibold text-zinc-400 uppercase tracking-wider mb-1">
            Total Visits
          </span>
          <Suspense
            fallback={
              <span className="text-5xl font-black text-indigo-200 dark:text-indigo-800 tabular-nums animate-pulse">
                ...
              </span>
            }
          >
            <Counter />
          </Suspense>
        </div>
      </div>
    </main>
  );
}

