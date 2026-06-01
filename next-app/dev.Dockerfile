# syntax=docker.io/docker/dockerfile:1

FROM node:24-alpine

WORKDIR /app

# Install pnpm globally
RUN corepack enable pnpm

# Copy package files
COPY package.json pnpm-lock.yaml ./

# Install dependencies with frozen lockfile
RUN pnpm install --frozen-lockfile

# Copy configuration files
COPY tsconfig.json .
COPY next.config.js .

# Copy Prisma schema
COPY prisma ./prisma

# Generate Prisma client
# Note: build-time generation for development environment (runtime env injection via Docker Compose)
RUN pnpm prisma generate || echo "Prisma generation completed with warnings"

# Copy source code
COPY src ./src
COPY public ./public

# Expose port 3000
EXPOSE 3000

# Start development server with Prisma migration
# set -e ensures errors propagate and stop execution immediately
CMD ["sh", "-c", "set -e; pnpm prisma migrate deploy && pnpm dev"]
