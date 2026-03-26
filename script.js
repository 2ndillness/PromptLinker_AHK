/**
 * Prompt Linker UI Logic
 */
const textArea = document.getElementById("main-textarea");
const contextMenu = document.getElementById("context-menu");

/**
 * 初期化処理
 */
document.addEventListener("DOMContentLoaded", () => {
  renderIcons();
  if (window.ahkSettings) {
    initSettings(window.ahkSettings);
  }
  textArea.focus();

  // セレクトボックスのアニメーション用
  const select = document.getElementById("target-action");
  const wrapper = select.parentElement;
  select.addEventListener("focus", () => wrapper.classList.add("active"));
  select.addEventListener("blur", () => wrapper.classList.remove("active"));
  select.addEventListener("change", () => select.blur()); // 選択したら閉じる
});

/**
 * 全アイコンのレンダリング
 */
function renderIcons() {
  const placeholders = document.querySelectorAll(".icon-placeholder");
  placeholders.forEach((el) => {
    const iconName = el.getAttribute("data-icon");
    if (ICONS[iconName]) {
      el.innerHTML = ICONS[iconName];
    }
  });
}

/**
 * 特定のアイコンを更新
 */
function updateIcon(el, iconName) {
  if (ICONS[iconName]) {
    el.innerHTML = ICONS[iconName];
    el.setAttribute("data-icon", iconName);
  }
}



/**
 * AHKからの設定をUIに反映
 */
function initSettings(settings) {
  document.getElementById("target-action").value = settings.TargetAction;
  document.getElementById("trigger-key").value =
    settings.TriggerKey || "Ctrl + Enter";
  updateFontSize(settings.FontSize);
  document.getElementById("minimize-after-check").checked =
    settings.MinimizeAfter;
  document.getElementById("save-log-check").checked = settings.SaveLog;
  document.getElementById("log-dir-display").value = settings.LogDir;

  const hotkeyInput = document.getElementById("hotkey-input");
  if (hotkeyInput) {
    hotkeyInput.value = formatHotkey(settings.RestoreHotkey || "^!l");
    hotkeyInput.onkeydown = handleHotkeyInput;
  }
}

/**
 * ホットキーを人間が読みやすい形式に変換 (例: ^!l -> Ctrl + Alt + L)
 */
