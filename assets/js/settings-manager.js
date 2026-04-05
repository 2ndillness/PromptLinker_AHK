/**
 * Settings and Hotkey Management
 */

/**
 * 使用を制限するホットキーのリスト (AHK形式)
 * 将来的にキーを増やす場合は、この配列に文字列を追加
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
  "^r",
  // Windowsシステム操作 (Win+L, D, E, R, S, X, I, Tabなど)
  "#l",
  "#d",
  "#e",
  "#r",
  "#s",
  "#x",
  "#i",
  "#v",
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
  "!c",
  "!t",
  "!k",
  "!b",
  "!-",
  "!=",
  "!m",
  "!e",
  "!a",
  "!o",
  "!h",
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
  document.getElementById("always-on-top-check").checked = settings.AlwaysOnTop;
  const extLabel = document.getElementById("export-ext-label");
  if (extLabel) extLabel.innerText = settings.ExportExtension || ".txt";
  const tabLabel = document.getElementById("tab-behavior-label");
  if (tabLabel) tabLabel.innerText = settings.TabBehavior || "Move Focus";
  updateExportDirectory(settings.ExportDir);

  const exportBtn = document.getElementById("export-btn");
  if (exportBtn) {
    const ext = (settings.ExportExtension || ".txt").replace(".", "");
    exportBtn.title = "Save as " + ext;
  }

  const hotkeyInput = document.getElementById("hotkey-input");
  if (hotkeyInput) {
    hotkeyInput.value = formatHotkey(settings.FocusHotkey || "^!f");
    hotkeyInput.onkeydown = handleHotkeyInput;
    hotkeyInput.onkeyup = (e) => {
      if (["Control", "Shift", "Alt", "Meta"].includes(e.key)) {
        const parts = [];
        if (e.ctrlKey) parts.push("^");
        if (e.shiftKey) parts.push("+");
        if (e.altKey) parts.push("!");
        if (e.metaKey) parts.push("#");

        const currentMods = parts.join("");
        if (hotkeyInput.classList.contains("recording")) {
          hotkeyInput.value = currentMods
            ? formatHotkey(currentMods) + " + ..."
            : "Recording...";
        }
      }
    };

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
    sendMsg("updateSetting", {
      key: "FocusHotkey",
      value: defaultHotkey,
    });
    showToast("Hotkey reset to default:\n" + formatted, "success");
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

  const parts = [];
  if (e.ctrlKey) parts.push("^");
  if (e.shiftKey) parts.push("+");
  if (e.altKey) parts.push("!");
  if (e.metaKey) parts.push("#");

  // モディファイアキーのみの場合はプレビューを表示して終了
  if (["Control", "Shift", "Alt", "Meta"].includes(e.key)) {
    const currentMods = parts.join("");
    e.target.value = currentMods
      ? formatHotkey(currentMods) + " + ..."
      : "Recording...";
    return;
  }

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
    showToast(`Hotkey is reserved:\n"${formatHotkey(ahkString)}"`, "error");
    return;
  }

  const formatted = formatHotkey(ahkString);
  e.target.value = formatted;
  window.ahkSettings.FocusHotkey = ahkString; // 即時同期してロールバックを防止
  sendMsg("updateSetting", {
    key: "FocusHotkey",
    value: ahkString,
  });
  showToast(`Hotkey updated: ${formatted}`, "success");
  e.target.blur(); // 入力完了時にフォーカスを外して確定させる
}
