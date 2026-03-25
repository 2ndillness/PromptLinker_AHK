StartLinking() {
    global IsLinking := true
    global wv
    ; HTML側の表示を更新
    wv.ExecuteScriptAsync(
        "updateBtn('Waiting...'); "
        . "updateStatus('Activate Target Window...', 'waiting');"
    )

    global StartTime := A_TickCount
    SetTimer(CheckActiveWindow, 100)
}

CancelLinking(msg := "Cancelled") {
    global IsLinking := false
    global wv
    SetTimer(CheckActiveWindow, 0)

    type := (msg == "Cancelled" || msg == "Timeout") ? "error" : "success"
    wv.ExecuteScriptAsync(
        "updateBtn('Link Target'); "
        . "updateStatus('" . msg . "', '" . type . "');"
    )
}

CheckActiveWindow() {
    global MainGui, wv, StartTime, TargetHWND, TargetProcess, IsLinking
    currentHWND := WinActive("A")
    if (currentHWND != 0 && currentHWND != MainGui.Hwnd) {
        SetTimer(CheckActiveWindow, 0)
        IsLinking := false
        TargetHWND := currentHWND
        TargetProcess := WinGetProcessName("ahk_id " . TargetHWND)

        ; リンク成功時の表示更新
        statusMsg := "Linked: " . TargetProcess
        wv.ExecuteScriptAsync(
            "updateBtn('Relink'); "
            . "updateStatus('" . statusMsg . "', 'success');"
        )

        WinActivate("ahk_id " . MainGui.Hwnd)

        ; テキストエリアにフォーカスを戻す(JS経由)
        wv.ExecuteScriptAsync(
            "document.getElementById('main-textarea').focus();"
        )
    } else if (A_TickCount - StartTime > 10000) {
        CancelLinking("Timeout")
    }
}

ChangeFontSize(delta) {
    global Settings, wv
    newSize := Settings["FontSize"] + delta
    if (newSize < 8)
        newSize := 8
    if (newSize > 40)
        newSize := 40
    Settings["FontSize"] := newSize
    wv.ExecuteScriptAsync("updateFontSize(" . newSize . ");")
}

SelectLogDir(*) {
    global MainGui, Settings, wv
    ; ダイアログが背後に隠れないように、一時的にAlwaysOnTopを解除
    MainGui.Opt("-AlwaysOnTop")
    selDir := FileSelect("D", "*" . Settings["LogDir"], "Select Log Directory")
    ; AlwaysOnTopを再設定
    MainGui.Opt("+AlwaysOnTop")
    if (selDir != "") {
        Settings["LogDir"] := selDir
        ; JS側の表示を更新（バックスラッシュをエスケープして渡す）
        escapedPath := StrReplace(selDir, "\", "\\")
        wv.ExecuteScriptAsync("updateLogDir('" . escapedPath . "');")
    }
}

OpenLatestLog(*) {
    global Settings, AppName, wv
    logFile := Settings["LogDir"]
        . "\history_" . A_YYYY . "-" . A_MM . "-" . A_DD . ".txt"
    if FileExist(logFile) {
        Run(logFile)
    } else {
        wv.PostWebMessageAsString("notify:error:No log file found for today.")
    }
}

ExecuteTransfer(text) {
    global MainGui, wv, TargetHWND, Settings
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
    Sleep(Settings["SubmitDelay"])

    mode := Settings["TargetAction"]
    if (mode == "Enter") {
        Send("{Enter}")
    } else if (mode == "Ctrl + Enter") {
        Send("^{Enter}")
    } else if (mode == "Shift + Enter") {
        Send("+{Enter}")
    }

    Sleep(150)
    ; 全モード共通でテキストエリアをクリア
    wv.ExecuteScriptAsync("document.getElementById('main-textarea').value = '';")

    if (Settings["MinimizeAfter"]) {
        WinMinimize("ahk_id " . MainGui.Hwnd)
    } else {
        WinActivate("ahk_id " . MainGui.Hwnd)
        wv.ExecuteScriptAsync("document.getElementById('main-textarea').focus();")
    }
}

SaveToLog(content) {
    global Settings
    if !DirExist(Settings["LogDir"]) {
        DirCreate(Settings["LogDir"])
    }
    fileName := Settings["LogDir"]
        . "\history_" . A_YYYY . "-" . A_MM . "-" . A_DD . ".txt"
    cleanContent := StrReplace(StrReplace(content, "`r`n", "`n"), "`r", "`n")
    cleanContent := StrReplace(cleanContent, "`n", "`r`n")
    logEntry := "[" . FormatTime(, "HH:mm:ss") . "]`r`n"
        . cleanContent
        . "`r`n------------------------------`r`n"
    FileAppend(logEntry, fileName, "UTF-8")
}

SaveAndExit(*) {
    global Settings, ConfigFile
    try {
        f := FileOpen(ConfigFile, "w", "UTF-8")
        f.Write(Jxon_Dump(Settings, "  "))
        f.Close()
    }
    ExitApp()
}

LoadSettings() {
    global Settings, ConfigFile
    if !FileExist(ConfigFile) {
        return
    }

    raw := ""
    try {
        raw := FileRead(ConfigFile, "UTF-8")
        if (raw == "")
            return
        loaded := Jxon_Load(&raw)
        for k, v in loaded {
            if Settings.Has(k)
                Settings[k] := v
        }
    } catch as err {
        MsgBox("設定ファイルが破損している可能性があるため、初期設定にリセットします。`n"
            . "詳細: " . err.Message . "`n"
            . "読込内容(先頭): " . SubStr(raw, 1, 100), "Config Load Error", 48)
        try {
            FileDelete(ConfigFile)
        }
    }
}

global CurrentRestoreHotkey := ""

UpdateRestoreHotkey(newKey) {
    global CurrentRestoreHotkey, wv
    ; 以前のホットキーがあれば無効化
    if (CurrentRestoreHotkey != "") {
        try Hotkey(CurrentRestoreHotkey, "Off")
    }

    ; 新しいホットキーを登録 (空文字の場合は登録解除のみ)
    if (newKey != "") {
        try {
            Hotkey(newKey, RestoreWindow, "On")
            CurrentRestoreHotkey := newKey
        } catch as err {
            ; 登録失敗（システム予約キーや構文エラー）の場合
            wv.PostWebMessageAsString("notify:error:Hotkey Registration Failed: " . newKey)
            ; UI側の表示を元に戻すために古い値を送り返す等の処理が必要だが、今回はエラー通知のみ行う
            CurrentRestoreHotkey := ""
        }
    }
}

RestoreWindow(hk) {
    global MainGui
    if WinExist("ahk_id " . MainGui.Hwnd) {
        WinActivate("ahk_id " . MainGui.Hwnd)
    }
}