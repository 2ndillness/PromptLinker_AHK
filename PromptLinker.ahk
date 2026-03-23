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
MainGui := Gui("+AlwaysOnTop +Resize", AppName)
MainGui.Opt("+MinSize600x450")
MainGui.OnEvent("Size", Gui_Size)
MainGui.OnEvent("Close", SaveAndExit)
SetWindowAttribute(MainGui) ; ダークモード適用（タイトルバー等）

; WebView2 コントロールの作成
global wvc := ""
try {
    ; DLLのパスを明示的に解決する
    dllDir := A_ScriptDir "\Lib\WebView2\" (A_PtrSize = 8 ? "64bit" : "32bit")
    dllPath := dllDir "\WebView2Loader.dll"

    if !FileExist(dllPath) {
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

; HTMLの読み込み（UIの定義）
htmlContent := GetHtmlContent()
if (htmlContent == "") {
    MsgBox("ui.html の内容が空です。ファイルを正しく保存できているか確認してください。", "Error", 16)
    ExitApp
}
wv.NavigateToString(htmlContent)
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

/**
 * ウィンドウにダークモード属性を適用する
 * Windows 10 (Build 17763以降) / Windows 11 対応
 */
SetWindowAttribute(GuiObj) {
    if (VerCompare(A_OSVersion, "10.0.17763") < 0)
        return

    ; DWMWA_USE_IMMERSIVE_DARK_MODE = 20 (Windows 11, Windows 10 20H1+)
    ; DWMWA_USE_IMMERSIVE_DARK_MODE_BEFORE_20H1 = 19 (Windows 10 older builds)
    attr := 20
    if (VerCompare(A_OSVersion, "10.0.18985") < 0)
        attr := 19

    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", GuiObj.Hwnd, "Int", attr, "Int*", 1, "Int", 4)

    ; コントロールのテーマをExplorerスタイル（ダーク対応）に設定
    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiObj.Hwnd, "Str", "DarkMode_Explorer", "Str", "")
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
    selDir := DirSelect("*" . Settings["LogDir"], 3, "Select Log Directory")
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

; ==============================================================================
; HTML Content (Modern UI Template)
; ==============================================================================
GetHtmlContent() {
    global Settings ; グローバル変数を参照することを明示
    htmlPath := A_ScriptDir "\ui.html"
    if !FileExist(htmlPath) {
        MsgBox("UI definition file not found:`n" htmlPath, "Error", 16)
        ExitApp
    }

    htmlContent := FileRead(htmlPath, "UTF-8")

    ; 現在の設定値をJSONオブジェクトとしてJSに注入する
    settingsJson := "{"
    settingsJson .= "SendMode: '" . Settings["SendMode"] . "',"
    settingsJson .= "FontSize: " . Settings["FontSize"] . ","
    settingsJson .= "SaveLog: " . (Settings["SaveLog"] ? "true" : "false") . ","
    settingsJson .= "LogDir: '" . StrReplace(Settings["LogDir"], "\", "\\") . "'"
    settingsJson .= "}"

    jsInjection := "initSettings(" . settingsJson . ");"

    return StrReplace(htmlContent, "// AHK_SETTINGS_INJECTION_PLACEHOLDER", jsInjection)
}