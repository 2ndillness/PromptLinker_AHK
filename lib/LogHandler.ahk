; ログ管理ライブラリ

/**
 * ログ保存先ディレクトリを選択する
 */
SelectLogDir(*) {
    global MainGui, Settings, wv
    ; ダイアログが隠れないよう一時的にAlwaysOnTopを解除
    MainGui.Opt("-AlwaysOnTop")
    selDir := FileSelect("D", "*" . Settings["LogDir"],
        "Select Log Directory")
    MainGui.Opt("+AlwaysOnTop")


    if (selDir != "") {
        ; 書き込み権限テスト
        testFile := selDir "\.write_test"
        try {
            FileAppend("", testFile)
            FileDelete(testFile)
        } catch {
            MsgBox("この場所には書き込み権限がありません。",
                "Permission Error", 48)
            return
        }


        Settings["LogDir"] := selDir
        escapedPath := StrReplace(selDir, "\", "\\")
        wv.ExecuteScriptAsync("updateLogDirectory('" . escapedPath . "');")
        SaveSettings()
    }
}

/**
 * 最新のログファイルを外部エディタで開く
 */
OpenLatestLog(*) {
    global Settings, wv
    logDir := Settings["LogDir"]
    latestFile := ""

    if !DirExist(logDir) {
        wv.PostWebMessageAsString("notify:error:Log directory not found.")
        return
    }

    ; history_YYYY-MM-DD.jsonl 形式から最新を探す
    Loop Files, logDir "\history_*.jsonl" {
        if (latestFile == "" ||
            StrCompare(A_LoopFileName, latestFile) > 0) {
            latestFile := A_LoopFileName
        }
    }


    if (latestFile != "") {
        fullPath := logDir "\" latestFile
        try {
            Run(fullPath)
        } catch {
            wv.PostWebMessageAsString("notify:error:Failed to open log file.")
        }
    } else {
        wv.PostWebMessageAsString("notify:info:No log files found.")
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
 * @param {string} target ターゲットプロセス名
 */
SaveToLog(content, target := "Unknown") {
    global Settings, wv
    logPath := Settings["LogDir"]
    if !DirExist(logPath) {
        try {
            DirCreate(logPath)
        } catch as err {
            wv.PostWebMessageAsString(
                "notify:error:Failed to create log dir: "
                . logPath . "`nReason: " . err.Message)
            return
        }

    }

    fileName := logPath
        . "\history_" . A_YYYY . "-" . A_MM . "-" . A_DD . ".jsonl"

    ; JSONオブジェクトの構築
    logObj := Map(
        "timestamp", FormatTime(, "yyyy-MM-ddTHH:mm:ss"),
        "target", target,
        "length", StrLen(content),
        "content", content
    )

    ; JSONLとして1行で書き出し
    logEntry := Jxon_Dump(logObj) . "`n"

    try {
        FileAppend(logEntry, fileName, "UTF-8")
    } catch as err {
        wv.PostWebMessageAsString(
            "notify:error:Log Write Failed to: "
            . fileName . "`nReason: " . err.Message)
    }
}