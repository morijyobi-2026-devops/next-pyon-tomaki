# syntax=docker.io/docker/dockerfile:1

FROM node:24-alpine AS base
RUN corepack enable pnpm

# 1. Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Copy package files for workspace
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY next-pyon/package.json ./next-pyon/

# Install dependencies with frozen lockfile
RUN pnpm install --frozen-lockfile

# 2. Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/next-pyon/node_modules ./next-pyon/node_modules
COPY . .

# Generate Prisma client
# DATABASE_URL はビルド時に実際の接続は不要だが、schema の env() 参照解決のためダミー値を渡す
ENV DATABASE_URL="file:/tmp/dummy.db"
RUN pnpm prisma generate --schema ./prisma/schema.prisma

# Next.js telemetry disable
ENV NEXT_TELEMETRY_DISABLED=1

RUN pnpm --filter next-pyon-tomaki-app build

# 3. Production runner
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy static assets and standalone build
COPY --from=builder /app/next-pyon/public ./next-pyon/public
COPY --from=builder --chown=nextjs:nodejs /app/next-pyon/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/next-pyon/.next/static ./next-pyon/.next/static

# Copy Prisma schema and migrations (for reference or manual migrations if needed)
COPY --from=builder --chown=nextjs:nodejs /app/prisma ./prisma

# Create directory for SQLite database if used locally in production mode
RUN mkdir -p /app/data && chown nextjs:nodejs /app/data

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Start Next.js server using standalone output
CMD ["node", "next-pyon/server.js"]
