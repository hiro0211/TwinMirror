# Twin Mirror プロジェクトメモリ

## 2026-05-17

### 作業内容
- Twin Mirror MVP のフルスカフォールド構築（仕様書 → 実装プラン → コード）
- プラン: `/Users/arimurahiroaki/.claude/plans/twin-mirror-floating-glade.md`
- xcodegen + Xcode 26.3 + iOS 26.2 SDK で iOS App プロジェクト生成
- Liquid Glass UI（GlassEffectContainer, glassEffect, interactive）でHome / Compose / Result / LoadingMorph 全画面実装
- Vision顔検出 → ImagePreprocessor → Gemini Nano Banana 2 (gemini-3.1-flash-image-preview) REST直接呼び出し
- フォールバックチェーン: Gemini 3.1 photoreal → Gemini 3.1 illustration → Gemini 2.5 illustration → OpenAI gpt-image-2
- TDD: PromptBuilder / ImagePreprocessor / GeminiImageGenerator の19テストすべてパス
- 利用規約・プライバシーポリシーHTML作成（docs/terms.html, docs/privacy.html）

### 検証結果
- `xcodebuild build`: BUILD SUCCEEDED (iOS 26.2 シミュレータ)
- `xcodebuild test`: TEST SUCCEEDED, 19 tests passed, 0 failures
- シミュレータでアプリ起動成功、Homeビュー完全描画（Liquid Glass ボタン、CTA、利用規約リンク全て表示）

### 次回やるべきこと
- **必須**: ユーザーが `TwinMirror.xcconfig` に実際の Gemini API キーを記入
- **必須**: 実機（iPhone 15 Pro / iPhone SE 第3世代）で60FPS確認 + 電池消費実測
- **重要**: Compose → 写真選択 → 生成フローをE2Eで実機テスト
- **重要**: 30回連続生成でGemini child-safety 拒否率を実測（イラストfallbackで0%が目標）
- TestFlight配信のための Apple Developer Program 加入 + 証明書設定
- App Store審査前の年齢制限17+ / Bundle ID最終確定
- 利用規約HTML を GitHub Pages or Notion にホスティング → AppConfig.swift の URL 差し替え

### 発見した問題点・注意事項
- **xcodebuild test が iOS 26.2 シミュレータでハングするケースあり**: simctl reboot で復旧。複数の xcodebuild test を同時実行すると詰まる
- **テストファイルの配置ミス容易**: `~/TwinMirrorTests/` (誤) vs `~/TwinMirror/TwinMirrorTests/` (正) — xcodegen の sources パスと一致させる必要
- **Child safety フィルタリスク（最重要）**: Gemini も OpenAI も photorealistic newborn を高確率でブロックする可能性。illustration fallback で回避設計済みだが、本番テストで拒否率実測必須
- **API キーがバイナリに同梱されるリスク**: 検証フェーズのみ許容。バズ確認後すぐにバックエンドプロキシ化が必要
- **Liquid Glass のA14世代パフォーマンス**: micro-stutter / 電池13-20%消費増。LoadingMorphView は実機FPS実測してから出荷
- **deployment target iOS 26.0 固定**: 採用率15%だが Liquid Glass 前提のため下位対応しない

### 変更したファイル（主要）

#### プロジェクト構成
- `/Users/arimurahiroaki/TwinMirror/project.yml` (xcodegen 設定)
- `/Users/arimurahiroaki/TwinMirror/TwinMirror.xcconfig` (APIキー、.gitignore対象)
- `/Users/arimurahiroaki/TwinMirror/TwinMirror.xcconfig.example`
- `/Users/arimurahiroaki/TwinMirror/.gitignore`
- `/Users/arimurahiroaki/TwinMirror/README.md`

#### アプリ本体
- `App/TwinMirrorApp.swift`
- `Features/Home/HomeView.swift`
- `Features/Compose/ComposeView.swift`
- `Features/Compose/ComposeViewModel.swift`
- `Features/Result/ResultView.swift`
- `Features/Result/ResultViewModel.swift`

