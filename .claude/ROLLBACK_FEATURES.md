# ロールバック手順書

このドキュメントは「履歴タブ」「美形すぎ問題の修正 (v3 プロンプト + 2-pass + Premium 履歴保存修正)」を **追加する前の状態に戻す** ための完全な手順書です。

調査済みの実装状態 (2026-05-23 時点):

| 機能 | 状態 | 戻す範囲 |
|---|---|---|
| **A. 美形すぎ問題 fix** (v3 prompts / 2-pass / Premium 履歴保存修正) | **未コミット** (working tree only) | 修正ファイル 14 + 新規ファイル 10 を破棄 |
| **B. 履歴タブ feature** | **コミット済み** (`be2e455` "Add image generation history feature with backend support") | コミット revert + Cloudflare R2/D1 のクリーンアップ |

---

## 使い方

Claude に **以下の見出しの「貼り付けるプロンプト」セクションをそのままコピペ** すると、調査 + 実行 + 検証まで自動で行ってくれます。手動でやりたい場合は「手動 git コマンド」を実行してください。

3 つのシナリオを用意:
1. **シナリオ A** — 美形すぎ問題 fix のみ戻す（履歴タブは残す）
2. **シナリオ B** — 履歴タブのみ戻す（美形すぎ fix は残す。基本的にこの順序は非推奨。先に A を実行してから B を実行する方が安全）
3. **シナリオ C** — 両方戻す (= 完全に元の状態 `0899a24` に戻す)

---

## シナリオ A: 美形すぎ問題 fix だけ戻す

### 貼り付けるプロンプト

```
.claude/ROLLBACK_FEATURES.md のシナリオ A を実行してください。

具体的には、未コミットの v3 プロンプト・2-pass 特徴抽出・Premium 履歴保存修正をすべて破棄して、HEAD (履歴タブ追加直後) の状態に戻したい。

以下の作業を順にやってください:
1. 現在の git status と diff を確認し、想定通り変更されていることを確認
2. 修正された 14 ファイルを HEAD 状態に復元 (git checkout HEAD -- <files>)
3. 追加された 10 ファイルを削除 (rm)
4. cloudflare-worker/src/index.ts と wrangler.jsonc は HEAD に戻す
   ただし wrangler.jsonc は database_id (25a1e539-84ba-49aa-8d65-2ea147325b44) を保持したいので、HEAD に戻したあと該当行だけ手動編集で実 ID に戻すかユーザに確認
5. xcodegen generate を実行して Xcode プロジェクトを再生成
6. xcodebuild test (175 tests = 169 元々 + 6 既存 saveCurrent。新規 V3/extractor/persistHistory 系は削除済み) が通ることを確認
7. cd cloudflare-worker && npm test (28 tests) が通ることを確認
8. cd cloudflare-worker && npx wrangler deploy で /describe-parents が剥がれた状態を本番反映
9. .claude/MEMORY.md の 2026-05-23 セクションを削除またはアーカイブ
```

### 影響範囲 (変更ファイル一覧)

**HEAD に戻すべきファイル (M)**
- `TwinMirror/Features/Compose/ComposeViewModel.swift`
- `TwinMirror/Features/Result/ResultViewModel.swift` (Premium 履歴保存ループ含む)
- `TwinMirror/Services/AnalyticsService.swift` (pass1_feature_extraction_* イベント)
- `TwinMirror/Services/BlendPrompts.swift` (version 引数)
- `TwinMirror/Services/ChildAgePrompts.swift` (美化助長表現除去)
- `TwinMirror/Services/GenerationOrchestrator.swift` (2-pass 統合)
- `TwinMirror/Services/ImagePreprocessor.swift` (年齢別 padding)
- `TwinMirror/Services/PromptBuilder.swift` (v3 default + observedFeatures)
- `TwinMirrorTests/GenerationOrchestratorTests.swift` (2-pass テスト)
- `TwinMirrorTests/ImagePreprocessorTests.swift` (age padding テスト)
- `TwinMirrorTests/ResultViewModelTests.swift` (persistHistory テスト)
- `cloudflare-worker/src/index.ts` (/describe-parents ルート)
- `cloudflare-worker/wrangler.jsonc` (※ database_id は実 ID に変えてあるので保持要検討)

