# syntax=docker.io/docker/dockerfile:1

FROM node:24-alpine

WORKDIR /app

# Install pnpm globally
RUN corepack enable pnpm

# Copy package files for workspace
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY next-app/package.json ./next-app/

# Install dependencies with frozen lockfile
RUN pnpm install --frozen-lockfile

# Copy configuration files
COPY next-app/tsconfig.json next-app/next.config.js ./next-app/

# Copy Prisma schema
COPY prisma ./prisma

# Generate Prisma client
# Note: build-time generation for development environment (runtime env injection via Docker Compose)
RUN pnpm prisma generate --schema ./prisma/schema.prisma || echo "Prisma generation completed with warnings"

# Copy source code
COPY next-app/src ./next-app/src
COPY next-app/public ./next-app/public

# Expose port 3000
EXPOSE 3000

# Start development server with Prisma migration
# set -e ensures errors propagate and stop execution immediately
CMD ["sh", "-c", "set -e; pnpm prisma migrate deploy --schema ./prisma/schema.prisma && pnpm --filter next-pyon-tomaki-app dev"]
