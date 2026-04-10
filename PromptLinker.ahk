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
if DirExist(ResDir) {
    try {
        DirDelete(ResDir, 1)
    }
}
if !DirExist(ResDir) {
    DirCreate(ResDir)
}

subDirs := ["assets\css", "assets\js", "assets\icons", "WebView2\32bit", "WebView2\64bit"]
for d in subDirs {
    if !DirExist(ResDir "\" d)
        DirCreate(ResDir "\" d)
}

FileInstall "ui.html", ResDir "\ui.html", 1
FileInstall "assets\js\main.js", ResDir "\assets\js\main.js", 1
FileInstall "assets\css\style.css", ResDir "\assets\css\style.css", 1
FileInstall "assets\js\editor-manager.js", ResDir "\assets\js\editor-manager.js", 1
FileInstall "assets\js\settings-manager.js", ResDir "\assets\js\settings-manager.js", 1
FileInstall "assets\js\ui-utils.js", ResDir "\assets\js\ui-utils.js", 1
FileInstall "assets\js\view-manager.js", ResDir "\assets\js\view-manager.js", 1
FileInstall "assets\app_icon.ico", ResDir "\assets\app_icon.ico", 1
FileInstall "assets\css\components.css", ResDir "\assets\css\components.css", 1
FileInstall "assets\css\theme.css", ResDir "\assets\css\theme.css", 1
FileInstall "assets\css\layout.css", ResDir "\assets\css\layout.css", 1
FileInstall "assets\css\forms.css", ResDir "\assets\css\forms.css", 1
FileInstall "assets\css\overlays.css", ResDir "\assets\css\overlays.css", 1
FileInstall "assets\icons\link.svg", ResDir "\assets\icons\link.svg", 1
FileInstall "assets\icons\settings.svg", ResDir "\assets\icons\settings.svg", 1
FileInstall "assets\icons\folder.svg", ResDir "\assets\icons\folder.svg", 1
FileInstall "assets\icons\arrow-left.svg", ResDir "\assets\icons\arrow-left.svg", 1
FileInstall "assets\icons\folder-open.svg", ResDir "\assets\icons\folder-open.svg", 1
FileInstall "assets\icons\save.svg", ResDir "\assets\icons\save.svg", 1
FileInstall "assets\icons\file-text.svg", ResDir "\assets\icons\file-text.svg", 1
FileInstall "assets\icons\help-circle.svg", ResDir "\assets\icons\help-circle.svg", 1
FileInstall "assets\icons\chevron-down.svg", ResDir "\assets\icons\chevron-down.svg", 1
FileInstall "assets\icons\lock.svg", ResDir "\assets\icons\lock.svg", 1
FileInstall "lib\WebView2\32bit\WebView2Loader.dll", ResDir "\WebView2\32bit\WebView2Loader.dll", 1
FileInstall "lib\WebView2\64bit\WebView2Loader.dll", ResDir "\WebView2\64bit\WebView2Loader.dll", 1

; ==============================================================================
; 初期設定・変数定義
; ==============================================================================
global AppName := "Prompt Linker"
global DataDir := A_AppData "\" StrReplace(AppName, " ", "_")
global PortableFile := A_ScriptDir "\settings.json"

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
            MsgBox("データディレクトリ作成失敗: " DataDir "`n" err.Message, "Error", 48)
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

global CurrentSlotIndex := 1
global TargetSlots := [{ hwnd: 0, exe: "", action: "", locked: false }, { hwnd: 0, exe: "", action: "", locked: false }, { hwnd: 0, exe: "", action: "", locked: false }
]

global Settings := Map(
    "FontSize", 14,
    "MinimizeOption", false,
    "AlwaysOnTop", false,
    "ExportExtension", ".txt",
    "ExportDir", "",
    "TargetAction", "Enter",
    "SubmitDelay", 400,
    "FocusHotkey", "^!f",
    "TriggerKey", "Ctrl + Enter",
    "TabBehavior", "Move Focus",
    "ClearTextAtTransfer", true,
    "ClearTextAtSave", false,
    "Presets", Map("1", "", "2", "", "3", "")
)

Gui_Size(thisGui, minMax, width, height) {
    global wvc
    if (minMax != -1 && IsSet(wvc) && wvc) {
        wvc.Fill()
    }
}

#Include Lib\WebView2\WebView2.ahk
#Include Lib\_JXON.ahk
#Include Lib\SettingsManager.ahk
#Include Lib\WindowManager.ahk
#Include Lib\AppLogic.ahk
#Include Lib\ExportHandler.ahk
#Include Lib\Hotkeys.ahk

OnMessage(0x0006, OnActivate)

OnActivate(wParam, lParam, msg, hwnd) {
    global MainGui, wvc, wv
    if (hwnd == MainGui.Hwnd && (wParam & 0xFFFF) != 0) {
        if (IsSet(wvc) && wvc) {
            try {
                wvc.MoveFocus(0)
            }
        }
        if (IsSet(wv) && wv) {
            SetTimer(() => (IsSet(wv) && wv ?
                wv.ExecuteScriptAsync(
                    "document.getElementById('main-textarea').focus();"
                ) : 0), -50)
        }
    }
}

LoadSettings()

MainGui := Gui("+Resize +MinSize500x140", AppName " - Unlinked")
MainGui.BackColor := "1e1e1e"
MainGui.OnEvent("Size", Gui_Size)
MainGui.OnEvent("Close", SaveAndExit)

SetFocusHotkey(Settings["FocusHotkey"])

HotIf((*) => WinActive("ahk_id " MainGui.Hwnd) && !IsRecordingHotkey)
Loop 3 {
    Hotkey("!" A_Index, (hk) => ApplyWindowPreset(Integer(SubStr(hk, -1))))
    Hotkey("+!" A_Index, (hk) => SaveWindowPreset(Integer(SubStr(hk, -1))))
}
Hotkey("!h", (*) => SetToolbarState(!IsToolbarHidden))
Hotkey("!l", (*) => (IsLinking ? CancelLinking() : StartLinking()))
Loop 3 {
    h := (hk) => ToggleSlotLock(Integer(SubStr(hk, -1)))
    Hotkey("^+" . A_Index, h)
    c := (hk) => ClearTargetSlot(Integer(SubStr(hk, -1)))
    Hotkey("^!" . A_Index, c)
}

Hotkey("!j", OpenSettings)
Hotkey("!r", (*) => wv.ExecuteScriptAsync("resetFocusHotkey();"))
Hotkey("!o", OpenExportDir)
Hotkey("!b", SelectExportDir)

Hotkey("^Tab", (*) => wv.ExecuteScriptAsync("rotateView(1)"))
Hotkey("^+Tab", (*) => wv.ExecuteScriptAsync("rotateView(-1)"))
Hotkey("^1", (*) => SwitchTargetSlot(1))
Hotkey("^2", (*) => SwitchTargetSlot(2))
Hotkey("^3", (*) => SwitchTargetSlot(3))
Hotkey("^,", (*) => wv.ExecuteScriptAsync("toggleSetView(true)"))
Hotkey("F1", (*) => wv.ExecuteScriptAsync("toggleHelp()"))

Hotkey("^s", (*) => wv.ExecuteScriptAsync("exportCurrentText()"))
Hotkey("!-", (*) => ChangeFontSize(-1))
Hotkey("!=", (*) => ChangeFontSize(1))
Hotkey("!a", (*) => ToggleAlwaysOnTop())
Hotkey("!e", (*) => ToggleExportExtension())
Hotkey("!m", (*) => ToggleSetting("MinimizeOption"))
Hotkey("+!t", (*) => ToggleSetting("ClearTextAtTransfer"))
Hotkey("+!s", (*) => ToggleSetting("ClearTextAtSave"))
Hotkey("!k", ToggleTriggerKey)
Hotkey("!t", (*) => CycleTabBehavior())


Hotkey("!p", (*) => UpdateTargetAction("Paste Only"))
Hotkey("!Enter", (*) => UpdateTargetAction("Enter"))
Hotkey("^!Enter", (*) => UpdateTargetAction("Ctrl + Enter"))
Hotkey("+!Enter", (*) => UpdateTargetAction("Shift + Enter"))
HotIf()

try {
    sub := (A_PtrSize = 8 ? "64bit" : "32bit")
    dll := ResDir "\WebView2\" sub "\WebView2Loader.dll"
    wvc := WebView2.Create(MainGui.Hwnd, , , , , , dll)
} catch as err {
    MsgBox("WebView2初期化失敗:`n" err.Message, "Error", 4096)
    ExitApp
}

wv := wvc.CoreWebView2
wv.Settings.AreBrowserAcceleratorKeysEnabled := true
wv.Settings.AreDefaultContextMenusEnabled := false
wv.Settings.IsZoomControlEnabled := false

wv.AddScriptToExecuteOnDocumentCreatedAsync(
    "window.ahkSettings = " Jxon_Dump(Settings) ";"
)

uPath := "file:///" StrReplace(ResDir, "\", "/") "/ui.html"
wv.add_WebMessageReceived(OnWebMsg)
wv.add_PermissionRequested(OnPermissionRequested)
wv.add_NavigationCompleted(OnNavigationCompleted)
wv.Navigate(uPath)

DwmSetDarkMode(hwnd) {
    val := Buffer(4, 0)
    NumPut("Int", 1, val)
    DllCall(
        "Dwmapi\DwmSetWindowAttribute",
        "Ptr", hwnd,
        "Int", 20,
        "Ptr", val,
        "Int", 4
    )
}
DwmSetDarkMode(MainGui.Hwnd)

if Settings["AlwaysOnTop"] {
    MainGui.Opt("+AlwaysOnTop")
}

MainGui.Show("w500 h500")
wvc.Fill()

ToggleAlwaysOnTop() {
    global Settings, MainGui
    newVal := !Settings["AlwaysOnTop"]
    MainGui.Opt(newVal ? "+AlwaysOnTop" : "-AlwaysOnTop")
    UpdateSetting(
        "AlwaysOnTop", newVal, "Always On Top: " . (newVal ? "ON" : "OFF")
    )
}

ToggleExportExtension() {
    global Settings
    newExt := (Settings["ExportExtension"] == ".txt") ? ".md" : ".txt"
    UpdateSetting("ExportExtension", newExt, "Extension: " newExt)
}

OnNavigationCompleted(sender, args) {
    global wvc
    SyncSlotsToJS()
    SetTimer(MonitorTargetStatus, 1000)
    wvc.IsVisible := true
    try {
        wvc.MoveFocus(0)
    }
}

OnPermissionRequested(sender, args) {
    args.State := 1
    args.Handled := 1
}

OnWebMsg(sender, args) {
    global IsRecordingHotkey
    jsonStr := args.WebMessageAsJson
    try {
        data := Jxon_Load(&jsonStr)
        if !(data is Map)
            return
        mType := data.Get("type", "")
        payload := data.Get("payload", "")
    } catch {
        return
    }

    if (mType == "toggleLink") {
        (IsLinking ? CancelLinking() : StartLinking())
    } else if (mType == "transfer") {
        ExecuteTransfer(payload)
    } else if (mType == "export") {
        ExportPrompt(payload)
    } else if (mType == "updateSetting") {
        if !(payload is Map)
            return
        k := payload.Get("key", "")
        v := payload.Get("value", "")

        if (k == "MinimizeOption" || k == "AlwaysOnTop" || k == "ClearTextAtTransfer" || k == "ClearTextAtSave") {
            v := (v = true || v = 1 || v == "1" || v == "true") ? true : false
            if (k == "AlwaysOnTop")
                MainGui.Opt(v ? "+AlwaysOnTop" : "-AlwaysOnTop")
        }

        if (k == "TargetAction")
            UpdateTargetAction(v)
        else
            UpdateSetting(k, v)

        if (k == "FocusHotkey") {
            SetFocusHotkey(Settings[k])
            wv.ExecuteScriptAsync(
                "window.ahkSettings.FocusHotkey = '" Settings[k] "';"
            )
        }
    } else if (mType == "updateExportExtension") {
        ; ペイロードが true なら .md, false なら .txt
        newExt := payload ? ".md" : ".txt"
        UpdateSetting("ExportExtension", newExt, "Extension: " newExt)
    } else if (mType == "changeFontSize") {
        if IsNumber(payload)
            ChangeFontSize(Integer(payload))
    } else if (mType == "selectExportDir") {
        SelectExportDir()
    } else if (mType == "openExportDir") {
        OpenExportDir()
    } else if (mType == "openSettings") {
        OpenSettings()
    } else if (mType == "toggleToolbar") {
        SetToolbarState(!IsToolbarHidden)
    } else if (mType == "startRecording") {
        IsRecordingHotkey := true
    } else if (mType == "stopRecording") {
        IsRecordingHotkey := false
    } else if (mType == "applyPreset") {
        if IsNumber(payload)
            ApplyWindowPreset(Integer(payload))
    } else if (mType == "savePreset") {
        if IsNumber(payload)
            SaveWindowPreset(Integer(payload))
    } else if (mType == "switchTargetSlot") {
        if IsNumber(payload)
            SwitchTargetSlot(Integer(payload))
    } else if (mType == "toggleSlotLock") {
        if IsNumber(payload)
            ToggleSlotLock(Integer(payload))
    } else if (mType == "clearTargetSlot") {
        if IsNumber(payload)
            ClearTargetSlot(Integer(payload))
    }
}