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
if !DirExist(ResDir) {
    DirCreate(ResDir)
}
if !DirExist(ResDir "\assets\css") {
    DirCreate(ResDir "\assets\css")
}
if !DirExist(ResDir "\assets\icons") {
    DirCreate(ResDir "\assets\icons")
}
if !DirExist(ResDir "\WebView2\32bit") {
    DirCreate(ResDir "\WebView2\32bit")
}
if !DirExist(ResDir "\WebView2\64bit") {
    DirCreate(ResDir "\WebView2\64bit")
}

; ファイルの展開 (コンパイル時のみEXEに埋め込まれ、実行時に展開される)
FileInstall "ui.html", ResDir "\ui.html", 1
FileInstall "script.js", ResDir "\script.js", 1
FileInstall "style.css", ResDir "\style.css", 1
FileInstall "icons.js", ResDir "\icons.js", 1

FileInstall "assets\app_icon.ico", ResDir "\assets\app_icon.ico", 1

FileInstall "assets\css\components.css", ResDir "\assets\css\components.css", 1
FileInstall "assets\css\theme.css", ResDir "\assets\css\theme.css", 1

FileInstall "assets\icons\back.svg", ResDir "\assets\icons\back.svg", 1
FileInstall "assets\icons\file.svg", ResDir "\assets\icons\file.svg", 1
FileInstall "assets\icons\folder.svg", ResDir "\assets\icons\folder.svg", 1
FileInstall "assets\icons\link.svg", ResDir "\assets\icons\link.svg", 1
FileInstall "assets\icons\open-folder.svg", ResDir "\assets\icons\open-folder.svg", 1
FileInstall "assets\icons\settings.svg", ResDir "\assets\icons\settings.svg", 1
FileInstall "assets\icons\view-log.svg", ResDir "\assets\icons\view-log.svg", 1

FileInstall "lib\WebView2\32bit\WebView2Loader.dll", ResDir
    . "\WebView2\32bit\WebView2Loader.dll", 1
FileInstall "lib\WebView2\64bit\WebView2Loader.dll", ResDir
    . "\WebView2\64bit\WebView2Loader.dll", 1

; ==============================================================================
; 初期設定・変数定義
; ==============================================================================
global AppName := "Prompt Linker"
global ConfigFile := A_ScriptDir "\config.json"
global TargetHWND := 0
global IsLinking := false
global TargetProcess := ""
global MainGui := ""
global wvc := ""
global wv := ""
; 設定マップ
global Settings := Map(
    "FontSize", 14,
    "MinimizeAfter", false,
    "SaveLog", false,
    "LogDir", A_ScriptDir "\logs",
    "TargetAction", "Enter",
    "SubmitDelay", 400,
    "RestoreHotkey", "^!l",
    "TriggerKey", "Ctrl + Enter"
)

; ==============================================================================
; コールバック関数
; ==============================================================================

Gui_Size(thisGui, minMax, width, height) {
    global wvc
    if (minMax == -1) {
        return
    }

    if (IsSet(wvc) && wvc) {
        wvc.Fill()
    }
}

; ==============================================================================
; ライブラリのインクルード
; ==============================================================================
#Include Lib\WebView2\WebView2.ahk
#Include Lib\_JXON.ahk
#Include Lib\AppLogic.ahk

; ==============================================================================
; アプリケーションの初期化
; ==============================================================================
LoadSettings()
UpdateRestoreHotkey(Settings["RestoreHotkey"])

if !DirExist(Settings["LogDir"]) {
    DirCreate(Settings["LogDir"])
}

MainGui := Gui("+AlwaysOnTop +Resize +MinSize450x150", AppName)
MainGui.BackColor := "1e1e1e"
MainGui.OnEvent("Size", Gui_Size)
MainGui.OnEvent("Close", SaveAndExit)

try {
    subDir := (A_PtrSize = 8 ? "64bit" : "32bit")
    ; 展開したDLLのパスを指定
    dllPath := ResDir "\WebView2\" subDir "\WebView2Loader.dll"

    if !FileExist(dllPath) {
        throw Error("WebView2Loader.dll が展開されていません。`nパス: " dllPath)
    }

    wvc := WebView2.Create(MainGui.Hwnd, , , , , , dllPath)
} catch as err {
    MsgBox(
        "WebView2の初期化に失敗しました。`n" . err.Message,
        "Error", 4096
    )
    ExitApp
}

wv := wvc.CoreWebView2
wv.Settings.AreDefaultContextMenusEnabled := false
wv.Settings.IsZoomControlEnabled := false

settingsJson := Jxon_Dump(Settings)
wv.AddScriptToExecuteOnDocumentCreatedAsync(
    "window.ahkSettings = " . settingsJson . ";"
)

; 展開した一時フォルダ内のHTMLをロード
htmlPath := "file:///" . StrReplace(ResDir, "\", "/") . "/ui.html"

wv.add_WebMessageReceived(OnWebMsg)
wv.add_PermissionRequested(OnPermissionRequested)
wv.Navigate(htmlPath)

DwmSetDarkMode(hwnd) {
    val := Buffer(4, 0)
    NumPut("Int", 1, val)
    DllCall("Dwmapi\DwmSetWindowAttribute"
        , "Ptr", hwnd, "Int", 20
        , "Ptr", val, "Int", 4)
}

MainGui.Show("w600 h450")
DwmSetDarkMode(MainGui.Hwnd)
wvc.IsVisible := true
wvc.Fill()

; ==============================================================================
; メインスレッド用関数
; ==============================================================================

OnPermissionRequested(sender, args) {
    args.State := 1
    args.Handled := 1
}
OnWebMsg(sender, args) {
    msg := args.TryGetWebMessageAsString()

    if (msg == "toggleLink") {
        if (IsLinking) {
            CancelLinking()
        } else {
            StartLinking()
        }
    } else if (SubStr(msg, 1, 9) == "transfer:") {
        ExecuteTransfer(SubStr(msg, 10))
    } else if (SubStr(msg, 1, 14) == "updateSetting:") {
        parts := StrSplit(msg, ":")
        if (parts.Length >= 3) {
            key := parts[2], val := parts[3]
            if (key == "SaveLog") {
                Settings[key] := (val == "1")
            } else if (key == "MinimizeAfter") {
                Settings[key] := (val == "1")
            } else {
                Settings[key] := val
            }

            ; ホットキーの設定変更であれば即時反映
            if (key == "RestoreHotkey") {
                UpdateRestoreHotkey(Settings[key])
            }
        }
    } else if (SubStr(msg, 1, 15) == "changeFontSize:") {
        ChangeFontSize(Integer(SubStr(msg, 16)))
    } else if (msg == "selectLogDir") {
        SelectLogDir()
    } else if (msg == "openLogDir") {
        Run(Settings["LogDir"])
    } else if (msg == "viewLatestLog") {
        OpenLatestLog()
    }
}