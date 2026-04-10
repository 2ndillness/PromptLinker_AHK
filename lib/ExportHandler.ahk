; プロンプト保存（エクスポート）管理ライブラリ
; @file Lib\ExportHandler.ahk

/**
 * 保存先ディレクトリを選択する
 */
SelectExportDir(*) {
    global MainGui, Settings, wv

    isOk := false
    isTopmost := Settings["AlwaysOnTop"]
    if (isTopmost)
        MainGui.Opt("-AlwaysOnTop")

    Loop {
        prompt := "Select Export Directory"
        selDir := FileSelect("D", "*" . Settings["ExportDir"], prompt)
        if (selDir == "")
            break

        ; 書き込み権限確認
        testFile := selDir "\.write_test"
        isOk := false
        try {
            FileAppend("", testFile)
            FileDelete(testFile)
            isOk := true
        } catch {
            msg := "Permission Denied: Please select another directory"
            wv.PostWebMessageAsString("notify:error:" . msg)
        }

        if (isOk) {
            Settings["ExportDir"] := selDir
            escapedPath := StrReplace(selDir, "\", "\\")
            wv.ExecuteScriptAsync("updateExportDirectory('" escapedPath "');")
            SaveSettings()
            isOk := true
            break
        }
    }

    if (isTopmost)
        MainGui.Opt("+AlwaysOnTop")
    return isOk
}

/**
 * 保存先ディレクトリをエクスプローラーで開く
 */
OpenExportDir(*) {
    global Settings, wv
    path := Settings["ExportDir"]
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

    savePath := Settings["ExportDir"]
    if (savePath == "" || !DirExist(savePath)) {
        wv.PostWebMessageAsString("notify:warning:Please select a directory")
        ; 選択に成功した場合は、そのまま保存処理を続行する
        if (SelectExportDir()) {
            ExportPrompt(content)
        }
        return
    }

    ; ファイル名生成
    timestamp := FormatTime(, "yyyy-MM-dd-HHmmss")
    title := ""
    lines := StrSplit(content, "`n", "`r")

    ; YAMLのtitleキー
    if (lines.Length > 1 && lines[1] == "---") {
        for i, line in lines {
            if (i > 1 && line == "---")
                break
            if (RegExMatch(line, "i)^title:\s*(.+)$", &match)) {
                title := Trim(match[1], " '`"`t")
                break
            }
            if (i > 15) ; 探索上限
                break
        }
    }

    ; H1見出し
    if (title == "") {
        for line in lines {
            if (RegExMatch(line, "^#\s+(.+)$", &match)) {
                title := match[1]
                break
            }
            if (A_Index > 20)
                break
        }
    }

    ; 最初の本文行 (空行や区切り線を除外)
    if (title == "") {
        for line in lines {
            trimmed := Trim(line)
            if (trimmed != "" && trimmed != "---" && trimmed != "***") {
                title := trimmed
                break
            }
            if (A_Index > 20)
                break
        }
    }

    title := SubStr(title, 1, 35)
    ; 禁止文字・制御文字の置換
    title := RegExReplace(title, '[\\/:*?"<>|\x00-\x1f]', "_")
    ; 文末の掃除
    title := Trim(title, ". ")

    fileName := timestamp . (title != "" ? "_" . title : "")
    fileName .= Settings["ExportExtension"]
    fullPath := savePath . "\" . fileName

    try {
        if FileExist(fullPath) {
            wv.PostWebMessageAsString("notify:warning:File already exists")
            return
        }
        FileAppend(content, fullPath, "UTF-8")
        wv.PostWebMessageAsString("notify:success:Saved as: " . fileName)
        if (Settings["ClearTextAtSave"]) {
            wv.ExecuteScriptAsync("clearTextArea();")
        }
    } catch as err {
        msg := "Export Failed: " . err.Message
        wv.PostWebMessageAsString("notify:error:" . msg)
    }
}
