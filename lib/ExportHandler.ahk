; プロンプト保存（エクスポート）管理ライブラリ
; @file Lib\ExportHandler.ahk

/**
 * 保存先ディレクトリを選択する
 */
SelectExportDir(*) {
    global MainGui, Settings, wv
    
    ; 現在の AlwaysOnTop 状態を確認
    isOk := false
    isTopmost := Settings["AlwaysOnTop"]
    if (isTopmost)
        MainGui.Opt("-AlwaysOnTop")
        
    Loop {
        ; エクスプローラ形式でフォルダ選択を表示
        prompt := "Select Export Directory"
        selDir := FileSelect("D", "*" . Settings["ExportDir"], prompt)
        
        if (selDir == "")
            break ; キャンセルされた場合は終了

        ; 書き込み権限テスト
        testFile := selDir "\.write_test"
        isOk := false
        try {
            FileAppend("", testFile)
            FileDelete(testFile)
            isOk := true
        } catch {
            msg := "Permission Denied: Please select another directory"
            wv.PostWebMessageAsString("notify:error:" . msg)
            ; ループを継続し、再選択させる
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

    ; ファイル名の生成: YYYYMMDD_HHMMSS_[1行目(20文字)].ext
    timestamp := FormatTime(, "yyyyMMdd_HHmmss")
    
    ; 1行目の抽出とクリーニング
    firstLine := StrSplit(content, "`n", "`r")[1]
    title := SubStr(firstLine, 1, 20)
    ; 禁止文字を置換
    title := RegExReplace(title, "[\\/:*?`"<>|]", "_")
    title := Trim(title)

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
    } catch as err {
        msg := "Export Failed: " . err.Message
        wv.PostWebMessageAsString("notify:error:" . msg)
    }
}
