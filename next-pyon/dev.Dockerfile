# syntax=docker.io/docker/dockerfile:1

# 開発用イメージ。ビルドコンテキストはリポジトリルート（pnpm workspace のため）。
FROM node:24.19.0-alpine

WORKDIR /app

# husky の git hook セットアップを無効化（コンテナ内に .git は無い）
ENV HUSKY=0
ENV NEXT_TELEMETRY_DISABLED=1

RUN corepack enable pnpm

# better-sqlite3 等のネイティブモジュールビルド用にツールをインストール
RUN apk add --no-cache python3 make g++

# 依存解決に必要なファイルだけ先にコピーしてレイヤーキャッシュを効かせる
COPY pnpm-workspace.yaml pnpm-lock.yaml package.json .npmrc ./
COPY next-pyon/package.json ./next-pyon/
# install 後、同じレイヤー内で pnpm ストア/キャッシュを削除してイメージを縮める。
# node_modules はハードリンクで実体が残るため壊れない（1.11GB -> 826MB）。
RUN pnpm install --frozen-lockfile \
  && rm -rf /root/.cache /root/.local/share/pnpm/store

# アプリのソース。compose では bind mount で上書きされる（ホットリロード用）。
COPY next-pyon ./next-pyon

WORKDIR /app/next-pyon

EXPOSE 3000

CMD ["pnpm", "dev"]