#### DesignSystem (Liquid Glass)
- `DesignSystem/Theme.swift`
- `DesignSystem/GlassButton.swift`
- `DesignSystem/GlassChip.swift`
- `DesignSystem/LoadingMorphView.swift`

#### Services
- `Services/ImageGenerator.swift` (protocol)
- `Services/GeminiImageGenerator.swift` (Nano Banana 2 REST)
- `Services/OpenAIImageGenerator.swift` (gpt-image-2 fallback)
- `Services/GenerationOrchestrator.swift` (フォールバックチェーン)
- `Services/FaceDetectionService.swift` (Vision)
- `Services/ImagePreprocessor.swift` (顔BBox→1024正方形)
- `Services/PromptBuilder.swift`
- `Services/PhotoSaveService.swift`
- `Services/AppConfig.swift`

#### Models / Resources
- `Models/GenerationRequest.swift` (BabyGender enum, GenerationResult)
- `Resources/Prompts/baby_realistic_v1.txt`
- `Resources/Prompts/baby_illustration_v1.txt`

#### Tests (TDD)
- `TwinMirrorTests/PromptBuilderTests.swift` (5 tests)
- `TwinMirrorTests/ImagePreprocessorTests.swift` (6 tests)
- `TwinMirrorTests/GeminiImageGeneratorTests.swift` (7 tests)
- `TwinMirrorTests/SmokeTests.swift` (1 test)

#### 法務
- `docs/terms.html`
- `docs/privacy.html`

### コマンド早見
```bash
cd /Users/arimurahiroaki/TwinMirror
xcodegen generate                              # プロジェクト再生成
open TwinMirror.xcodeproj                      # Xcodeで開く
xcodebuild build -scheme TwinMirror -destination 'id=C7BB8D3B-A9A9-4CB8-8EAA-1A350FD6B584'
xcodebuild test -scheme TwinMirror -destination 'id=C7BB8D3B-A9A9-4CB8-8EAA-1A350FD6B584'
xcrun simctl launch C7BB8D3B-A9A9-4CB8-8EAA-1A350FD6B584 app.twinmirror.ios
```

## 2026-05-18

### 作業内容
- `GenerationOrchestrator.defaultAttempts` を OpenAI 排他化（Gemini 暗黙フォールバック撤廃）
  - OpenAIキー有効時: OpenAI 単独 attempt のみ返す
  - OpenAIキー未設定 / プレースホルダー時のみ既存 Gemini 3.1/2.5/illustration チェーンを返す（後方互換）
- 関連テストを新仕様に追従:
  - `test_defaultAttempts_openaiFirstWhenKeyPresent` → `test_defaultAttempts_onlyOpenAIWhenKeyPresent`（count == 1 / Gemini 含まないことを明示検証）
  - `test_defaultAttempts_endsWithIllustrationFallback` → `..._whenOpenAIAbsent`（openAIKey="" の時のみ illustration が末尾）

### 変更ファイル
- `TwinMirror/Services/GenerationOrchestrator.swift`
- `TwinMirrorTests/GenerationOrchestratorTests.swift`

### 検証結果
- `xcodebuild test`: ALL 37 tests passed (0 failures)
- 計画ファイル: `/Users/arimurahiroaki/.claude/plans/users-arimurahiroaki-downloads-img-4843-enumerated-hanrahan.md`

### 背景
ユーザーが GPT API に切り替えたつもりだったが、`generate()` ループの transient-error
フォールバック（429/400/5xx）により OpenAI 失敗 → Gemini 呼び出し → Gemini 側のクレジット
枯渇エラー（"Your prepayment credits are depleted. AI Studio..."）がユーザーに表示されていた。
OpenAI のエラーがそのまま伝播するよう、OpenAI キー有効時はチェーン長を 1 にした。

### 次回確認したいこと
- シミュレータ実機で `api.openai.com` のみにリクエストが飛ぶことを Proxyman 等で再確認
- OpenAI 側のクレジット残高 / `gpt-image-2` モデル名（2026-04 リリース、今も実在するか公式 doc で確認）
- 必要なら post-MVP として OpenAI 安全ブロック時の illustration スタイル attempt を検討

