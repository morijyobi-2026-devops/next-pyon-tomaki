import { defineCloudflareConfig } from "@opennextjs/cloudflare";

// incremental cache の override は付けない（R2 未使用）。
// ISR/動的ルートを追加して永続キャッシュが必要になったら R2 を有効化し、
// incrementalCache を設定し直す。
export default defineCloudflareConfig();
