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
});

/**
 * 全アイコンのレンダリング
 */
function renderIcons() {
  const placeholders = document.querySelectorAll(".icon-placeholder");
  placeholders.forEach(el => {
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
 * 最大化ボタンのアイコン切り替え
 * @param {boolean} isMaximized
 */
function updateMaxIcon(isMaximized) {
  const btn = document.getElementById("max-btn");
  const placeholder = btn.querySelector(".icon-placeholder");
  if (isMaximized) {
    updateIcon(placeholder, "restore");
    btn.title = "Restore";
  } else {
    updateIcon(placeholder, "maximize");
    btn.title = "Maximize";
  }
}

/**
 * AHKからの設定をUIに反映
 */
function initSettings(settings) {
  document.getElementById("send-mode").value = settings.SendMode;
  updateFontSize(settings.FontSize);
  document.getElementById("save-log-check").checked = settings.SaveLog;
  document.getElementById("log-dir-display").value = settings.LogDir;
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
function toggleSettingsView() {
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
  if (e.ctrlKey && e.key === "Enter") {
    sendMsg("transfer:" + textArea.value);
  }
});

textArea.addEventListener("contextmenu", (e) => {
  e.preventDefault();
  contextMenu.style.left = e.clientX + "px";
  contextMenu.style.top = e.clientY + "px";
  contextMenu.style.display = "block";
});

window.addEventListener("click", (e) => {
  if (!contextMenu.contains(e.target)) {
    contextMenu.style.display = "none";
  }
});

/**
 * コンテキストメニューコマンド実行
 */
function execCmd(cmd) {
  textArea.focus();
  document.execCommand(cmd);
  contextMenu.style.display = "none";
}
