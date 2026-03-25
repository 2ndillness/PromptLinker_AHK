; ==============================================================================
; リサイズ機能 (-Caption ウィンドウ用)
; ==============================================================================
StartResize() {
    global MainGui, wvc
    CoordMode "Mouse", "Screen"

    DllCall("User32\ReleaseCapture")
    MouseGetPos(&startX, &startY)
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . MainGui.Hwnd)

    ; リサイズ中の描画負荷を軽減するため、Sizeイベントを一時的に無効化
    MainGui.OnEvent("Size", %"Gui_Size"%, 0)

    ; ドラッグ中の処理
    while GetKeyState("LButton", "P") {
        MouseGetPos(&curX, &curY)
        newW := winW + (curX - startX)
        newH := winH + (curY - startY)

        ; 最小サイズ制限 (450x200)
        if (newW < 450)
            newW := 450
        if (newH < 200)
            newH := 200

        WinMove(winX, winY, newW, newH, "ahk_id " . MainGui.Hwnd)
        Sleep(10)
    }

    ; イベントを再開し、最終的なサイズにWebView2を合わせる
    MainGui.OnEvent("Size", %"Gui_Size"%, 1)
    if (IsSet(wvc) && wvc)
        wvc.Fill()
}

; ==============================================================================
; スナップ機能 (Win + 矢印)
; -Caption ウィンドウでもショートカットで配置できるようにする
; ==============================================================================
#HotIf WinActive("ahk_id " . (IsSet(MainGui) ? MainGui.Hwnd : 0))
#Left:: SnapWin("Left")
#Right:: SnapWin("Right")
#Up:: SnapWin("Up")
#Down:: SnapWin("Down")
#HotIf

SnapWin(dir) {
    global MainGui
    if !WinExist("ahk_id " . MainGui.Hwnd)
        return

    ; 現在のウィンドウ位置を取得
    WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " . MainGui.Hwnd)

    ; ウィンドウの中心点があるモニタの作業領域を取得
    cX := wx + ww / 2, cY := wy + wh / 2
    mLeft := 0, mTop := 0, mRight := 0, mBottom := 0
    loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &L, &T, &R, &B)
        if (cX >= L && cX <= R && cY >= T && cY <= B) {
            mLeft := L, mTop := T, mRight := R, mBottom := B
            break
        }
    }
    ; モニタが特定できない場合のフォールバック
    if (mRight == 0)
        MonitorGetWorkArea(MonitorGetPrimary(), &mLeft, &mTop, &mRight, &mBottom)

    mW := mRight - mLeft, mH := mBottom - mTop

    ; 状態判定 (許容誤差を含める)
    tol := 15
    isMax := WinGetMinMax("ahk_id " . MainGui.Hwnd) == 1
    isLHalf := !isMax && Abs(wx - mLeft) < tol && Abs(wy - mTop) < tol && Abs(ww - mW / 2) < tol && Abs(wh - mH) < tol
    isRHalf := !isMax && Abs(wx - (mLeft + mW / 2)) < tol && Abs(wy - mTop) < tol && Abs(ww - mW / 2) < tol && Abs(wh - mH) < tol
    isTLeft := !isMax && Abs(wx - mLeft) < tol && Abs(wy - mTop) < tol && Abs(ww - mW / 2) < tol && Abs(wh - mH / 2) < tol
    isTRight := !isMax && Abs(wx - (mLeft + mW / 2)) < tol && Abs(wy - mTop) < tol && Abs(ww - mW / 2) < tol && Abs(wh - mH / 2) < tol
    isBLeft := !isMax && Abs(wx - mLeft) < tol && Abs(wy - (mTop + mH / 2)) < tol && Abs(ww - mW / 2) < tol && Abs(wh - mH / 2) < tol
    isBRight := !isMax && Abs(wx - (mLeft + mW / 2)) < tol && Abs(wy - (mTop + mH / 2)) < tol && Abs(ww - mW / 2) < tol && Abs(wh - mH / 2) < tol

    ; 移動用ヘルパー
    SetPos(x, y, w, h) {
        if WinGetMinMax("ahk_id " . MainGui.Hwnd) != 0
            WinRestore("ahk_id " . MainGui.Hwnd)
        WinMove(x, y, w, h, "ahk_id " . MainGui.Hwnd)
    }

    ; 方向に応じた遷移ロジック
    if (dir == "Up") {
        if (isLHalf)
            SetPos(mLeft, mTop, mW / 2, mH / 2)           ; 左半分 -> 左上
        else if (isRHalf)
            SetPos(mLeft + mW / 2, mTop, mW / 2, mH / 2)   ; 右半分 -> 右上
        else if (isBLeft)
            SetPos(mLeft, mTop, mW / 2, mH)             ; 左下 -> 左半分
        else if (isBRight)
            SetPos(mLeft + mW / 2, mTop, mW / 2, mH)     ; 右下 -> 右半分
        else
            WinMaximize("ahk_id " . MainGui.Hwnd)    ; その他 -> 最大化
    }
    else if (dir == "Down") {
        if (isMax)
            WinRestore("ahk_id " . MainGui.Hwnd)     ; 最大化 -> 復元
        else if (isTLeft)
            SetPos(mLeft, mTop, mW / 2, mH)             ; 左上 -> 左半分
        else if (isTRight)
            SetPos(mLeft + mW / 2, mTop, mW / 2, mH)     ; 右上 -> 右半分
        else if (isLHalf)
            SetPos(mLeft, mTop + mH / 2, mW / 2, mH / 2)   ; 左半分 -> 左下
        else if (isRHalf)
            SetPos(mLeft + mW / 2, mTop + mH / 2, mW / 2, mH / 2) ; 右半分 -> 右下
        else
            WinMinimize("ahk_id " . MainGui.Hwnd)    ; その他 -> 最小化
    }
    else if (dir == "Left") {
        if (isMax || isRHalf || (!isLHalf && !isTLeft && !isBLeft))
            SetPos(mLeft, mTop, mW / 2, mH)             ; 右半分/最大化/通常 -> 左半分
        else if (isTRight)
            SetPos(mLeft, mTop, mW / 2, mH / 2)           ; 右上 -> 左上
        else if (isBRight)
            SetPos(mLeft, mTop + mH / 2, mW / 2, mH / 2)   ; 右下 -> 左下
    }
    else if (dir == "Right") {
        if (isMax || isLHalf || (!isRHalf && !isTRight && !isBRight))
            SetPos(mLeft + mW / 2, mTop, mW / 2, mH)     ; 左半分/最大化/通常 -> 右半分
        else if (isTLeft)
            SetPos(mLeft + mW / 2, mTop, mW / 2, mH / 2)   ; 左上 -> 右上
        else if (isBLeft)
            SetPos(mLeft + mW / 2, mTop + mH / 2, mW / 2, mH / 2) ; 左下 -> 右下
    }

    ; WebView2の描画更新
    if (IsSet(MainGui) && MainGui) {
        newMinMax := WinGetMinMax("ahk_id " . MainGui.Hwnd)
        Gui_Size(MainGui, newMinMax, 0, 0)
    }
}