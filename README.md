# Prompt Linker

`Prompt Linker` は、AIチャット（ChatGPT, Claude, Gemini等）などで作成したプロンプトを、ターゲットとなるアプリケーションの入力欄へ素早く転送・送信するための AutoHotkey 製ユーティリティツールです。

WebView2 を利用したモダンなUIを備え、プロンプトの編集から送信までを一貫してサポートします。

## 主な機能

- **ターゲットウィンドウへの転送**: 任意のウィンドウをターゲットとしてロックし、テキストを一括送信します。
- **WebView2 ベースのUI**: HTML/CSS/JS を使用したカスタマイズ性の高いインターフェース。
- **ログ保存機能**: 送信したプロンプトを日付ごとのテキストファイルとして自動保存します。
- **ウィンドウ位置保存**: プリセット機能により、メインウィンドウの位置とサイズを素早く復元できます。
- **ポータブル動作**: 書き込み権限のあるディレクトリでは、実行ファイルと同じ場所に設定とログを保存します。

## 使い方

1. `PromptLinker.exe` を実行します。
2. 「Link Target」ボタンを押し、プロンプトを送信したいターゲットウィンドウをクリックします。
3. テキストエリアにプロンプトを入力し、`Ctrl + Enter` (デフォルト) で送信します。

## 開発・ビルド方法

本プロジェクトをソースからビルドするには以下の環境が必要です。

- [AutoHotkey v2.0+](https://www.autohotkey.com/)
- [Ahk2Exe](https://www.autohotkey.com/docs/v2/howto/Compile.htm) (コンパイル用)

### 手順
1. リポジトリをクローンまたはダウンロードします。
2. `PromptLinker.ahk` を Ahk2Exe でコンパイル、または直接実行します。

## 使用している外部ライブラリ

本プロジェクトでは、AutoHotkey コミュニティの素晴らしいライブラリを使用させていただいています。

- **WebView2.ahk** (by [thqby](https://github.com/thqby/WebView2.ahk))
  - Microsoft Edge WebView2 コントロールを AutoHotkey から操作するためのライブラリです。
- **JXON.ahk** (by [cocob](https://github.com/cocob/AutoHotkey-JSON), v2 adapted by community)
  - JSON データのパースおよび生成に使用しています。
- **Promise.ahk** / **ComVar.ahk**
  - 非同期処理や COM オブジェクトの操作を効率化するために使用しています。

## 免責事項・ライセンス

本ソフトウェアは現状有姿で提供されます。使用に伴ういかなる損害についても責任を負いかねます。
ソースコードの利用については、各外部ライブラリのライセンスに従ってください。
