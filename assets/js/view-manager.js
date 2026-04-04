/**
 * View Management for Prompt Linker
 */
const APP_VIEWS = ["main-view", "settings-view", "help-view"];

/**
 * 指定されたビューを表示し、他を非表示にする
 */
function showView(targetId) {
  APP_VIEWS.forEach((id) => {
    const el = document.getElementById(id);
    if (!el) return;

    if (id === targetId) {
      el.classList.remove("hidden");
      if (id === "main-view") {
        const ta = document.getElementById("main-textarea");
        if (ta) ta.focus();
      }
    } else {
      el.classList.add("hidden");
    }
  });
}

/**
 * 設定画面の表示/非表示をトグル
 * @param {boolean|null} forceState 強制的に開閉する場合の状態
 */
function toggleSetView(forceState = null) {
  const settingsEl = document.getElementById("settings-view");
  if (!settingsEl) return;

  const isOpening = forceState !== null
    ? forceState
    : settingsEl.classList.contains("hidden");

  showView(isOpening ? "settings-view" : "main-view");
}

/**
 * ビューを循環切り替え (Ctrl + Tab 等で使用)
 * @param {number} direction +1 or -1
 */
function rotateView(direction) {
  const currentIndex = APP_VIEWS.findIndex(
    (id) => !document.getElementById(id).classList.contains("hidden")
  );
  if (currentIndex === -1) return;

  const nextIndex = (currentIndex + direction + APP_VIEWS.length) %
    APP_VIEWS.length;
  showView(APP_VIEWS[nextIndex]);
}

/**
 * ヘルプ画面の表示/非表示をトグル
 * @param {boolean|null} forceState 強制的に開閉する場合の状態
 */
function toggleHelp(forceState = null) {
  const helpEl = document.getElementById("help-view");
  if (!helpEl) return;

  const isOpening = forceState !== null
    ? forceState
    : helpEl.classList.contains("hidden");

  showView(isOpening ? "help-view" : "main-view");
}
