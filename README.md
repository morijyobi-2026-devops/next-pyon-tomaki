# next-pyon-tomaki

next-pyon-tomaki

更新日: 2026-06-29

## セットアップとツール

1. `mise install`
   - `mise.toml` に従って Node.js 24.17.0 と pnpm 11.8.0 を用意します。
2. `pnpm install`
   - `prepare` script で husky が実行され、`pre-commit` hook が設定されます。
3. `pnpm run lint`
   - ESLint (`next-pyon`) と `markdownlint-cli2` (ドキュメント) をまとめて確認できます。

## コミット時の自動チェック

- コミット時は husky の `pre-commit` から `lint-staged` が実行されます。
- ステージングされた `.md` ファイルおよび `next-pyon/` 配下のソースコードに対して、それぞれ `markdownlint-cli2` と `eslint` が実行されます。
- 静的解析でエラーが出た場合、コミットは中断されます。

## CI/CD (GitHub Actions)

- **CI (`ci.yml`)**:
  - プルリクエスト作成・更新時に実行されます。
  - `lint` ジョブでコードとドキュメントのチェックを行います。
  - `build` ジョブで Next.js アプリのビルド、および OpenNext 向けのビルド (`next-pyon/.open-next`) を行い、アーティファクトとして保存します。
  - `deploy-preview` ジョブで Cloudflare Pages にプレビュー版をデプロイし、プルリクエストにプレビューURLを自動でコメントします。
- **CD (`cd.yml`)**:
  - `main` ブランチへのプッシュ（マージ）時に実行されます。
  - D1マイグレーションをプロダクション環境に適用したのち、ビルドおよび Cloudflare Pages への本番デプロイを行います。

デプロイには、GitHub Secrets に設定された `CLOUDFLARE_API_TOKEN` および `CLOUDFLARE_ACCOUNT_ID` を使用します。

## 開発運用

- Issue と Pull Request は日本語で記載します。
