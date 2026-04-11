# Prompt Linker

WebView2 (HTML/CSS/JS) を使用した AutoHotkey v2 製のテキスト転送ツールです。
任意のテキスト（プロンプト等）を、指定したウィンドウへホットキーや右クリックメニューから転送し、
Enterなどのアクションを自動実行します。

## 🚀 主な機能

- **ターゲット切り替え**: ターゲットとなるアプリを選択し、テキストをクリップボード経由で転送。
- **プリセット機能**: ウィンドウ状態などをプリセットとして保存し呼び出す。
- **単一EXE化対応**: 全てのリソースを内包したポータブルな実行ファイルとしてビルド可能。

## 🛠 動作環境

- **OS**: Windows 10 / 11
- **Runtime**: [AutoHotkey v2.0+](https://www.autohotkey.com/)
- **WebView2**: Microsoft Edge WebView2 ランタイム（通常は標準インストール済み）

## 📂 プロジェクト構成

```text
PromptLinker_AHK/
├── PromptLinker.ahk      # メインエントリーポイント（リソース展開とUI起動）
├── ui.html               # メインUI（HTMLテンプレート）
├── lib/                  # AHK ライブラリ
│   ├── AppLogic.ahk      # 転送処理等のコアロジック
│   ├── SettingsManager.ahk # 設定管理
│   ├── WindowManager.ahk # ウィンドウ操作（アクティブ化等）
│   ├── Hotkeys.ahk       # ホットキー登録
│   ├── ExportHandler.ahk # データエクスポート
│   ├── _JXON.ahk         # JSON処理 (Community Library)
│   ├── ComVar.ahk        # COM VARIANT構造体操作 (Community Library)
│   ├── Promise.ahk       # 非同期処理 (Community Library)
│   └── WebView2/         # WebView2 連携ライブラリ
│       ├── WebView2.ahk  # WebView2 ラッパー (Community Library)
│       └── [32bit/64bit] # WebView2Loader.dll
├── assets/               # UI用静的リソース
│   ├── css/              # スタイルシート (theme, layout, components等)
│   ├── js/               # フロントエンドJavaScript (view/editor manager等)
│   └── icons/            # SVGアイコン素材
└── docs/                 # ユーザーマニュアル
    └── index.html        # 詳細な操作説明書
```

## 🙏 外部ライブラリへの謝辞 (Credits)

本プロジェクトの開発にあたり、以下の素晴らしい AutoHotkey コミュニティのライブラリを使用させていただいております。

- **[WebView2.ahk](https://github.com/thqby/ahk2_lib/tree/master/WebView2)**, **[Promise.ahk](https://github.com/thqby/ahk2_lib/blob/master/Promise.ahk)**, **[ComVar.ahk](https://github.com/thqby/ahk2_lib/blob/master/ComVar.ahk)**
  - Author: [thqby](https://github.com/thqby)
  - License: [MIT](https://github.com/thqby/ahk2_lib/blob/master/LICENSE)
  - 役割: WebView2 コントロールの制御、非同期処理の実現、COM操作。
- **[_JXON.ahk](https://github.com/cocobelgica/AutoHotkey-JSON)** (v2 port)
  - Original Author: [cocobelgica](https://github.com/cocobelgica)
  - License: [Unlicense](https://github.com/cocobelgica/AutoHotkey-JSON/blob/master/LICENSE)
  - 役割: 設定データの JSON 形式による保存・読み込み。

- **[Lucide Icons](https://lucide.dev/)**
  - License: [ISC](https://github.com/lucide-icons/lucide/blob/main/LICENSE)
  - 役割: UIに使用されている各種SVGアイコン。

## 🔨 開発とビルド

### ソースコードからの実行
`PromptLinker.ahk` を AutoHotkey v2 で実行してください。

### コンパイル (EXE化)
[Ahk2Exe](https://github.com/AutoHotkey/Ahk2Exe/releases) を使用して、`PromptLinker.ahk` をコンパイルしてください。
`FileInstall` 命令により、必要な全てのリソースが単一の実行ファイルにパックされます。

## 📖 マニュアル

詳細な使用方法については、[オンラインマニュアル](https://2ndillness.github.io/PromptLinker_AHK/) を参照してください。

## ⚠️ 免責事項・ライセンス

### 免責事項
本アプリの使用によって生じた、いかなる損害についても作者は一切の責任を負いません。自己責任でご利用ください。

### ライセンス
本アプリケーションのソースコードは MIT License の下で公開されています。

ただし、配布しているコンパイル済み実行ファイル（.exe）には
AutoHotkey v2（GPL v2）が組み込まれています。

そのため、実行ファイル部分には GPL v2 が適用されます。
本リポジトリでソースコードを公開することで GPL の要件を満たしています。

- MIT License（本プロジェクトのソースコード）
- GPL v2（AutoHotkey ランタイム部分）

