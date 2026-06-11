export default function Home() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center p-24 bg-zinc-50 dark:bg-black text-black dark:text-zinc-50 font-sans">
      <main className="flex flex-col items-center gap-4 text-center">
        <h1 className="text-4xl font-bold tracking-tight">next-pyon</h1>
        <p className="text-lg text-zinc-600 dark:text-zinc-400">
          Welcome to your new Next.js application on Cloudflare.
        </p>
      </main>
    </div>
  );
}