**削除すべきファイル (??)**
- `TwinMirror/Models/ParentFeatures.swift`
- `TwinMirror/Resources/Prompts/blend_block_balanced_v3.txt`
- `TwinMirror/Resources/Prompts/blend_block_father_leaning_v3.txt`
- `TwinMirror/Resources/Prompts/blend_block_mother_leaning_v3.txt`
- `TwinMirror/Resources/Prompts/child_illustration_v3.txt`
- `TwinMirror/Resources/Prompts/child_realistic_v3.txt`
- `TwinMirror/Services/ParentFeatureExtractor.swift`
- `TwinMirrorTests/ParentFeatureExtractorTests.swift`
- `TwinMirrorTests/PromptBuilderV3Tests.swift`
- `cloudflare-worker/src/describe.ts`
- `cloudflare-worker/test/describe.test.ts`

### 手動 git コマンド

```bash
cd /Users/arimurahiroaki/TwinMirror

# 1) 修正ファイルを HEAD に戻す (M)
git checkout HEAD -- \
  TwinMirror/Features/Compose/ComposeViewModel.swift \
  TwinMirror/Features/Result/ResultViewModel.swift \
  TwinMirror/Services/AnalyticsService.swift \
  TwinMirror/Services/BlendPrompts.swift \
  TwinMirror/Services/ChildAgePrompts.swift \
  TwinMirror/Services/GenerationOrchestrator.swift \
  TwinMirror/Services/ImagePreprocessor.swift \
  TwinMirror/Services/PromptBuilder.swift \
  TwinMirrorTests/GenerationOrchestratorTests.swift \
  TwinMirrorTests/ImagePreprocessorTests.swift \
  TwinMirrorTests/ResultViewModelTests.swift \
  cloudflare-worker/src/index.ts \
  cloudflare-worker/wrangler.jsonc

# 2) 新規ファイルを削除 (??)
rm TwinMirror/Models/ParentFeatures.swift \
   TwinMirror/Resources/Prompts/blend_block_balanced_v3.txt \
   TwinMirror/Resources/Prompts/blend_block_father_leaning_v3.txt \
   TwinMirror/Resources/Prompts/blend_block_mother_leaning_v3.txt \
   TwinMirror/Resources/Prompts/child_illustration_v3.txt \
   TwinMirror/Resources/Prompts/child_realistic_v3.txt \
   TwinMirror/Services/ParentFeatureExtractor.swift \
   TwinMirrorTests/ParentFeatureExtractorTests.swift \
   TwinMirrorTests/PromptBuilderV3Tests.swift \
   cloudflare-worker/src/describe.ts \
   cloudflare-worker/test/describe.test.ts

# 3) wrangler.jsonc の database_id を実 ID に再設定 (HEAD は REPLACE_AFTER_CREATE プレースホルダ)
#    手動 or sed で書き戻す
sed -i '' 's|"database_id": "REPLACE_AFTER_CREATE"|"database_id": "25a1e539-84ba-49aa-8d65-2ea147325b44"|' cloudflare-worker/wrangler.jsonc

# 4) Xcode プロジェクト再生成
xcodegen generate

# 5) iOS テスト
xcodebuild test -scheme TwinMirror -destination 'id=C7BB8D3B-A9A9-4CB8-8EAA-1A350FD6B584'

# 6) Worker テスト
cd cloudflare-worker && npm test && cd ..

# 7) Worker 再デプロイ (/describe-parents エンドポイントを本番から削除)
cd cloudflare-worker && npx wrangler deploy && cd ..
```

---

## シナリオ B: 履歴タブだけ戻す

⚠️ **A を実行してから B を実行することを推奨**。A の変更は履歴タブに依存する箇所があるため (例: ResultViewModel.persistHistory の Premium 3 枚保存ループ)、先に A を戻さないと revert が衝突する。

### 貼り付けるプロンプト

