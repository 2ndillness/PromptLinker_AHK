#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; コンパイラ設定 (Ahk2Exe用)
; ==============================================================================
;@Ahk2Exe-SetMainIcon assets\app_icon.ico
;@Ahk2Exe-SetName Prompt Linker
;@Ahk2Exe-SetVersion 1.0.0

; ==============================================================================
; リソースの展開処理 (単一EXE化用)
; ==============================================================================
global ResDir := A_Temp "\PromptLinker_Resources"
; 古いファイルがあれば一旦削除（終了時のディレイ解消のため、起動時に掃除を行う）
if DirExist(ResDir) {
    try {
        DirDelete(ResDir, 1)
    }
}
if !DirExist(ResDir) {
    DirCreate(ResDir)
}

; サブフォルダの作成
subDirs := ["assets\css", "assets\js", "assets\icons",
    "WebView2\32bit", "WebView2\64bit"]
for d in subDirs {
    if !DirExist(ResDir "\" d)
        DirCreate(ResDir "\" d)
}

; ファイルの展開 (実行時に展開)
FileInstall "ui.html", ResDir "\ui.html", 1
FileInstall "script.js", ResDir "\script.js", 1
FileInstall "style.css", ResDir "\style.css", 1
FileInstall "editor-manager.js", ResDir "\assets\js\editor-manager.js", 1
FileInstall "settings-manager.js", ResDir "\assets\js\settings-manager.js", 1
FileInstall "ui-utils.js", ResDir "\assets\js\ui-utils.js", 1

FileInstall "assets\app_icon.ico", ResDir "\assets\app_icon.ico", 1

FileInstall "assets\css\components.css", ResDir "\assets\css\components.css", 1
FileInstall "assets\css\theme.css", ResDir "\assets\css\theme.css", 1
FileInstall "assets\css\layout.css", ResDir "\assets\css\layout.css", 1
FileInstall "assets\css\forms.css", ResDir "\assets\css\forms.css", 1
FileInstall "assets\css\overlays.css", ResDir "\assets\css\overlays.css", 1

; アイコンファイルの展開
FileInstall "assets\icons\link.svg", ResDir "\assets\icons\link.svg", 1
FileInstall "assets\icons\settings.svg", ResDir "\assets\icons\settings.svg", 1
FileInstall "assets\icons\folder.svg", ResDir "\assets\icons\folder.svg", 1
FileInstall "assets\icons\arrow-left.svg",
    ResDir "\assets\icons\arrow-left.svg", 1
FileInstall "assets\icons\folder-open.svg",
    ResDir "\assets\icons\folder-open.svg", 1
FileInstall "assets\icons\save.svg", ResDir "\assets\icons\save.svg", 1
FileInstall "assets\icons\file-text.svg",
    ResDir "\assets\icons\file-text.svg", 1
FileInstall "assets\icons\help-circle.svg",
    ResDir "\assets\icons\help-circle.svg", 1
FileInstall "assets\icons\chevron-down.svg",
    ResDir "\assets\icons\chevron-down.svg", 1
FileInstall "lib\WebView2\32bit\WebView2Loader.dll",
    ResDir "\WebView2\32bit\WebView2Loader.dll", 1
FileInstall "lib\WebView2\64bit\WebView2Loader.dll",
    ResDir "\WebView2\64bit\WebView2Loader.dll", 1

; ==============================================================================
; 初期設定・変数定義
; ==============================================================================
global AppName := "Prompt Linker"
global DataDir := A_AppData "\" StrReplace(AppName, " ", "_")
global PortableFile := A_ScriptDir "\settings.json"

; 書き込み権限テスト
IsScriptDirWritable() {
    testFile := A_ScriptDir "\.write_test"
    try {
        FileAppend("", testFile)
        FileDelete(testFile)
        return true
    } catch {
        return false
    }
}

; 設定ファイルのパス決定
if FileExist(PortableFile) || IsScriptDirWritable() {
    global SettingsFile := PortableFile
    global UsePortable := true
} else {
    global SettingsFile := DataDir "\settings.json"
    global UsePortable := false
    if !DirExist(DataDir) {
        try {
            DirCreate(DataDir)
        } catch as err {
            MsgBox("データディレクトリ作成失敗: " DataDir "`n" err.Message,
                "Error", 48)
        }
    }
}

global TargetHWND := 0
global IsLinking := false
global IsRecordingHotkey := false
global TargetProcess := ""
global MainGui := ""
global wvc := ""
global wv := ""
global StartTime := 0
global IsToolbarHidden := false

; ターゲットスロット管理
global CurrentSlotIndex := 1
global TargetSlots := [
    { hwnd: 0, exe: "", action: "" },
    { hwnd: 0, exe: "", action: "" },
    { hwnd: 0, exe: "", action: "" }
]

; 設定マップの初期値
global Settings := Map(
    "FontSize", 14,
    "MinimizeOption", false,
    "SaveLog", false,
    "LogDir", (UsePortable ? A_ScriptDir "\logs" : DataDir "\logs"),
    "TargetAction", "Enter",
    "SubmitDelay", 400,
    "FocusHotkey", "^!f",
    "TriggerKey", "Ctrl + Enter",
    "Presets", Map("1", "", "2", "", "3", "")
)

; ==============================================================================
; コールバック関数
; ==============================================================================
Gui_Size(thisGui, minMax, width, height) {
    global wvc
    if (minMax != -1 && IsSet(wvc) && wvc) {
        wvc.Fill()
    }
}

; ==============================================================================
; ライブラリのインクルード
; ==============================================================================
#Include Lib\WebView2\WebView2.ahk
#Include Lib\_JXON.ahk
#Include Lib\SettingsManager.ahk
#Include Lib\WindowManager.ahk
#Include Lib\AppLogic.ahk
#Include Lib\LogHandler.ahk
#Include Lib\Hotkeys.ahk

; ==============================================================================
; アプリケーションの初期化
; ==============================================================================
LoadSettings()

; ログディレクトリの作成
if Settings["SaveLog"] && !DirExist(Settings["LogDir"]) {
    try {
        DirCreate(Settings["LogDir"])
    } catch {
        Settings["LogDir"] := DataDir "\logs"
        if !DirExist(Settings["LogDir"])
            DirCreate(Settings["LogDir"])
    }
}

MainGui := Gui("+AlwaysOnTop +Resize +MinSize500x140", AppName " - Unlinked")
MainGui.BackColor := "1e1e1e"
MainGui.OnEvent("Size", Gui_Size)
MainGui.OnEvent("Close", SaveAndExit)

; フォーカス用ホットキー
SetFocusHotkey(Settings["FocusHotkey"])

; プリセット用ホットキー (当アプリ内のみ)
HotIf((*) => WinActive("ahk_id " MainGui.Hwnd) && !IsRecordingHotkey)
Loop 3 {
    Hotkey("!" A_Index, (hk) => ApplyWindowPreset(Integer(SubStr(hk, -1))))
    Hotkey("+!" A_Index, (hk) => SaveWindowPreset(Integer(SubStr(hk, -1))))
}
Hotkey("!t", (*) => wv.PostWebMessageAsString("toggleToolbar"))

; アプリ操作用ショートカット
Hotkey("!l", (*) => (IsLinking ? CancelLinking() : StartLinking()))
Hotkey("!j", OpenSettings)
Hotkey("!d", OpenLogDir)
Hotkey("!o", OpenLatestLog)

; 表示切り替え (ビュー巡回)
Hotkey("^Tab", (*) => wv.ExecuteScriptAsync("rotateView(1)"))
Hotkey("^+Tab", (*) => wv.ExecuteScriptAsync("rotateView(-1)"))

; ターゲットスロット切り替え
Hotkey("^1", (*) => SwitchTargetSlot(1))
Hotkey("^2", (*) => SwitchTargetSlot(2))
Hotkey("^3", (*) => SwitchTargetSlot(3))

; ビューダイレクト指定
Hotkey("^,", (*) => wv.ExecuteScriptAsync("toggleSetView(true)"))
Hotkey("F1", (*) => wv.ExecuteScriptAsync("toggleHelp()"))

; フォントサイズ変更
Hotkey("!-", (*) => ChangeFontSize(-1))
Hotkey("!=", (*) => ChangeFontSize(1))

; 設定トグル
Hotkey("!s", (*) => ToggleSetting("SaveLog"))
Hotkey("!m", (*) => ToggleSetting("MinimizeOption"))
Hotkey("!k", ToggleTriggerKey)

; TargetAction 変更
Hotkey("!p", (*) => UpdateTargetAction("Paste Only"))
Hotkey("!Enter", (*) => UpdateTargetAction("Enter"))
Hotkey("^!Enter", (*) => UpdateTargetAction("Ctrl + Enter"))
Hotkey("+!Enter", (*) => UpdateTargetAction("Shift + Enter"))
HotIf()

try {
    sub := (A_PtrSize = 8 ? "64bit" : "32bit")
    dll := ResDir "\WebView2\" sub "\WebView2Loader.dll"
    if !FileExist(dll)
        throw Error("WebView2Loader.dll 欠損: " dll)
    wvc := WebView2.Create(MainGui.Hwnd, , , , , , dll)
} catch as err {
    MsgBox("WebView2初期化失敗:`n" err.Message, "Error", 4096)
    ExitApp
}

wv := wvc.CoreWebView2
try {
    wvc.DefaultBackgroundColor := 0
} catch {
}

wv.Settings.AreDefaultContextMenusEnabled := false
wv.Settings.IsZoomControlEnabled := false

wv.AddScriptToExecuteOnDocumentCreatedAsync(
    "window.ahkSettings = " Jxon_Dump(Settings) ";"
)

; 展開フォルダ内のHTMLをロード
uPath := "file:///" StrReplace(ResDir, "\", "/") "/ui.html"
wv.add_WebMessageReceived(OnWebMsg)
wv.add_PermissionRequested(OnPermissionRequested)
wv.add_NavigationCompleted(OnNavigationCompleted)
wv.Navigate(uPath)

; ダークモード適用
DwmSetDarkMode(hwnd) {
    val := Buffer(4, 0)
    NumPut("Int", 1, val)
    DllCall("Dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 20,
        "Ptr", val, "Int", 4)
}
DwmSetDarkMode(MainGui.Hwnd)

MainGui.Show("w500 h400")
wvc.IsVisible := true
wvc.Fill()

; ==============================================================================
; メインスレッド用関数
; ==============================================================================
OnNavigationCompleted(sender, args) {
    SyncSlotsToJS()
    SetTimer(MonitorTargetStatus, 1000)
}

OnPermissionRequested(sender, args) {
    args.State := 1
    args.Handled := 1
}

OnWebMsg(sender, args) {
    global IsRecordingHotkey
    msg := args.TryGetWebMessageAsString()

    if (msg == "toggleLink") {
        (IsLinking ? CancelLinking() : StartLinking())
    } else if (SubStr(msg, 1, 9) == "transfer:") {
        ExecuteTransfer(SubStr(msg, 10))
    } else if (SubStr(msg, 1, 14) == "updateSetting:") {
        pts := StrSplit(msg, ":")
        if (pts.Length >= 3) {
            k := pts[2], v := pts[3]
            if (k == "SaveLog" || k == "MinimizeOption")
                Settings[k] := (v == "1")
            else
                Settings[k] := v

            ; 設定変更をUIに反映
            wv.ExecuteScriptAsync("updateUI('" k "', '" v "');")

            if (k == "FocusHotkey") {
                SetFocusHotkey(Settings[k])
                wv.ExecuteScriptAsync(
                    "window.ahkSettings.FocusHotkey = '" Settings[k] "';"
                )
            }
            SaveSettings()
        }
    } else if (SubStr(msg, 1, 15) == "changeFontSize:") {
        ChangeFontSize(Integer(SubStr(msg, 16)))
    } else if (msg == "selectLogDir") {
        SelectLogDir()
    } else if (msg == "openLogDir") {
        OpenLogDir()
    } else if (msg == "openSettings") {
        OpenSettings()
    } else if (msg == "viewLatestLog") {
        OpenLatestLog()
    } else if (msg == "toggleToolbar") {
        SetToolbarState(!IsToolbarHidden)
    } else if (msg == "startRecording") {
        IsRecordingHotkey := true
    } else if (msg == "stopRecording") {
        IsRecordingHotkey := false
    } else if (SubStr(msg, 1, 12) == "applyPreset:") {
        ApplyWindowPreset(Integer(SubStr(msg, 13)))
    } else if (SubStr(msg, 1, 11) == "savePreset:") {
        SaveWindowPreset(Integer(SubStr(msg, 12)))
    } else if (SubStr(msg, 1, 17) == "switchTargetSlot:") {
        SwitchTargetSlot(Integer(SubStr(msg, 18)))
    }
}