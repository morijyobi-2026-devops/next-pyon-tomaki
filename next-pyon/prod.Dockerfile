# syntax=docker.io/docker/dockerfile:1

# 本番用イメージ。ビルドコンテキストはリポジトリルート（pnpm workspace のため）。
FROM node:24.18.0-alpine AS base
RUN corepack enable pnpm
ENV HUSKY=0
ENV NEXT_TELEMETRY_DISABLED=1

# Step 1. 依存解決とビルド
FROM base AS builder
WORKDIR /app

# 依存解決に必要なファイルだけ先にコピーしてレイヤーキャッシュを効かせる
COPY pnpm-workspace.yaml pnpm-lock.yaml package.json ./
COPY next-pyon/package.json ./next-pyon/
RUN pnpm install --frozen-lockfile

COPY next-pyon ./next-pyon
# next.config.ts はこのフラグがある時だけ standalone 出力を有効にする
ENV BUILD_STANDALONE=1
RUN NODE_OPTIONS="--max-old-space-size=1536" pnpm --filter next-pyon build

# Step 2. 本番イメージ。standalone 出力だけをコピーして軽量化する。
FROM node:24.18.0-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME=0.0.0.0
ENV NEXT_TELEMETRY_DISABLED=1

# root では実行しない
RUN addgroup -S -g 1001 nodejs \
  && adduser -S -u 1001 -G nodejs nextjs

# outputFileTracingRoot をリポジトリルートにしているため、
# standalone は next-pyon/ のディレクトリ構造を保持して出力される。
COPY --from=builder --chown=nextjs:nodejs /app/next-pyon/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/next-pyon/.next/static ./next-pyon/.next/static

USER nextjs

EXPOSE 3000

# ポートは compose 側で公開する
CMD ["node", "next-pyon/server.js"]
