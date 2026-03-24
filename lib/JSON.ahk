#Requires AutoHotkey v2.0

/**
 * JSONの相互変換を行うクラス
 */
class JSON {
    static null := ComValue(1, 0)
    static true := ComValue(0xB, 1)
    static false := ComValue(0xB, 0)

    static Dump(obj, indent := "") {
        return this._Dump(obj, indent, "")
    }

    static _Dump(obj, indent, prefix) {
        if IsObject(obj) {
            if obj is Array {
                if !obj.Length
                    return "[]"
                s := "", step := indent ? "`n" . prefix . indent : ""
                for v in obj
                    s .= "," . step . this._Dump(v, indent, prefix . indent)
                return "[" . SubStr(s, 2) . (indent ? "`n" . prefix : "") . "]"
            }
            if obj is Map {
                if !obj.Count
                    return "{}"
                s := "", step := indent ? "`n" . prefix . indent : ""
                for k, v in obj {
                    val := this._Dump(v, indent, prefix . indent)
                    key := this._Dump(k, indent, prefix . indent)
                    s .= "," . step . key . (indent ? ": " : ":") . val
                }
                return "{" . SubStr(s, 2) . (indent ? "`n" . prefix : "") . "}"
            }
            throw Error("Object type not supported.", -1, Type(obj))
        } else if IsNumber(obj)
            return String(obj)
        else if obj == this.null
            return "null"
        else if obj == this.true
            return "true"
        else if obj == this.false
            return "false"

        ; 文字列のエスケープ処理
        obj := StrReplace(obj, "\", "\\")
        obj := StrReplace(obj, "`"", "\`"")
        obj := StrReplace(obj, "`n", "\n")
        obj := StrReplace(obj, "`r", "\r")
        obj := StrReplace(obj, "`t", "\t")
        return "`"" . obj . "`""
    }

    static Load(text) {
        try {
            html := ComObject("htmlfile")
            html.write("<meta http-equiv='X-UA-Compatible' content='IE=9'>")
            v := html.parentWindow.JSON.parse(text)
            return this._Convert(v)
        } catch
            throw Error("Invalid JSON", -1)
    }

    static _Convert(v) {
        if IsObject(v) {
            ; JavaScriptのArray判定
            if v.constructor.toString() == "function Array() { [native code] }" {
                arr := []
                loop v.length
                    arr.Push(this._Convert(v.%A_Index - 1%))
                return arr
            } else {
                m := Map()
                for k in v
                    m[k] := this._Convert(v.%k%)
                return m
            }
        }
        return v
    }
}
