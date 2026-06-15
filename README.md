# next-pyon-tomaki

## プロジェクト概要

学校の時間割から「次にどの教室へ行けばよいか」をすぐに確認できる個人用アプリケーション。

学生は Google Workspace アカウントでログイン後、授業一覧から自分の履修授業を選択します。選択結果から個人用カレンダーが自動生成され、ホーム画面では現在時刻に応じて「次に行くべき教室」が大きく表示されます。

授業が終了する 10 分前には自動的に次の授業が優先表示されるため、毎回時間割表を確認する手間が不要になります。

## 主な機能（ver0.1）

- **Google Workspace ログイン** - 学校ドメインのアカウントで認証
- **履修授業選択** - 授業一覧から自分の時間割を構成
- **個人用カレンダー生成** - 選択した授業から週間予定を自動作成
- **次の教室案内** - 時刻に応じて次の移動先を優先表示
- **管理者向け授業マスタ管理** - 許可されたユーザーが授業情報を登録・編集

## 技術スタック

- **フロントエンド / バックエンド** - Next.js 16 (App Router) + TypeScript
- **UI** - React 19 + Tailwind CSS v4
- **データベース** - SQLite (Prisma ORM)
- **認証** - Google OAuth 2.0
- **インフラ** - Docker / Docker Compose

## 開発・実行環境 (Docker Compose)

本プロジェクトでは Docker Compose を使用して、開発環境および本番環境のビルド・実行が可能です。

### 事前準備

コンテナ間の通信を確立するため、共通ネットワーク `my_network` を事前に作成してください。

```bash
docker network create my_network
```

### 開発環境の起動 (ホットリロード対応)

開発用コンテナをビルドおよび起動します。ホスト側のソースコードの変更はホットリロードにより即座に反映されます。

```bash
# ビルド
docker compose -f compose.dev.yaml build

# 起動
docker compose -f compose.dev.yaml up
```

### 本番環境の起動 (マルチステージビルド / Standalone出力)

Next.js の `standalone` モードビルドを利用した、軽量な本番用イメージのビルドおよび起動を行います。

```bash
# ビルド (ビルド時に埋め込む環境変数を引き渡します)
docker compose -f compose.prod.yaml build

# 起動 (バックグラウンドで起動)
docker compose -f compose.prod.yaml up -d
```

## ドキュメント

- [設計仕様](docs/superpowers/specs/2026-04-30-classroom-navigation-design.md) - ver0.1 の完全な要件定義
- [実装計画](docs/superpowers/plans/2026-05-14-implementation.md) - 15 タスク分解、5 フェーズ構成

## 更新日

2026-06-15
