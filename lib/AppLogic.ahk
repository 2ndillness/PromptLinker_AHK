StartLinking() {
    global IsLinking, StartTime
    IsLinking := true
    ; HTML側の表示を更新
    MainGui.Title := AppName . " - Waiting for target window..."
    wv.PostWebMessageAsString("notify:info:Click Target Window...")
    wv.ExecuteScriptAsync(
        "updateBtn('Waiting...'); "
    )

    StartTime := A_TickCount
    SetTimer(CheckActiveWindow, 100)
}

CancelLinking(msg := "Cancelled") {
    global IsLinking
    IsLinking := false
    SetTimer(CheckActiveWindow, 0)

    MainGui.Title := AppName " - Unlinked" ;

    ; キャンセル時はinfo、タイムアウト時はerrorとしてトーストを表示
    type := (msg == "Timeout") ? "error" : "info"
    wv.PostWebMessageAsString("notify:" type ":" msg)

    wv.ExecuteScriptAsync(
        "updateBtn('Link Target'); "
    )
}

CheckActiveWindow() {
    global IsLinking, TargetHWND, TargetProcess
    currentHWND := WinActive("A")
    if (currentHWND != 0 && currentHWND != MainGui.Hwnd) {
        SetTimer(CheckActiveWindow, 0)
        IsLinking := false
        TargetHWND := currentHWND
        TargetProcess := WinGetProcessName("ahk_id " . TargetHWND)

        ; タイトルバーに接続先を表示
        MainGui.Title := AppName . " - Linked: " . TargetProcess
        wv.PostWebMessageAsString("notify:success:Linked: " . TargetProcess)

        wv.ExecuteScriptAsync(
            "updateBtn('Relink'); "
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

/**
 * 現在のウィンドウ位置とサイズをプリセットに保存
 * @param {number} index プリセット番号 (1-3)
 */
SaveWindowPreset(index) {
    WinGetPos(&x, &y, &w, &h, "ahk_id " . MainGui.Hwnd)

    ; 座標データとツールバーの状態を保存
    presetData := Map("x", x, "y", y, "w", w, "h", h, "isToolbarHidden", IsToolbarHidden)
    Settings["Presets"][String(index)] := presetData

    wv.PostWebMessageAsString("notify:success:Preset " . index . " Saved!")
}

/**
 * プリセットの座標を適用
 * @param {number} index プリセット番号 (1-3)
 */
ApplyWindowPreset(index) {
    preset := Settings["Presets"][String(index)]

    if (preset == "" || !(preset is Map)) {
        wv.PostWebMessageAsString("notify:error:Preset " . index . " is empty.")
        return
    }

    ; 安全チェック: 保存された座標が現在のモニター領域内にあるか確認
    isVisible := false
    monitorCount := MonitorGetCount()
    Loop monitorCount {
        MonitorGetWorkArea(A_Index, &left, &top, &right, &bottom)
        ; 左上角がモニターのいずれかに含まれていればOKとする
        if (
            preset["x"] >= left
            && preset["x"] < right
            && preset["y"] >= top
            && preset["y"] < bottom
        ) {
            isVisible := true
            break
        }
    }

    ; 画面外（モニター構成変更時など）の場合は、中央付近へ補正
    if (!isVisible) {
        preset["x"] := 100
        preset["y"] := 100
    }

    MainGui.Move(preset["x"], preset["y"], preset["w"], preset["h"])

    ; ツールバーの状態を復元
    if (preset.Has("isToolbarHidden")) {
        global IsToolbarHidden := preset["isToolbarHidden"]
        wv.PostWebMessageAsString(IsToolbarHidden ? "hideToolbar" : "showToolbar")
    }

    wv.PostWebMessageAsString("notify:info:Preset " . index . " Applied")
    WinActivate("ahk_id " . MainGui.Hwnd)
    wv.ExecuteScriptAsync("document.getElementById('main-textarea').focus();")
}

ChangeFontSize(delta) {
    newSize := Settings["FontSize"] + delta
    if (newSize < 8)
        newSize := 8
    if (newSize > 40)
        newSize := 40
    Settings["FontSize"] := newSize
    wv.ExecuteScriptAsync("updateFontSize(" . newSize . ");")
}

SelectLogDir(*) {
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
    }
}

OpenLatestLog(*) {
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
    try {
        if !DirExist(DataDir) && !FileExist(PortableFile) {
            DirCreate(DataDir)
        }
        f := FileOpen(SettingsFile, "w", "UTF-8")
        f.Write(Jxon_Dump(Settings, "  "))
        f.Close()
    } catch as err {
        MsgBox("設定の保存に失敗しました。`n" err.Message, "Error", 48)
    }
    ExitApp()
}

LoadSettings() {
    if !FileExist(SettingsFile) {
        return
    }

    raw := ""
    try {
        raw := FileRead(SettingsFile, "UTF-8")
        if (raw == "")
            return
        loaded := Jxon_Load(&raw)
        for k, v in loaded {
            if Settings.Has(k) {
                Settings[k] := v
            }
        }
        ; SubmitDelay の許容範囲チェック (100ms - 2000ms)
        if Settings.Has("SubmitDelay") {
            val := Settings["SubmitDelay"]
            Settings["SubmitDelay"] := Max(100, Min(2000, val))
        }
    } catch as err {
        MsgBox("設定ファイルが破損している可能性があるため、初期設定にリセットします。`n"
            . "詳細: " . err.Message . "`n"
            . "読込内容(先頭): " . SubStr(raw, 1, 100), "Settings Load Error", 48)
        try {
            FileDelete(SettingsFile)
        }
    }
}

global CurrentRestoreHotkey := ""

UpdateRestoreHotkey(newKey) {
    global CurrentRestoreHotkey
    HotIf() ; 常にグローバルなホットキーとして登録されるようコンテキストをリセット
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
            wv.PostWebMessageAsString(
                "notify:error:Hotkey Registration Failed: " . newKey
            )
            CurrentRestoreHotkey := ""
        }
    }
}

RestoreWindow(hk) {
    if WinExist("ahk_id " . MainGui.Hwnd) {
        WinActivate("ahk_id " . MainGui.Hwnd)
    }
}