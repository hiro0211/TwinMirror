# Twin Mirror プロジェクトメモリ

## 2026-05-20（午後・TestFlight準備セッション）

### 作業内容（Phase 1 ローカルコード完了・全64テスト緑）

#### コスト保護
- `UsageLimiter.swift` 新設（UserDefaults で 1日3回制限、TDD で 6 tests）
  - `@unchecked Sendable` で Swift 6 strict concurrency 対応
  - `dailyLimit = 3`, `tryConsume() -> Bool`, `remainingToday`, `canGenerate`
  - Asia/Tokyo タイムゾーン基準で日付ロールオーバー
- `GenerationOrchestrator.candidateCount = 1` に固定（コスト1/3に削減）

#### プレミアムモード削除
- `GenerationQuality` enum 完全削除（`GenerationRequest.swift` から fast/premium 分岐撤廃）
- `OpenAIImageGenerator.swift` + `OpenAIImageGeneratorTests.swift` ファイル削除
- `OPENAI_API_KEY` を `Info.plist` / `project.yml` / `AppConfig` から削除
- `ComposeView.qualitySection` / `QualityModeCard` private struct 削除
- `GenerationOrchestrator.defaultAttempts(geminiKey:)` シングル引数化、Geminiチェーン直返し
- 関連テストを `GenerationOrchestratorTests` で書き直し（quality系を削除、Gemini-only検証に統一）

#### Apple Guideline 5.1.2(i) AI同意フロー
- `ComposeView` に `AIConsentSheet` 新設（初回生成前に明示同意取得）
- `@AppStorage("twinmirror.consent.ai")` で永続化
- `AIConsentSheet` は medium/large detent、Geminiへの送信を箇条書きで開示
- `disclaimerSection` に「画像はGoogle Geminiに送信されます」を追加
- 生成ボタン押下時の制御: 「利用制限チェック → 同意チェック → tryConsume → navigate」

#### UI: 残り回数バッジ
- `usageBadge` を `disclaimerSection` と `generateButton` の間に追加
- `gauge.medium` アイコン + 「本日の残り生成回数: X / 3」

#### iOS17+ Privacy Manifest
- `TwinMirror/Resources/PrivacyInfo.xcprivacy` 新設
  - `NSPrivacyTracking: false`
  - 収集データ: PhotosOrVideos（App Functionality 用、Linked/Tracking false）
  - Required Reason API: `NSPrivacyAccessedAPICategoryUserDefaults` 理由コード `CA92.1`（自アプリ内アクセス）

#### 法務ドキュメント更新
- `docs/privacy.html`: OpenAI記述削除、Apple Guideline 5.1.2(i) 明記、利用回数制限を新セクションで追加、日付 2026-05-20
- `docs/terms.html`: 第4条 OpenAI記述削除、第5条「利用回数の制限」新設、日付 2026-05-20
- `AppConfig.swift`: privacyURL / termsURL を `https://hiro0211.github.io/TwinMirror/<page>.html` に差し替え

### リサーチで判明した重要事項
- **Apple Review Guideline 5.1.2(i)（2025-11-13 施行）**: 第三者AIへの個人データ送信に明示同意必須。広範な同意フォームは無効、具体的開示が必要
- **Nano Banana 料金（2026-05時点）**: Gemini 2.5 Flash Image = $0.039/枚、Gemini 3 Pro Image = $0.039 (1K) / $0.134 (2K) / $0.24 (4K)
- **iOS 日本リワード eCPM**: $15-30（1枚原価$0.039なら 1.3-2.5 view で黒字化可能）
- **1枚生成化はリワード収益化の前提**: 3枚生成だと 4-8 view 必要で UX崩壊

### 検証結果
- `xcodegen generate`: 成功
- `xcodebuild test`: **全64テスト緑**（UsageLimiterTests 6件追加、quality系テスト削除を相殺）

### 残作業（次セッションまたは同セッション継続）
- **ユーザー作業**:
  - GitHub Pages 有効化（`Settings → Pages → Source: main / docs`）
  - 変更を `git commit && git push` してGitHub Pagesへ反映
  - https://hiro0211.github.io/TwinMirror/privacy.html がアクセス可能になることを確認
  - Apple Developer Program ($99/年) 加入確認 → developer.apple.com にログイン
  - App Store Connect にログイン
- **Claude in Chrome で対応**:
  - Bundle ID `app.twinmirror.ios` を developer.apple.com で登録
  - App Store Connect で新規アプリ作成（Name: ツインミラー / SKU: twinmirror-001）
  - TestFlight ベータ情報入力（ベータ説明、フィードバック email）
- **ユーザー手作業**:
  - Xcode で Team を個人アカウントに設定
  - Product → Archive → Distribute App → App Store Connect Upload
  - TestFlight 内部テスト確認 → 外部テスト用 Beta App Review 提出
- **App Review リスク**:
  - AI生成 + 子ども画像 = ガイドライン4.1/5.0 系で要注意
  - 「娯楽目的・遺伝予測ではない」ディスクレーマーを維持
  - 18歳以上写真限定の注意書きを維持

### 主要変更ファイル一覧
- 新規: `TwinMirror/Services/UsageLimiter.swift`
- 新規: `TwinMirror/Resources/PrivacyInfo.xcprivacy`
- 新規: `TwinMirrorTests/UsageLimiterTests.swift`
- 削除: `TwinMirror/Services/OpenAIImageGenerator.swift`
- 削除: `TwinMirrorTests/OpenAIImageGeneratorTests.swift`
- 変更: `TwinMirror/Models/GenerationRequest.swift`（GenerationQuality 削除）
- 変更: `TwinMirror/Services/GenerationOrchestrator.swift`（quality 分岐撤廃、candidateCount=1 固定）
- 変更: `TwinMirror/Services/AppConfig.swift`（openAIAPIKey 削除、URL を github.io に）
- 変更: `TwinMirror/Features/Compose/ComposeView.swift`（AIConsentSheet, usageBadge, qualitySection 削除）
- 変更: `TwinMirror/Features/Compose/ComposeViewModel.swift`（quality 削除）
- 変更: `TwinMirror/Features/Result/ResultViewModel.swift`（quality / openAIKey 参照削除）
- 変更: `TwinMirror/Info.plist`（OPENAI_API_KEY 削除）
- 変更: `project.yml`（OPENAI_API_KEY 削除）
- 変更: `TwinMirrorTests/GenerationOrchestratorTests.swift`（書き直し）
- 変更: `TwinMirrorTests/ResultViewModelTests.swift`（quality 引数削除）
- 変更: `docs/privacy.html` / `docs/terms.html`

### 発見した問題点・注意事項
- `static let shared` を `final class` に持たせるには Swift 6 では Sendable 必須。UserDefaults 操作のみで実質スレッドセーフなら `@unchecked Sendable` が最も実用的
- `xcconfig` の `OPENAI_API_KEY` 行は本物のキー値を含むため、ユーザー側で手動削除推奨（コードからは未参照になっているが、コミット時の誤り防止のため）
- `gemini-3.1-flash-image-preview` は **candidateCount > 1 を許可しない**（前セッション記録）。1枚固定化はこの仕様にも整合

## 2026-05-20（夜・GitHub Pages公開・アイコン透かし除去）

### 追加対応
- **Apple Developer Program**: 個人アカウントで加入済み（過去にデプロイ実績あり）— 新規加入手続き不要
- **GitHub リポ**: `hiro0211/TwinMirror` を **public に変更**（Pagesは Free private では使えない、`.gitignore` で API キーは未追跡を確認済み）
- **GitHub Pages 有効化**: `main` ブランチの `/docs` を公開 — ステータス `built`
  - https://hiro0211.github.io/TwinMirror/privacy.html (HTTP 200)
  - https://hiro0211.github.io/TwinMirror/terms.html (HTTP 200)
  - https://hiro0211.github.io/TwinMirror/AppIcon.png (HTTP 200)
- **AppIcon Gemini透かし除去**: 右下の白いスパークルを Python/PIL でインペイント
  - 元画像バックアップ: `assets/icons/AppIcon_before_watermark_removal.png`
  - 検出: 行ごとのピンク基準色との差分で186 pixel特定、bb (920-978, 940-991)
  - 修復: 同じx列の -60px 上から色サンプリング（縦グラデーション尊重）+ 境界ガウスblur
- **privacy.html / terms.html を Liquid Glass デザインに刷新**:
  - backdrop-filter blur(24px) saturate(180%) で frosted glass カード
  - ピンク→マゼンタのグラデーション見出し（背景クリップ）
  - 番号バッジ、pillナビ、AppIconヒーロー
  - ダークモード対応 + モバイルレスポンシブ
  - Theme.swift の `Theme.Colors.*` と `Theme.Gradients.background` を CSS 変数で再現

### コミット履歴（このセッション内）
- `fb3f877` Remove OpenAI integration and implement usage limits（コード変更：別プロセスでコミット済み）
- `e4c4173` Remove Gemini watermark from AppIcon for App Store Review compliance
- `da45387` Redesign privacy/terms pages with Liquid Glass aesthetic matching the app