```
.claude/ROLLBACK_FEATURES.md のシナリオ B を実行してください。

履歴タブ機能 (コミット be2e455 "Add image generation history feature with backend support") を取り除いて、その親コミット 0899a24 (onboarding survey) の状態に戻したい。

⚠️ 先にシナリオ A が完了している前提 (working tree がクリーン)。もし未コミット差分があれば、まずシナリオ A を実行してください。

以下を順に:
1. git status で working tree がクリーンであることを確認 (もしダーティなら停止して報告)
2. git revert be2e455 --no-edit を実行
   - もし conflict が出たら自動解決せず停止して内容を報告
3. 生成された revert コミットをユーザに見せて確認
4. xcodegen generate
5. xcodebuild test (履歴タブ関連 22 テスト = HistoryServiceTests 12 + HistoryViewModelTests 10 が消える) が通ることを確認
6. cd cloudflare-worker && npm test (履歴系 ~16 テストが消える) が通ることを確認
7. cd cloudflare-worker && npx wrangler deploy で /history /history/:id 系を本番から剥がす
8. ユーザに以下のクリーンアップを案内 (実行はしない):
   - Cloudflare R2 bucket "twinmirror-history" 削除: npx wrangler r2 bucket delete twinmirror-history
   - Cloudflare D1 database "twinmirror-history-db" 削除: npx wrangler d1 delete twinmirror-history-db --skip-confirmation
   - これらは課金リスクが低いので残しておくのも選択肢
```

### 手動 git コマンド

```bash
cd /Users/arimurahiroaki/TwinMirror

# 1) 履歴コミットを revert (新規 revert commit を作成)
git revert be2e455 --no-edit

# 2) Xcode プロジェクト再生成 + テスト
xcodegen generate
xcodebuild test -scheme TwinMirror -destination 'id=C7BB8D3B-A9A9-4CB8-8EAA-1A350FD6B584'

# 3) Worker 再デプロイ
cd cloudflare-worker && npm test && npx wrangler deploy && cd ..

# 4) Cloudflare 側のリソースをクリーンアップ (任意)
cd cloudflare-worker
npx wrangler r2 bucket delete twinmirror-history
npx wrangler d1 delete twinmirror-history-db
cd ..
```

---

## シナリオ C: 全部戻す (両方を一気に)

### 貼り付けるプロンプト

```
.claude/ROLLBACK_FEATURES.md のシナリオ C を実行してください。

履歴タブと美形すぎ問題 fix の両方を完全に戻して、コミット 0899a24 (onboarding survey feature) の状態に戻したい。

順序:
1. まずシナリオ A を実行 (未コミット差分を破棄)
2. working tree が完全にクリーンになったことを git status で確認
3. 次にシナリオ B を実行 (be2e455 コミットを revert)
4. 全テスト・Worker テスト・デプロイまで完了
5. Cloudflare R2/D1 のクリーンアップは課金リスクが低いのでユーザに確認

各ステップの結果を報告し、conflict や予期しない差分があれば停止してください。
```

### 手動コマンド (一気に)

```bash
cd /Users/arimurahiroaki/TwinMirror

# === シナリオ A ===
git checkout HEAD -- \
  TwinMirror/Features/Compose/ComposeViewModel.swift \
  TwinMirror/Features/Result/ResultViewModel.swift \
  TwinMirror/Services/AnalyticsService.swift \
  TwinMirror/Services/BlendPrompts.swift \
  TwinMirror/Services/ChildAgePrompts.swift \
  TwinMirror/Services/GenerationOrchestrator.swift \
  TwinMirror/Services/ImagePreprocessor.swift \
  TwinMirror/Services/PromptBuilder.swift \
  TwinMirrorTests/GenerationOrchestratorTests.swift \
  TwinMirrorTests/ImagePreprocessorTests.swift \
  TwinMirrorTests/ResultViewModelTests.swift \
  cloudflare-worker/src/index.ts \
  cloudflare-worker/wrangler.jsonc

rm TwinMirror/Models/ParentFeatures.swift \
   TwinMirror/Resources/Prompts/blend_block_balanced_v3.txt \
   TwinMirror/Resources/Prompts/blend_block_father_leaning_v3.txt \
   TwinMirror/Resources/Prompts/blend_block_mother_leaning_v3.txt \
   TwinMirror/Resources/Prompts/child_illustration_v3.txt \
   TwinMirror/Resources/Prompts/child_realistic_v3.txt \
   TwinMirror/Services/ParentFeatureExtractor.swift \
   TwinMirrorTests/ParentFeatureExtractorTests.swift \
   TwinMirrorTests/PromptBuilderV3Tests.swift \
   cloudflare-worker/src/describe.ts \
   cloudflare-worker/test/describe.test.ts

# === シナリオ B ===
git revert be2e455 --no-edit

# === ビルド・テスト・デプロイ ===
xcodegen generate
xcodebuild test -scheme TwinMirror -destination 'id=C7BB8D3B-A9A9-4CB8-8EAA-1A350FD6B584'
cd cloudflare-worker && npm test && npx wrangler deploy && cd ..

# === Cloudflare リソース削除 (任意・課金影響軽微) ===
# cd cloudflare-worker
# npx wrangler r2 bucket delete twinmirror-history
# npx wrangler d1 delete twinmirror-history-db
# cd ..
```

