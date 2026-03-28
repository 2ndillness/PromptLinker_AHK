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
 * AHKへメッセージを送信
 */
function sendMsg(msg) {
  if (window.chrome?.webview) {
    window.chrome.webview.postMessage(msg);
  }
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
  } else if (msg === "hideToolbar") {
    document.querySelector(".toolbar").classList.add("collapsed");
  } else if (msg === "showToolbar") {
    document.querySelector(".toolbar").classList.remove("collapsed");
  }
});

/**
 * テキスト編集コマンドの実行
 * @param {string} cmd
 */
async function execCmd(cmd) {
  textArea.focus();
  const start = textArea.selectionStart;
  const end = textArea.selectionEnd;
  const selectedText = textArea.value.substring(start, end);

  try {
    switch (cmd) {
      case "cut":
        if (start !== end) {
          await navigator.clipboard.writeText(selectedText);
          textArea.setRangeText("", start, end, "end");
          textArea.dispatchEvent(new Event("input"));
        }
        break;
      case "copy":
        if (start !== end) {
          await navigator.clipboard.writeText(selectedText);
        }
        break;
      case "paste":
        const text = await navigator.clipboard.readText();
        textArea.setRangeText(text, start, end, "end");
        textArea.dispatchEvent(new Event("input"));
        break;
      case "selectAll":
        textArea.select();
        break;
    }
  } catch (err) {
    console.error(`${cmd} failed: `, err);
  }
  contextMenu.style.display = "none";
}