### 次のステップ（残タスク）
- **Bundle ID 登録**（developer.apple.com）— Claude in Chrome
- **App Store Connect 新規アプリ作成** — Claude in Chrome
- **Xcode Archive + Upload**（ユーザー手作業）
- **TestFlight 内部テスト → 外部テスト（Beta App Review 提出）**

## 2026-05-20（夜・Apple Developer / App Store Connect 登録完了）

### 登録された識別子
- **Apple Developer Team ID**: `KV6CYPA7JK`（Hiroaki Arimura 個人アカウント）
- **Bundle ID (App ID)**: `app.twinmirror.ios`（Explicit、Capabilities なし）
- **App Store Connect App ID**: `6771413156`
- **App名 (ASC)**: `Twin Mirror`（英語）
- **プライマリ言語**: 日本語 (ja)
- **SKU**: `twinmirror-001`
- **ユーザアクセス**: アクセス制限なし

### ASC ダッシュボード URL
- アプリ管理: https://appstoreconnect.apple.com/apps/6771413156

### Claude in Chrome 自動化メモ
- ASC の **`<select>` ドロップダウン**は React 制御で、`form_input` の値設定だけでは反映されない
- ネイティブセッターで値を設定し `change` / `input` イベントを bubbles で dispatch する必要がある（JavaScript経由）
- 例: `Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, 'value').set.call(el, 'ja')` → `dispatchEvent(new Event('change', {bubbles:true}))`

## 2026-05-21（Cloudflare Workers プロキシ化・GEMINI_API_KEY をバンドルから除去）

### 背景
TestFlight/App Store 配布で iOS バンドル内に Gemini API キーを埋め込むのは危険（`.ipa` を unzip すれば誰でも抽出できる）。Cloudflare Workers をプロキシとして立て、キーは Worker 側 Secret に保管する構成へ移行した。

### 設計判断
- デプロイ: **Wrangler CLI**
- 認証: v1 = **共有シークレット (`X-Auth-Token` ヘッダー)**、v2 で App Attest 追加予定
- モデル切替: クライアントが JSON 最上位の `model` フィールドで指定 → Worker が allowlist 検証して Gemini エンドポイントへ転送
- レート制限: v1 はクライアント側 `UsageLimiter` のみ（v2 で KV ベース per-device 制限予定）
- 計画: `/Users/arimurahiroaki/.claude/plans/tender-stargazing-abelson.md`

### 構成（実装後）
```
iOS ──POST {model, contents, ...} + X-Auth-Token──> CF Worker ──+ x-goog-api-key──> Gemini
```
Gemini レスポンスはステータスもボディもパススルー → iOS 側パーサ無変更。

### 新規ファイル（Worker）
- `cloudflare-worker/package.json` `wrangler.jsonc` `tsconfig.json` `vitest.config.ts` `.gitignore`
- `cloudflare-worker/src/index.ts`（POST /generate のみ受付、X-Auth-Token 検証、model allowlist、Gemini 転送）
- `cloudflare-worker/test/index.test.ts`（vitest 9件全パス、plain Node 環境で実行）
- `cloudflare-worker/README.md`（日本語デプロイ手順）
- `cloudflare-worker/SECRETS_TO_SET.md`（**gitignored**、生成済み WORKER_AUTH_TOKEN を保管）

### iOS 側変更
- `TwinMirror.xcconfig.example` / `TwinMirror.xcconfig`: `GEMINI_API_KEY` → `WORKER_URL` + `WORKER_AUTH_TOKEN` に置換
- `TwinMirror/Info.plist` + `project.yml`: 同上（xcconfig で値注入）
- `TwinMirror/Services/AppConfig.swift`: `geminiAPIKey` 削除、`workerURL: URL?` / `workerAuthToken: String` 追加
- `TwinMirror/Services/GeminiImageGenerator.swift`:
  - init: `init(workerURL:authToken:model:)` に変更
  - URL: `workerURL.appendingPathComponent("generate")`
  - ヘッダー: `x-goog-api-key` → `X-Auth-Token`
  - ボディ最上位に `"model": rawValue` 追加（Worker 側で抜き取って Gemini に転送）
  - `parseResponse` は無変更（Gemini レスポンスがパススルーされるため）
- `TwinMirror/Services/GenerationOrchestrator.swift`: `init(workerURL:authToken:)` / `defaultAttempts(workerURL:authToken:)` に変更
- `TwinMirror/Features/Result/ResultViewModel.swift`: workerURL が nil ならフェールセーフで空 attempts
- `TwinMirrorTests/GeminiImageGeneratorTests.swift` + `GenerationOrchestratorTests.swift`: 新シグネチャに追従
- `.gitignore`: `cloudflare-worker/node_modules/`, `.wrangler/`, `.dev.vars`, `SECRETS_TO_SET.md` 追加

### 検証結果
- Worker: `npm test` → **9/9 passed**（404/401/400/500/forward/passthrough を網羅）
- iOS: `xcodebuild test` → **全テスト緑**（TEST SUCCEEDED）

### xcconfig の URL 表記の罠
xcconfig は `//` をコメント開始扱いするため、`https://...` を直書きできない。`https:/$()/...` のように `$()` で `//` を分断する必要あり。コメントで明記済み。

### 残作業（ユーザー手動）
1. `cd cloudflare-worker && npm install && npx wrangler login`
2. `npx wrangler secret put GEMINI_API_KEY` ← **Gemini AI Studio で発行した本物のキーをペースト**（唯一の手動入力）
3. `npx wrangler secret put WORKER_AUTH_TOKEN` ← `cloudflare-worker/SECRETS_TO_SET.md` の値をコピペ
4. `npx wrangler deploy` → 出力された Worker URL を Claude に伝える
5. Claude が `TwinMirror.xcconfig` の `WORKER_URL` を更新 → ユーザーが `xcodegen generate` → ビルド

### v2 で後追い
- Apple App Attest 統合（端末証明で共有シークレット置換）
- Cloudflare KV で per-device daily limit（クライアント `UsageLimiter` のサーバー側バックアップ）
- Gemini レスポンスのストリーミング転送（タイムアウト対策）

### 注意事項
- `@cloudflare/vitest-pool-workers` は採用せず、plain vitest + Node 環境で十分（fetch / Request / Response は Node 18+ 標準）。Workers 固有バインディング（KV, DO）を使い始めたら pool に乗り換える
- LSP（SourceKit）が `UIKit` / `XCTest` を解決できない警告は依然出るが、xcodebuild では問題なし
- 旧 `geminiAPIKey` プロパティは完全削除済み、`OPENAI_API_KEY` xcconfig 行も同様に既に未参照（過去メモ参照）

## 2026-05-21

### 作業内容
- プレミアムモード（3枚生成: 50:50 / 父70:30 / 母70:30）を追加実装
- 高速モード = 1枚（balanced のみ）、プレミアム = 3枚（balanced + fatherLeaning + motherLeaning）
- フリーミアム設計: 非課金は premium 1回/日、fast 3回/日（独立カウンター）
- Gemini はブレンド比の数値パラメータを公開していないため、プロンプト本文（自然言語）で表現。`PRIMARY facial template: Image A (FATHER)` 等のロール指定で 70:30 を誘導
- 部分成功を許容: 3枚中1〜2枚成功時はその分だけ返す（全失敗時のみ throw）

### 主要な設計判断
- `ImageGenerator.generate(request:prompt:count:)` を `generate(request:prompt:)` に簡素化。並列化は Orchestrator が担う（責務分離）
- `GenerationOrchestrator.generate` は `request.mode.blendRatios` ごとに独立したフォールバックチェーンを並列実行。プロンプトはタスク開始前に同期構築（PromptBuilder を非Sendable境界越しに送らない）
- `GenerationResult.ratios: [BlendRatio]` を追加して images と並びを揃える（ResultView でバッジに使う）
- `UsageLimiter` は fast / premium で完全別キー（`twinmirror.usage.premium.*`）。`isPremiumSubscriber: @Sendable () -> Bool` フックで IAP 加入時に上限を 1000 に切替できる

### 検証結果
- `xcodebuild build`: BUILD SUCCEEDED (iPhone 17 simulator)
- `xcodebuild test`: TEST SUCCEEDED, 87 tests passed, 0 failures
- 新規/拡張テスト: BlendRatioTests (9), PromptBuilderTests (+5), GenerationOrchestratorTests (+4), UsageLimiterTests (+6)

### 次回やるべきこと
- **Phase B（IAP）**: `SubscriptionManager` (StoreKit2) と `PaywallView` を新規実装し、`UsageLimiter` の `isPremiumSubscriber` に結線
  - App Store Connect で月額/年額サブスク SKU 作成（`com.twinmirror.premium.monthly` など）
  - `.storekit` Configuration ファイルを Xcode に追加してローカルテスト
- **実機検証**: 同じ両親写真で premium 3 枚生成して、父寄り/母寄りが視覚的に判別できるか確認。プロンプト文言を強化（`STRONGLY emphasize FATHER`, `MOTHER must be only barely recognizable` 等）する余地あり
- **Cloudflare Worker レート確認**: premium モードで3並列リクエストになるため、Worker 側の rate limit / timeout 設定を再点検

