#Include Lib\WebView2\WebView2.ahk
#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; 1. 初期設定・変数定義
; ==============================================================================
global AppName := "Prompt Linker"
global ConfigFile := A_ScriptDir "\config.json"
global TargetHWND := 0
global TargetProcess := ""
global IsSettingsVisible := false
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
; 2. GUIの構築
; ==============================================================================
MainGui := Gui("+AlwaysOnTop +Resize -Caption", AppName) ; -Captionでタイトルバー削除
MainGui.BackColor := "1e1e1e" ; 背景色をHTMLと合わせる
MainGui.Opt("+MinSize400x300")
MainGui.OnEvent("Size", Gui_Size)
MainGui.OnEvent("Close", SaveAndExit)

; WebView2 コントロールの作成
global wvc := ""
try {
    ; DLLのパスを明示的に解決する
    subDir := (A_PtrSize = 8 ? "64bit" : "32bit")
    dllPath := ""

    ; 探索パスリスト
    searchPaths := [A_ScriptDir "\Lib\WebView2\" subDir "\WebView2Loader.dll", A_ScriptDir "\WebView2\" subDir "\WebView2Loader.dll"]
    for path in searchPaths {
        if FileExist(path)
            dllPath := path
    }

    if (dllPath == "") {
        dllPath := A_ScriptDir "\Lib\WebView2\" subDir "\WebView2Loader.dll" ; エラーメッセージ用にデフォルトを設定
        throw Error("WebView2Loader.dll が見つかりません。`nパス: " dllPath)
    }

    ; 明示的なパスを指定してCreate
    wvc := WebView2.Create(MainGui.Hwnd, , , , , , dllPath)
} catch as err {
    MsgBox("WebView2の初期化に失敗しました。`n" err.Message "`n`nLib/WebView2/ フォルダの構成を確認してください。", "Error", 16)
    ExitApp
}

; コアオブジェクトを取得し、設定を行う
global wv := wvc.CoreWebView2
wv.Settings.AreDefaultContextMenusEnabled := false ; 右クリックメニューを無効化
wv.Settings.IsZoomControlEnabled := false

; ==============================================================================
; 設定値の注入とHTMLファイルのロード
; ==============================================================================
settingsJson := "{"
settingsJson .= "SendMode: '" . Settings["SendMode"] . "',"
settingsJson .= "FontSize: " . Settings["FontSize"] . ","
settingsJson .= "SaveLog: " . (Settings["SaveLog"] ? "true" : "false") . ","
settingsJson .= "LogDir: '" . StrReplace(Settings["LogDir"], "\", "\\") . "'"
settingsJson .= "}"

; HTMLロード前にJS変数を定義しておく
wv.AddScriptToExecuteOnDocumentCreatedAsync("window.ahkSettings = " . settingsJson . ";")

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
; 3. 機能ロジック
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
    }
}

StartLinking() {
    global IsLinking := true
    ; HTML側の表示を更新
    wv.ExecuteScriptAsync("updateBtn('Waiting...'); updateStatus('Activate Target Window...', '#FF8C00');")

    global StartTime := A_TickCount
    SetTimer(CheckActiveWindow, 100)
}

CancelLinking(msg := "Cancelled") {
    global IsLinking := false
    SetTimer(CheckActiveWindow, 0)

    color := (msg == "Cancelled" || msg == "Timeout") ? "#cc0000" : "#28a745"
    wv.ExecuteScriptAsync("updateBtn('Link Target'); updateStatus('" . msg . "', '" . color . "');")
}

CheckActiveWindow() {
    currentHWND := WinActive("A")
    if (currentHWND != 0 && currentHWND != MainGui.Hwnd) {
        SetTimer(CheckActiveWindow, 0)
        global IsLinking := false
        global TargetHWND := currentHWND
        global TargetProcess := WinGetProcessName("ahk_id " . TargetHWND)

        ; リンク成功時の表示更新
        statusMsg := "Linked: " . TargetProcess
        wv.ExecuteScriptAsync("updateBtn('Relink'); updateStatus('" . statusMsg . "', '#28a745');")

        WinActivate("ahk_id " . MainGui.Hwnd)

        ; テキストエリアにフォーカスを戻す(JS経由)
        wv.ExecuteScriptAsync("document.getElementById('main-textarea').focus();")
    } else if (A_TickCount - StartTime > 10000) {
        CancelLinking("Timeout")
    }
}

ChangeFontSize(delta) {
    newSize := Settings["FontSize"] + delta
    if (newSize < 8)
        newSize := 8
    if (newSize > 40)
        newSize := 40
    Settings["FontSize"] := newSize
    wv.ExecuteScriptAsync("updateFontSizeDisplay(" . newSize . ");")
}

