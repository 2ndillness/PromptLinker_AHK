/**
 * Settings and Hotkey Management
 */

/**
 * AHKからの設定をUIに反映
 */
function initSettings(settings) {
  document.getElementById("target-action").value = settings.TargetAction;
  document.getElementById("trigger-key").value =
    settings.TriggerKey || "Ctrl + Enter";
  updateFontSize(settings.FontSize);
  document.getElementById("minimize-option-check").checked =
    settings.MinimizeOption;
  document.getElementById("save-log-check").checked = settings.SaveLog;
  updateLogDirectory(settings.LogDir);

  const hotkeyInput = document.getElementById("hotkey-input");
  if (hotkeyInput) {
    hotkeyInput.value = formatHotkey(settings.FocusHotkey || "^!f");
    hotkeyInput.onkeydown = handleHotkeyInput;
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
    showToast("Shortcut reset to default: " + formatted, "success");
  }
}

/**
 * ホットキー入力ハンドラ
 */
function handleHotkeyInput(e) {
  e.preventDefault();
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
  e.target.value = formatHotkey(ahkString);
  sendMsg("updateSetting:FocusHotkey:" + ahkString);
}
