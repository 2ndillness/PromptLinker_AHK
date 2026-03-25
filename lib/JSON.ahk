#Requires AutoHotkey v2.0

/**
 * JSONの相互変換を行うクラス
 */
class JSON {
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

        ; 文字列のエスケープ処理
        obj := StrReplace(obj, "\", "\\")
        obj := StrReplace(obj, "`"", "\`"")
        obj := StrReplace(obj, "`n", "\n")
        obj := StrReplace(obj, "`r", "\r")
        obj := StrReplace(obj, "`t", "\t")
        return "`"" . obj . "`""
    }

    static Load(text) {
        text := StrReplace(text, "`r", "")
        pos := 1
        len := StrLen(text)
        return this._ParseValue(text, &pos, len)
    }

    static _ParseValue(text, &pos, len) {
        while pos <= len && InStr(" `t`n", SubStr(text, pos, 1))
            pos++
        if pos > len
            return ""

        char := SubStr(text, pos, 1)
        if char == "{"
            return this._ParseObject(text, &pos, len)
        if char == "["
            return this._ParseArray(text, &pos, len)
        if char == '"'
            return this._ParseString(text, &pos, len)
        if IsNumber(char) || char == "-"
            return this._ParseNumber(text, &pos, len)
        if SubStr(text, pos, 4) = "true" {
            pos += 4
            return 1
        }
        if SubStr(text, pos, 5) = "false" {
            pos += 5
            return 0
        }
        if SubStr(text, pos, 4) = "null" {
            pos += 4
            return ""
        }
        throw Error("Invalid JSON at position " . pos)
    }

    static _ParseObject(text, &pos, len) {
        pos++
        obj := Map()
        while pos <= len {
            while pos <= len && InStr(" `t`n", SubStr(text, pos, 1))
                pos++
            if SubStr(text, pos, 1) == "}" {
                pos++
                return obj
            }
            if SubStr(text, pos, 1) != '"'
                throw Error("Expected key at position " . pos)
            key := this._ParseString(text, &pos, len)

            while pos <= len && InStr(" `t`n", SubStr(text, pos, 1))
                pos++
            if SubStr(text, pos, 1) != ":"
                throw Error("Expected ':' at position " . pos)
            pos++
            val := this._ParseValue(text, &pos, len)
            obj[key] := val

            while pos <= len && InStr(" `t`n", SubStr(text, pos, 1))
                pos++
            char := SubStr(text, pos, 1)
            if char == "}" {
                pos++
                return obj
            }
            if char == ","
                pos++
            else
                throw Error("Expected '}' or ',' at position " . pos)
        }
    }

    static _ParseArray(text, &pos, len) {
        pos++
        arr := []
        while pos <= len {
            while pos <= len && InStr(" `t`n", SubStr(text, pos, 1))
                pos++
            if SubStr(text, pos, 1) == "]" {
                pos++
                return arr
            }
            val := this._ParseValue(text, &pos, len)
            arr.Push(val)
            while pos <= len && InStr(" `t`n", SubStr(text, pos, 1))
                pos++
            char := SubStr(text, pos, 1)
            if char == "]" {
                pos++
                return arr
            }
            if char == ","
                pos++
            else
                throw Error("Expected ']' or ',' at position " . pos)
        }
    }

    static _ParseString(text, &pos, len) {
        pos++
        str := ""
        while pos <= len {
            char := SubStr(text, pos, 1)
            if char == '"' {
                pos++
                return str
            }
            if char == "\" {
                pos++
                char := SubStr(text, pos, 1)
                if char == "u" {
                    pos++
                    code := SubStr(text, pos, 4)
                    str .= Chr("0x" . code)
                    pos += 4
                } else {
                    if char == "n"
                        str .= "`n"
                    else if char == "r"
                        str .= "`r"
                    else if char == "t"
                        str .= "`t"
                    else
                        str .= char
                    pos++
                }
            } else {
                str .= char
                pos++
            }
        }
    }

    static _ParseNumber(text, &pos, len) {
        start := pos
        while pos <= len && (IsNumber(SubStr(text, pos, 1)) || InStr("-.eE+", SubStr(text, pos, 1)))
            pos++
        numStr := SubStr(text, start, pos - start)
        return IsNumber(numStr) ? numStr + 0 : numStr
    }
}