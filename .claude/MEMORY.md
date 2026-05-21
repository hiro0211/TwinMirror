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

## 2026-05-20

### 高速モード保存バグ修正（ユーザー報告 + 隠れた重大バグ）

#### 報告された現象
高速モードで3枚のカルーセルを左右にスワイプして「保存」を押すと、表示が真ん中に戻る。

#### 発見した隠れた重大バグ
表示が戻るだけでなく、**保存される画像も常に真ん中の `bestImage`** だった。左右にスワイプして保存しても、保存されるのは真ん中の画像。ユーザー認識（「保存はできている」）と実態が乖離していた。

#### 根本原因
- `ResultView.swift`：`TabView(selection: .constant(result.bestIndex))` の constant binding → 再描画で必ず真ん中に戻る。
- `ResultViewModel.swift`：`saveCurrent()` が常に `result.bestImage` を保存していた。

#### 修正内容（TDD）
1. `PhotoSaveService.swift`：`PhotoSaving` protocol 追加（DI 用）。
2. `ResultViewModel.swift`：`saveService` を DI 可能に。`saveCurrent()` → `saveCurrent(at index: Int)` に変更し、`result.images[index]` を保存。範囲外は no-op。
3. `ResultView.swift`：`@State selectedIndex` を導入。`TabView(selection: $selectedIndex)` で双方向バインド。`onAppear` / `onChange(of: result.images.count)` で再生成時に `bestIndex` にリセット。保存ボタンは `saveCurrent(at: selectedIndex)` を呼ぶ。
4. `TwinMirrorTests/ResultViewModelTests.swift`（新規・6 tests）：`SpyPhotoSaver` で「index で指定した画像が保存されること」を検証。全 71 テスト緑。

#### 変更ファイル
- `TwinMirror/Services/PhotoSaveService.swift`
- `TwinMirror/Features/Result/ResultViewModel.swift`
- `TwinMirror/Features/Result/ResultView.swift`
- `TwinMirrorTests/ResultViewModelTests.swift`（新規）

#### 残課題・要手動確認
- 実機/シミュレータで高速モードを起動して、左→保存→写真アプリで左画像が保存されていることを目視確認すること（自動テストは ViewModel 層までしかカバーできない）。
- プレミアムモード（1枚のみ）でも保存が機能することを確認。

#### 注意点
- LSP（SourceKit）が UIKit / XCTest を解決できないノイズが出るが、xcodebuild ではビルド・テストとも成功する環境問題。実害なし。

### ParentPhotoCard の X ボタンが見切れ＆タップ不可だったバグ修正

#### 現象
お母さん（右側）の写真カードの X ボタンが画面右端で見切れて押せない。お父さん側でも厳密には同じ clip が起きていたが視認しにくく目立たなかった。

#### 根本原因
`ParentPhotoCard` の overlay 構造：
- X ボタンは `Image.padding(m).overlay(alignment: .topTrailing)` で配置
- 親 ZStack に `.glassEffect(... in: .rect(cornerRadius: 20))` が掛かっており、cornerRadius=20pt の角丸カーブによって、たった 4pt (xs) のインセットで置かれた X ボタンが視覚的にもタップ判定的にも clip されていた

#### 修正内容（Option A：内側に X を収める）
`TwinMirror/Features/Compose/ComposeView.swift` の `ParentPhotoCard` のみ修正：
1. `.overlay(alignment: .topTrailing)` を **ZStack の `.glassEffect` の外側** に移動 → clip 影響を受けない
2. ボタン padding を `xs (4pt)` → `s (8pt)` に増やし、角丸カーブの内側へ
3. `.frame(width: 44, height: 44)` + `.contentShape(Circle())` で Apple HIG の最小タップ領域 44×44pt を確保
4. `.foregroundStyle(.white, .black.opacity(0.6))`（0.5→0.6）で視認性微改善
5. `.accessibilityLabel("写真を削除")` 追加

#### 検証
- 全 71 自動テストが緑のまま（ロジック層は無変更）
- 手動検証：実機シミュレータで写真選択 → 両カードの X が表示・タップで写真クリアできることを確認すること（未実施）

#### 変更ファイル
- `TwinMirror/Features/Compose/ComposeView.swift`（ParentPhotoCard のみ）

#### 注意点
SwiftUI で clip された View に overlay を当てる時は、**clip より外側で overlay を当てる**のが定石。`.glassEffect(...in:)` は `.clipShape` 相当の振る舞いをするため、その内側に overlay を置くと両端でカットされる。

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
