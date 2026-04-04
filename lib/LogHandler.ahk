; プロンプト保存（エクスポート）管理ライブラリ

/**
 * 保存先ディレクトリを選択する
 */
SelectLogDir(*) {
    global MainGui, Settings, wv
    ; ダイアログが隠れないよう一時的にAlwaysOnTopを解除
    wasAlwaysOnTop := Settings["AlwaysOnTop"]
    if (wasAlwaysOnTop)
        MainGui.Opt("-AlwaysOnTop")
        
    selDir := DirSelect("*" . Settings["LogDir"], 3, "Select Save Directory")
    
    if (wasAlwaysOnTop)
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
 * 保存先ディレクトリをエクスプローラーで開く
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
 * 現在のテキストを指定された形式でファイルに保存する
 * @param {string} content 保存するテキスト
 */
ExportPrompt(content) {
    global Settings, wv
    if (content == "") {
        wv.PostWebMessageAsString("notify:warning:No text to save")
        return
    }

    savePath := Settings["LogDir"]
    if !DirExist(savePath) {
        try {
            DirCreate(savePath)
        } catch as err {
            wv.PostWebMessageAsString("notify:error:Failed to create save dir")
            return
        }
    }

    ; ファイル名の生成: YYYYMMDD_HHMMSS_[1行目(20文字)].ext
    timestamp := FormatTime(, "yyyyMMdd_HHmmss")
    
    ; 1行目の抽出とクリーニング
    firstLine := StrSplit(content, "`n", "`r")[1]
    title := SubStr(firstLine, 1, 20)
    ; ファイル名に使用できない文字を置換
    title := RegExReplace(title, "[\\/:*?`"<>|]", "_")
    title := Trim(title)

    fileName := timestamp . (title != "" ? "_" . title : "") . Settings["ExportExtension"]
    fullPath := savePath . "\" . fileName

    try {
        if FileExist(fullPath) {
            wv.PostWebMessageAsString("notify:warning:File already exists")
            return
        }
        FileAppend(content, fullPath, "UTF-8")
        wv.PostWebMessageAsString("notify:success:Saved as: " . fileName)
    } catch as err {
        wv.PostWebMessageAsString("notify:error:Save Failed: " . err.Message)
    }
}
