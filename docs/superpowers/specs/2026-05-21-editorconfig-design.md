# EditorConfig Design

## 1. 目的

このリポジトリで編集時の基本ルールを統一し、
改行・末尾改行・インデントの揺れを減らす。

## 2. 解決したい課題

- エディタごとの既定値に依存しており、編集結果がぶれうる
- LF 改行や末尾改行の扱いが明文化されていない
- soft tab の幅が決まっておらず、今後のファイル追加時に揺れやすい
- Markdown では末尾空白を意図的に使う場合があり、
  一律 trim すると表現を壊す可能性がある

## 3. 採用方針

- リポジトリ直下に `.editorconfig` を追加する
- `root = true` を指定し、この設定をリポジトリの起点にする
- 共通設定で以下を統一する
  - `charset = utf-8`
  - `end_of_line = lf`
  - `insert_final_newline = true`
  - `trim_trailing_whitespace = true`
  - `indent_style = space`
  - `indent_size = 2`
- `*.md` だけ `trim_trailing_whitespace = false` にして、
  Markdown の表現を壊さないようにする
- `package.json`、husky、lint 設定は変更しない

## 4. 構成

### 4.1 .editorconfig

- `[*]` に共通設定を置く
- `[*.md]` に Markdown 向けの例外設定を置く
- 現状のリポジトリにある Markdown、JSON、JSONC、shell script、
  lockfile に対して一貫した編集ルールを与える

### 4.2 既存ツールとの関係

- markdownlint の運用はそのまま維持する
- EditorConfig はエディタ側で効く設定とし、
  npm script や pre-commit hook は増やさない
- Markdown だけ末尾空白の trim を無効化することで、
  既存の Markdown 運用と衝突しにくくする

## 5. エラー時の扱い

- `.editorconfig` 自体は編集補助用のため、
  未対応エディタでは強制されない
- ただし対応エディタでは保存時にルールが反映され、
  改行やインデントの揺れを未然に防げる
- 既存の markdownlint は引き続き Markdown 品質の確認を担当する

## 6. 完成条件

1. リポジトリ直下に `.editorconfig` が追加されている
2. 共通設定で LF、末尾改行、space 2 桁の soft tab が定義されている
3. `*.md` だけ末尾空白 trim の例外が定義されている
4. 既存の Markdown lint 運用を変更せずに導入できている
