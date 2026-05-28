# サプライチェーン攻撃対策の設計書

**日付**: 2026-05-28  
**対象プロジェクト**: next-pyon-tomaki

## 概要

npm の既知の脆弱性（自動更新による悪意あるパッケージの混入、タイポスクアッティング）から保護するため、以下の4つの対策を実装する：

1. GitHub Actions を SHA hash で固定（完全なアクションバージョン制御）
2. npm → pnpm への移行（より安全なパッケージ管理）
3. Renovate の導入（スケジュール化された、段階的なアップデート）
4. Minimum Release Age の設定（新規パッケージの慎重な導入）

---

## フェーズ1: GitHub Actions を SHA hash で固定

### Phase 1: 目指すもの

`lint.yml` の GitHub Actions reference を完全に固定し、未認可のアクション更新を防ぐ。

### Phase 1 実装内容

- `actions/checkout@v4` → `actions/checkout@<full-sha>`
- `actions/setup-node@v4` → `actions/setup-node@<full-sha>`

**対象ワークフロー**: `.github/workflows/lint.yml`

### Phase 1 メリット

- アクションの悪意あるバージョンが実行されるリスクを排除
- 即座に実装可能（pnpm 移行に依存しない）

---

## フェーズ2: npm → pnpm への移行

### Phase 2: 目指すもの

より安全で効率的なパッケージマネージャー（pnpm 9.x）に移行。

### Phase 2 実装内容

1. **pnpm インストール**
   - Node.js 環境に pnpm 9.x をインストール
   - 既存の node_modules と package-lock.json を削除

2. **pnpm init**
   - `pnpm install` で pnpm-lock.yaml を生成

3. **.npmrc の作成**

   ```env
   engine-strict=true
   save-exact=true
   ```

   - `engine-strict`: engines フィールドを厳密に検証
   - `save-exact`: 新規依存を完全なバージョンで保存

4. **GitHub Actions ワークフローの更新**
   - `npm ci` → `pnpm ci`
   - `actions/setup-node` の cache を `pnpm`

5. **package.json の更新**
   - `"packageManager": "pnpm@9.x.x"` を追加
   - `"engines": { "node": "20.x", "pnpm": "9.x" }` を追加

### Phase 2 メリット

- pnpm はファイルシステムレイアウトにより typosquatting 対策が強い
- バージョン完全固定により再現性が向上

---

## フェーズ3: Renovate の導入

### Phase 3: 目指すもの

スケジュール化された、段階的なパッケージアップデート。

### Phase 3 実装内容

1. **renovate.json の作成**

   ```json
   {
     "extends": ["config:base"],
     "schedule": ["before 5am on Monday", "before 5am on Thursday"],
     "timezone": "Asia/Tokyo",
     "npm": {
       "minimumReleaseAge": "3 days"
     },
     "packageRules": [
       {
         "description": "Auto-merge minor and patch updates",
         "matchUpdateTypes": ["minor", "patch"],
         "automerge": true,
         "automergeType": "pr"
       }
     ]
   }
   ```

2. **GitHub Actions アップデート**
   - `renovate.json` に actions 向けの rules を追加
   - `postUpdateOptions: ["gomodTidy"]` など（必要に応じて）

### Phase 3 スケジュール

- **実行時刻**: 月曜日・木曜日の日本時間 05:00 前
- **最小リリース年齢**: 3日（新規パッケージリリース後 3日以上待機）

### Phase 3 メリット

- 人為的なアップデート管理の負担を削減
- 定期的で予測可能なアップデートサイクル

---

## フェーズ4: pnpm の Minimum Release Age 設定

### Phase 4: 目指すもの

pnpm インストール時に、リリースから 2日以内のパッケージをインストールしない。

### Phase 4 実装内容

**.npmrc に以下を追加:**

```env
install-missing-peer-deps=false
prefer-offline=true
```

注: pnpm の native minimum-release-age 設定は `registry` ごとの設定のため、
npm registry との統合では Renovate の `minimumReleaseAge: "3 days"` で対応。

---

## ファイル変更一覧

| ファイル | 操作 | 説明 |
|---------|------|------|
| `.github/workflows/lint.yml` | 編集 | actions を SHA hash で固定 |
| `package.json` | 編集 | pnpm version を追加、engine を指定 |
| `renovate.json` | 作成 | Renovate 設定 |
| `.npmrc` | 作成 | pnpm 設定ファイル |
| `.nvmrc` | 作成 | Node.js バージョン固定（オプション） |
| `pnpm-lock.yaml` | 生成 | pnpm ロックファイル（自動生成） |
| `package-lock.json` | 削除 | npm ロックファイル（移行後は不要） |
| `node_modules/` | 削除 | npm 依存（pnpm に置換） |

---

## テスト・検証方法

1. **GitHub Actions が正常に動作**
   - lint.yml が SHA hash reference で実行される
   - Node.js 20 が起動される

2. **pnpm が正常に動作**
   - `pnpm install` でパッケージがインストール可能
   - `pnpm ci` がロックファイルを正確に再現

3. **Renovate が正常に動作**
   - 月曜日・木曜日 05:00 に Renovate PR が作成される
   - アップデート対象が npm パッケージと GitHub actions に限定されている

4. **Minimum Release Age が適用**
   - リリース 3日未満のパッケージは Renovate PR 対象にならない

---

## リスク・注意点

1. **pnpm への移行は breaking change**
   - CI/CD が npm から pnpm に切り替わる
   - 既存の npm スクリプトは互換性がある

2. **Renovate は GitHub Apps 認証が必要**
   - リポジトリに Renovate を有効化する設定が必要

3. **GitHub Actions SHA hash の取得**
   - 各アクションの最新リリースページで SHA を確認する必要がある

---

## 実装順序

1. **フェーズ1**: GitHub Actions を SHA hash で固定（即座）
2. **フェーズ2**: npm → pnpm への移行
3. **フェーズ3**: Renovate の導入
4. **フェーズ4**: pnpm 設定ファイルの確認・調整

各フェーズは前のフェーズに依存せず、並列実装も可能。
