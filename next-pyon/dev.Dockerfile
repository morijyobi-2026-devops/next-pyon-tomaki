# syntax=docker.io/docker/dockerfile:1

# 開発用イメージ。ビルドコンテキストはリポジトリルート（pnpm workspace のため）。
FROM node:24.18.0-alpine

WORKDIR /app

# husky の git hook セットアップを無効化（コンテナ内に .git は無い）
ENV HUSKY=0
ENV NEXT_TELEMETRY_DISABLED=1

RUN corepack enable pnpm

# 依存解決に必要なファイルだけ先にコピーしてレイヤーキャッシュを効かせる
COPY pnpm-workspace.yaml pnpm-lock.yaml package.json ./
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