### 発見した問題点・注意事項
- **`UsageLimiter` テストで `@Sendable` 警告**: `now: { self.date(...) }` のキャプチャは `XCTestCase` が non-Sendable なので失敗する。`let fixedNow = date(...)` でローカル定数化して回避する必要あり
- **SourceKit が依然 `UIKit` / `XCTest` を解決できないことが多い**: xcodebuild ビルドには影響なし。`xcodegen` 実行直後に Xcode を再起動すれば収まる
- **GenerationResult の `ratios` パラメータはデフォルト `[]`**: 既存テスト互換のため。新規呼び出し（Orchestrator）は必ず明示的に渡す
- Gemini は per-feature の数値ブレンドを実機検証していないため、`70:30` が実際にどれくらい区別できるかは現時点で未知

### 変更したファイル（主要）

#### 新規
- `TwinMirror/Models/BlendRatio.swift` — BlendRatio / GenerationMode enum
- `TwinMirror/Services/BlendPrompts.swift` — `{{BLEND_BLOCK}}` 用テンプレートローダー
- `TwinMirror/Resources/Prompts/blend_block_balanced.txt`
- `TwinMirror/Resources/Prompts/blend_block_father_leaning.txt`
- `TwinMirror/Resources/Prompts/blend_block_mother_leaning.txt`
- `TwinMirrorTests/BlendRatioTests.swift`

#### 修正
- `TwinMirror/Models/GenerationRequest.swift` — `mode` / `ratios` 追加
- `TwinMirror/Resources/Prompts/child_realistic_v2.txt` — FEATURE INHERITANCE を `{{BLEND_BLOCK}}` 化
- `TwinMirror/Resources/Prompts/child_illustration_v2.txt` — 同上
- `TwinMirror/Services/PromptBuilder.swift` — `blendRatio` 引数
- `TwinMirror/Services/ImageGenerator.swift` — single-image return に簡素化
- `TwinMirror/Services/GeminiImageGenerator.swift` — count 引数削除
- `TwinMirror/Services/GenerationOrchestrator.swift` — 全面書き換え（per-ratio パイプラインの並列実行 + 部分成功）
- `TwinMirror/Services/UsageLimiter.swift` — premium カウンター + IAP フック
- `TwinMirror/Features/Compose/ComposeViewModel.swift` — `mode` プロパティ
- `TwinMirror/Features/Compose/ComposeView.swift` — `ModeCard` セクション + モード別残数バッジ + premium ペイウォール対応の handleGenerateTapped
- `TwinMirror/Features/Result/ResultView.swift` — `BlendRatioBadge` / `ParentBar` overlay
- `TwinMirrorTests/GenerationOrchestratorTests.swift` — 全面書き換え（fast / premium / partial / all-fail）
- `TwinMirrorTests/GeminiImageGeneratorTests.swift` — シグネチャ変更追随
- `TwinMirrorTests/PromptBuilderTests.swift` — blend ratio テスト追加
- `TwinMirrorTests/UsageLimiterTests.swift` — premium カウンターテスト追加

### 計画ファイル
- `/Users/arimurahiroaki/.claude/plans/1-3-1-3-1-70-30-2-uiwo-users-arimurahir-woolly-cocoa.md`

## 2026-05-21

### 作業内容
- ComposeView (子ども生成画面) と AIConsentSheet (AI処理確認シート) のコントラスト改善
- 計画: `/Users/arimurahiroaki/.claude/plans/users-arimurahiroaki-downloads-img-4892-mutable-feather.md`
- 基準: 性別選択チップ (`GlassChip`) のクリアな白ガラス / ピンクガラスのコントラスト

### 変更内容
- `ComposeView.swift` の body から `instructionsSection`（"使い方" カード）を削除
- `instructionsSection` の定義ブロック（lines 150-161 相当）を全削除
- `disclaimerSection` の `glassEffect` を `Theme.Colors.cream.opacity(0.85)` → `.white.opacity(0.4)` に変更し、性別チップ非選択状態と同じトーンに統一
- `AIConsentSheet` 本体を `ZStack { Theme.Gradients.background.ignoresSafeArea(); ... }` で包み、`.presentationBackground(Theme.Colors.cream)` を追加してデフォルト sheet material の透けを排除
- "キャンセル" ボタンの色を `Theme.Colors.textSecondary` → `Theme.Colors.textPrimary.opacity(0.7)` に強化（font も weight: .medium 追加）

### 検証結果
- `xcodebuild build` (iPhone 17 Pro / iOS 26.x simulator): **BUILD SUCCEEDED**
- シミュレーター実機での目視確認は未実施（ユーザー側で確認予定）

### 変更したファイル
- `TwinMirror/Features/Compose/ComposeView.swift` (1ファイルのみ)

### 次回やるべきこと
- シミュレーター/実機で AIConsentSheet を開き、ピンクボタンと本文テキストのコントラストが性別チップと同等になっているか目視確認
- "ご利用について" カードがオレンジ警告 + 白ガラス背景で読みやすくなっているか確認

### 計画ファイル
- `/Users/arimurahiroaki/.claude/plans/users-arimurahiroaki-downloads-img-4892-mutable-feather.md`

## 2026-05-21

### 作業内容
Firebase Analytics 連携を新規導入。
- Firebase Console で `TwinMirror` プロジェクト作成 (project ID: `twinmirror-981c0`, GA 地域: 日本)
- iOS アプリ登録 (bundle: `app.twinmirror.ios`, App Store ID: `6771413156`)
- `GoogleService-Info.plist` を `TwinMirror/Resources/` に配置 (`.gitignore` で除外)
- `project.yml` に Firebase SPM 依存追加 (`from: 12.0.0`、`FirebaseAnalytics` + `FirebaseCore`、`OTHER_LDFLAGS: -ObjC`)
- `Services/AnalyticsService.swift` 新規追加 (`AnalyticsTracking` プロトコル + `AnalyticsEvent` enum + `FirebaseAnalyticsService` + `NoopAnalyticsService`)
- `TwinMirrorApp.swift` で `FirebaseApp.configure()` 呼び出し
- ViewModels (`ComposeViewModel`/`ResultViewModel`) と Views (`HomeView`/`ComposeView`) に AnalyticsTracking を DI で注入
- イベント: home_viewed, compose_opened, compose_image_set, compose_generate_tapped, generation_started/succeeded/failed, result_regenerated, result_saved, result_save_failed, usage_limit_hit
- TwinMirrorTests に `AnalyticsServiceTests.swift` 追加 (8テスト)
- `xcodegen generate` 後、94テスト全合格

### 注意事項
- `GoogleService-Info.plist` はリポジトリに含めない方針 (`.gitignore` 済)。新規環境では Firebase Console から再ダウンロードして `TwinMirror/Resources/` に配置する必要あり
- Firebase SDK は `12.13.0` で resolve された (`from: 12.0.0` の up-to-next-major)
- DebugView を見るには Scheme → Run → Arguments に `-FIRDebugEnabled` を追加 (TestFlight 配布前に外す)

### 次回やるべきこと
- 実機/Simulator で DebugView にイベントが到達するか確認
- README とプライバシーポリシー (`docs/privacy.html`) に Firebase Analytics 利用の記載追加
- ATT (App Tracking Transparency) 方針の整理 (IDFA 非利用なら不要だが文書化する)

### 変更したファイル
- `project.yml` (Firebase package + linker flag)
- `TwinMirror/App/TwinMirrorApp.swift` (FirebaseApp.configure)
- `TwinMirror/Services/AnalyticsService.swift` (新規)
- `TwinMirror/Features/Home/HomeView.swift`
- `TwinMirror/Features/Compose/ComposeView.swift`
- `TwinMirror/Features/Compose/ComposeViewModel.swift`
- `TwinMirror/Features/Result/ResultViewModel.swift`
- `TwinMirror/Resources/GoogleService-Info.plist` (新規・gitignore)
- `TwinMirrorTests/AnalyticsServiceTests.swift` (新規)
- `.gitignore` (plist を除外)

### 計画ファイル
- `/Users/arimurahiroaki/.claude/plans/firebase-claude-in-chrome-firebas-analys-velvet-puzzle.md`


## 2026-05-21 アーキテクチャ図ドキュメント追加

### 作業内容
- `docs/architecture.md` を新規作成
- Mermaid.js で 5 種類のアーキテクチャ図を記述：
  1. システム全体図（iOS ↔ Cloudflare Worker ↔ Gemini / Firebase / GitHub Pages）
  2. iOS アプリ内部レイヤー（UI / ViewModel / Models / Services）
  3. 画像生成パイプライン シーケンス図（並列ブレンド比 + フォールバックチェーン）
  4. Cloudflare Worker リクエストフロー（認証・モデル allowlist・サイズ検証）
  5. デプロイ・ビルド構成（xcodegen / Wrangler / Worker Secrets）
- 末尾に技術スタック早見表を追加

### 変更ファイル
- `docs/architecture.md` (新規)

