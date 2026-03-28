/**
 * ターゲットウィンドウへテキストを転送し、設定に応じたアクションを実行する
 */
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

SaveAndExit(*) {
    SaveSettings()
    ExitApp()
}