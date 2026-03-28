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
 * @param {boolean|null} forceState 強制的に設定画面を表示(true)か非表示(false)か
 */
function toggleSetView(forceState = null) {
  const mainView = document.getElementById("main-view");
  const setView = document.getElementById("settings-view");

  const isOpeningSettings =
    forceState !== null ? forceState : setView.classList.contains("hidden");

  if (isOpeningSettings) {
    mainView.classList.add("hidden");
    setView.classList.remove("hidden");
  } else {
    mainView.classList.remove("hidden");
    setView.classList.add("hidden");
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
 * AHK側からの操作をUIコンポーネントに反映させる
 */
function updateUI(key, value) {
  switch (key) {
    case "SaveLog":
      document.getElementById("save-log-check").checked = value;
      break;
    case "MinimizeOption":
      document.getElementById("minimize-option-check").checked = value;
      break;
    case "TriggerKey":
      document.getElementById("trigger-key").value = value;
      break;
    case "TargetAction":
      document.getElementById("target-action").value = value;
      break;
  }
}
