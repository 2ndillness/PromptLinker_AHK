; ==============================================================================
; リサイズ機能 (-Caption ウィンドウ用)
; ==============================================================================
StartResizing() {
    DllCall("User32\ReleaseCapture")
    MouseGetPos(&startX, &startY)
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . MainGui.Hwnd)

    ; ドラッグ中の処理
    while GetKeyState("LButton", "P") {
        MouseGetPos(&curX, &curY)
        newW := winW + (curX - startX)
        newH := winH + (curY - startY)

        ; 最小サイズ制限 (300x150)
        if (newW < 300)
            newW := 300
        if (newH < 150)
            newH := 150

        WinMove(winX, winY, newW, newH, "ahk_id " . MainGui.Hwnd)
        Sleep(10)
    }
    ; リサイズ終了後にWebView2を再調整（念のため）
    if (wvc)
        wvc.Fill()
}

; ==============================================================================
; スナップ機能 (Win + 矢印)
; -Caption ウィンドウでもショートカットで配置できるようにする
; ==============================================================================
#HotIf WinActive("ahk_id " . MainGui.Hwnd)
#Left:: SnapWindow("Left")
#Right:: SnapWindow("Right")
#Up:: SnapWindow("Max")
#Down:: SnapWindow("Min")
#HotIf

SnapWindow(pos) {
    ; 現在のモニタの作業領域(タスクバー除く)を取得
    MonitorGetWorkArea(MonitorGetPrimary(), &WALeft, &WATop, &WARight, &WABottom)
    WAWidth := WARight - WALeft
    WAHeight := WABottom - WATop

    WinGetPos(&currX, &currY, &currW, &currH, "ahk_id " . MainGui.Hwnd)

    if (pos == "Left") {
        WinRestore("ahk_id " . MainGui.Hwnd)
        WinMove(
            WALeft,
            WATop,
            WAWidth / 2,
            WAHeight,
            "ahk_id " . MainGui.Hwnd
        )
    } else if (pos == "Right") {
        WinRestore("ahk_id " . MainGui.Hwnd)
        WinMove(
            WALeft + WAWidth / 2,
            WATop,
            WAWidth / 2,
            WAHeight,
            "ahk_id " . MainGui.Hwnd
        )
    } else if (pos == "Max") {
        WinMaximize("ahk_id " . MainGui.Hwnd)
    } else if (pos == "Min") {
        isMax := WinGetMinMax("ahk_id " . MainGui.Hwnd)
        if (isMax == 1) {
            WinRestore("ahk_id " . MainGui.Hwnd)
        } else {
            WinMinimize("ahk_id " . MainGui.Hwnd)
        }
    }

    ; サイズ変更イベントを発火させてWebViewを調整
    Gui_Size(MainGui, 0, 0, 0)
}