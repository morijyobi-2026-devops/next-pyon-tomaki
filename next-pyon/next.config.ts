import type { NextConfig } from "next";
import path from "node:path";

// Docker の prod イメージビルド時のみ standalone 出力を有効にする。
// ローカルの `next start` は `output: "standalone"` と併用できず警告が出るため、
// 通常ビルド（mise run build / start）や OpenNext のビルドには影響させない。
const standalone =
  process.env.BUILD_STANDALONE === "1"
    ? {
        output: "standalone" as const,
        // pnpm workspace（モノレポ）のルートを基準にトレースする。
        // これがないと standalone がルートのロックファイル/依存を取りこぼす。
        outputFileTracingRoot: path.join(__dirname, ".."),
      }
    : {};

const nextConfig: NextConfig = {
  ...standalone,
};

export default nextConfig;
