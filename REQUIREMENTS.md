# Prompt Linker 要件定義書

## 1. アプリケーション概要
「Prompt Linker」は、ユーザーが入力したテキストを、指定したターゲットウィンドウに自動的に「貼り付け＋送信」するためのブリッジツールである。主にLLM（ChatGPT, Claude, GeminiCLI等）へのプロンプト入力を効率化することを目的とする。

### 1.1 開発・動作環境
- **ターゲットOS**: Windows 10 (必須)
- **非対応**: Mac, Linux 等の Windows 以外の OS への移植は考慮しない（Win32 API に強く依存するため）。
- **UI制約**: Windows 11 専用の UI 機能（Mica 素材、特定の WinUI 3 スタイルなど）は避け、Windows 10 で正常に動作・表示される標準的かつモダンなデザインを採用すること。

---

## 2. ユーザーインターフェース (UI) 仕様

### 2.1 メインウィンドウ構成
- **全体設定**: 
    - 常に最前面表示 (`Topmost="True"`)
    - サイズ: 幅600px、高さ450px（最小サイズ: 300x150）
    - タイトルバー: アイコンとタイトルを表示（OS 標準のタイトルバーに近い挙動を推奨）

#### A. ツールバー (上部)
1. **Link ボタン (`LinkBtn`)**:
    - 初期状態: "Link Target" (Icon: リンク/鎖のシンボル。Fluent System Icons の `Link20` 相当)
    - 待機中: "Waiting..." (外観変更: 背景色を警告色/黄色系に変更)
    - リンク完了後: "Relink" (Icon: 同上)
2. **送信モード選択 (`SendModeCombo`)**:
    - ドロップダウン形式。以下の5モードを選択可能：
        - `Enter`: 貼り付け後にEnter
        - `Ctrl + Enter`: 貼り付け後にCtrl+Enter
        - `Shift + Enter`: 貼り付け後にShift+Enter
        - `Paste + Min`: 貼り付け後にアプリを最小化（Enterは送らない）
        - `Paste Only`: 貼り付けのみ（Enterは送らない）
3. **設定ボタン (`SettingsBtn`)**:
    - 歯車アイコン (Icon: 設定/歯車のシンボル。Fluent System Icons の `Settings20` 相当)。メイン入力欄と設定パネルの表示を切り替える。
4. **ステータスラベル (`StatusLabel`)**:
    - 非接続時: "Disconnected" (赤色、太字推奨)
    - 接続完了時: "Linked: [プロセス名]" (緑色、太字推奨)

#### B. メインエリア (中央〜下部)
1. **入力テキストエリア (`MainTextBox`)**:
    - 複数行入力可能 (`AcceptsReturn="True"`)
    - 折り返しあり (`TextWrapping="Wrap"`)
    - フォント: `Meiryo` (推奨), 初期サイズ 14px
    - コンテキストメニュー: Cut, Copy, Paste, Select All (Windows 標準の操作感)
2. **設定パネル (`SettingsPanel`)**: (設定ボタンで切替表示)
    - **Font Size**: `-`ボタン / 現在値ラベル / `+`ボタン。
    - **Save Log**: トグルスイッチ（またはチェックボックス）。
    - **Log Dir**: 読み取り専用テキストボックス + フォルダ選択ボタン（フォルダブラウザダイアログを呼び出す）。
    - **アクションボタン**:
        - "Open Folder": ログフォルダをエクスプローラーで開く。
        - "View Latest Log": 本日のログファイルをメモ帳等で開く。

---

## 3. 機能仕様詳細

### 3.1 ターゲットリンク・ロジック
1. ユーザーが `LinkBtn` をクリック。
2. 100ms間隔で `GetForegroundWindow` (Win32 API) を監視するタイマーを起動（最大10秒）。
3. 「自分以外のウィンドウ」がアクティブになった瞬間、そのウィンドウハンドル (HWND) をターゲットとして保持する。
4. ターゲットのプロセス名を取得し、UIに反映する。

### 3.2 テキスト送信プロセス (`ExecuteTransfer`)
実行トリガー: `MainTextBox` 上での `Ctrl + Enter` 入力、または特定の送信操作。
1. **前処理**: 入力テキストを取得（前後の空白削除）。内容が空なら中断。
2. **履歴保存**: `SaveLog` が有効なら、指定ディレクトリの `history_yyyy-MM-dd.txt` に追記。
3. **クリップボード**: テキストをクリップボードにセット。
4. **ウィンドウ操作 (Win32 API)**: 
    - ターゲットウィンドウが最小化されている場合は復元 (`ShowWindow` SW_RESTORE)。
    - ターゲットウィンドウを最前面へ移動しフォーカスを当てる (`SetForegroundWindow`)。
5. **キー送信 (シミュレーション)**: 
    - 200ms待機（フォーカス遷移の安定化のため）。
    - `Ctrl + V` を送信。
    - `PasteDelay` (デフォルト400ms) 待機。
    - モードに応じた完了キー（`{ENTER}`, `^{ENTER}`, `+{ENTER}` 等）を送信。
6. **後処理**:
    - 150ms待機。
    - `Paste + Min` モードなら自ウィンドウを最小化。
    - それ以外なら自ウィンドウにフォーカスを戻し、テキストエリアをクリアして即座に次の入力に備える。

### 3.3 グローバルホットキー
- `Ctrl + Alt + L` (デフォルト) により、アプリが非アクティブや最小化状態であっても、最前面に呼び出し、フォーカスを当てる。(`RegisterHotKey` API を使用)

---

## 4. データ・設定仕様

### 4.1 設定ファイル (`config.json`)
アプリ実行ディレクトリに保存。以下の項目を保持：
- `FontSize`: 整数 (デフォルト: 14)
- `SaveLog`: 真偽値 (デフォルト: true)
- `LogDir`: 文字列 (デフォルト: "logs")
- `SendMode`: 文字列 ("Enter", "Ctrl + Enter", etc.)
- `HotKeyModifiers`: 整数 (デフォルト: 3 ※Ctrl+Alt)
- `HotKeyKey`: 整数 (デフォルト: 0x4C ※'L'キー)
- `PasteDelay`: 整数 (ミリ秒、デフォルト: 400)

---

## 5. 技術的制約と依存関係 (Windows 10 専用)

### 5.1 Win32 API 依存
移植先でも以下の API 呼び出し（または同等のラッパー）が必須となる：
- `GetForegroundWindow`: アクティブウィンドウのハンドル取得
- `SetForegroundWindow`: 指定ウィンドウへのフォーカス移動
- `IsWindow` / `IsIconic` / `ShowWindow`: ウィンドウの存在確認と表示状態の操作
- `RegisterHotKey` / `UnregisterHotKey`: OS 全域でのホットキー監視
- `GetWindowThreadProcessId`: ウィンドウからプロセスIDを特定

### 5.2 キー入力シミュレーション
- `SendInput` または `keybd_event` を使用して、信頼性の高いキー入力を実現すること。クリップボード経由の貼り付け (`Ctrl+V`) を基本とする。

### 5.3 ログ形式
- ファイル名: `history_yyyy-MM-dd.txt`
- 文字コード: UTF-8（Windows 10 のメモ帳等で閲覧可能な形式）
- 追記フォーマット: `[HH:mm:ss]\r\n{本文}\r\n------------------------------\r\n`
