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
 * 表示ビューの切り替え管理
 * 将来的にログ画面を追加する場合は、この配列に ID を追加するだけで対応可能です。
 */
const APP_VIEWS = ["main-view", "settings-view", "help-view"];

/**
 * 指定されたビューを表示し、他を非表示にする
 * @param {string} targetId 表示する要素のID
 */
function showView(targetId) {
  APP_VIEWS.forEach((id) => {
    const el = document.getElementById(id);
    if (!el) return;

    if (id === targetId) {
      el.classList.remove("hidden");
      if (id === "main-view") textArea.focus();
    } else {
      el.classList.add("hidden");
    }
  });
}

/**
 * 設定画面の表示切り替え
 * @param {boolean|null} forceState 強制的に設定画面を表示(true)か非表示(false)か
 */
function toggleSetView(forceState = null) {
  const isOpeningSettings =
    forceState !== null
      ? forceState
      : document.getElementById("settings-view").classList.contains("hidden");

  showView(isOpeningSettings ? "settings-view" : "main-view");
}

/**
 * ビューを順番に切り替える (Ctrl+Tab 用)
 * @param {number} direction 1: 次へ, -1: 前へ
 */
function rotateView(direction) {
  const currentIndex = APP_VIEWS.findIndex(
    (id) => !document.getElementById(id).classList.contains("hidden"),
  );
  // 負の数に対応したループ計算
  const nextIndex =
    (currentIndex + direction + APP_VIEWS.length) % APP_VIEWS.length;
  showView(APP_VIEWS[nextIndex]);
}

/**
 * インデックス指定でビューを切り替える (Ctrl+1, 2... 用)
 * @param {number} index ビューのインデックス
 */
function showViewByIndex(index) {
  if (index >= 0 && index < APP_VIEWS.length) {
    showView(APP_VIEWS[index]);
  }
}

/**
 * ヘルプモーダルの表示切り替え
 * @param {boolean|null} forceState 強制指定
 */
function toggleHelp(forceState = null) {
  const helpView = document.getElementById("help-view");
  if (!helpView) return;

  const isOpening =
    forceState !== null ? forceState : helpView.classList.contains("hidden");

  showView(isOpening ? "help-view" : "main-view");
}

/**
 * グローバルキーイベント (Escキーなどの共通処理)
 */
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") {
    // メイン画面以外が表示されているなら、メインに戻る
    const isMainVisible = !document
      .getElementById("main-view")
      .classList.contains("hidden");
    if (!isMainVisible) {
      showView("main-view");
    }
  }
});

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
