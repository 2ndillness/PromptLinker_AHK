#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; 初期設定・変数定義 (Includeより先に宣言してグローバルスコープを確立)
; ==============================================================================
global AppName := "Prompt Linker"
global ConfigFile := A_ScriptDir "\config.json"
global TargetHWND := 0
global TargetProcess := ""
global IsLinking := false
global Settings := Map(
    "FontSize", 14,
    "SaveLog", true,
    "LogDir", A_ScriptDir "\logs",
    "SendMode", "Enter",
    "PasteDelay", 400
)
global MainGui := ""
global wvc := ""
global wv := ""

; ==============================================================================
; コールバック関数 (Includeより先に定義して他ファイルから参照可能にする)
; ==============================================================================

Gui_Size(thisGui, minMax, width, height) {
    global wvc, wv
    if (minMax == -1) {
        return
    }

    ; WebView2のリサイズ
    if (IsSet(wvc) && wvc)
        wvc.Fill()

    ; UIの最大化ボタンのアイコン更新 (1: 最大化, 0: 通常)
    if (IsSet(wv) && wv) {
        isMax := (minMax == 1 ? "true" : "false")
        wv.ExecuteScript("if(typeof updateMaxIcon === 'function') updateMaxIcon(" . isMax . ");")
    }
}

; ==============================================================================
; ライブラリのインクルード
; ==============================================================================
#Include Lib\WebView2\WebView2.ahk
#Include Lib\JSON.ahk
#Include Lib\AppLogic.ahk
#Include Lib\WindowControl.ahk

; ==============================================================================
; アプリケーションの初期化
; ==============================================================================
LoadSettings()

if !DirExist(Settings["LogDir"]) {
    DirCreate(Settings["LogDir"])
}

; GUIの構築
MainGui := Gui("+AlwaysOnTop -Caption", AppName)
MainGui.BackColor := "1e1e1e"
MainGui.OnEvent("Size", Gui_Size)
MainGui.OnEvent("Close", SaveAndExit)

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
wv := wvc.CoreWebView2
wv.Settings.AreDefaultContextMenusEnabled := false
wv.Settings.IsZoomControlEnabled := false

; 設定値の注入
settingsJson := JSON.Dump(Settings)
wv.AddScriptToExecuteOnDocumentCreatedAsync(
    "window.ahkSettings = " . settingsJson . ";"
)

; ui.html をロード
htmlPath := "file:///" . StrReplace(A_ScriptDir, "\", "/") . "/ui.html"
if !FileExist(A_ScriptDir "\ui.html") {
    MsgBox("ui.html が見つかりません。", "Error", 16)
    ExitApp
}
wv.Navigate(htmlPath)

; イベントハンドラ登録
wv.add_WebMessageReceived(WebView_OnMessage)

MainGui.Show("w600 h450")
wvc.IsVisible := true
wvc.Fill()

; ==============================================================================
; メインスレッド用関数
; ==============================================================================

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
    } else if (msg == "dragWindow") {
        DllCall("User32\ReleaseCapture")
        PostMessage(0xA1, 2, 0, MainGui.Hwnd)
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
        StartResizing()
    }
}