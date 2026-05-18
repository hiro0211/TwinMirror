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
