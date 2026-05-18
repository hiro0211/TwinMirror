# Twin Mirror (ツインミラー)

2人の写真から「未来の赤ちゃん」を1枚生成するiOSアプリ。TikTokでのバズ可能性を検証するMVP。

## セットアップ

### 必要環境
- Xcode 26.3 以上
- macOS 15.6 以上
- iOS 26 SDK
- xcodegen (`brew install xcodegen`)

### 手順

1. APIキーを取得
   - Gemini: https://aistudio.google.com/apikey
   - OpenAI（任意、緊急fallback用）: https://platform.openai.com/api-keys

2. `TwinMirror.xcconfig` を編集してキーを設定
   ```
   GEMINI_API_KEY = your_actual_key_here
   OPENAI_API_KEY = your_actual_key_or_empty
   ```

3. Xcodeプロジェクト生成
   ```
   xcodegen generate
   ```

4. Xcodeで開く
   ```
   open TwinMirror.xcodeproj
   ```

5. シミュレータまたは実機で実行（⌘R）

### セキュリティ警告

`TwinMirror.xcconfig` のAPIキーはアプリバイナリに同梱されます。逆コンパイルで抜かれるリスクがあるため、**バズ検証フェーズのみ**この方式を採用しています。本格運用時は必ずバックエンドプロキシ経由に切り替えてください。

Google AI Studio / OpenAI ともに低めのQuota制限を設定して被害を最小化することを推奨します。

## アーキテクチャ

- **UI**: SwiftUI + iOS 26 Liquid Glass
- **画像生成**: Gemini Nano Banana 2 (`gemini-3.1-flash-image-preview`) → 2.5 → OpenAI gpt-image-2 のフォールバックチェーン
- **顔検出**: Vision Framework
- **設計指針**: 追加SDKゼロ、TDD、機能最小

詳細は `/Users/arimurahiroaki/.claude/plans/twin-mirror-floating-glade.md` を参照。
