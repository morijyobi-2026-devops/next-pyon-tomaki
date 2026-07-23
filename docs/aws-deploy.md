# AWS Production デプロイガイド

本プロジェクトの Next.js アプリケーションを AWS（特に AWS Academy Learner Lab 環境）上で本番運用（Production）するための構築手順とデプロイ自動化の解説です。

---

## 🏗 1. インフラ構成の概要

Terraform を利用して、以下のリソースを AWS 上に自動構築します。

- **VPC / ネットワーク**:
  - `10.0.0.0/16` の VPC
  - パブリックサブネット×2、プライベートサブネット×2
  - インターネットゲートウェイおよびルートテーブルの自動関連付け
- **セキュリティグループ**:
  - `next-pyon-web-sg`
  - インバウンド: SSH（`22`）および HTTP（`80`）を全世界（`0.0.0.0/0`）から許可
  - アウトバウンド: 全て許可
- **EC2 インスタンス**:
  - `t3.micro`（Ubuntu 24.04 LTS）
  - 20GB GP3 ルートボリューム（Docker イメージビルド用の容量を確保）
  - **User Data による自動初期化**:
    - メモリ不足（OOM）防止のため **2GB の Swap 領域** を自動作成・有効化
    - Docker CE, Docker Compose, Git の自動インストール
    - デプロイユーザー（`ubuntu`）を `docker` グループへ追加

---

## 🔑 2. 事前準備

AWS リソースを操作するために、以下の準備を行ってください。

### AWS 認証情報の更新 (AWS Academy を使う場合)

AWS Academy のセッションは一定時間（通常 4 時間）で切れるため、操作前に必ず最新の認証情報をセットする必要があります。

1. AWS Academy のコンソールを開き、「**AWS Details**」から「**AWS CLI**」の接続情報をコピーします。

2. 開発環境の `~/.aws/credentials` を開き、`[morijyobi-2026-devops]` プロファイルを作成または更新します。

   ```ini
   [morijyobi-2026-devops]
   aws_access_key_id = ASIA...
   aws_secret_access_key = ...
   aws_session_token = IQoJb3JpZ2luX2Vj...
   ```

### SSH 鍵の配置

1. AWS Academy で自動付与される SSH 秘密鍵（通常は `labsuser.pem`）をローカルマシンの `~/.ssh/labsuser.pem` に配置します。

2. または、他のパスに置く場合はデプロイ時に引数でパスを指定します（例: `./deploy.sh ~/path/to/key.pem`）。

---

## 🚀 3. ローカルからのデプロイ方法 (自動タスク)

`mise.toml` にインフラ構築とアプリデプロイの自動タスクを定義しています。以下のコマンドを順に実行するだけでデプロイが完了します。

### ステップ 1: Terraform の初期化

```bash
mise run aws:init
```

### ステップ 2: 変更計画の確認

```bash
# どのようなリソースが作成されるか確認します
mise run aws:plan
```

### ステップ 3: インフラの自動構築

```bash
# AWS 上に必要なリソース（VPC、EC2等）が自動作成されます
mise run aws:apply
```

### ステップ 4: アプリケーションのデプロイ

```bash
# EC2 のパブリック IP を Terraform から自動取得し、
# rsync でソースを転送して Docker コンテナをビルド・起動します
mise run aws:deploy
```

秘密鍵のパスがデフォルト（`~/.ssh/labsuser.pem`）以外の場合は、直接シェルスクリプトを実行してください:

```bash
./deploy.sh /path/to/your-key.pem
```

### 🧹 不要になったら（クリーンアップ）

```bash
# AWS のリソースをすべて自動削除します
mise run aws:destroy
```

---

## 🤖 4. GitHub Actions によるデプロイ自動化 (CI/CD)

GitHub リポジトリから自動（または手動トリガー）で AWS へのインフラ構築およびデプロイを行うためのワークフロー [aws-deploy.yml](file:///.github/workflows/aws-deploy.yml) を設定しました。

### 設定手順

GitHub リポジトリの **Settings > Secrets and variables > Actions** にて、以下の Repository Secrets を登録します。

| Secret 名 | 説明 |
| :--- | :--- |
| `AWS_ACCESS_KEY_ID` | AWS Academy から取得したアクセスキーID |
| `AWS_SECRET_ACCESS_KEY` | AWS Academy から取得したシークレットキー |
| `AWS_SESSION_TOKEN` | AWS Academy から取得したセッションキー（一定時間で更新が必要） |
| `AWS_EC2_SSH_KEY` | `labsuser.pem`（秘密鍵）のテキスト内容そのまま |

### 実行方法

1. GitHub リポジトリの **Actions** タブを開きます。

2. 左メニューから **AWS Production Deploy** を選択します。

3. **Run workflow** ボタンをクリックし、Terraform Action（`apply` / `plan` / `destroy` / `none`）を選択して実行します。

   - `apply`: インフラの構築・更新を行ったのち、最新のアプリを EC2 に自動デプロイします。
   - `none`: インフラは更新せず、すでに起動している EC2 に対してアプリのデプロイのみを実行します。
   - `destroy`: インフラをすべて削除します。