### 追加修正 (同日)
- OpenAI 400エラー "Duplicate parameter: 'image'" を解消
  - `OpenAIImageGenerator.multipartBody` のフィールド名を `image` → `image[]` に変更
  - OpenAI `/v1/images/edits` は同名フィールド重複を 400 で拒否する。複数画像は配列記法 `image[]` で渡す必要がある
  - テスト `test_multipartBody_imageFieldRepeatedNotBracketed` → `test_multipartBody_imageFieldUsesArrayBracketsForMultiple` に書き換え、`image[]` が画像数ぶん出ること & bracket無しの `image` が出ないことを検証
- `xcodebuild test`: 全 37 tests pass

### さらなる追加機能 (同日・生成モード選択)
- ユーザーが生成前に「高速モード」「プレミアムモード」を選択できるよう実装
  - **高速モード** (`.fast`): Gemini 3.1 Nano Banana 2 中心。Geminiチェーンを使用。サブテキスト「約10秒でサクッと生成」
  - **プレミアムモード** (`.premium`): OpenAI gpt-image-2 単独。キーが無効ならGeminiにフォールバック。サブテキスト「1〜2分かけて高画質に仕上げる」
- 追加・変更内容:
  - `Models/GenerationRequest.swift`: `GenerationQuality` enum (displayName / subtitle / systemImage) と `GenerationRequest.quality` フィールド (default `.fast`)
  - `Services/GenerationOrchestrator.swift`: `defaultAttempts` & `init` に `quality` 引数を追加し switch でルーティング。`geminiChain` private helper を抽出
  - `Features/Compose/ComposeViewModel.swift`: `quality: GenerationQuality = .fast` を追加、`buildGenerationRequest()` に流し込み
  - `Features/Result/ResultViewModel.swift`: `init` で `quality: initialRequest.quality` を Orchestrator に渡す、`regenerate` でも quality を保持
  - `Features/Compose/ComposeView.swift`: 性別セクションの直下に `qualitySection` を追加。Liquid Glass ベースの `QualityModeCard` (private struct) を inline 実装。アイコン (`bolt.fill` / `sparkles`) + 日本語タイトル + サブテキスト + チェックマーク。fast は accent (青)、premium は primaryDeep (濃いピンク) のティント
  - `TwinMirrorTests/GenerationOrchestratorTests.swift`: quality ベースの新テスト 6 件で旧テスト 4 件を置き換え

### 検証結果
- `xcodebuild build`: BUILD SUCCEEDED
- `xcodebuild test`: ALL 39 tests passed (新規 quality ルーティングテストを含む)
- 自然な日本語化リサーチ: Google Gemini モバイル app の「高速モード / 思考モード」UIを参考にした（ラベル＋サブテキストの2行構成）

### さらなる追加修正 (同日・タイムアウト対策)
- `OpenAIImageGenerator.swift` の `urlRequest.timeoutInterval` を `90` → `240` 秒に延長
- 理由: `gpt-image-2` は `quality=high` × `n=3` × 参照画像2枚で 60〜180 秒かかることが多く、
  90秒では URLSession 側がタイムアウトして「生成できませんでした」と表示されてしまっていた。
  OpenAI ダッシュボードでは Credit balance $4.56 / 直近 24h で 2 requests 成功と確認済み（クレジット切れではない）。
- `xcodebuild test`: 全 37 tests pass（変更は定数のみ、ロジック非影響）

## 2026-05-18

### 作業内容
- Compose 画面（写真選択画面）の「使い方 / ご利用について」カードが、淡パステル背景の上で暗く濁って読めなかった問題を修正
- プラン: `/Users/arimurahiroaki/.claude/plans/users-arimurahiroaki-downloads-img-4842-dazzling-kettle.md`（案A採用）
- `TwinMirror/Features/Compose/ComposeView.swift` のみ変更：
  - L120 使い方カード：`.glassEffect(.regular.tint(.white.opacity(0.3)))` → `.tint(.white.opacity(0.7))`
  - L132 ご利用についてカード：`.tint(.orange.opacity(0.2))` → `.tint(Theme.Colors.cream.opacity(0.85))`（オレンジティントの茶色濁りを回避、アイコンの `.orange` は残して注意喚起ニュアンスを担保）
  - L223 `BulletText` 本文：`Theme.Colors.textSecondary` → `Theme.Colors.textPrimary`（行頭「•」は textSecondary 維持で階層感確保）