### 次回やるべきこと（任意）
- README.md からの `docs/architecture.md` への内部リンク追加
- 図に StoreKit 2 / IAP 周りが正式に組み込まれたタイミングで該当セクション更新

## 2026-05-22

### 作業内容
- プレミアムモード（3 枚生成）の出力サイズ不揃いを 3:4 縦長スマホサイズに統一
- プラン: `/Users/arimurahiroaki/.claude/plans/3-3-4-zany-bengio.md`
- 三層防御で実装：
  1. **API パラメータ**: `GeminiImageGenerator.buildRequestBody` の `generationConfig` に `imageConfig.aspectRatio: "3:4"` を追加（Gemini 2.5/3.1 image preview 共に正式サポート）
  2. **プロンプト指示**: `child_realistic_v2.txt` / `child_illustration_v2.txt` の COMPOSITION 先頭に「Output aspect ratio: 3:4 vertical portrait」を明示
  3. **後段正規化**: `parseResponse` の戻り値直前に `normalizeToAspect3x4(_:)` を追加。アスペクトフィル + 中央クロップで 864×1152 ピクセルに統一
- TDD: 失敗テストを先に書き（`test_buildRequestBody_includesAspectRatio3x4`、`test_parseResponse_normalizesOutputTo3x4Aspect`）→ 実装 → Green

### 検証結果
- `xcodebuild test`: TEST SUCCEEDED, 98 tests passed, 0 failures
- 既存テストの回帰なし

### 変更ファイル
- `TwinMirror/Services/GeminiImageGenerator.swift` (imageConfig 追加・normalizeToAspect3x4 追加)
- `TwinMirror/Resources/Prompts/child_realistic_v2.txt` (3:4 指示を COMPOSITION に追加)
- `TwinMirror/Resources/Prompts/child_illustration_v2.txt` (同上)
- `TwinMirrorTests/GeminiImageGeneratorTests.swift` (新規 2 テスト追加、旧 `test_parseResponse_extractsBase64Image` を `test_parseResponse_normalizesOutputTo3x4Aspect` にリネーム)

### 発見した問題点・注意事項
- `gemini-3.1-flash-image-preview` には `imageConfig.aspectRatio` を稀に無視する既知バグ報告あり（Google AI Developers Forum）。三層防御の根拠
- API JSON フィールド名は **`imageConfig.aspectRatio`** が正（一部のドキュメントが `responseFormat.image.aspectRatio` と紛らわしく書いてあるが、Vercel AI Gateway / Kong / LiteLLM / LangChain など現場の実装はすべて `imageConfig` を使用）
- `normalizeToAspect3x4` の `UIGraphicsImageRenderer` には `format.scale = 1` を明示（既存 `ImagePreprocessor.resize` と同じパターン）。これがないと Retina スケール（×2/×3）で意図せず大きな PNG が出る

### 次回やるべきこと
- 実機でプレミアム生成を実行し、3 枚すべて 864×1152 で揃っていることを目視確認
- fast モード（1 枚生成）でも 3:4 になっていることを確認
- 必要なら `bestIndex` 選択ロジック（JPEG サイズで最大を選ぶ）を見直す — 全て同サイズになったため JPEG バイト数比較が無意味になる可能性

## 2026-05-22

### 作業内容
- RevenueCat SDK 統合（プラン: `/Users/arimurahiroaki/.claude/plans/help-me-integrate-revenuecat-lively-cherny.md`）
- Swift Package Manager で `purchases-ios-spm` v5.x（解決済み: 5.73.1）、`RevenueCat` と `RevenueCatUI` の両プロダクトを追加
- 新規 `Services/PurchaseService.swift`: `@MainActor @Observable` シングルトン。`bootstrap()` で `Purchases.configure`、`customerInfoStream` を購読、`isPremium`/`purchase`/`restorePurchases`/`refreshOfferings` を提供
- Entitlement 識別子は `"TwinMirror Premium"`（`nonisolated static let premiumEntitlementID`）
- `UsageLimiter.shared` を `{ MainActor.assumeIsolated { PurchaseService.shared.isPremium } }` に切替（既存テストは全パス）
- `TwinMirrorApp.init()` に `PurchaseService.shared.bootstrap()` を追加（Firebase の次）
- 新規 Paywall 一式（`Features/Paywall/`）: `PaywallView`（カスタム SwiftUI）、`PaywallViewModel`、`SubscriptionManagementView`（RevenueCatUI の `CustomerCenterView` ラッパー）
- ComposeView に Pro/管理ピル追加、プレミアム上限時は Paywall シート提示、加入後は「無制限」表示に切替
- `AnalyticsEvent` に `paywallShown(source:)`/`purchaseCompleted(packageID:)`/`restoreCompleted(wasPremium:)` 追加
- 新規 `TwinMirrorTests/PurchaseServiceTests.swift`（4 件）と `AnalyticsServiceTests` 拡張（2 件）

### 検証結果
- `xcodegen generate`: 成功
- `xcodebuild test -scheme TwinMirror -destination 'platform=iOS Simulator,name=iPhone 17'`: **TEST SUCCEEDED**, 104 tests passed, 0 failures
- 既存 `UsageLimiterTests` 15 件すべてパス（`shared` の差し替えで回帰なし）

### 設定したこと
- `TwinMirror.xcconfig` に `REVENUECAT_API_KEY = test_nBedRHEzfCmiNvhxzLMbucdSByG`（gitignore 済み）
- `TwinMirror.xcconfig.example` に `REVENUECAT_API_KEY = REPLACE_WITH_REVENUECAT_API_KEY` プレースホルダ追加
- `project.yml` の Info.plist properties に `REVENUECAT_API_KEY: $(REVENUECAT_API_KEY)` 追加
- `AppConfig.swift` に `revenueCatAPIKey` アクセサ追加（`REPLACE_` プレフィックスは空に正規化）

### 次回やるべきこと（手動・ダッシュボード/実機検証）
- RevenueCat ダッシュボードで以下を確認・設定:
  - Project の API key（iOS）が現在の test key と一致しているか
  - Entitlement に `TwinMirror Premium` が存在しアクティブか（大小・スペース完全一致）
  - Offering（current）に `monthly` と `yearly` の Package が紐付いているか
  - Products が App Store Connect の Product ID と Sandbox/Production で一致しているか
- App Store Connect で月額・年額の自動更新サブスクリプションを作成（テスト用 Sandbox アカウントを準備）
- StoreKit Configuration File（`*.storekit`）を用意して Xcode のスキームに紐付ければシミュレータで購入フローを E2E 検証可能
- 実機 or シミュレータで以下を手動確認:
  1. Compose 画面の「Pro」ピル → PaywallView 表示 → プラン選択 → 購入 → 自動 dismiss
  2. 購入後に「管理」ピルへ切替・「無制限」バッジ表示
  3. プレミアム枠 1/1 を使い切った 2 回目に Paywall が自動表示される（`bypassLimit` は DEBUG で true なのでテストには Release ビルドまたは bypass 一時無効化が必要）
  4. 「サブスクリプション管理」から `CustomerCenterView` が開いて解約導線が機能する
  5. 機種変・再インストール後に「購入を復元」で `isPremium` 復元
- 必要なら本番用 API key（`appl_...`）を別途発行して xcconfig を切替

### 変更したファイル（主要）
- `project.yml`（package + dependency + Info.plist）
- `TwinMirror.xcconfig` / `TwinMirror.xcconfig.example`
- `TwinMirror/App/TwinMirrorApp.swift`
- `TwinMirror/Services/AppConfig.swift`
- `TwinMirror/Services/UsageLimiter.swift`（`.shared` のみ）
- `TwinMirror/Services/AnalyticsService.swift`（イベント追加）
- `TwinMirror/Services/PurchaseService.swift`（新規）
- `TwinMirror/Features/Paywall/PaywallView.swift`（新規）
- `TwinMirror/Features/Paywall/PaywallViewModel.swift`（新規）
- `TwinMirror/Features/Paywall/SubscriptionManagementView.swift`（新規）
- `TwinMirror/Features/Compose/ComposeView.swift`（Pro/管理ピル、Paywall sheet、premiumBadgeText）
- `TwinMirrorTests/PurchaseServiceTests.swift`（新規）
- `TwinMirrorTests/AnalyticsServiceTests.swift`（新規イベントのテスト追加）

### 発見した問題点・注意事項
- `PurchaseService` は `@MainActor` 隔離のため、静的ヘルパー（`premiumEntitlementID` / `isPremium(in:)`）は `nonisolated` で公開してテストから同期コンテキストで呼べるようにした
- `UsageLimiter.shared` のクロージャは `MainActor.assumeIsolated` で `PurchaseService.shared.isPremium` を読む。`tryConsume*` が常にメインスレッドから呼ばれる前提（現状の SwiftUI 経由呼び出しでは満たされる）
- xcconfig は gitignore 済み。CI 等でビルドする場合は別途 secret 注入が必要
- API key は `test_` プレフィックスのため Sandbox/開発用。本番リリース前に `appl_...` 形式の本番 key への差し替えが必要

## 2026-05-22（AgeRulerPicker スナップ不能バグ修正）

