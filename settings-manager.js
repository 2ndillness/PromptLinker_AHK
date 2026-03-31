/**
 * Settings and Hotkey Management
 */

/**
 * 使用を制限するホットキーのリスト (AHK形式)
 * 将来的にキーを増やす場合は、この配列に文字列を追加してください。
 */
const HOTKEY_BLACKLIST = [
  // 一般的なアプリ操作 (Ctrl+C, V, A, Z, S, Fなど)
  "^c",
  "^v",
  "^x",
  "^a",
  "^z",
  "^y",
  "^s",
  "^f",
  "^n",
  "^w",
  "^p",
  // Windowsシステム操作 (Win+L, D, E, R, S, X, I, Tabなど)
  "#l",
  "#d",
  "#e",
  "#r",
  "#s",
  "#x",
  "#i",
  "#tab",
  "!tab",
  "!f4",
  // 当アプリで使用済みのキー
  "^Enter",
  "+Enter",
  "^1",
  "^2",
  "^3",
  "^+1",
  "^+2",
  "^+3",
  "^!1",
  "^!2",
  "^!3",
  "^,",
  "!1",
  "!2",
  "!3",

  "+!1",
  "+!2",
  "+!3",
  "!l",
  "!Enter",
  "^!Enter",
  "+!Enter",
  "!p",
  "^tab",
  "^+tab",
  "f1",
  "!j",
  "!r",
  "!t",
  "!k",
  "!d",
  "!b",
  "!-",
  "!=",
  "!+",
  "!m",
  "!s",
  "!o",

];
let recordingTimeout = null;

/**
 * AHKからの設定をUIに反映
 */
function initSettings(settings) {
  const actionLabel = document.getElementById("target-action-label");
  if (actionLabel) {
    actionLabel.innerText = settings.TargetAction;
  }
  const triggerLabel = document.getElementById("trigger-key-label");
  if (triggerLabel) {
    triggerLabel.innerText = settings.TriggerKey || "Ctrl + Enter";
  }
  const mShortcut = document.getElementById("menu-transfer-shortcut");
  if (mShortcut) {
    mShortcut.innerText = settings.TriggerKey || "Ctrl + Enter";
  }
  updateFontSize(settings.FontSize);
  document.getElementById("minimize-option-check").checked =
    settings.MinimizeOption;
  document.getElementById("save-log-check").checked = settings.SaveLog;
  updateLogDirectory(settings.LogDir);

  const hotkeyInput = document.getElementById("hotkey-input");
  if (hotkeyInput) {
    hotkeyInput.value = formatHotkey(settings.FocusHotkey || "^!f");
    hotkeyInput.onkeydown = handleHotkeyInput;

    hotkeyInput.onfocus = () => {
      sendMsg("startRecording");
      hotkeyInput.classList.add("recording");
      hotkeyInput.value = "Recording...";
      // 10秒操作がなければ自動解除
      recordingTimeout = setTimeout(() => {
        // タイムアウト時にエラーとして通知
        showToast("Recording timed out.", "error");
        hotkeyInput.blur();
      }, 10000);
    };

    hotkeyInput.onblur = () => {
      sendMsg("stopRecording");
      hotkeyInput.classList.remove("recording");
      if (recordingTimeout) clearTimeout(recordingTimeout);
      // 現在の設定値に戻す
      hotkeyInput.value = formatHotkey(window.ahkSettings.FocusHotkey);
    };
  }
}

/**
 * ホットキーを人間が読みやすい形式に変換 (例: ^!l -> Ctrl + Alt + L)
 */
function formatHotkey(ahkKey) {
  if (!ahkKey) return "None";
  const displayParts = [];

  if (ahkKey.includes("^")) displayParts.push("Ctrl");
  if (ahkKey.includes("+")) displayParts.push("Shift");
  if (ahkKey.includes("!")) displayParts.push("Alt");
  if (ahkKey.includes("#")) displayParts.push("Win");

  const keyPart = ahkKey.replace(/[\^\+\!#]/g, "");
  if (keyPart.length === 1) {
    displayParts.push(keyPart.toUpperCase());
  } else if (keyPart) {
    displayParts.push(keyPart);
  }

  return displayParts.length > 0 ? displayParts.join(" + ") : "None";
}

/**
 * ホットキーをデフォルト値にリセット
 */
function resetFocusHotkey() {
  const defaultHotkey = "^!f";
  const hotkeyInput = document.getElementById("hotkey-input");
  if (hotkeyInput) {
    const formatted = formatHotkey(defaultHotkey);
    hotkeyInput.value = formatted;
    sendMsg("updateSetting:FocusHotkey:" + defaultHotkey);
    showToast("Hotkey reset to default: " + formatted, "success");
  }
}

/**
 * ホットキー入力ハンドラ
 */
function handleHotkeyInput(e) {
  e.preventDefault();
  if (e.key === "Delete") {
    e.target.blur();
    showToast("Hotkey recording cancelled.", "warning");
    return;
  }

  if (["Control", "Shift", "Alt", "Meta"].includes(e.key)) return;

  const parts = [];
  if (e.ctrlKey) parts.push("^");
  if (e.shiftKey) parts.push("+");
  if (e.altKey) parts.push("!");
  if (e.metaKey) parts.push("#");

  let key = e.key;
  const map = {
    " ": "Space",
    Escape: "Esc",
    Enter: "Enter",
    Tab: "Tab",
    ArrowUp: "Up",
    ArrowDown: "Down",
    ArrowLeft: "Left",
    ArrowRight: "Right",
    Backspace: "BS",
    Delete: "Del",
  };

  key = map[key] || (key.length === 1 ? key.toLowerCase() : key);
  if (!key.startsWith("F") && key.length > 1 && !map[e.key]) return;

  if (parts.length === 0 && !key.match(/^F([1-9]|1[0-2])$/)) {
    showToast("Modifier key (Ctrl/Alt/Shift) required.", "error");
    return;
  }

  const ahkString = parts.join("") + key;

  // ブラックリストチェック (大文字小文字を区別せず比較)
  const isBlacklisted = HOTKEY_BLACKLIST.some(
    (k) => k.toLowerCase() === ahkString.toLowerCase(),
  );

  if (isBlacklisted) {
    showToast(`Hotkey "${formatHotkey(ahkString)}" is reserved.`, "error");
    return;
  }

  const formatted = formatHotkey(ahkString);
  e.target.value = formatted;
  window.ahkSettings.FocusHotkey = ahkString; // 即時同期してロールバックを防止
  sendMsg("updateSetting:FocusHotkey:" + ahkString);
  showToast(`Hotkey updated: ${formatted}`, "success");
  e.target.blur(); // 入力完了時にフォーカスを外して確定させる
}
