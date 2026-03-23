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
MainGui.Opt("+MinSize300x150")
MainGui.OnEvent("Size", Gui_Size)

; A. ツールバー
MainGui.SetFont("s10", "Meiryo")
LinkBtn := MainGui.Add("Button", "x10 y10 w110 h30", "Link Target")
LinkBtn.OnEvent("Click", LinkBtn_Click)

SendModeCombo := MainGui.Add("DropDownList", "x+10 yp w120 Choose1", ["Enter", "Ctrl + Enter", "Shift + Enter", "Paste + Min", "Paste Only"])
SendModeCombo.Text := Settings["SendMode"]
SendModeCombo.OnEvent("Change", (ctrl, *) => Settings["SendMode"] := ctrl.Text)

SettingsBtn := MainGui.Add("Button", "x+10 yp w40 h30", "⚙")
SettingsBtn.OnEvent("Click", ToggleSettings)

MainGui.SetFont("Bold cRed s10")
StatusLabel := MainGui.Add("Text", "x+10 yp+5 w250 vStatus", "Disconnected")

; B. メインエリア
MainGui.SetFont("Norm cDefault s" . Settings["FontSize"], "Meiryo")
MainTextBox := MainGui.Add("Edit", "xm y50 w580 h340 Multi WantReturn vMainTextBox")
MainTextBox.OnEvent("Focus", (*) => Hotkey("^Enter", ExecuteTransfer, "On"))
MainTextBox.OnEvent("LoseFocus", (*) => Hotkey("^Enter", "Off"))

; C. 設定パネル
MainGui.SetFont("s10", "Meiryo")
StGroup := MainGui.Add("GroupBox", "xm y50 w580 h340 Hidden vStGroup", "Settings")
StFontLabel := MainGui.Add("Text", "xp+20 yp+40 Hidden vStFontLabel", "Font Size:")
StFontDec := MainGui.Add("Button", "x+10 yp-5 w30 h25 Hidden vStFontDec", "-")
StFontVal := MainGui.Add("Text", "x+5 yp+5 w30 Center Hidden vStFontVal", Settings["FontSize"])
StFontInc := MainGui.Add("Button", "x+5 yp-5 w30 h25 Hidden vStFontInc", "+")
StFontDec.OnEvent("Click", (*) => ChangeFontSize(-1))
StFontInc.OnEvent("Click", (*) => ChangeFontSize(1))

StLogCheck := MainGui.Add("CheckBox", "x20 y+20 Hidden vStLogCheck", "Save Log")
StLogCheck.Value := Settings["SaveLog"]
StLogCheck.OnEvent("Click", (ctrl, *) => Settings["SaveLog"] := ctrl.Value)

StLogDirTxt := MainGui.Add("Edit", "x20 y+10 w350 ReadOnly Hidden vStLogDirTxt", Settings["LogDir"])
StLogDirBtn := MainGui.Add("Button", "x+5 yp-2 w80 h28 Hidden vStLogDirBtn", "Browse...")
StLogDirBtn.OnEvent("Click", SelectLogDir)

StOpenDir := MainGui.Add("Button", "x20 y+20 w150 h30 Hidden vStOpenDir", "Open Log Folder")
StOpenDir.OnEvent("Click", (*) => Run(Settings["LogDir"]))
StViewLog := MainGui.Add("Button", "x+10 yp w150 h30 Hidden vStViewLog", "View Latest Log")
StViewLog.OnEvent("Click", OpenLatestLog)

MainGui.OnEvent("Close", SaveAndExit)
MainGui.Show("w600 h450")

; ==============================================================================
; 3. 機能ロジック
; ==============================================================================

Gui_Size(thisGui, minMax, width, height) {
    if (minMax = -1) {
        return
    }
    MainTextBox.Move(, , width - 20, height - 60)
    StGroup.Move(, , width - 20, height - 60)
}

LinkBtn_Click(*) {
    global IsLinking
    if (IsLinking) {
        CancelLinking()
    } else {
        StartLinking()
    }
}

StartLinking() {
    global IsLinking := true
    LinkBtn.Text := "Waiting..."
    StatusLabel.SetFont("Bold cFF8C00")
    StatusLabel.Value := "Activate Target Window..."
    global StartTime := A_TickCount
    SetTimer(CheckActiveWindow, 100)
}

CancelLinking(msg := "Cancelled") {
    global IsLinking := false
    SetTimer(CheckActiveWindow, 0)
    LinkBtn.Text := "Link Target"
    StatusLabel.SetFont("Bold cRed")
    StatusLabel.Value := msg
}

CheckActiveWindow() {
    currentHWND := WinActive("A")
    if (currentHWND != 0 && currentHWND != MainGui.Hwnd) {
        SetTimer(CheckActiveWindow, 0)
        global IsLinking := false
        global TargetHWND := currentHWND
        global TargetProcess := WinGetProcessName("ahk_id " . TargetHWND)
        LinkBtn.Text := "Relink"
        StatusLabel.SetFont("Bold cGreen")
        StatusLabel.Value := "Linked: " . TargetProcess
        WinActivate("ahk_id " . MainGui.Hwnd)
        MainTextBox.Focus()
    } else if (A_TickCount - StartTime > 10000) {
        CancelLinking("Timeout")
    }
}

ChangeFontSize(delta) {
    Settings["FontSize"] := Settings["FontSize"] + delta
    if (Settings["FontSize"] < 8) {
        Settings["FontSize"] := 8
    }
    if (Settings["FontSize"] > 40) {
        Settings["FontSize"] := 40
    }
    StFontVal.Value := Settings["FontSize"]
    MainTextBox.SetFont("s" . Settings["FontSize"])
}

SelectLogDir(*) {
    selDir := DirSelect("*" . Settings["LogDir"], 3, "Select Log Directory")
    if (selDir != "") {
        Settings["LogDir"] := selDir
        StLogDirTxt.Value := selDir
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

ExecuteTransfer(*) {
    text := Trim(MainTextBox.Value)
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
        MainTextBox.Value := ""
        MainTextBox.Focus()
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

ToggleSettings(*) {
    global IsSettingsVisible := !IsSettingsVisible
    show := IsSettingsVisible
    MainTextBox.Visible := !show
    ctrls := ["StGroup", "StFontLabel", "StFontDec", "StFontVal", "StFontInc",
        "StLogCheck", "StLogDirTxt", "StLogDirBtn", "StOpenDir", "StViewLog"]
    for name in ctrls {
        MainGui[name].Visible := show
    }
    SettingsBtn.Text := show ? "🔙" : "⚙"
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
        WinActivate()
        MainTextBox.Focus()
    }
}