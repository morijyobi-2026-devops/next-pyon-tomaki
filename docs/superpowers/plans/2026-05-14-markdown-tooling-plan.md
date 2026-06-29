# Markdown Tooling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Markdown lint を `npm run lint:md` で実行でき、`.md` を commit する時は husky + lint-staged で自動的に markdownlint が走るようにする。

**Architecture:** リポジトリ直下に tooling 用の最小 `package.json` を追加し、`markdownlint-cli2`、`husky`、`lint-staged` を devDependency として管理する。手動実行は `lint:md` script に集約し、commit 時は `.husky/pre-commit` から `lint-staged` を呼んで staged の `.md` だけを検査する。

**Tech Stack:** npm, markdownlint-cli2, husky, lint-staged

---

## File Structure

- `package.json` - Markdown tooling の依存関係、scripts、lint-staged 設定
- `package-lock.json` - npm install で生成される lockfile
- `.husky/pre-commit` - commit 前に lint-staged を起動する hook
- `README.md` - markdownlint の手動実行方法と hook のセットアップ手順
- `.markdownlint.jsonc` - markdownlint ルール設定。既存ファイルを継続利用する

### Task 1: package.json と markdownlint 実行入口を追加する

**Files:**

- Create: `package.json`
- Create: `package-lock.json`
- Modify: `README.md`

- [ ] **Step 1: `lint:md` の失敗確認を行う**

Run: `npm run lint:md`  
Expected: FAIL with an npm error that `package.json` cannot be found or that the `lint:md` script is missing.

- [ ] **Step 2: 最小の tooling 用 package.json を書く**

`package.json`

```json
{
  "name": "next-pyon-suzuryo-tooling",
  "private": true,
  "scripts": {
    "prepare": "husky",
    "lint:md": "markdownlint-cli2 \"README.md\" \"docs/**/*.md\""
  },
  "devDependencies": {
    "husky": "^9.1.7",
    "lint-staged": "^15.2.10",
    "markdownlint-cli2": "^0.22.0"
  },
  "lint-staged": {
    "*.md": "markdownlint-cli2"
  }
}
```

- [ ] **Step 3: 依存関係をインストールして lockfile を生成する**

Run: `npm install`  
Expected: PASS with `package-lock.json` created and `.husky/` initialized by the `prepare` script.

- [ ] **Step 4: README に手動実行手順を追記する**

`README.md`

```md
# next-pyon-suzuryo

next-pyon-suzuryo

更新日: 2026-04-23

## Markdown lint

1. `npm install`
2. `npm run lint:md`

commit 時の自動チェックは husky の pre-commit hook で動作する。
```

- [ ] **Step 5: `lint:md` を実行して通ることを確認する**

Run: `npm run lint:md`  
Expected: PASS with `markdownlint-cli2` reporting `Summary: 0 error(s)`.

- [ ] **Step 6: コミットする**

```bash
git add package.json package-lock.json README.md
git commit -m "chore: add markdown lint tooling"
```

### Task 2: husky pre-commit で staged Markdown を自動 lint する

**Files:**

- Create: `.husky/pre-commit`
- Modify: `README.md`

- [ ] **Step 1: hook が未設定であることを確認する**

Run: `test -f .husky/pre-commit && cat .husky/pre-commit`  
Expected: FAIL or empty output because the pre-commit hook does not exist yet.

- [ ] **Step 2: pre-commit hook を書く**

`.husky/pre-commit`

```sh
npx lint-staged
```

- [ ] **Step 3: hook の説明を README に追記する**

`README.md`

```md
# next-pyon-suzuryo

next-pyon-suzuryo

更新日: 2026-04-23

## Markdown lint

1. `npm install`
2. `npm run lint:md`

commit 時の自動チェックは husky の pre-commit hook で動作する。
staged された `.md` ファイルだけが lint-staged 経由で検査される。
```

- [ ] **Step 4: staged Markdown に対する hook の動作を検証する**

Run: `printf '# bad trailing spaces  \n' > /tmp/markdown-hook-check.md && cp /tmp/markdown-hook-check.md ./README.md && git add README.md && .husky/pre-commit`  
Expected: FAIL with markdownlint output showing the README violation.

- [ ] **Step 5: 正常な Markdown に戻して hook の成功を確認する**

Run: `git checkout -- README.md && git add README.md && .husky/pre-commit`  
Expected: PASS with lint-staged completing successfully.

- [ ] **Step 6: コミットする**

```bash
git add .husky/pre-commit README.md
git commit -m "chore: enforce markdown lint on commit"
```

### Task 3: 最終確認で markdownlint と hook 設定を固める

**Files:**

- Modify: `package.json`
- Modify: `.husky/pre-commit`
- Modify: `README.md`

- [ ] **Step 1: 全体の確認コマンドを実行する**

Run: `npm run lint:md && .husky/pre-commit`  
Expected: PASS with `markdownlint-cli2` reporting `Summary: 0 error(s)` and lint-staged exiting successfully.

- [ ] **Step 2: 設定ファイルを見直して不要な変更がないことを確認する**

Run: `git --no-pager diff -- package.json .husky/pre-commit README.md .markdownlint.jsonc`  
Expected: output only for the intended markdown tooling changes.

- [ ] **Step 3: 最終コミットを作る**

```bash
git add package.json package-lock.json .husky/pre-commit README.md
git commit -m "docs: document markdown lint workflow"
```
