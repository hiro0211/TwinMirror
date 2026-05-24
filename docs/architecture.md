# Twin Mirror アーキテクチャ図

このドキュメントは Twin Mirror アプリ全体のシステムアーキテクチャを Mermaid.js で図解したものです。
GitHub / VS Code / Obsidian など Mermaid 対応ビューアでそのままレンダリングできます。

---

## 1. システム全体図 (High-Level Architecture)

iOS クライアント → Cloudflare Worker (プロキシ) → Google Gemini API という 3 層構成。
Gemini API キーは Worker 側 Secret に格納され、iOS バンドルからは取り除かれている。

```mermaid
flowchart LR
    subgraph Device["📱 ユーザー端末 (iOS 26)"]
        direction TB
        App["Twin Mirror App<br/>(SwiftUI)"]
        Vision["Vision Framework<br/>(顔検出)"]
        Photos["Photos Library<br/>(保存)"]
        App --> Vision
        App --> Photos
    end

    subgraph CF["☁️ Cloudflare Edge (Workers)"]
        Worker["twinmirror-gemini-proxy<br/>POST /generate"]
        Secrets[("Worker Secrets<br/>GEMINI_API_KEY<br/>WORKER_AUTH_TOKEN")]
        Obs["Observability Logs"]
        Worker -.読込.-> Secrets
        Worker -.送信.-> Obs
    end

    subgraph Google["🤖 Google AI"]
        Gemini["Generative Language API<br/>gemini-3.1-flash-image-preview<br/>gemini-2.5-flash-image"]
    end

    subgraph Firebase["🔥 Firebase"]
        Analytics["Firebase Analytics<br/>(イベント計測)"]
    end

    subgraph GitHub["🌐 GitHub Pages"]
        Legal["terms.html / privacy.html"]
    end

    App -- "POST /generate<br/>X-Auth-Token<br/>(父・母 JPEG + プロンプト)" --> Worker
    Worker -- "x-goog-api-key<br/>generateContent" --> Gemini
    Gemini -- "生成画像 (Base64)" --> Worker
    Worker -- "Pass-through<br/>(ステータス・ボディそのまま)" --> App
    App -- "イベントログ" --> Analytics
    App -. "規約・プライバシー表示" .-> Legal

    classDef device fill:#e3f2fd,stroke:#1565c0,color:#0d47a1
    classDef cf fill:#fff3e0,stroke:#ef6c00,color:#e65100
    classDef goog fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20
    classDef fb fill:#ffebee,stroke:#c62828,color:#b71c1c
    classDef gh fill:#f3e5f5,stroke:#6a1b9a,color:#4a148c
    class App,Vision,Photos device
    class Worker,Secrets,Obs cf
    class Gemini goog
    class Analytics fb
    class Legal gh
```

---

## 2. iOS アプリ内部レイヤー構造

SwiftUI MVVM + サービスレイヤー。追加 SDK ゼロ方針で Vision / Photos / Foundation のみを使用。

