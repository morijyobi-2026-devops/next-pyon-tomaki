# next-pyon-suzuryo

next-pyon-suzuryo

更新日: 2026-05-21

## Markdown lint

1. `mise install`
   - `mise.toml` に従って Node.js 24.15.0 と pnpm 10.33.0 を用意します。
2. `pnpm install`
   - `prepare` script で husky が実行され、`pre-commit` hook が設定されます。
3. `pnpm run lint`
   - 現在は `pnpm run lint:md` を呼び出し、`README.md` と `docs/**/*.md` をまとめて確認できます。

## Commit-time auto-check

- commit 時は husky の `pre-commit` から、ローカルに固定された `./node_modules/.bin/lint-staged` が実行されます。
- hook を直接確認する場合も、先に `pnpm install` を実行してローカル依存関係をそろえてください。
- staged された `.md` ファイルだけが `markdownlint-cli2` で検査されます。
- markdownlint が失敗した場合、commit は中断されます。

## GitHub Actions

- `.github/workflows/lint.yml` で `pull_request` と `push` を契機に lint を実行します。
- GitHub Actions でも Node.js 24.15.0 を使い、pnpm 10.33.0 の `minimumReleaseAge` を 2880 分（2 日）に設定した上で `pnpm install --frozen-lockfile` の後に `pnpm run lint` を実行します。
- CI では lint・build・docker に加え OpenNext ビルド検証も実行します。
- Cloudflare へのデプロイは Cloudflare Workers Builds（Git ネイティブ連携）が担当するため、GitHub に API トークンは登録しません。詳細は [`next-pyon/README.md`](next-pyon/README.md) を参照してください。

## GitHub 運用

- Issue と Pull Request は日本語で記載します。
