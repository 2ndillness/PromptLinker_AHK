; プロンプト保存（エクスポート）管理ライブラリ
; @file Lib\ExportHandler.ahk

/**
 * 保存先ディレクトリを選択する
 */
SelectExportDir(*) {
    global MainGui, Settings, wv
    
    ; 現在の AlwaysOnTop 状態を確認
    isTopmost := WinGetExStyle(MainGui.Hwnd) & 0x8
    
    if (isTopmost)
        MainGui.Opt("-AlwaysOnTop")
        
    ; エクスプローラ形式でフォルダ選択を表示
    prompt := "Select Export Directory"
    selDir := FileSelect("D", "*" . Settings["ExportDir"], prompt)
    
    if (isTopmost)
        MainGui.Opt("+AlwaysOnTop")

    if (selDir != "") {
        ; 書き込み権限テスト
        testFile := selDir "\.write_test"
        try {
            FileAppend("", testFile)
            FileDelete(testFile)
        } catch {
            wv.PostWebMessageAsString("notify:error:Permission Denied")
            return
        }

        Settings["ExportDir"] := selDir
        escapedPath := StrReplace(selDir, "\", "\\")
        wv.ExecuteScriptAsync("updateExportDirectory('" . escapedPath . "');")
        SaveSettings()
    }
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
    if !DirExist(savePath) {
        ; NOTE: ステップ2でこの部分をダイアログ誘導に強化予定
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
