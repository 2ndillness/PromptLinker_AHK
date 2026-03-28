; ログ管理ライブラリ

/**
 * ログ保存先ディレクトリを選択する
 */
SelectLogDir(*) {
    global MainGui, Settings, wv
    ; ダイアログが隠れないよう一時的にAlwaysOnTopを解除
    MainGui.Opt("-AlwaysOnTop")
    selDir := FileSelect("D", "*" . Settings["LogDir"], "Select Log Directory")
    MainGui.Opt("+AlwaysOnTop")

    if (selDir != "") {
        ; 書き込み権限テスト
        testFile := selDir "\.write_test"
        try {
            FileAppend("", testFile)
            FileDelete(testFile)
        } catch {
            MsgBox("この場所には書き込み権限がありません。", "Permission Error", 48)
            return
        }

        Settings["LogDir"] := selDir
        escapedPath := StrReplace(selDir, "\", "\\")
        wv.ExecuteScriptAsync("updateLogDirectory('" . escapedPath . "');")
        SaveSettings()
    }
}

/**
 * 本日のログファイルを外部エディタで開く
 */
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

/**
 * ログディレクトリをエクスプローラーで開く
 */
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

/**
 * 指定された内容をログファイルに追記する
 * @param {string} content 保存するテキスト
 */
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

    ; 改行コードの正規化 (`r`n に統一)
    clean := StrReplace(StrReplace(content, "`r`n", "`n"), "`r", "`n")
    clean := StrReplace(clean, "`n", "`r`n")

    logEntry := "[" . FormatTime(, "HH:mm:ss") . "]`r`n"
        . clean . "`r`n------------------------------`r`n"

    try {
        FileAppend(logEntry, fileName, "UTF-8")
    } catch as err {
        wv.PostWebMessageAsString("notify:error:Log Write Failed: " err.Message)
    }
}