### 報告された現象
- 年齢ルーラーで「4歳」にスワイプしようとすると、勝手に 7歳 や 0歳 に戻される
- 結果として 0歳 以外で生成画面に進めず、ユーザーには「0〜5歳の生成ができない」「メモリがズレている」と見えていた

### 根本原因（1 つに集約）
`AgeRulerPicker.swift` の `ruler` で `LazyHStack` の直接の子として太い `Color.clear` パッド (≒160pt) を入れ、それを `.scrollTargetLayout()` で包んでいた。

- `.scrollTargetLayout()` は LazyHStack の直接の子をすべて snap target にするため、空白パッドも `.viewAligned` の snap 候補に混入していた → 4 歳付近で指を離すとパッドや lazy 化されていない隣接 id に吸い寄せられて 7/0 へ戻っていた
- `LazyHStack` の lazy 化により、`.scrollPosition(id:)` は実体化済みの id しか追跡できず、窓外への移動が阻害されていた
- 「生成失敗」は picker の不具合の副作用。生成パイプライン（PromptBuilder / GenerationOrchestrator / GeminiImageGenerator / Worker）には年齢依存の分岐は元から存在しない

### 修正内容
`TwinMirror/DesignSystem/AgeRulerPicker.swift` の `ruler` computed property のみ書き換え：

1. `LazyHStack` → `HStack`（21 ticks のみ。lazy 化の便益なし）
2. 内部の `Color.clear` パッドを削除し、ScrollView レベルの `.contentMargins(.horizontal, edgePad, for: .scrollContent)` に置換 → パッドが snap target にならない
3. `.scrollTargetBehavior(.viewAligned(limitBehavior: .always))` で慣性中間止まりも防止

### 検証結果
- `xcodebuild test -scheme TwinMirror -destination 'platform=iOS Simulator,name=iPhone 17'`: **TEST SUCCEEDED, 104 tests, 0 failures**
- 手動 UI 検証はユーザー側で必要（Compose 画面 → ルーラーを 0/4/5/7/12/18/20 へドラッグ → 指を離した位置で snap が中央指標に揃い、`X歳` 表示と一致すること）

### 計画ファイル
- `/Users/arimurahiroaki/.claude/plans/0-5-0-2-shimmying-pebble.md`

### 変更ファイル
- `TwinMirror/DesignSystem/AgeRulerPicker.swift`（`ruler` のみ）

### 注意事項
- `.contentMargins(_:_:for:)` は iOS 17+ 公式 API。deployment target iOS 26 なので問題なし
- 万一 `for: .scrollContent` で余白が効かない SDK バリエーションに遭遇したら `.safeAreaPadding(.horizontal, edgePad)` に切替（同等効果、API がより安定）
- SourceKit が `Cannot find ChildAge/Theme in scope` を吐くが、これは indexer の既存ノイズで実害なし（既往メモリにも記録あり）。`xcodebuild test` が正なので問題なし

---

## 2026-05-22（アプリレビュー依頼モーダル実装）

### 目的
App Store のレビュー数と評価を増やすため、ポジティブな瞬間に「楽しんでいるユーザー」だけを App Store のレビュー記入画面へ誘導する Satisfaction Gate パターンを実装。

### ベストプラクティス調査結果（2026-05時点 WebSearch）
- Satisfaction Gate（事前ふるい分け）で平均評価 +0.5 動く事例あり
- ポジティブな瞬間（タスク完了直後）でトリガー
- インストール直後は出さない（3〜7日）
- 90日クールダウン、ライフタイムキャップ 2〜3
- バージョン単位で1回まで（Apple HIG）
- Apple の `requestReview` は使わず、`apps.apple.com/app/id...?action=write-review` ディープリンクで安全側に振る

### 実装サマリ
- 新規 `ReviewRequestService`（`@MainActor @Observable` シングルトン）
  - 表示条件: install≥3日 / saveCount≥2 / cooldown≥60日 / 同バージョン未提示 / lifetime<3
  - UserDefaults キーは `twinmirror.review.*` 名前空間
- 新規 `ReviewRequestSheet`（3 ステップの SwiftUI シート）
  - Step1 「ツインミラーはいかがですか？」→ 「気に入っている」/「もう少し」
  - Step2a → App Store の write-review URL を `openURL`
  - Step2b → mailto: でフィードバック窓口（`support@twinmirror.app`）
- `ResultViewModel.saveCurrent` 成功直後に `reviewService.recordPositiveEvent()`
- `TwinMirrorApp.init` で `ReviewRequestService.shared.bootstrap()` を呼んで初回起動日を記録
- AnalyticsEvent に `reviewPromptShown` / `reviewPromptAnswered(satisfied:)` / `reviewPromptCtaTapped(action:)` を追加

### 変更ファイル
- 新規: `TwinMirror/Services/ReviewRequestService.swift`
- 新規: `TwinMirror/Features/Review/ReviewRequestSheet.swift`
- 新規: `TwinMirrorTests/ReviewRequestServiceTests.swift`（11 ケース）
- 修正: `TwinMirror/Services/AppConfig.swift`（`appStoreID` / write-review URL / mailto）
- 修正: `TwinMirror/Services/AnalyticsService.swift`（3 イベント追加）
- 修正: `TwinMirror/App/TwinMirrorApp.swift`（bootstrap）
- 修正: `TwinMirror/Features/Result/ResultViewModel.swift`（DI + recordPositiveEvent）
- 修正: `TwinMirror/Features/Result/ResultView.swift`（.sheet バインディング）
- 修正: `TwinMirrorTests/AnalyticsServiceTests.swift`（3 ケース追加）

### 検証
- `xcodegen generate` 実行済み（新規ファイルが target に追加）
- `xcodebuild test -scheme TwinMirror -destination 'platform=iOS Simulator,name=iPhone 17'`: **TEST SUCCEEDED, 117 tests, 0 failures**（旧 104 → +13）

### 未完了タスク・次回やるべきこと
- **支援メールアドレス `support@twinmirror.app` は実在しない**。ドメイン取得 → メール転送設定するか、`AppConfig.feedbackMailtoURL` を実在アドレスに差し替える必要あり
- 実機 E2E（3 日経過＋2 回保存後にだけ表示されることを `UserDefaults` 手動操作で確認）はリリース前に推奨
- TestFlight で初回観測後、`review_prompt_answered` の `satisfied=1` 割合・`review_prompt_cta_tapped(action=open_app_store)` 率を Firebase Analytics で確認し、しきい値（3日/2回/60日）の最適化検討

### 計画ファイル
- `/Users/arimurahiroaki/.claude/plans/appstor-glimmering-wand.md`

### 注意事項
- Apple の native `requestReview()` を使うパターン（フィルタリング後に表示）は Apple ガイドラインのグレーゾーンなので**意図的に避けた**。今回は明示的に「レビューを書く」を選んだユーザーだけ write-review ディープリンクで App Store に飛ばす設計
- ライフタイム上限 3 は Apple 側のレート制限（365日に3回）と整合
- `Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString")` でバージョンを取得し、同バージョン2回目以降は出さない

---

## 2026-05-22（オンボーディングアンケート実装）

### 目的
初回起動時に 3 問の軽量アンケートを表示し、顧客理解を深めてサービス改善に役立てる。
回答は Firebase **User Property** にセットして、以降の生成・課金イベントを年齢層×獲得チャネル×利用目的でクロス分析できるようにする。

### ベストプラクティス調査（2026-05 WebSearch）
- 質問数は 2〜3 問が最適（Spotify 3つ、Kontentino 2つ）
- 「スキップ」は隠さない（隠すと離脱率増）
- HDYHAU はシングルセレクト推奨（multi-select はノイズ化）
- 進捗表示「1/3」は完了率を上げる
- アナリティクスで取れる情報（国・端末）は聞かず、自己申告でしか取れない intent / source / age に絞る

### アンケート設問（最終）
1. **年齢層**: 〜24 / 25〜34 / 35〜44 / 45〜
2. **獲得チャネル**: App Store / SNS / 友人 / メディア / 広告 / その他
3. **利用目的**: パートナーと想像 / カップルで楽しむ / 友達とエンタメ / 興味本位

### 実装サマリ
- 新規 `OnboardingSurveyService`（`@MainActor @Observable` シングルトン）
  - `isCompleted` を UserDefaults からブート時に復元
  - `recordAnswer(step:key:value:)` で per-question event + setUserProperty
  - `markCompleted` / `markSkipped` どちらも `isCompleted = true` で再表示防止
- 新規 `OnboardingSurveyView`
  - `.fullScreenCover` で初回起動時のみ表示
  - 進捗 Capsule x3 + `n / 3` ラベル
  - 各設問は `SurveyOptionCard`（既存 `ModeCard` 系の白カード）でタップ自動進行
  - 「← 戻る」「スキップ」常設
  - 完了時 0.9s の「ありがとうございます！」スプラッシュ
- 新規 `Models/OnboardingSurveyAnswers.swift` に `AgeBracket` / `AcquisitionSource` / `UseCase` enum
- 新規 `DesignSystem/SurveyOptionCard.swift`
- `HomeView` の `.onAppear` で `!isCompleted` のとき `isSurveyPresented = true`
- `AnalyticsEvent` に 4 case 追加: `onboardingSurveyShown` / `..._questionAnswered` / `..._completed` / `..._skipped`