- Theme.swift / Assets.xcassets は変更なし、既存トークン (`cream`, `textPrimary`) を再利用

### 次回やるべきこと
- 実機 (iOS 26 / iPhone 16 Pro) で 2 カードの可読性を目視確認
- Dynamic Type xLarge 以上での折り返し挙動確認
- `xcodebuild test -scheme TwinMirror` で 37 テストが引き続き通ることを確認（UI 変更のみなのでロジック影響なし想定）

### 発見した問題点・注意事項
- **iOS 26 Liquid Glass `.regular` マテリアル**は背景の輝度を強く引き下げるため、パステル背景に重ねる場合は `.tint(...)` の opacity を 0.6〜0.85 程度まで上げないとマッディな見た目になる。色付きティント（特にオレンジ・ブラウン系）は濁りやすいので、警告系はアイコン色だけで表現し背景はクリーム/白寄りにするのが安全
- 編集後に SourceKit が `Cannot find 'Theme' in scope` 等を出したが、これは indexer が他ファイルを解決できていない既存症状で、今回の差分（値の置換のみ）とは無関係

### 変更したファイル
- `TwinMirror/Features/Compose/ComposeView.swift`

## 2026-05-19

### 作業内容
- 「赤ちゃん」→「子ども」の全面リネーム（UI / Info.plist / project.yml / 利用規約・プライバシー HTML / README）
- 生成対象年齢を **0〜20歳の連続レンジ**に拡張。ComposeView に **横スクロール年齢ピッカー `AgeRulerPicker`** を新設
- ピッカーは iOS 26 純正 API（`.scrollPosition(id:)` + `.scrollTargetBehavior(.viewAligned)` + `.sensoryFeedback(.selection, trigger:)` + `.glassEffect(...)`）で実装。実機ではティック切替ごとに触覚（`UISelectionFeedbackGenerator` 相当）が発火
- `ChildAge` 値型を追加（years + bucket: newborn/toddler/child/preteen/teen/youngAdult）。0〜20 を 6 バケットへマッピングしてプロンプト断片を生成
- `BabyGender` → `ChildGender` 全面リネーム（型名のみ、case 名は不変なので呼び出し側のリテラル変更は最小限）
- プロンプトテンプレートを `baby_*_v1.txt` → `child_*_v2.txt` に刷新。`{{AGE_BLOCK}}` プレースホルダで年齢ブロックを Swift 側から差し込む構造に
- 計画: `/Users/arimurahiroaki/.claude/plans/0-5-10-15-warm-canyon.md`

### 検証結果
- `xcodegen generate` 成功
- `xcodebuild build`: BUILD SUCCEEDED（iPhone 17 Pro simulator, iOS 26.2）
- `xcodebuild test`: **TEST SUCCEEDED, 65 tests passed, 0 failures**（前回37 → 今回65、+28テスト追加）
- 追加テスト: `ChildAgeTests`(12) / `ChildAgePromptsTests`(9) / 拡張した `PromptBuilderTests`(8) で全年齢×全スタイル×全 gender のプレースホルダ残存チェック網羅

### 次回やるべきこと
- **必須・実機**: AgeRulerPicker のスクロール触覚 (`UISelectionFeedbackGenerator`) が期待どおり鳴るか実機で確認（シミュレータでは触覚は再生されない）
- **必須・実機**: 0/3/7/12/18/20 歳を順に生成し、(a) 顔の同一性、(b) 年齢らしさ、(c) バケット境界でジャンプ感がないか目視
- **次フェーズ**: 0/5/10/15/20 の **同セッション並列タイムライン生成**（5タイル段階表示 + TaskGroup 並列 + per-age cache）
- **次フェーズ・優先度高**: 18歳ゲート + 第三者AI同意フロー（Apple Guideline 5.1.2(i) 2025-11 更新）+ 結果画像へ AI 透かし焼き込み
- **次フェーズ**: 二段マスター肖像パイプライン（identity 一貫性最大化）
- **オペレーション**: TikTok スパイク前に Gemini Tier 2 ($250 cumulative spend) と OpenAI Tier 2 へ昇格

