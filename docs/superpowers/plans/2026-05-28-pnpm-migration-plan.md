# pnpm Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** npm ベースの依存関係管理を pnpm へ移行し、pnpm を `mise.toml` で `10.33.0` に固定管理しつつ `minimumReleaseAge` を 2 日（2880 分）で共有設定化する。

**Architecture:** `mise.toml` をローカルと CI の共通なツール定義源にし、依存関係の正本は `pnpm-lock.yaml` に一本化する。pnpm 固有の共有設定は `pnpm-workspace.yaml` に置き、README と GitHub Actions を pnpm ベースの手順へそろえる。

**Tech Stack:** Node.js 24.15.0, pnpm, mise, GitHub Actions, husky, lint-staged, markdownlint-cli2

---

## Task 1: Toolchain and lockfile migration

**Files:**

- Create: `pnpm-workspace.yaml`
- Create: `pnpm-lock.yaml`
- Modify: `mise.toml`
- Modify: `package.json`
- Delete: `package-lock.json`

- [ ] **Step 1: Run the migration check before changing files**

```bash
cd /repo
rg -n 'pnpm|minimumReleaseAge' mise.toml package.json pnpm-workspace.yaml
```

Expected: FAIL for `pnpm-workspace.yaml` (missing file) and no matches for pnpm settings in `mise.toml` / `package.json`.

- [ ] **Step 2: Update `mise.toml` to install pnpm via mise**

```toml
[tools]
node = "24.15.0"
pnpm = "10.33.0"
```

- [ ] **Step 3: Add pnpm project settings**

```yaml
minimumReleaseAge: 2880
```

Write the snippet above to `pnpm-workspace.yaml`.

- [ ] **Step 4: Update `package.json` for pnpm-oriented scripts**

```json
{
  "name": "next-pyon-suzuryo-tooling",
  "private": true,
  "engines": {
    "node": "24.15.0"
  },
  "scripts": {
    "prepare": "husky",
    "lint": "pnpm run lint:md",
    "lint:md": "markdownlint-cli2 \"README.md\" \"docs/**/*.md\""
  },
  "devDependencies": {
    "husky": "9.1.7",
    "lint-staged": "15.2.10",
    "markdownlint-cli2": "0.22.0"
  },
  "lint-staged": {
    "*.md": "markdownlint-cli2"
  }
}
```

- [ ] **Step 5: Replace the lockfile**

```bash
cd /repo
rm package-lock.json
mise install
pnpm install
```

Expected: PASS with `pnpm-lock.yaml` created and no `package-lock.json` left in the repository.

- [ ] **Step 6: Verify the new toolchain works**

Run: `pnpm run lint`  
Expected: PASS with markdownlint finishing successfully.

- [ ] **Step 7: Commit**

```bash
git add mise.toml package.json pnpm-workspace.yaml pnpm-lock.yaml package-lock.json
git commit -m "chore: migrate tooling to pnpm"
```

## Task 2: README migration

**Files:**

- Modify: `README.md`

- [ ] **Step 1: Find npm-specific instructions that must be removed**

```bash
cd /repo
rg -n 'npm install|npm run lint|npm ci' README.md
```

Expected: PASS with matches showing the old npm-oriented instructions.

- [ ] **Step 2: Rewrite setup instructions for pnpm + mise**

```md
1. `mise install`
   - `mise.toml` に従って Node.js 24.15.0 と pnpm を用意します。
2. `pnpm install`
   - `prepare` script で husky が実行され、`pre-commit` hook が設定されます。
3. `pnpm run lint`
   - 現在は `pnpm run lint:md` を呼び出し、`README.md` と `docs/**/*.md` をまとめて確認できます。
```

- [ ] **Step 3: Rewrite the hook and CI notes**

```md
- hook を直接確認する場合も、先に `pnpm install` を実行してローカル依存関係をそろえてください。
- GitHub Actions でも `mise.toml` に従って Node.js と pnpm を用意し、`pnpm install --frozen-lockfile` の後に `pnpm run lint` を実行します。
- pnpm では `minimumReleaseAge` を 2 日 (`2880` 分) に設定し、公開直後の依存関係を即時に取り込みません。
```

- [ ] **Step 4: Verify no npm-oriented setup text remains in README**

Run: `rg -n 'npm install|npm run lint|npm ci' README.md`  
Expected: PASS with no matches.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: update setup instructions for pnpm"
```

## Task 3: GitHub Actions migration

**Files:**

- Modify: `.github/workflows/lint.yml`

- [ ] **Step 1: Confirm the workflow is still npm-based**

```bash
cd /repo
rg -n 'actions/setup-node|cache: npm|npm ci|npm run lint' .github/workflows/lint.yml
```

Expected: PASS with matches for the current npm-based workflow.

- [ ] **Step 2: Replace the setup step with mise-based tooling**

```yaml
name: Lint

on:
  pull_request:
  push:
    branches:
      - main

permissions:
  contents: read

jobs:
  markdown:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup mise tools
        uses: jdx/mise-action@v4

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Run lint
        run: pnpm run lint
```

- [ ] **Step 3: Verify repository commands still pass after the workflow change**

Run: `pnpm run lint`  
Expected: PASS with markdownlint finishing successfully.

- [ ] **Step 4: Sanity check that npm-only workflow snippets are gone**

Run: `rg -n 'cache: npm|npm ci' .github/workflows/lint.yml`  
Expected: PASS with no matches.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/lint.yml
git commit -m "ci: run lint with mise-managed pnpm"
```

## Task 4: Final verification and cleanup

**Files:**

- Modify: `mise.toml`
- Modify: `package.json`
- Modify: `README.md`
- Modify: `.github/workflows/lint.yml`
- Create: `pnpm-workspace.yaml`
- Create: `pnpm-lock.yaml`
- Delete: `package-lock.json`

- [ ] **Step 1: Reinstall dependencies from scratch with pnpm**

```bash
cd /repo
rm -rf node_modules
mise install
pnpm install --frozen-lockfile
```

Expected: PASS with dependencies installed from `pnpm-lock.yaml`.

- [ ] **Step 2: Run the repository verification command**

Run: `pnpm run lint`  
Expected: PASS with 0 markdownlint errors.

- [ ] **Step 3: Inspect the final diff**

Run: `git --no-pager diff --stat`  
Expected: PASS with changes limited to the pnpm migration files and docs.

- [ ] **Step 4: Create the final commit**

```bash
git add mise.toml package.json README.md .github/workflows/lint.yml pnpm-workspace.yaml pnpm-lock.yaml package-lock.json
git commit -m "chore: switch repository tooling to pnpm"
```