### 変更ファイル
- 新規: `TwinMirror/Models/OnboardingSurveyAnswers.swift`
- 新規: `TwinMirror/Features/Onboarding/OnboardingSurveyService.swift`
- 新規: `TwinMirror/Features/Onboarding/OnboardingSurveyView.swift`
- 新規: `TwinMirror/DesignSystem/SurveyOptionCard.swift`
- 新規: `TwinMirrorTests/OnboardingSurveyServiceTests.swift`（8 ケース）
- 新規: `TwinMirrorTests/OnboardingSurveyAnswersTests.swift`（5 ケース）
- 修正: `TwinMirror/Services/AnalyticsService.swift`（4 イベント追加）
- 修正: `TwinMirror/Features/Home/HomeView.swift`（.fullScreenCover）
- 修正: `TwinMirrorTests/AnalyticsServiceTests.swift`（3 case 追加）

### 検証
- `xcodegen generate` 実行済み
- `xcodebuild test -scheme TwinMirror -destination 'platform=iOS Simulator,name=iPhone 17'`: **TEST SUCCEEDED, 133 tests, 0 failures**（旧 117 → +16）

### Firebase User Property（重要）
回答時に `survey_age_bracket` / `survey_source` / `survey_use_case` の 3 つを `setUserProperty` で保持。Firebase Analytics の **Comparisons** タブから:
- 「TikTok 経由ユーザーの premium 課金率」
- 「45 歳〜ユーザーの保存回数」
- 「興味本位ユーザーのリテンション」
などのクロス分析が可能になる。

### 計画ファイル
- `/Users/arimurahiroaki/.claude/plans/onboarding-survey.md`

### 未完了タスク・次回やるべきこと
- **TestFlight ファネル観測**: `onboarding_survey_shown` → 各 `..._question_answered` → `..._completed` の通過率を Funnel レポートで確認。Q2 で大きく落ちるなら選択肢を見直す
- **アンケート結果を表示する設定画面**は今回スコープ外。需要が見えたら追加
- 既存ユーザー（UserDefaults に `twinmirror.survey.completed` がない既インストール勢）には次回起動時にアンケートが出る点に注意。リリースノートで案内推奨

### 注意事項
- 既存仕様：再インストール（UserDefaults クリア）でアンケート再表示。これは仕様
- スキップ／完了 どちらも `isCompleted = true` で永続化、再表示なし
- `markCompleted` は idempotent（2回目以降は副作用なし）
- `SurveyOptionCard` の `.shadow` は iOS 26 で正しく描画されることをシミュレータで確認済み

## 2026-05-22

### 作業内容（画像生成履歴タブ追加）
- 仕様: 無料ユーザーは直近 3 件 / Premium は全件無制限の画像生成履歴。
- バックエンド: Cloudflare Worker に R2 (HISTORY_BUCKET) + D1 (HISTORY_DB) を追加。
  - 新規エンドポイント: `POST /history`, `GET /history`, `GET /history/:id/image?variant=`, `DELETE /history/:id`
  - `scheduled()` で `expires_at < now` の D1 行と R2 オブジェクトを物理削除（無料ユーザー 30 日 TTL）
  - 認証: 既存 `X-Auth-Token` に加え `X-Device-Id`(UUIDv4), `X-Is-Premium`(true|false) ヘッダ
  - 詳細実装: `src/history.ts`, `src/auth.ts`, `migrations/0001_history.sql`
  - ルータ化: `src/index.ts` を path/method 振り分け式に変更（既存 `/generate` の挙動は維持）
- iOS:
  - `HistoryService` + `DeviceIdentity`(Keychain で UUID 永続化) を新設
  - `HistoryViewModel` (@Observable) でグループ化（今日/昨日/今月/それ以前）+ freeLimitReached 判定
  - `MainTabView` を root に追加して 2 タブ構成（ホーム / 履歴）に再構成
  - `HistoryView` は `LazyVGrid` + `.glassEffect` + `matchedTransitionSource` で Hero モーフ準備
  - `PremiumLockCard` を Free ユーザーの 4 件目に挿入 → `PaywallView` を sheet で開く
  - `ResultViewModel.generate()` 成功時に `bestImage` を 512px サムネ付きで自動保存（fire & forget）
- TDD 順序: Worker 16 テスト先行 → 実装で全緑、iOS 9 + 7 テスト先行 → 実装で全緑

### 検証結果
- Worker: `npm test` 全 28 緑、`npm run typecheck` 緑
- iOS: `xcodebuild test` 全 149 緑、`xcodebuild build` 成功（iPhone 17 Pro Simulator）

### 次回やるべきこと（ユーザー手動）
1. `cd cloudflare-worker && npx wrangler r2 bucket create twinmirror-history`
2. `npx wrangler d1 create twinmirror-history-db` → 出力された `database_id` を `wrangler.jsonc` の `REPLACE_AFTER_CREATE` と差し替え
3. `npx wrangler d1 migrations apply twinmirror-history-db --local`
4. `npx wrangler d1 migrations apply twinmirror-history-db --remote`
5. `npx wrangler deploy`
6. Xcode シミュレータで履歴タブの動作確認（Free 3 件壁・Premium 無制限・Hero モーフ）

### 注意事項
- `X-Is-Premium` ヘッダはクライアント信頼。実害は履歴を多く見せるだけで購買保護ではない（既存ポリシー）。
- 履歴の auto-save は `Task.detached` で非同期、失敗は `resultSaveFailed(errorKind: "history_...")` analytics へ。
- `wrangler.jsonc` の `database_id` を差し替えるまでデプロイ不可。
- R2/D1 の課金: 無料枠（10GB R2、5M reads/day D1）で日次数百ユーザーまでは余裕。

### 変更ファイル（主要）
- cloudflare-worker/src/index.ts, src/history.ts, src/auth.ts
- cloudflare-worker/migrations/0001_history.sql
- cloudflare-worker/wrangler.jsonc, SECRETS_TO_SET.md
- cloudflare-worker/test/history.test.ts, test/helpers/mocks.ts
- TwinMirror/App/TwinMirrorApp.swift
- TwinMirror/Models/HistoryItem.swift
- TwinMirror/Services/HistoryService.swift, DeviceIdentity.swift, AnalyticsService.swift
- TwinMirror/Features/Root/MainTabView.swift
- TwinMirror/Features/History/HistoryView.swift, HistoryDetailView.swift, HistoryViewModel.swift, HistoryEmptyState.swift, PremiumLockCard.swift
- TwinMirror/Features/Result/ResultViewModel.swift
- TwinMirrorTests/HistoryServiceTests.swift, HistoryViewModelTests.swift, Support/MockURLProtocol.swift

## 2026-05-24

### 作業内容: 美形すぎ問題 fix のロールバック (シナリオ A)
- `.claude/ROLLBACK_FEATURES.md` のシナリオ A を実行し、v3 プロンプト・2-pass 特徴抽出・Premium 履歴保存修正をすべて HEAD (be2e455 = 履歴タブ追加直後) に戻した
- 履歴タブ機能は維持
- 副作用: Premium モードの 3 枚履歴保存修正も一緒に巻き戻ったので、Premium 生成時の履歴は再び 1 枚のみに戻る

### 実行手順
1. バックアップ作成: `git branch backup/before-rollback-20260524 HEAD` + `git stash push -u -m "before-rollback-20260524"`
2. stash で working tree が HEAD まで一掃される (untracked 含む)
3. `.claude/ROLLBACK_FEATURES.md` は stash の untracked 領域 (`stash@{0}^3`) から復元
4. `wrangler.jsonc` の `database_id` を `REPLACE_AFTER_CREATE` から実 ID `25a1e539-84ba-49aa-8d65-2ea147325b44` に再設定
5. `xcodegen generate` + `xcodebuild test` → **149 tests pass, 0 failures** (HEAD 想定値どおり)
6. `cd cloudflare-worker && npm test` → **28 tests pass**
7. `npx wrangler deploy` 成功 → 本番から `/describe-parents` 剥がれた
   - 新 Version ID: ed1ee747-1e61-43ed-8252-5b1f4f8b7cf9

### 復旧したい場合
```bash
git stash pop   # 未コミット変更を復元
# または
git checkout backup/before-rollback-20260524
```
stash には 14 modified + 11 untracked が保存されている (`git stash show -u stash@{0} --name-only` で確認可)

### Cloudflare 側の残存
- D1 `twinmirror-history-db` (id: 25a1e539-...) と R2 `twinmirror-history` はそのまま残存 (履歴タブが使うため)
- `/describe-parents` ルートを叩いた iOS app は 404 を受けるが、stash 状態ではこのコード自体ないので呼ばれない