### 発見した問題点・注意事項
- **`.scrollPosition(id: $optionalInt)`**: バインディングは `Int?` 必須。`age.years` (`Int`) との同期は `onChange` 二方向で行うが、`onAppear` で初回 `scrolledYear = age.years` を入れないと初期スクロール位置が左端になる
- **Gemini も OpenAI もシード固定不可**: 年齢間で同一個体性を保つには **プロンプトのみで identity-anchor 文を強化する**しかない（"Do NOT change underlying face structure inherited from A and B" を共通文に常駐させた）。次フェーズの二段マスター肖像パイプラインで根本対策
- **`candidateCount > 1` は Gemini 3.1 Flash Image では 400 を返す**（リサーチで確認、Google AI Forum 2026 記事）。タイムライン化する際は **5 並列リクエスト**で対応する必要あり
- **`@State` で持つ `@Observable` ViewModel への `$Binding`**: SwiftUI iOS 17+ の `@Bindable var vm = viewModel` を computed property 内で宣言する書き方で対応。`$viewModel.x` 直接は使えない
- **SourceKit の `Cannot find ... in scope` 警告**: 編集中に頻発するが、`xcodegen generate` 直後は project の index が古いだけで実害なし。`xcodebuild build` で実証する運用が確実

### 変更したファイル

#### モデル / Services
- `TwinMirror/Models/GenerationRequest.swift`（`ChildGender` リネーム、`ChildAge` struct 新設、`GenerationRequest.age` 追加）
- `TwinMirror/Services/ChildAgePrompts.swift`（新規、バケット別プロンプト断片）
- `TwinMirror/Services/PromptBuilder.swift`（`build(style:gender:age:)` シグネチャ、新テンプレ名）
- `TwinMirror/Services/GenerationOrchestrator.swift`（`age` を PromptBuilder に渡す1行追加）

#### リソース
- `TwinMirror/Resources/Prompts/child_realistic_v2.txt`（新規）
- `TwinMirror/Resources/Prompts/child_illustration_v2.txt`（新規）
- `TwinMirror/Resources/Prompts/baby_realistic_v1.txt`（削除）
- `TwinMirror/Resources/Prompts/baby_illustration_v1.txt`（削除）

#### UI / DesignSystem
- `TwinMirror/DesignSystem/AgeRulerPicker.swift`（新規、横スクロールルーラー）
- `TwinMirror/DesignSystem/GlassButton.swift`（プレビュー文言更新）
- `TwinMirror/Features/Compose/ComposeView.swift`（年齢セクション挿入、ナビ/CTA/性別参照のリネーム）
- `TwinMirror/Features/Compose/ComposeViewModel.swift`（`age` プロパティ、`ChildGender` 参照）
- `TwinMirror/Features/Home/HomeView.swift`（文言3箇所）
- `TwinMirror/Features/Result/ResultView.swift`（`ChildGender.allCases` リネーム）
- `TwinMirror/Features/Result/ResultViewModel.swift`（`ChildGender` 参照、再生成で `age` を維持）

#### 設定 / ドキュメント
- `TwinMirror/Info.plist`（NSPhotoLibrary* descriptions の「赤ちゃん」→「子ども」）
- `project.yml`（同上）
- `README.md`（製品定義拡張）
- `docs/privacy.html`（「赤ちゃん」→「子ども」x2）
- `docs/terms.html`（製品定義拡張）

#### テスト（新規・拡張）
- `TwinMirrorTests/ChildAgeTests.swift`（新規、12 tests）
- `TwinMirrorTests/ChildAgePromptsTests.swift`（新規、9 tests）
- `TwinMirrorTests/PromptBuilderTests.swift`（新シグネチャに移行、全年齢ループの placeholder 残存チェック追加）
