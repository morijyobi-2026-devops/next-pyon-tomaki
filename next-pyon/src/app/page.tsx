import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

export default async function Home() {
  const counter = await prisma.counter.upsert({
    where: { id: 1 },
    update: { count: { increment: 1 } },
    create: { id: 1, count: 1 },
  });

  return (
    <div className="flex min-h-screen flex-col items-center justify-center p-24 bg-zinc-50 dark:bg-black text-black dark:text-zinc-50 font-sans">
      <main className="flex flex-col items-center gap-4 text-center">
        <h1 className="text-4xl font-bold tracking-tight">next-pyon</h1>
        <p className="text-lg text-zinc-600 dark:text-zinc-400">
          Welcome to your new Next.js application on Cloudflare.
        </p>
        <div className="mt-8 p-6 bg-white dark:bg-zinc-900 rounded-2xl shadow-xl border border-zinc-200 dark:border-zinc-800 min-w-[200px]">
          <p className="text-sm font-medium text-zinc-500 dark:text-zinc-400 uppercase tracking-wider">
            Access Counter
          </p>
          <p className="text-6xl font-black mt-2 text-indigo-600 dark:text-indigo-400">
            {counter.count}
          </p>
        </div>
      </main>
    </div>
  );
}