---

## 注意事項

### Cloudflare 側の状態
- **Worker は本番デプロイ済み** (`https://twinmirror-gemini-proxy.arimurahiroaki40.workers.dev`)。コード revert 後に `npx wrangler deploy` しないと本番には旧コードのまま残る
- **R2 bucket `twinmirror-history`** と **D1 `twinmirror-history-db` (id: 25a1e539-84ba-49aa-8d65-2ea147325b44)** はインフラとして残存。コード revert だけでは消えない
- **GEMINI_API_KEY / WORKER_AUTH_TOKEN secret は影響なし** (どのシナリオでも引き続き必要)

### iOS 側の状態
- xcconfig (`TwinMirror.xcconfig`) の WORKER_URL/WORKER_AUTH_TOKEN は影響なし
- 履歴タブ revert 時、`MainTabView` が単一画面に戻るため iOS UI 構造が変わる
- v2 プロンプトファイル (`child_realistic_v2.txt` 等) は履歴 commit 以前から存在しているので、シナリオ A 後も残る (= 戻し先として有効)

### 緊急時の最終手段
全部を強制的に元に戻したい場合 (履歴を書き換える破壊的操作):

```bash
git reset --hard 0899a24
git clean -fd  # 未追跡ファイルも削除
```

⚠️ **`reset --hard` は revert と違い、コミット履歴を書き換える**。リモートに push 済みなら他作業者と衝突する可能性。個人開発でリモートにも push 済みなら `git push --force` が必要 (これも破壊的)。可能なら `git revert` を優先。

### v3 → v2 の "ソフトロールバック" (コード変更なし)
ファイル削除や git revert を伴わない、最も軽量な巻き戻し方法。本番品質に問題が出ただけなら、まずこれを試すのが安全:

`TwinMirror/Services/PromptBuilder.swift` の 1 箇所だけ変更:
```swift
// 変更前 (v3 がデフォルト)
init(bundle: Bundle = .main, version: Version = .v3) {
// 変更後 (v2 に戻す)
init(bundle: Bundle = .main, version: Version = .v2) {
```
+ `GenerationOrchestrator(attempts:)` 経由のテストでは extractor=nil なので Phase 2 (2-pass) は自動的に無効化される。本番では `init(workerURL:authToken:)` 経由なので extractor を nil 化したいなら `GenerationOrchestrator` 側で `featureExtractor` を渡さない init を呼ぶよう変える必要あり。

これだけで v2 プロンプト挙動に戻る (Phase 2 の 2-pass は別途切る必要あり)。本格的に元に戻したいときに限ってシナリオ A を使う。

---

## バックアップ推奨

シナリオを実行する前に、念のためバックアップブランチを作っておくと安心:

```bash
git branch backup/before-rollback-$(date +%Y%m%d) HEAD
git stash push -u -m "before-rollback-$(date +%Y%m%d)"  # 未コミット差分も保存
```

戻したいときは:
```bash
git stash pop  # 未コミット差分を復元
git checkout backup/before-rollback-YYYYMMDD  # コミット差分を復元
```
