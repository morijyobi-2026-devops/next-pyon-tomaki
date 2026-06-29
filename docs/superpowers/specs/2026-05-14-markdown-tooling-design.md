# Markdown Tooling Design

## 1. 目的

Markdown ファイルに対して、手動実行と commit 時の両方で
markdownlint を安定して実行できるようにする。

## 2. 解決したい課題

- リポジトリに `package.json` がまだ存在しない
- Markdown lint を実行する入口が統一されていない
- `.md` を commit する際に自動チェックが走らない

## 3. 採用方針

- tooling 用の最小 `package.json` を追加する
- `markdownlint-cli2` を devDependency として追加する
- `npm run lint:md` で Markdown 全体を lint できるようにする
- `husky` の `pre-commit` から `lint-staged` を呼び、
  staged の `.md` だけを lint する
- 既存の `.markdownlint.jsonc` をルール定義として継続利用する

## 4. 構成

### 4.1 package.json

- `lint:md` script を追加する
- `prepare` script を追加し、husky をセットアップできるようにする
- `markdownlint-cli2`、`husky`、`lint-staged` を管理する

### 4.2 Husky

- `.husky/pre-commit` を追加する
- pre-commit では `npx lint-staged` を実行する

### 4.3 lint-staged

- staged された `*.md` を対象に `markdownlint-cli2` を実行する
- 対象は commit 対象のファイルだけに絞り、待ち時間を抑える

### 4.4 ドキュメント

- README に `npm install` 後の hook セットアップを明記する
- `npm run lint:md` の実行方法を README に書く

## 5. エラー時の扱い

- markdownlint が失敗した場合、pre-commit は失敗として commit を止める
- 開発者は手動で `npm run lint:md` を実行して全体確認できる

## 6. 完成条件

1. `npm run lint:md` で Markdown lint を実行できる
2. `.md` を staged して commit すると pre-commit で自動 lint が走る
3. 既存の Markdown ファイルが現行ルールで lint を通る