SelectLogDir(*) {
    ; ダイアログが背後に隠れないように、一時的にAlwaysOnTopを解除
    MainGui.Opt("-AlwaysOnTop")
    ; モダンなフォルダ選択ダイアログを使用
    selDir := FileSelect("D", "*" . Settings["LogDir"], "Select Log Directory")
    ; AlwaysOnTopを再設定
    MainGui.Opt("+AlwaysOnTop")
    if (selDir != "") {
        Settings["LogDir"] := selDir
        ; JS側の表示を更新（バックスラッシュをエスケープして渡す）
        escapedPath := StrReplace(selDir, "\", "\\")
        wv.ExecuteScriptAsync("updateLogDirDisplay('" . escapedPath . "');")
    }
}

OpenLatestLog(*) {
    logFile := Settings["LogDir"] . "\history_" . A_YYYY . "-" . A_MM . "-" . A_DD . ".txt"
    if FileExist(logFile) {
        Run(logFile)
    } else {
        MsgBox("No log file found for today.", AppName)
    }
}

ExecuteTransfer(text) {
    if (text == "" || TargetHWND == 0 || !WinExist("ahk_id " . TargetHWND)) {
        return
    }

    if (Settings["SaveLog"]) {
        SaveToLog(text)
    }

    A_Clipboard := text
    if (WinGetMinMax("ahk_id " . TargetHWND) = -1) {
        WinRestore("ahk_id " . TargetHWND)
    }

    WinActivate("ahk_id " . TargetHWND)
    if (!WinWaitActive("ahk_id " . TargetHWND, , 2)) {
        return
    }

    Sleep(200)
    Send("^v")
    Sleep(Settings["PasteDelay"])

    mode := Settings["SendMode"]
    if (mode == "Enter") {
        Send("{Enter}")
    } else if (mode == "Ctrl + Enter") {
        Send("^{Enter}")
    } else if (mode == "Shift + Enter") {
        Send("+{Enter}")
    }

    Sleep(150)
    if (mode == "Paste + Min") {
        WinMinimize("ahk_id " . MainGui.Hwnd)
    } else {
        WinActivate("ahk_id " . MainGui.Hwnd)
        wv.ExecuteScriptAsync("document.getElementById('main-textarea').value = ''; document.getElementById('main-textarea').focus();")
    }
}

SaveToLog(content) {
    if !DirExist(Settings["LogDir"]) {
        DirCreate(Settings["LogDir"])
    }
    fileName := Settings["LogDir"] . "\history_" . A_YYYY . "-" . A_MM . "-" . A_DD . ".txt"
    cleanContent := StrReplace(StrReplace(content, "`r`n", "`n"), "`r", "`n")
    cleanContent := StrReplace(cleanContent, "`n", "`r`n")
    logEntry := "[" . FormatTime(, "HH:mm:ss") . "]`r`n" . cleanContent . "`r`n------------------------------`r`n"
    FileAppend(logEntry, fileName, "UTF-8")
}

SaveAndExit(*) {
    try {
        jsonStr := '{' . '`r`n'
        jsonStr .= '  "FontSize": ' . Settings["FontSize"] . ',`r`n'
        jsonStr .= '  "SaveLog": ' . (Settings["SaveLog"] ? "true" : "false") . ',`r`n'
        jsonStr .= '  "LogDir": "' . StrReplace(Settings["LogDir"], "\", "\\") . '",`r`n'
        jsonStr .= '  "SendMode": "' . Settings["SendMode"] . '",`r`n'
        jsonStr .= '  "PasteDelay": ' . Settings["PasteDelay"] . '`r`n'
        jsonStr .= '}'

        if FileExist(ConfigFile) {
            FileDelete(ConfigFile)
        }
        FileAppend(jsonStr, ConfigFile, "UTF-8")
    }
    ExitApp()
}

LoadSettings() {
    if !FileExist(ConfigFile) {
        return
    }

    try {
        raw := FileRead(ConfigFile, "UTF-8")
        if RegExMatch(raw, '"FontSize":\s*(\d+)', &m) {
            Settings["FontSize"] := Number(m[1])
        }
        if RegExMatch(raw, '"SaveLog":\s*(true|false)', &m) {
            Settings["SaveLog"] := (m[1] = "true")
        }
        if RegExMatch(raw, '"LogDir":\s*"(.*?)"', &m) {
            Settings["LogDir"] := StrReplace(m[1], "\\", "\")
        }
        if RegExMatch(raw, '"SendMode":\s*"(.*?)"', &m) {
            Settings["SendMode"] := m[1]
        }
        if RegExMatch(raw, '"PasteDelay":\s*(\d+)', &m) {
            Settings["PasteDelay"] := Number(m[1])
        }
    }
}

^!l:: {
    if WinExist("ahk_id " . MainGui.Hwnd) {
        WinActivate("ahk_id " . MainGui.Hwnd)
    }
}