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
  const select = document.getElementById("send-mode");
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
  if (e.ctrlKey && e.key === "Enter") {
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
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(-20px)';
    toast.style.transition = 'all 0.3s ease-in';
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