```mermaid
flowchart TB
    subgraph UI["🎨 UI Layer (SwiftUI Views)"]
        Root["RootView<br/>(初回起動分岐)"]
        Welcome["WelcomeView<br/>(初回起動のみ)"]
        Tab["MainTabView"]
        Compose["ComposeView<br/>(=ホームタブ)"]
        History["HistoryView"]
        Result["ResultView"]
        DS["DesignSystem<br/>(GlassButton, AgeRulerPicker,<br/>LoadingMorphView, Theme)"]
    end

    subgraph VM["🧠 ViewModel Layer (@Observable)"]
        ComposeVM["ComposeViewModel"]
        ResultVM["ResultViewModel"]
    end

    subgraph Models["📦 Models"]
        GenReq["GenerationRequest<br/>GenerationResult<br/>ChildGender / ChildAge"]
        Blend["BlendRatio<br/>GenerationMode<br/>(fast / premium)"]
    end

    subgraph Services["⚙️ Services Layer"]
        Orch["GenerationOrchestrator<br/>(並列パイプライン<br/>+ フォールバックチェーン)"]
        GenAbs["ImageGenerator (protocol)"]
        Gemini["GeminiImageGenerator"]
        Prompt["PromptBuilder<br/>BlendPrompts<br/>ChildAgePrompts"]
        Pre["ImagePreprocessor<br/>(顔中心クロップ + JPEG)"]
        Face["FaceDetectionService<br/>(Vision)"]
        Save["PhotoSaveService<br/>(Photos)"]
        Limit["UsageLimiter<br/>(UserDefaults / 日次制限)"]
        Cfg["AppConfig<br/>(WORKER_URL / TOKEN)"]
        Ana["AnalyticsService<br/>(Firebase wrapper)"]
    end

    Root --> Welcome
    Root --> Tab
    Tab --> Compose
    Tab --> History
    Compose --> ComposeVM
    Compose --> DS
    Result --> ResultVM
    Result --> DS

    ComposeVM --> Face
    ComposeVM --> Pre
    ComposeVM --> GenReq
    ComposeVM --> Ana

    ResultVM --> Orch
    ResultVM --> Save
    ResultVM --> Ana
    ResultVM --> Cfg

    Orch --> Prompt
    Orch --> GenAbs
    GenAbs -.実装.-> Gemini
    Gemini --> Cfg

    Compose --> Limit
    ResultVM --> Blend
    Orch --> Blend

    classDef ui fill:#e3f2fd,stroke:#1565c0,color:#0d47a1
    classDef vm fill:#fce4ec,stroke:#ad1457,color:#880e4f
    classDef model fill:#fff8e1,stroke:#f57f17,color:#e65100
    classDef svc fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20
    class Root,Welcome,Tab,Compose,History,Result,DS ui
    class ComposeVM,ResultVM vm
    class GenReq,Blend model
    class Orch,GenAbs,Gemini,Prompt,Pre,Face,Save,Limit,Cfg,Ana svc
```

---

## 3. 画像生成パイプライン (シーケンス図)

`premium` モードでは 3 つのブレンド比 (balanced / fatherLeaning / motherLeaning) を **並列** に
それぞれ独立したフォールバックチェーン (Nano Banana 2 → 2.5 → イラスト調) で実行する。

```mermaid
sequenceDiagram
    autonumber
    actor User as ユーザー
    participant CV as ComposeView
    participant FS as FaceDetectionService<br/>(Vision)
    participant PP as ImagePreprocessor
    participant UL as UsageLimiter
    participant RV as ResultViewModel
    participant Orch as GenerationOrchestrator
    participant Gen as GeminiImageGenerator
    participant CFW as Cloudflare Worker
    participant API as Gemini API
    participant FA as Firebase Analytics
    participant Ph as Photos Library

    User->>CV: 父・母の写真を選択
    CV->>FS: detectLargestFace(image)
    FS-->>CV: DetectedFace
    User->>CV: 性別・年齢・モード指定<br/>「生成」タップ
    CV->>UL: tryConsume(mode)
    alt 上限内
        UL-->>CV: true
        CV->>PP: process(image, face)
        PP-->>CV: 顔中心クロップ済 JPEG
        CV->>RV: GenerationRequest を渡して遷移
        RV->>FA: generation_started
        RV->>Orch: generate(request)

        par balanced
            Orch->>Gen: nanoBanana2 + photorealistic
            Gen->>CFW: POST /generate (X-Auth-Token)
            CFW->>CFW: トークン検証 / model allowlist / サイズ検証
            CFW->>API: generateContent (x-goog-api-key)
            API-->>CFW: 画像 (Base64)
            CFW-->>Gen: pass-through
            Gen-->>Orch: UIImage
        and fatherLeaning
            Orch->>Gen: 同上 (失敗時 2.5 → illustration)
        and motherLeaning
            Orch->>Gen: 同上
        end

        Orch-->>RV: GenerationResult (画像配列)
        RV->>FA: generation_succeeded
        RV-->>User: 結果表示
        User->>RV: 保存タップ
        RV->>Ph: PHPhotoLibrary.save
        Ph-->>RV: success
        RV->>FA: result_saved
    else 上限超過
        UL-->>CV: false
        CV->>FA: usage_limit_hit
        CV-->>User: ペイウォール表示
    end
```

---

## 4. Cloudflare Worker リクエストフロー

Worker は薄いプロキシだが、認証・モデル制限・ボディサイズ検証など複数のゲートを通過する。

