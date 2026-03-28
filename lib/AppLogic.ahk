SelectLogDir(*) {
    global MainGui, Settings, wv
    ; ダイアログが背後に隠れないように、一時的にAlwaysOnTopを解除
    MainGui.Opt("-AlwaysOnTop")
    selDir := FileSelect("D", "*" . Settings["LogDir"], "Select Log Directory")
    ; AlwaysOnTopを再設定
    MainGui.Opt("+AlwaysOnTop")
    if (selDir != "") {
        ; 書き込み権限テスト
        testFile := selDir "\.write_test"
        try {
            FileAppend("", testFile)
            FileDelete(testFile)
        } catch {
            MsgBox(
                "このディレクトリには書き込み権限がありません。`n" .
                "別の場所を選択してください。",
                "Permission Error",
                48
            )
            return
        }

        Settings["LogDir"] := selDir
        ; JS側の表示を更新（バックスラッシュをエスケープして渡す）
        escapedPath := StrReplace(selDir, "\", "\\")
        wv.ExecuteScriptAsync("updateLogDir('" . escapedPath . "');")
        SaveSettings()
    }
}

OpenLatestLog(*) {
    global Settings, wv
    logFile := Settings["LogDir"]
        . "\history_" . A_YYYY . "-" . A_MM . "-" . A_DD . ".txt"
    if FileExist(logFile) {
        try {
            Run(logFile)
        } catch {
            wv.PostWebMessageAsString("notify:error:Failed to open log file.")
        }
    } else {
        wv.PostWebMessageAsString("notify:error:No log file found for today.")
    }
}

ExecuteTransfer(text) {
    global TargetHWND, Settings, MainGui, wv
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

    if (Settings["MinimizeOption"]) {
        WinMinimize("ahk_id " . MainGui.Hwnd)
    } else {
        WinActivate("ahk_id " . MainGui.Hwnd)
        wv.ExecuteScriptAsync("document.getElementById('main-textarea').focus();")
    }
}

SaveToLog(content) {
    global Settings, wv
    if !DirExist(Settings["LogDir"]) {
        try {
            DirCreate(Settings["LogDir"])
        } catch {
            wv.PostWebMessageAsString("notify:error:Failed to create log directory.")
            return
        }
    }
    fileName := Settings["LogDir"]
        . "\history_" . A_YYYY . "-" . A_MM . "-" . A_DD . ".txt"
    cleanContent := StrReplace(StrReplace(content, "`r`n", "`n"), "`r", "`n")
    cleanContent := StrReplace(cleanContent, "`n", "`r`n")
    logEntry := "[" . FormatTime(, "HH:mm:ss") . "]`r`n"
        . cleanContent
        . "`r`n------------------------------`r`n"
    try {
        FileAppend(logEntry, fileName, "UTF-8")
    } catch as err {
        wv.PostWebMessageAsString("notify:error:Log Write Failed: " err.Message)
    }
}

SaveAndExit(*) {
    SaveSettings()
    ExitApp()
}

OpenLogDir(*) {
    global Settings, wv
    path := Settings["LogDir"]
    if DirExist(path) {
        try {
            Run(path)
        } catch {
            wv.PostWebMessageAsString("notify:error:Open Failed")
        }
    } else {
        wv.PostWebMessageAsString("notify:error:Folder not found")
    }
}