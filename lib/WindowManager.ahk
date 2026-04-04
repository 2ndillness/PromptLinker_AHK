; ウィンドウ管理ライブラリ

/**
 * ターゲットウィンドウのリンクを開始
 */
StartLinking() {
    global IsLinking, StartTime, MainGui, AppName, wv, IsRecordingHotkey
    IsLinking := true
    MainGui.Title := AppName . " - Waiting for target window..."
    wv.PostWebMessageAsString("notify:info:Click Target Window...")
    wv.ExecuteScriptAsync("setLinkWaiting(true);")
    StartTime := A_TickCount
    SetTimer(CheckActiveWindow, 100)
}



/**
 * リンク処理を中断
 * @param {string} msg 通知メッセージ
 */
CancelLinking(msg := "Cancelled") {
    global IsLinking, MainGui, AppName, wv
    IsLinking := false
    SetTimer(CheckActiveWindow, 0)
    MainGui.Title := AppName " - Unlinked"
    type := (msg == "Timeout") ? "error" : "warning"
    wv.PostWebMessageAsString("notify:" type ":" msg)
    wv.ExecuteScriptAsync("setLinkWaiting(false);")
}

/**
 * アクティブウィンドウを監視しリンクを確定
 */
CheckActiveWindow() {
    global IsLinking, TargetHWND, TargetProcess, MainGui, AppName, wv, StartTime, Settings
    currentHWND := WinActive("A")
    if (currentHWND != 0 && currentHWND != MainGui.Hwnd) {
        SetTimer(CheckActiveWindow, 0)
        IsLinking := false
        TargetHWND := currentHWND
        TargetProcess := WinGetProcessName("ahk_id " TargetHWND)
        MainGui.Title := AppName " - Linked: " TargetProcess


        ; スロットに追加
        AddTargetSlot(TargetHWND, TargetProcess
            , Settings["TargetAction"])

        wv.PostWebMessageAsString("notify:success:Linked: " TargetProcess)
        wv.ExecuteScriptAsync("setLinkWaiting(false);")
        WinActivate("ahk_id " MainGui.Hwnd)
    } else if (A_TickCount - StartTime > 10000) {

        CancelLinking("Timeout")
    }
}

/**
 * ウィンドウ位置をプリセットに保存
 */
SaveWindowPreset(index) {
    global MainGui, IsToolbarHidden, Settings, IsRecordingHotkey
    if (IsRecordingHotkey)
        return

    WinGetPos(&x, &y, &w, &h, "ahk_id " . MainGui.Hwnd)
    presetData := Map(
        "x", x, "y", y, "w", w, "h", h,
        "isToolbarHidden", IsToolbarHidden,
        "action", Settings["TargetAction"]
    )
    Settings["Presets"][String(index)] := presetData
    wv.PostWebMessageAsString("notify:success:Preset " . index . " Saved!")
    SaveSettings()
}


/**
 * プリセットの座標を適用
 */
ApplyWindowPreset(index) {
    global Settings, MainGui, wv, IsToolbarHidden, IsRecordingHotkey
    if (IsRecordingHotkey)
        return
    preset := Settings["Presets"][String(index)]
    if (preset == "" || !(preset is Map)) {
        wv.PostWebMessageAsString("notify:error:Preset " . index . " is empty.")
        return
    }
    if (!IsWindowVisible(preset["x"], preset["y"])) {
        preset["x"] := 100
        preset["y"] := 100
    }
    MainGui.Move(preset["x"], preset["y"], preset["w"], preset["h"])
    if (preset.Has("isToolbarHidden")) {
        IsToolbarHidden := preset["isToolbarHidden"]
        wv.PostWebMessageAsString(IsToolbarHidden ? "hideToolbar" 
            : "showToolbar")
    }



    ; ターゲットアクションの復元
    if (preset.Has("action")) {
        UpdateTargetAction(preset["action"])
    }

    wv.PostWebMessageAsString("notify:success:Preset " . index . " Applied")
    WinActivate("ahk_id " . MainGui.Hwnd)
}



/**
 * 指定座標がモニター内にあるか確認
 */
IsWindowVisible(x, y) {
    visible := false
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
        ; スナップ時のわずかな画面外や、タイトルバーの一部が
        ; 画面内にあれば許容するため、マージン(100px)を設ける
        if (x >= l - 100 && x < r && y >= t - 100 && y < b) {
            visible := true
            break
        }
    }
    return visible
}

/**
 * ツールバーの表示状態を切り替え
 */
SetToolbarState(hide) {
    global IsToolbarHidden, wv, IsRecordingHotkey
    if (IsRecordingHotkey)
        return
    IsToolbarHidden := hide
    wv.PostWebMessageAsString(hide ? "hideToolbar" : "showToolbar")
}