```mermaid
flowchart TD
    Start(["POST リクエスト着信"]) --> M{"Method == POST<br/>かつ Path == /generate ?"}
    M -- No --> E404[["404 not_found"]]
    M -- Yes --> Cfg{"Secrets が設定済み?<br/>(GEMINI_API_KEY,<br/>WORKER_AUTH_TOKEN)"}
    Cfg -- No --> E500[["500 server_misconfigured"]]
    Cfg -- Yes --> Auth{"X-Auth-Token が<br/>定数時間比較で一致?"}
    Auth -- No --> E401[["401 unauthorized"]]
    Auth -- Yes --> Size{"Content-Length<br/>≦ 8 MiB ?"}
    Size -- No --> E413[["413 payload_too_large"]]
    Size -- Yes --> Parse{"JSON パース成功?"}
    Parse -- No --> E400a[["400 invalid_json"]]
    Parse -- Yes --> Model{"model が allowlist?<br/>(gemini-3.1-flash-image-preview /<br/>gemini-2.5-flash-image)"}
    Model -- No --> E400b[["400 model_not_allowed"]]
    Model -- Yes --> Strip["body から model を除去"]
    Strip --> Fwd["Gemini API へ転送<br/>x-goog-api-key 付与"]
    Fwd --> Resp["upstream の status / body を<br/>そのまま pass-through"]
    Resp --> End(["クライアントへ応答"])

    classDef err fill:#ffebee,stroke:#c62828,color:#b71c1c
    classDef ok fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20
    class E404,E500,E401,E413,E400a,E400b err
    class Resp,End,Fwd,Strip ok
```

---

## 5. デプロイ・ビルド構成

iOS は Xcode/xcodegen でビルド、Worker は Wrangler で Cloudflare へデプロイ。
両者は `WORKER_URL` と `WORKER_AUTH_TOKEN` (共有シークレット) で結合される。

```mermaid
flowchart LR
    subgraph Dev["💻 開発者マシン"]
        XCfg["TwinMirror.xcconfig<br/>(WORKER_URL / WORKER_AUTH_TOKEN)"]
        XGen["xcodegen → project.yml"]
        Xcode["Xcode 26.3 ビルド"]
        Wrangler["wrangler deploy"]
        DevVars[".dev.vars (gitignored)"]
        XCfg --> XGen --> Xcode
    end

    subgraph IPA["📦 iOS バイナリ (TestFlight / App Store)"]
        Bundle["TwinMirror.app<br/>(SwiftUI + Firebase SDK)"]
    end

    subgraph CFD["☁️ Cloudflare"]
        Edge["twinmirror-gemini-proxy<br/>(Edge 全リージョン)"]
        SecretStore[("Worker Secrets")]
    end

    Xcode --> Bundle
    Wrangler --> Edge
    Wrangler -- "secret put" --> SecretStore
    DevVars -. ローカル実行のみ .-> Wrangler

    Bundle -- HTTPS --> Edge
    Edge -.使用.-> SecretStore

    classDef dev fill:#e1f5fe,stroke:#0277bd,color:#01579b
    classDef out fill:#fff3e0,stroke:#ef6c00,color:#e65100
    classDef cf fill:#fce4ec,stroke:#ad1457,color:#880e4f
    class XCfg,XGen,Xcode,Wrangler,DevVars dev
    class Bundle out
    class Edge,SecretStore cf
```

---

## 補足: 主要技術スタック

| レイヤー | 採用技術 |
|---|---|
| iOS UI | SwiftUI, iOS 26 Liquid Glass |
| iOS 状態管理 | `@Observable` (Swift 5.9+) |
| 顔検出 | Vision Framework (`VNDetectFaceRectanglesRequest`) |
| 画像保存 | Photos Framework (`PHPhotoLibrary`) |
| 計測 | Firebase Analytics |
| バックエンド | Cloudflare Workers (TypeScript) |
| デプロイツール | Wrangler |
| AI モデル | Gemini 3.1 Flash Image Preview (Nano Banana 2) → 2.5 Flash Image フォールバック |
| 静的ホスティング | GitHub Pages (規約・プライバシー) |
| 課金 (将来) | StoreKit 2 (premium モード解放) |
