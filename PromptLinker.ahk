#Include Lib\WebView2\WebView2.ahk
#Include Lib\JSON.ahk
#Include Lib\AppLogic.ahk
#Include Lib\WindowControl.ahk
#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; 初期設定・変数定義
; ==============================================================================
global AppName := "Prompt Linker"
global ConfigFile := A_ScriptDir "\config.json"
global TargetHWND := 0
global TargetProcess := ""
; global IsSettingsVisible := false
global IsLinking := false

; デフォルト設定
global Settings := Map(
    "FontSize", 14,
    "SaveLog", true,
    "LogDir", A_ScriptDir "\logs",
    "SendMode", "Enter",
    "PasteDelay", 400
)

; 設定の読み込み
LoadSettings()

if !DirExist(Settings["LogDir"]) {
    DirCreate(Settings["LogDir"])
}

; ==============================================================================
; GUIの構築
; ==============================================================================
MainGui := Gui("+AlwaysOnTop -Caption", AppName) ; 太い枠を消すためResizeを削除
MainGui.BackColor := "1e1e1e" ; 背景色をHTMLと合わせる
; MainGui.Opt("+MinSize300x150") ; 自前リサイズ時はGuiの制限が効かないためコード内で制御
MainGui.OnEvent("Size", Gui_Size)
MainGui.OnEvent("Close", SaveAndExit)

; WebView2 コントロールの作成
global wvc := ""
try {
    ; DLLのパスを明示的に解決する
    subDir := (A_PtrSize = 8 ? "64bit" : "32bit")
    dllPath := ""

    ; 探索パスリスト
    searchPaths := [
        A_ScriptDir "\Lib\WebView2\" subDir "\WebView2Loader.dll",
        A_ScriptDir "\WebView2\" subDir "\WebView2Loader.dll"
    ]
    for path in searchPaths {
        if FileExist(path)
            dllPath := path
    }

    if (dllPath == "") {
        dllPath := A_ScriptDir "\Lib\WebView2\" subDir "\WebView2Loader.dll"
        throw Error("WebView2Loader.dll が見つかりません。`nパス: " dllPath)
    }

    ; 明示的なパスを指定してCreate
    wvc := WebView2.Create(MainGui.Hwnd, , , , , , dllPath)
} catch as err {
    MsgBox(
        "WebView2の初期化に失敗しました。`n"
        . err.Message
        . "`n`nLib/WebView2/ フォルダの構成を確認してください。",
        "Error",
        16
    )
    ExitApp
}

; コアオブジェクトを取得し、設定を行う
global wv := wvc.CoreWebView2
wv.Settings.AreDefaultContextMenusEnabled := false ; 右クリックメニューを無効化
wv.Settings.IsZoomControlEnabled := false

; ==============================================================================
; 設定値の注入とHTMLファイルのロード
; ==============================================================================
settingsJson := JSON.Dump(Settings)

; HTMLロード前にJS変数を定義しておく
wv.AddScriptToExecuteOnDocumentCreatedAsync(
    "window.ahkSettings = " . settingsJson . ";"
)

; ui.html をファイルとしてロード (CSS/JSの相対パス解決のため)
htmlPath := "file:///" . StrReplace(A_ScriptDir, "\", "/") . "/ui.html"

; ファイル存在確認
if !FileExist(A_ScriptDir "\ui.html") {
    MsgBox("ui.html が見つかりません。", "Error", 16)
    ExitApp
}

; Navigate を使用してローカルファイルをロード
wv.Navigate(htmlPath)

; イベントハンドラ登録
wv.add_WebMessageReceived(WebView_OnMessage)

MainGui.Show("w600 h450") ; WebViewの準備が整ってからウィンドウを表示
wvc.IsVisible := true     ; WebView2を明示的に可視化
wvc.Fill()                ; ウィンドウサイズに合わせてWebView2を広げる

; ==============================================================================
; 機能ロジック
; ==============================================================================

Gui_Size(thisGui, minMax, width, height) {
    if (minMax = -1) {
        return
    }
    ; WebView2コントローラーをウィンドウサイズに合わせる
    if (wvc)
        wvc.Fill()
}

WebView_OnMessage(sender, args) {
    msg := args.TryGetWebMessageAsString()

    if (msg == "toggleLink") {
        if (IsLinking)
            CancelLinking()
        else
            StartLinking()

    } else if (SubStr(msg, 1, 9) == "transfer:") {
        ExecuteTransfer(SubStr(msg, 10))

    } else if (SubStr(msg, 1, 14) == "updateSetting:") {
        parts := StrSplit(msg, ":")
        if (parts.Length >= 3) {
            key := parts[2]
            val := parts[3]
            if (key == "SaveLog")
                Settings[key] := (val == "1")
            else
                Settings[key] := val
        }

    } else if (SubStr(msg, 1, 15) == "changeFontSize:") {
        delta := Integer(SubStr(msg, 16))
        ChangeFontSize(delta)

    } else if (msg == "selectLogDir") {
        SelectLogDir()
    } else if (msg == "openLogDir") {
        Run(Settings["LogDir"])
    } else if (msg == "viewLatestLog") {
        OpenLatestLog()

        ; ウィンドウ制御系メッセージの処理
    } else if (msg == "dragWindow") {
        DllCall("User32\ReleaseCapture") ; WebViewからマウスキャプチャを解放
        PostMessage(0xA1, 2, 0, MainGui.Hwnd) ; WM_NCLBUTTONDOWN
    } else if (msg == "toggleMax") {
        if (WinGetMinMax(MainGui.Hwnd) == 1)
            MainGui.Restore()
        else
            MainGui.Maximize()
    } else if (msg == "minWindow") {
        MainGui.Minimize()
    } else if (msg == "closeWindow") {
        SaveAndExit()
    } else if (msg == "resizeWindow") {
        ; HTML側のグリップがドラッグされたらリサイズモード(右下)を開始
        StartResizing()
    }
}