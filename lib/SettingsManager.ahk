; 設定管理ライブラリ

/**
 * 設定ファイルを読み込む
 */
LoadSettings() {
    global SettingsFile, Settings
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
        msg := "設定ファイル破損のためリセットします。`n"
            . "詳細: " . err.Message . "`n"
            . "読込内容: " . SubStr(raw, 1, 100)
        MsgBox(msg, "Settings Load Error", 48)
        try {
            FileDelete(SettingsFile)
        }
    }
}


/**
 * 現在の設定をファイルに保存
 */
SaveSettings() {
    global Settings, SettingsFile, DataDir, PortableFile, wv
    try {
        if !DirExist(DataDir) && !FileExist(PortableFile) {
            DirCreate(DataDir)
        }
        if (f := FileOpen(SettingsFile, "w", "UTF-8")) {
            f.Write(Jxon_Dump(Settings, "  "))
            f.Close()
        }
    } catch as err {
        wv.PostWebMessageAsString("notify:error:Save Failed:`n" err.Message)
    }
}

/**
 * フォントサイズを変更
 * @param {number} delta 増減値
 */
ChangeFontSize(delta) {
    global Settings, wv
    newSize := Settings["FontSize"] + delta
    if (newSize < 8)
        newSize := 8
    if (newSize > 40)
        newSize := 40
    Settings["FontSize"] := newSize
    wv.ExecuteScriptAsync("updateFontSize(" . newSize . ");")
    SaveSettings()
}

/**
 * 設定ファイルを外部エディタで開く
 */
OpenSettings(*) {
    global SettingsFile, wv
    SaveSettings() ; 最新の状態を書き出してから開く
    if !FileExist(SettingsFile)
        return

    try {
        Run(SettingsFile)
    } catch {
        try {
            Run("notepad.exe " . SettingsFile)
        } catch as err {
            wv.PostWebMessageAsString("notify:error:Open Failed")
        }
    }
}

/**
 * 設定値をトグルしてJS側に通知する共通関数
 * @param {string} key Settingsマップのキー
 */
ToggleSetting(key) {
    global Settings, wv
    Settings[key] := !Settings[key]
    valStr := Settings[key] ? "true" : "false"
    wv.ExecuteScriptAsync("updateUI('" key "', " valStr ");")
    SaveSettings()
    wv.PostWebMessageAsString("notify:success:" . key . " updated")
}

/**
 * 送信トリガーキーをトグルする
 */
ToggleTriggerKey(*) {
    global Settings, wv
    current := Settings["TriggerKey"]
    newVal := (current == "Ctrl + Enter") ? "Shift + Enter" : "Ctrl + Enter"
    Settings["TriggerKey"] := newVal
    wv.ExecuteScriptAsync("updateUI('TriggerKey', '" newVal "');")
    SaveSettings()
    wv.PostWebMessageAsString("notify:success:Trigger: " . newVal)
}


/**
 * ターゲットアクションを更新する
 * @param {string} action アクション名
 */
UpdateTargetAction(action) {
    global Settings, wv
    Settings["TargetAction"] := action
    wv.ExecuteScriptAsync("updateUI('TargetAction', '" action "');")
    
    UpdateSlotAction(action)
    SaveSettings()
    wv.PostWebMessageAsString("notify:success:Action: " . action)
}