### 同日・Premium 履歴 3 枚保存だけ部分復元
- ロールバック後にユーザ依頼「履歴は 3 枚のままで」→ 美形すぎ fix は v2 に戻したまま、Premium 履歴保存修正だけ stash から復元
- 復元対象: `TwinMirror/Features/Result/ResultViewModel.swift` + `TwinMirrorTests/ResultViewModelTests.swift`
- 復元前に grep で 2-pass / ParentFeature 系の漏れがないことを検証 (両ファイルともゼロ)
- 復元方法: `git show stash@{0}:<path> > <path>` (`git checkout stash@{0} --` はパス解決エラーが出るため git show を使用)
- 検証: `xcodebuild test` → **154 tests pass (149 + 5 persistHistory)**, 0 failures
- シミュレータが preflight checks busy で 1 度失敗したが (既知症状)、shutdown 試行後の再実行で成功
- Worker は変更なし (前回デプロイ済みの状態でそのまま動作)

### 最終状態
- 美形すぎ問題 fix: 戻されたまま (v2 プロンプト、Pass 1 なし)
- 履歴タブ機能: 維持
- Premium 3 枚履歴保存: 復活
- iOS test: 154 / 154
- Worker test: 28 / 28

---

## 2026-05-24

### 作業内容
- Welcome 画面（ランディング）を初回起動時のみ表示するようリファクタ
- Home タブの中身を ComposeView（生成画面）に直接差し替え（旧 HomeView ランディング経由をやめた）
- 元 `HomeView.swift` を完全削除、`Features/Home/` ディレクトリも削除
- 新規 `WelcomeView` (`TwinMirror/Features/Welcome/WelcomeView.swift`) を作成し、旧 HomeView のランディング body をそのまま移植
- 新規 `RootView` (`TwinMirror/Features/Root/RootView.swift`) を作成。`@AppStorage("twinmirror.welcome.completed")` で WelcomeView ↔ MainTabView を切替
- `TwinMirrorApp.swift` の WindowGroup を `MainTabView()` → `RootView()` に変更
- `MainTabView.swift` の Home タブ中身を `HomeView()` → `NavigationStack { ComposeView() }` に変更
- `docs/architecture.md` の Mermaid 図に Root/Welcome/Tab/Compose/History を追加（HomeView 参照を更新）

### 設計判断
- 初回完了判定は `OnboardingSurveyService.isCompleted` ではなく独立フラグ `twinmirror.welcome.completed` を採用
  - 理由: survey は「スキップでも完了扱い」だが welcome は「ユーザーが明示的にボタンを押した瞬間」に閉じたい / 関心の分離
- Welcome / Survey 順序は「Welcome 表示と同時に survey を fullScreenCover」→ survey 完了/スキップで Welcome に戻る → ボタンタップで MainTabView へ
- MainTabView 切替後は標準フェードのみ、PhotosPicker 自動展開などの追加演出なし

### 検証結果
- `xcodebuild test -scheme TwinMirror`: **154 tests pass / 0 failures**
- シミュレータ実機検証（iPhone 16e）:
  - 完全リセット後の初回起動: WelcomeView + OnboardingSurveyView 表示、タブバーなし ✅
  - `survey.completed=1` のみ設定: WelcomeView のみ表示、タブバーなし ✅
  - `welcome.completed=1` 設定: MainTabView 直接表示、Home タブ = ComposeView ✅

### 変更したファイル
- 新規: `TwinMirror/Features/Welcome/WelcomeView.swift`
- 新規: `TwinMirror/Features/Root/RootView.swift`
- 編集: `TwinMirror/App/TwinMirrorApp.swift` (WindowGroup の中身)
- 編集: `TwinMirror/Features/Root/MainTabView.swift` (Home タブ = NavigationStack { ComposeView })
- 編集: `docs/architecture.md` (Mermaid 図)
- 削除: `TwinMirror/Features/Home/HomeView.swift` および `Features/Home/` ディレクトリ
- 再生成: `TwinMirror.xcodeproj` (xcodegen)
- 計画書: `/Users/arimurahiroaki/.claude/plans/var-folders-8c-cgy525cj1zj5w6r1-q4-hppw-expressive-swan.md`

### 発見した問題点・注意事項
- iOS Simulator では `xcrun simctl uninstall` の後に UserDefaults が完全消去されない場合がある（実測で `survey.completed = 1` が残存）。完全リセットしたい場合は `defaults delete <bundleID>` を併用する
- @AppStorage の default 値はキーが未設定の場合に返るだけで、UserDefaults には書き込まれない（=`defaults read` には現れない）。これを利用して「キー未設定 = 初回起動」と判定できる
- 今回は SwiftUI View のロジックが薄い（@AppStorage 切替＋クロージャ呼び出し）ため、UI 単体テストはリポジトリ既存パターン（HomeView も無テスト）に合わせてスキップ。検証はビルド + 既存テスト + シミュレータ実機で実施

### 次回やるべきこと
- 必要であれば `WelcomeView` のアクセシビリティ確認（VoiceOver）
- 既存 `home_viewed` 分析イベントが「初回ランディング表示時のみ」発火に変わったため、計測ダッシュボード側の前提を見直す（必要に応じて `composeOpened` を主要 KPI に差し替え）

