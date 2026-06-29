# pnpm Migration Design

## 1. 目的

このリポジトリの依存関係管理を npm から pnpm に切り替え、
ローカル開発環境と GitHub Actions の両方で
`mise.toml` を起点に同じツール群をそろえられるようにする。

併せて、pnpm の `minimumReleaseAge` を 2 日に設定し、
公開直後のパッケージを即時に取り込まない運用へ移行する。

## 2. 解決したい課題

- 現在は `package-lock.json`、README、GitHub Actions が npm 前提になっている
- `mise.toml` では Node.js だけを管理しており、pnpm の導入経路が揃っていない
- 新規公開直後の依存関係を避けるためのリポジトリ共有設定がない
- npm と pnpm を併記すると、開発手順と CI の両方で運用がぶれやすい

## 3. 検討したアプローチ

### 3.1 npm を残しつつ pnpm を追加する

- README や CI に pnpm を追加するが、`package-lock.json` も残す
- 既存運用との差分は小さい
- ただし lockfile と実行手順が二重化し、どちらを正とするか曖昧になる

### 3.2 pnpm へ全面移行し、ローカルと CI の導入元を mise に統一する（採用）

- `mise.toml` に Node.js と pnpm を定義する
- lockfile を `pnpm-lock.yaml` に一本化し、`package-lock.json` は削除する
- `pnpm-workspace.yaml` に `minimumReleaseAge: 2880` を定義する
- GitHub Actions も `mise` でツールをそろえてから `pnpm install --frozen-lockfile` を実行する

この方法なら、ツール導入元・lockfile・インストール手順を一つにそろえられる。
ユーザー要望の「pnpm は mise で固定バージョン管理する」とも最も整合する。

### 3.3 pnpm へ移行しつつ、CI だけ pnpm 専用 setup action を使う

- ローカルは `mise`、CI は `pnpm/action-setup` などを使う
- CI の記述は短くできる
- ただしツール導入の責務が二系統に分かれ、`mise.toml` が唯一の定義源にならない

## 4. 採用方針

- 3.2 を採用する
- `mise.toml` の `[tools]` に `pnpm = "10.33.0"` を追加し、
  Node.js 24.15.0 と合わせて `mise install` で取得できるようにする
- `package.json` は pnpm 前提の説明に合わせるが、
  `packageManager` フィールドは追加しない
  - 理由: pnpm のバージョンは `mise.toml` で固定バージョン管理とする要件があり、
    `packageManager` フィールドと二重管理になることを避けるため
- `package-lock.json` は削除し、`pnpm install` で `pnpm-lock.yaml` を生成する
- `pnpm-workspace.yaml` を追加し、少なくとも以下を定義する
  - `minimumReleaseAge: 2880`
- `package.json` の script や README は pnpm 表記へ更新する
- GitHub Actions は `jdx/mise-action@v4` で `mise install` 相当のセットアップを行い、
  `pnpm install --frozen-lockfile` と `pnpm run lint` を使う

## 5. 構成

### 5.1 `mise.toml`

- Node.js 24.15.0 は維持する
- pnpm を `10.33.0` で固定追加する
- これにより、開発者は `mise install` だけで Node.js と pnpm の両方をそろえられる

### 5.2 `pnpm-workspace.yaml`

- pnpm の共有設定ファイルとして新規追加する
- 単一パッケージ構成でも、リポジトリ単位の pnpm 設定置き場として使う
- `minimumReleaseAge: 2880` を設定し、2 日未満の公開直後バージョンを避ける

### 5.3 `package.json` / lockfile

- install 後のフックは従来どおり `prepare: "husky"` を維持する
- `lint` は `lint:md` を呼ぶ形を保ちつつ、pnpm 前提の実行例へそろえる
- 依存関係の実体は `pnpm-lock.yaml` を正とし、`package-lock.json` は削除する

### 5.4 README

- セットアップ手順を `npm install` から `pnpm install` に更新する
- lint 実行例を `pnpm run lint` / `pnpm run lint:md` に更新する
- GitHub Actions と commit-time hook の説明も pnpm 基準に合わせる
- `minimumReleaseAge` を 2 日（2880 分）で運用していることを明記する

### 5.5 GitHub Actions

- `actions/setup-node` の npm キャッシュ前提設定は外す
- `jdx/mise-action@v4` で `mise.toml` に従ったツールセットアップを行う
- install は `pnpm install --frozen-lockfile` を使い、
  lockfile との差異を CI で早期検知する

## 6. エラー時の扱い

- `pnpm install --frozen-lockfile` が失敗した場合は、
  `package.json` と `pnpm-lock.yaml` の不整合として扱う
- `minimumReleaseAge` により条件を満たす版が存在しない場合は、
  install を失敗として扱い、即時のフォールバックは入れない
- `mise install` が失敗した場合は、
  `mise.toml` の設定誤りまたは外部ツール取得失敗として明示的に表面化させる

## 7. 完成条件

1. `mise.toml` で Node.js と pnpm を管理できる
2. リポジトリの lockfile が `pnpm-lock.yaml` に統一されている
3. pnpm の `minimumReleaseAge` が 2 日（2880 分）で共有設定化されている
4. README と GitHub Actions が pnpm + mise 前提に更新されている
5. 既存の Markdown lint 運用と husky の流れを維持したまま移行できている
