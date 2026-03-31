; コアロジックライブラリ

/**
 * ターゲットウィンドウへテキストを転送し、設定に応じたアクションを実行する
 */
ExecuteTransfer(text) {
    global TargetHWND, TargetProcess, Settings, MainGui, wv
    if (text == "" || TargetHWND == 0 || !WinExist("ahk_id " . TargetHWND)) {
        wv.PostWebMessageAsString("notify:error:Target window not found")
        return
    }

    if (Settings["SaveLog"]) {
        SaveToLog(text, TargetProcess)
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
    wv.ExecuteScriptAsync("document.getElementById('main-textarea').value = '';")

    if (Settings["MinimizeOption"]) {
        WinMinimize("ahk_id " . MainGui.Hwnd)
    } else {
        WinActivate("ahk_id " . MainGui.Hwnd)
        wv.ExecuteScriptAsync("document.getElementById('main-textarea')"
            . ".focus();")
    }
}



/**
 * 新しいターゲットをスロットに登録する
 */
AddTargetSlot(hwnd, exe, action) {
    global TargetSlots, CurrentSlotIndex, wv

    ; 重複チェック（HWNDが既に存在すればそのスロットを選択）
    for index, slot in TargetSlots {
        if (slot.hwnd == hwnd) {
            CurrentSlotIndex := index
            slot.action := action ; アクションのみ最新に更新
            SyncSlotsToJS()
            return
        }
    }

    ; 1. 空きスロット（かつアンロック）を探す
    added := false
    for index, slot in TargetSlots {
        if (!slot.locked && (slot.hwnd == 0
            || !WinExist("ahk_id " . slot.hwnd))) {
            TargetSlots[index].hwnd := hwnd

            TargetSlots[index].exe := exe
            TargetSlots[index].action := action

            CurrentSlotIndex := index
            added := true
            break
        }
    }

    ; 2. 空きがなければ「現在の次」から順にアンロックなスロットを探して上書き
    if (!added) {
        checkIdx := CurrentSlotIndex
        Loop 3 {
            checkIdx := Mod(checkIdx, 3) + 1
            if (!TargetSlots[checkIdx].locked) {
                TargetSlots[checkIdx] := {
                    hwnd: hwnd, exe: exe, action: action, locked: false
                }
                CurrentSlotIndex := checkIdx

                added := true
                break
            }
        }

    }

    ; 3. 全てロックされている場合
    if (!added) {
        wv.PostWebMessageAsString("notify:warning:All slots are locked")
        return
    }

    SyncSlotsToJS()
}

/**
 * 指定したスロットに切り替える
 */
SwitchTargetSlot(index) {
    global TargetSlots, CurrentSlotIndex, TargetHWND, TargetProcess, Settings
    global MainGui, AppName, wv

    if (index < 1 || index > 3)
        return

    slot := TargetSlots[index]
    if (slot.hwnd == 0) {
        wv.PostWebMessageAsString("notify:error:Slot "
            . index . " is empty")
        return
    }



    if (!WinExist("ahk_id " . slot.hwnd)) {
        wv.PostWebMessageAsString("notify:error:Target window "
            . "no longer exists")
        slot.hwnd := 0
        slot.exe := ""


        SyncSlotsToJS()
        return
    }

    CurrentSlotIndex := index
    TargetHWND := slot.hwnd
    TargetProcess := slot.exe
    Settings["TargetAction"] := slot.action

    ; UI更新
    MainGui.Title := AppName . " - Linked: " . TargetProcess
    wv.ExecuteScriptAsync("updateUI('TargetAction', '" . slot.action . "');")
    wv.ExecuteScriptAsync("updateLinkButton('Relink');")
    SyncSlotsToJS()
    wv.PostWebMessageAsString("notify:success:Switched to Slot " . index)
}

/**
 * スロットのロック状態を切り替える
 */
ToggleSlotLock(index) {
    global TargetSlots, wv
    if (index < 1 || index > 3) {
        return
    }
    
    slot := TargetSlots[index]
    if (slot.hwnd == 0) {
        wv.PostWebMessageAsString("notify:warning:Slot " . index . " is empty")
        return
    }

    slot.locked := !slot.locked
    SyncSlotsToJS()
    status := slot.locked ? "Locked" : "Unlocked"
    wv.PostWebMessageAsString("notify:success:Slot "
        . index . " " . status)
}



/**
 * スロットをクリア（アンリンク）する
 */
ClearTargetSlot(index) {
    global TargetSlots, CurrentSlotIndex, TargetHWND, TargetProcess, MainGui, AppName, wv
    if (index < 1 || index > 3) {
        return
    }

    slot := TargetSlots[index]
    if (slot.hwnd == 0) {
        wv.PostWebMessageAsString("notify:warning:Slot "
            . index . " is already empty")
        return
    }



    ; ロックされている場合はクリアさせない
    if (slot.locked) {
        wv.PostWebMessageAsString(
            "notify:warning:Unlock slot " . index . " first")
        return
    }


    slot.hwnd := 0
    slot.exe := ""
    
    ; 現在選択中のスロットをクリアした場合の処理
    if (index == CurrentSlotIndex) {
        TargetHWND := 0
        TargetProcess := ""
        MainGui.Title := AppName . " - Unlinked"
        wv.ExecuteScriptAsync("updateLinkButton('Link Target');")
    }

    SyncSlotsToJS()
    wv.PostWebMessageAsString("notify:success:Slot " . index . " Cleared")
}

/**
 * 現在のスロットのアクションを更新
 */
UpdateSlotAction(action) {
    global TargetSlots, CurrentSlotIndex
    if (TargetSlots[CurrentSlotIndex].hwnd != 0) {
        TargetSlots[CurrentSlotIndex].action := action
        SyncSlotsToJS()
    }
}

/**
 * スロット情報をJS側に同期
 */
SyncSlotsToJS() {
    global TargetSlots, CurrentSlotIndex, wv
    jsonStr := "["
    for index, slot in TargetSlots {
        exeName := slot.exe ? slot.exe : "(Empty)"
        active := (index == CurrentSlotIndex) ? "true" : "false"
        locked := slot.locked ? "true" : "false"
        jsonStr .= '{"index":' index ',"exe":"' exeName
            . '","active":' active ',"locked":' locked '}'

        if (index < 3)
            jsonStr .= ","

    }
    jsonStr .= "]"
    wv.ExecuteScriptAsync("updateTargetSlots(" . jsonStr . ");")
}

/**
 * ターゲットスロットの存在を監視し、閉じられた場合はクリアする
 */
MonitorTargetStatus() {
    global TargetSlots, CurrentSlotIndex, TargetHWND, TargetProcess, MainGui, AppName, wv
    changed := false

    for index, slot in TargetSlots {
        if (slot.hwnd != 0 && !WinExist("ahk_id " . slot.hwnd)) {
            slot.hwnd := 0
            slot.exe := ""
            changed := true

            ; 現在選択中のスロットが閉じられた場合
            if (index == CurrentSlotIndex) {
                TargetHWND := 0
                TargetProcess := ""
                MainGui.Title := AppName . " - Unlinked"
                wv.ExecuteScriptAsync("updateLinkButton('Link Target');")
                wv.ExecuteScriptAsync("updateUI('TargetAction', 'Enter');")
            }
        }
    }

    if (changed) {
        SyncSlotsToJS()
    }
}

SaveAndExit(*) {
    global MainGui, wvc, wv
    ; ウィンドウを即座に隠してユーザーに終了を印象付ける
    MainGui.Hide()
    SaveSettings()

    ; WebView2リソースの解放
    wv := ""
    wvc := ""

    ExitApp()
}
