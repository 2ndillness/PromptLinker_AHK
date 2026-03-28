; ホットキー管理用ライブラリ

global CurrentFocusHotkey := ""

/**
 * アプリを最前面に呼ぶホットキーを設定
 * @param {string} newKey AHK形式のキー表記
 */
SetFocusHotkey(newKey) {
    global CurrentFocusHotkey, wv
    HotIf() ; グローバル登録のためコンテキストをリセット

    ; 以前のホットキーがあれば無効化
    if (CurrentFocusHotkey != "") {
        try Hotkey(CurrentFocusHotkey, "Off")
    }

    ; 新しいホットキーを登録 (空文字の場合は登録解除のみ)
    if (newKey != "") {
        try {
            Hotkey(newKey, FocusApp, "On")
            CurrentFocusHotkey := newKey
        } catch as err {
            wv.PostWebMessageAsString(
                "notify:error:Hotkey Registration Failed: " . newKey
            )
            CurrentFocusHotkey := ""
        }
    }
}

/**
 * アプリケーションウィンドウをアクティブ化する
 */
FocusApp(hk) {
    global MainGui, IsRecordingHotkey
    if (IsRecordingHotkey)
        return
    if WinExist("ahk_id " . MainGui.Hwnd) {
        WinActivate("ahk_id " . MainGui.Hwnd)
    }
}