### 同日・Gemini モデルを Flash → Pro に切替 (スピード改善)
- Premium モードが依然として遅い問題への対応
- 根本原因: Google 側のキャパシティ不足により `gemini-3.1-flash-image-preview` が `gemini-3-pro-image-preview` より遅いという既知バグ (googleapis/js-genai#1544)。Flash の名前に反して Pro の方が高速
- 修正内容:
  - `cloudflare-worker/src/index.ts`: ALLOWED_MODELS に `gemini-3-pro-image-preview` を追加
  - `TwinMirror/Services/GeminiImageGenerator.swift`: Model enum に `.proImage` 追加、デフォルトを `.proImage` に変更
  - `TwinMirror/Services/GenerationOrchestrator.swift`: defaultAttempts の 1 番目を `.proImage` に変更、Flash と 2.5 はフォールバック専用に降格
  - `TwinMirrorTests/GenerationOrchestratorTests.swift`: テスト名 + コメントを Pro 優先に更新 (assertion は style のみなので変更不要)
- コスト影響: Pro $0.134/枚 vs Flash $0.067/枚 — 2 倍 (Premium ユーザー対象なので許容)
- 検証: iOS 154 / 154 tests pass, Worker 28 / 28 tests pass
- デプロイ: Worker Version ID `fd308a24-d2c0-4d5b-8cb5-92f27b2f6c2b`

### 次回の確認ポイント
- 実機 Premium モードで以前 (Flash 時代) より速くなったかを実測
- 1 枚あたり 20〜40秒 → 期待値 10〜20秒 (公式 issue でも 50% 高速化の事例)
- もし Pro の方が画質も良いなら、Fast モードでも Pro 採用を検討

## 2026-05-24

### 作業内容
- ペイウォール (`TwinMirror/Features/Paywall/PaywallView.swift`) を全面リライト
- 参考画像 `~/Downloads/IMG_4970.PNG`（めろとーく Premium）の構成を踏襲：ヘッダー → 周期タブ → 割引バナー → 機能比較表 → スティッキーCTA
- 単一ティア × 3 周期 (週/月/年) の TwinMirror に合わせ、タブを「ティア選択」から「課金周期選択」へ転用
- 比較表 7 行を `docs/paywall.md` 章4「課金メリット優先順位」に従って配置：年齢進行 → 履歴 → 3パターン → ウォーターマーク → 4K → Fast → 広告
- アイコンはすべて既存 SF Symbols 体系から流用（`sparkles` / `crown.fill` / `figure.child` / `clock.arrow.circlepath` / `square.grid.2x2.fill` / `drop.fill` / `4k.tv` / `bolt.fill` / `rectangle.slash.fill`）
- 動的割引算出 `savingsInfo(for:)` — 選択中プランの週額換算 vs 週額プラン実勢価格を RevenueCat `Package.storeProduct.price` から計算
- CTA は既存 `GlassButton(isProminent:)` を再利用してデザイン統一、`safeAreaInset(edge: .bottom)` で底面固定

### 検証結果
- `xcodebuild build` (iPhone 17 Pro, iOS 26.2): **BUILD SUCCEEDED**
- 実機/シミュレータでの UI 検証は未実施（次回確認推奨）

### 変更したファイル
- `TwinMirror/Features/Paywall/PaywallView.swift`（全面リライト、334 → ~400 行）

### 次回やるべきこと
- シミュレータ起動 → Compose の Pro バッジ / 上限到達 / History ロックカードの 3 経路で表示確認
- iPhone SE と iPhone 17 Pro Max でレイアウト崩れ無いか確認
- 比較表の「Fast 生成 2回/日」は doc 値 — 現行コードは `UsageLimiter.fastDailyLimit = 3`。マーケ訴求と実装の差分は別タスクで解消必要

### 発見した問題点・注意事項
- `docs/paywall.md` の Free 仕様（Fast 2回/日、履歴 2件、年齢 5・10歳のみ等）と現行実装は未一致。ペイウォール表示は doc 値（マーケティング側）を信頼
- `package.storeProduct.priceFormatter` を流用しつつ独自 `NumberFormatter` で日割り表示を組み立て（priceFormatter は fractionDigits が通貨依存のため）
- ナビゲーションバーのタイトルを空にし、右上に `xmark.circle.fill` を配置（参考画像の X ボタンに合わせる）

## 2026-05-24

### 作業内容
- 生成画像左下に "TwinMirror" ウォーターマークを焼き込み（TikTok / SNOW スタイル）
- 無料ユーザーのみ対象、プレミアムユーザーは無加工（`docs/paywall.md` L26/L45 仕様準拠）
- 計画: `/Users/arimurahiroaki/.claude/plans/tiktok-twinmirror-users-arimurahiroaki-floofy-treasure.md`
- TDD で実装：WatermarkRendererTests (6件) → 実装 → ResultViewModelTests 拡張 (3件追加) → 統合
- `UIGraphicsImageRenderer` + 半透明黒ピル + 白文字 (SF Pro Semibold) で明暗両背景に対応
- 画像サイズ 6% マージン、フォントサイズ 4.5% で 864×1152 想定

### 検証結果
- `xcodebuild test` フル実行: **163 tests, 0 failures**
- WatermarkRendererTests: サイズ・スケール保持、左下変更、中央/右上非変更、暗背景視認性
- ResultViewModelTests: 無料時 watermarker 呼出、プレミアム時非呼出、保存経路にも反映

### 変更したファイル
- `TwinMirror/Services/WatermarkRenderer.swift`（新規）
- `TwinMirrorTests/WatermarkRendererTests.swift`（新規）
- `TwinMirror/Services/GenerationOrchestrator.swift`（`GenerationOrchestrating` プロトコル追加で DI 化）
- `TwinMirror/Features/Result/ResultViewModel.swift`（`watermarker` / `isPremiumProvider` / `orchestrator` DI 追加、`generate()` で `!isPremium` 時に焼き込み）
- `TwinMirrorTests/ResultViewModelTests.swift`（`SpyWatermarker` / `StubOrchestrator` 追加 + 3 テスト）

### 次回やるべきこと
- 実機シミュレータで Compose → 生成 → ResultView で左下 "TwinMirror" 表示を目視確認
- Photos アプリで保存後の画像にも watermark が焼かれていることを確認
- プレミアム化（RevenueCat sandbox or PurchaseService 差し替え）で watermark が消えることを確認
- 履歴サムネイル（512px max）にも watermark が見えるサイズかを確認（フォント 4.5% × 0.6 縮小 → 12pt 相当、ぎりぎり）

### 発見した問題点・注意事項
- `format.opaque` を `alphaInfo == .none` で判定する最初の実装は誤り（JPEG デコード後は `.noneSkipFirst`/`.noneSkipLast` で .none ではない）。simplify レビューで削除、デフォルト false に依存
- `ResultViewModel.orchestrator` を `any GenerationOrchestrating` 化したことで初めて `generate()` の単体テストが書けるようになった（従来は AppConfig.workerURL に依存して必ず空 attempts で fail）
- ウォーターマーク文言・配置・色はすべて `TwinMirrorWatermark` のプロパティで上書き可能（将来のロゴアイコン追加余地あり）
- SourceKit が "No such module 'UIKit'" を出すことがあるが、`xcodegen generate` 後の DerivedData インデックス再構築が遅れているだけで実害なし

## 2026-05-24（午後・テスト購入で entitlement が active にならない問題の診断機能追加）

### 問題の状況
- ユーザーが sandbox 環境でテスト購入したところ、購入後も以下 2 つが premium 化されなかった：
  1. **新規生成画像にウォーターマークが付いたまま** （ResultViewModel.swift:70）
  2. **履歴タブの「Premium で無制限」モーダル（PremiumLockCard）が消えない** （HistoryView.swift:100-106）
- 両方とも `PurchaseService.shared.isPremium` を参照しているため、`isPremium == false` のまま = **RevenueCat entitlement が active になっていない**ことが確定
- ユーザー仮説「RevenueCat がテストモードだから」は誤り：`appl_...` API キー（TwinMirror.xcconfig:13）は production キーで sandbox/production を自動判定する（[公式 sandbox docs](https://www.revenuecat.com/docs/test-and-launch/sandbox)）

### 作業内容（診断機能の追加、TDD で 1 件追加）
- `PurchaseService.debugEntitlementSummary`（#if DEBUG）追加：期待 entitlement ID、isPremium、active/all entitlements、originalAppUserId を文字列化
- `PurchaseService.startCustomerInfoStream()` に DEBUG ログを追加：ストリーム更新ごとに entitlement 状態を `os_log` 出力
- `PaywallViewModel.purchase()` 成功時に DEBUG ログ追加：購入直後の active entitlements / isPremium を出力
- `ResultView` 左上に DEBUG オーバーレイ追加：`PurchaseService.shared.debugEntitlementSummary` を黒半透明背景で表示
- `HistoryView` に `.onChange(of: purchaseService.isPremium)` 追加：購入後に履歴を自動再読込（freeLimitReached キャッシュ刷新）

### 検証結果
- `xcodebuild test -scheme TwinMirror -destination 'platform=iOS Simulator,name=iPhone 17'`: **163 tests, 0 failures**
- 新規テスト: `test_debugEntitlementSummary_includesExpectedID_andIsPremiumFlag`（DEBUG ガード内）

### 変更したファイル
- `TwinMirror/Services/PurchaseService.swift` — `debugEntitlementSummary` プロパティ、ストリーム DEBUG ログ
- `TwinMirror/Features/Result/ResultView.swift` — DEBUG オーバーレイ
- `TwinMirror/Features/Paywall/PaywallViewModel.swift` — `os` import + 購入成功 DEBUG ログ
- `TwinMirror/Features/History/HistoryView.swift` — `@State purchaseService` + `onChange(of:)` で `viewModel.load()`
- `TwinMirrorTests/PurchaseServiceTests.swift` — `debugEntitlementSummary` のスモークテスト追加

### 次回やるべきこと（ユーザー手動確認）
- DEBUG ビルドを実機にインストールし、ResultView 左上のオーバーレイで `isPremium: true/false` と `active: [...]` を目視確認
- `isPremium: false` のまま購入が完了した場合の切り分け：
  - `active: [(none)]` → RevenueCat ダッシュボードで "TwinMirror Premium" entitlement が無いか product 未 attach → ダッシュボードで設定
  - `active: [別名]` → entitlement ID 不一致 → コードかダッシュボードのどちらかを揃える（`PurchaseService.swift:21`、`PurchaseServiceTests.swift:9`）
  - `customerInfo: nil (未到達)` → SDK 初期化失敗
- RevenueCat ダッシュボード（app.revenuecat.com）の "View Sandbox Data" トグル ON で Customers タブにテスト購入が記録されているか確認
- App Store Connect 側で In-App Purchase product が "Ready to Submit" / "Approved" ステータスか確認（"Missing Metadata" だと sandbox でも entitlement 付与失敗あり）

### 発見した問題点・注意事項
- ウォーターマークは **生成時に画像に焼き込まれる**（`ResultViewModel.swift:70`）ため、購入前に生成された画像は永久に消えない。今回の問題は「新規生成画像にも付いた」ので焼き込み済みではなく `isPremium == false` 起因
- `HistoryView.task` は `didAppearOnce` で初回のみ実行 → 購入後に History タブに戻っても `freeLimitReached` キャッシュが残る。`onChange(of: isPremium)` で解決
- `PurchaseService` は `@Observable` なので `PurchaseService.shared.isPremium` 変化が SwiftUI に伝播する。`@State` で保持すれば onChange で観測可能
- `Purchases.shared.customerInfoStream` は購入成功時に即時 emit するため、ストリーム更新 → `customerInfo` 反映 → `isPremium` 再評価 → SwiftUI 再描画 → `onChange` 発火、の流れが成立する
- 計画ファイル: `/Users/arimurahiroaki/.claude/plans/twinmirror-revenuecat-claude-in-chrome-imperative-leaf.md`

### 原因確定と修正（同日中に解決）
- ユーザーから RevenueCat ダッシュボードのスクリーンショット提供：
  - Entitlement Identifier: **`premium`**（小文字、スペースなし）
  - Display Name: "Premium"
  - Attached products: `com.twinmirror.premium.{monthly,weekly,yearly}`
- コード側 `premiumEntitlementID = "TwinMirror Premium"` と完全不一致 → `entitlements["TwinMirror Premium"]` が nil → `isActive` false → `isPremium = false`
- **修正**: コード側を `"premium"` に揃える（ダッシュボードの Display Name はそのまま "Premium" 表示）
  - `PurchaseService.swift:21` リテラル変更
  - `PurchaseService.swift:13` ドキュメントコメント追従
  - `PurchaseServiceTests.swift:9` 契約テスト更新
  - `PurchaseServiceTests.swift:39` debugEntitlementSummary テスト更新
- `PaywallView.swift:110` の `Text("TwinMirror Premium")` はユーザー向け表示名なのでそのまま残す
- `xcodebuild test`: **164 tests, 0 failures**
- 次回ユーザー検証時に DEBUG オーバーレイで `active: [premium]` / `isPremium: true` が見えるはず
