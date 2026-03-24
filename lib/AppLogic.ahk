StartLinking() {
    global IsLinking := true
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
    SetTimer(CheckActiveWindow, 0)

    type := (msg == "Cancelled" || msg == "Timeout") ? "error" : "success"
    wv.ExecuteScriptAsync(
        "updateBtn('Link Target'); "
        . "updateStatus('" . msg . "', '" . type . "');"
    )
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
    logFile := Settings["LogDir"]
        . "\history_" . A_YYYY . "-" . A_MM . "-" . A_DD . ".txt"
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
        wv.ExecuteScriptAsync(
            "document.getElementById('main-textarea').value = ''; "
            . "document.getElementById('main-textarea').focus();"
        )
    }
}

SaveToLog(content) {
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
    try {
        if FileExist(ConfigFile)
            FileDelete(ConfigFile)
        FileAppend(JSON.Dump(Settings, "  "), ConfigFile, "UTF-8")
    }
    ExitApp()
}

LoadSettings() {
    if !FileExist(ConfigFile) {
        return
    }

    try {
        raw := FileRead(ConfigFile, "UTF-8")
        loaded := JSON.Load(raw)
        for k, v in loaded {
            if Settings.Has(k)
                Settings[k] := v
        }
    }
}

^!l:: {
    if WinExist("ahk_id " . MainGui.Hwnd) {
        WinActivate("ahk_id " . MainGui.Hwnd)
    }
}