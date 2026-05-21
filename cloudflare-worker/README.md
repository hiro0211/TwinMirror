# TwinMirror Gemini Proxy (Cloudflare Worker)

Gemini API キーを iOS アプリのバンドルから取り除き、Worker 側 Secret に保管するためのプロキシ。
iOS アプリは `POST /generate` を `X-Auth-Token` ヘッダー付きで呼び出すだけ。

---

## あなたが手で値を入力するのは Gemini API キー 1 回だけ

`WORKER_AUTH_TOKEN` はリポジトリ内の `SECRETS_TO_SET.md`（gitignored）に既に書き出してあるので、
画面に出てくる prompt にコピペするだけ。

### 手順（コピペで完了）

```bash
cd cloudflare-worker
npm install

# 1) Cloudflare にログイン（ブラウザが開く）
npx wrangler login

# 2) Gemini API キーを登録（← ここで Gemini AI Studio で発行した本物の key をペースト）
npx wrangler secret put GEMINI_API_KEY

# 3) Worker ↔ iOS アプリ間の共有トークンを登録
#    SECRETS_TO_SET.md の値をコピーして prompt にペースト
npx wrangler secret put WORKER_AUTH_TOKEN

# 4) デプロイ
npx wrangler deploy
```

デプロイすると `https://twinmirror-gemini-proxy.<your-subdomain>.workers.dev` のような URL が出力される。
**この URL を Claude に伝えると、iOS 側の `TwinMirror.xcconfig` の `WORKER_URL` を埋める作業まで自動でやる**。

---

## ローカル開発（任意）

```bash
# secrets を .dev.vars に書く（gitignored）
cat > .dev.vars <<EOF
GEMINI_API_KEY=your_real_gemini_key
WORKER_AUTH_TOKEN=<SECRETS_TO_SET.md の値>
EOF

npm run dev   # http://localhost:8787
```

## テスト

```bash
npm test
```

`@cloudflare/vitest-pool-workers` で Workers ランタイムと同じ isolate 内で実行。

## 設計メモ

- `POST /generate` 以外は 404
- `X-Auth-Token` が一致しなければ 401
- `model` フィールドが allowlist (`gemini-3.1-flash-image-preview`, `gemini-2.5-flash-image`) になければ 400
- ボディから `model` を抜いた残り（`contents`, `generationConfig`, `safetySettings`）をそのまま Gemini に転送
- Gemini のレスポンスはステータスコードもボディもパススルー → iOS 側パーサに変更不要
- ペイロード 8MB 超は 413
- ログは Cloudflare ダッシュボード（observability=on）で確認

## 後追い（v2）

- Apple App Attest 検証（共有シークレットの代わりに端末証明）
- Cloudflare KV で per-device daily limit（クライアント `UsageLimiter` のサーバ側バックアップ）
- Rate limiting binding でグローバル QPS 制限
