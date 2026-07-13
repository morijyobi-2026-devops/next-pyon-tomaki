# Terraform 学習用ディレクトリ

このディレクトリは、Terraform (Infrastructure as Code) の基本操作を一から動かして学ぶための作業スペースです。

## Terraform とは？

- **Infrastructure as Code (IaC)**: インフラ（サーバー、ネットワーク、ファイルなど）の構成をコード（`.tf` ファイル）で定義し、自動的にリソースを作成・管理する仕組みです。
- **マルチクラウド対応**: AWS, Google Cloud, Azure だけでなく、Docker, Kubernetes, GitHub, あるいはローカルファイルシステムなど、様々なサービス（Providers）を同じ記法で操作できます。

---

## 基本的な概念

1. **Provider（プロバイダー）**: 操作対象のプラットフォーム（AWS, GCP, Local File など）を定義します。
2. **Resource（リソース）**: 作成する具体的なインフラ要素（EC2インスタンス、S3バケット、ファイルなど）を定義します。
3. **State（ステートファイル）**: Terraform が現在のインフラの状態を記録するファイルです（`terraform.tfstate`）。これにより、コードと実際の環境の差分を検知します。

---

## 動かしてみる（ローカルファイル作成 of 例）

このディレクトリにある `main.tf` は、ローカル環境にテキストファイルを生成するシンプルな構成になっています。
以下の手順に沿って、Terraform の基本ライフサイクルコマンドを実行してみましょう。

> [!NOTE]
> コマンドを実行する際は、事前に `terraform-study` ディレクトリに移動するか、mise を通して実行してください。
> 例: `mise exec -- terraform <command>` もしくは、シェルで `mise` が有効になっている場合は単に `terraform <command>`

### 1. 初期化 (`terraform init`)

Terraform はコードを解析し、必要なプロバイダー（今回は `hashicorp/local`）をインターネットからダウンロードして初期化します。

```bash
# terraform-study ディレクトリ内で実行
mise exec -- terraform init
```

### 2. 計画の確認 (`terraform plan`)

実際にリソースを作成する前に、Terraform がどのような変更を行うかの「計画（ドライラン）」を確認します。

```bash
mise exec -- terraform plan
```

### 3. 適用・リソース作成 (`terraform apply`)

定義ファイルを元に、実際にリソースを作成します。途中で `Enter a value:` と確認を求められたら、`yes` と入力してください。

```bash
mise exec -- terraform apply
```

実行が成功すると、このディレクトリ内に `hello.txt` が自動生成されます。

### 4. 状態の確認 (`terraform.tfstate`)

適用が完了すると、`terraform.tfstate` というファイルが生成され、現在の構成が記録されます。

### 5. リソースの削除 (`terraform destroy`)

作成したリソースをすべて削除し、クリーンアップします。確認を求められたら `yes` と入力します。

```bash
mise exec -- terraform destroy
```

実行後、`hello.txt` が削除されます。