function formatHotkey(ahkKey) {
  if (!ahkKey) return "None";
  const displayParts = [];

  // モディファイアキーの順序を整えて追加
  if (ahkKey.includes("^")) displayParts.push("Ctrl");
  if (ahkKey.includes("+")) displayParts.push("Shift");
  if (ahkKey.includes("!")) displayParts.push("Alt");
  if (ahkKey.includes("#")) displayParts.push("Win");

  // AHKの特殊記号を除去して残ったキー名を取得
  const keyPart = ahkKey.replace(/[\^\+\!#]/g, "");

  if (keyPart.length === 1) {
    // 1文字（a, b, c...）なら大文字にして追加
    displayParts.push(keyPart.toUpperCase());
  } else if (keyPart) {
    // 特殊キー（Space, Enter, F1...）ならそのまま追加
    displayParts.push(keyPart);
  }

  return displayParts.length > 0 ? displayParts.join(" + ") : "None";
}

/**
 * ホットキーをデフォルト値にリセット
 */
function resetHotkey() {
  const defaultHotkey = "^!l";
  const hotkeyInput = document.getElementById("hotkey-input");
  if (hotkeyInput) {
    const formatted = formatHotkey(defaultHotkey);
    hotkeyInput.value = formatted;
    sendMsg("updateSetting:RestoreHotkey:" + defaultHotkey);
    showToast("Shortcut reset to default: " + formatted, "success");
  }
}

/**
 * AHKへメッセージを送信
 */
function sendMsg(msg) {
  if (window.chrome?.webview) {
    window.chrome.webview.postMessage(msg);
  }
}

/**
 * Linkボタンのテキスト更新
 */
function updateBtn(text) {
  const btn = document.getElementById("link-btn");
  const textEl = btn.querySelector(".btn-text");
  if (textEl) textEl.innerText = text;
}

/**
 * ステータスラベルの更新
 */
function updateStatus(text, type) {
  const el = document.getElementById("status-label");
  el.innerText = text;
  el.className = "status-label " + (type || "");
}

/**
 * フォントサイズの更新
 */
function updateFontSize(size) {
  document.getElementById("font-size-val").innerText = size;
  textArea.style.fontSize = size + "px";
}

/**
 * ログディレクトリ表示の更新
 */
function updateLogDir(path) {
  document.getElementById("log-dir-display").value = path;
}

/**
 * 設定画面の表示切り替え
 */
function toggleSetView() {
  const mainView = document.getElementById("main-view");
  const setView = document.getElementById("settings-view");
  mainView.classList.toggle("hidden");
  setView.classList.toggle("hidden");
  if (!mainView.classList.contains("hidden")) {
    textArea.focus();
  }
}

/**
 * イベントリスナー
 */
textArea.addEventListener("keydown", (e) => {
  const trigger = document.getElementById("trigger-key").value;
  const isCtrlTrigger = trigger === "Ctrl + Enter" && e.ctrlKey && !e.shiftKey;
  const isShiftTrigger =
    trigger === "Shift + Enter" && e.shiftKey && !e.ctrlKey;

  if ((isCtrlTrigger || isShiftTrigger) && e.key === "Enter") {
    e.preventDefault();
    sendMsg("transfer:" + textArea.value);
  }
});

textArea.addEventListener("contextmenu", (e) => {
  e.preventDefault();

  // 位置計算のために一旦表示（非可視）
  contextMenu.style.visibility = "hidden";
  contextMenu.style.display = "block";

  const menuWidth = contextMenu.offsetWidth;
  const menuHeight = contextMenu.offsetHeight;
  const winWidth = window.innerWidth;
  const winHeight = window.innerHeight;

  let x = e.clientX;
  let y = e.clientY;

  if (x + menuWidth > winWidth) x -= menuWidth;
  if (y + menuHeight > winHeight) y -= menuHeight;

  if (x < 0) x = 0;
  if (y < 0) y = 0;

  contextMenu.style.left = x + "px";
  contextMenu.style.top = y + "px";
  contextMenu.style.visibility = "visible";
});

window.addEventListener("click", (e) => {
  if (!contextMenu.contains(e.target)) {
    contextMenu.style.display = "none";
  }
});

/**
 * トースト通知の表示
 * @param {string} msg
 * @param {string} type 'info' | 'error' | 'success'
 */
function showToast(msg, type = "info") {
  const container = document.getElementById("toast-container");
  const toast = document.createElement("div");
  toast.className = `toast ${type}`;
  toast.innerText = msg;

  container.appendChild(toast);

  // 3秒後に削除
  setTimeout(() => {
    toast.style.opacity = "0";
    toast.style.transform = "translateY(-20px)";
    toast.style.transition = "all 0.3s ease-in";
    setTimeout(() => toast.remove(), 300);
  }, 3000);
}

/**
 * AHKからのメッセージを受信
 */
window.chrome.webview.addEventListener("message", (event) => {
  const msg = event.data;
  if (typeof msg !== "string") return;

  if (msg.startsWith("notify:")) {
    const parts = msg.split(":");
    const type = parts[1] || "info";
    const text = parts.slice(2).join(":");
    showToast(text, type);
  }
});

/**
 * ホットキー入力ハンドラ
 * キー入力をAHK形式の文字列(^!lなど)に変換して送信
 */
function handleHotkeyInput(e) {
  e.preventDefault();
  // 修飾キーのみの場合は無視
  if (["Control", "Shift", "Alt", "Meta"].includes(e.key)) return;

  const parts = [];
  if (e.ctrlKey) parts.push("^");
  if (e.shiftKey) parts.push("+");
  if (e.altKey) parts.push("!");
  if (e.metaKey) parts.push("#");

  let key = e.key;
  // 特殊キーの変換マップ
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

  if (map[key]) {
    key = map[key];
  } else if (key.length === 1) {
    key = key.toLowerCase();
  } else if (!key.startsWith("F")) {
    // F1-F12以外で未対応の特殊キーは無視
    return;
  }

  // 安全策: 修飾キーがなく、かつF1-F12でない場合は登録を許可しない
  // (単独の 'a' や 'Enter' などをグローバルホットキーにするとPC操作不能になるため)
  if (parts.length === 0 && !key.match(/^F([1-9]|1[0-2])$/)) {
    showToast("Modifier key (Ctrl/Alt/Shift) required.", "error");
    return;
  }

  const ahkString = parts.join("") + key;
  e.target.value = formatHotkey(ahkString);
  sendMsg("updateSetting:RestoreHotkey:" + ahkString);
}
