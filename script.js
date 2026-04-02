/**
 * Prompt Linker UI Logic
 */
const textArea = document.getElementById("main-textarea");
const contextMenu = document.getElementById("context-menu");

/**
 * 初期化処理
 */
document.addEventListener("DOMContentLoaded", () => {
  if (window.ahkSettings) {
    initSettings(window.ahkSettings);
  }
  textArea.focus();

  // ツールバーの右クリックで格納
  const toolbar = document.querySelector(".toolbar");
  toolbar.addEventListener("contextmenu", (e) => {
    e.preventDefault();
    if (!toolbar.classList.contains("collapsed")) {
      sendMsg("toggleToolbar");
      // 格納後に入力フォーカスを維持
      setTimeout(() => textArea.focus(), 50);
    }
  });

  // ツールバーのクリック (隠れている時は再表示)
  toolbar.addEventListener("click", () => {
    if (toolbar.classList.contains("collapsed")) {
      sendMsg("toggleToolbar");
    }
  });

  // textarea 上端クリックでツールバー再表示
  textArea.addEventListener("click", (e) => {
    if (toolbar.classList.contains("collapsed") && e.offsetY <= 5) {
      sendMsg("toggleToolbar");
    }
  });

  // 上端付近での視覚フィードバック
  textArea.addEventListener("mousemove", (e) => {
    if (toolbar.classList.contains("collapsed") && e.offsetY <= 5) {
      textArea.classList.add("at-top");
    } else {
      textArea.classList.remove("at-top");
    }
  });
  textArea.addEventListener("mouseleave", () => {
    textArea.classList.remove("at-top");
  });
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
 * 将来的にログ画面を追加する場合は、この配列に ID を追加
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
 * ヘルプ画面表示切り替え
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
 * ターゲットメニューの表示切り替え
 */
function toggleTargetMenu(e) {
  e.stopPropagation();
  const menu = document.getElementById("target-menu");
  menu.classList.toggle("hidden");

  // メニューが開いた時、外側クリックで閉じるようにする
  if (!menu.classList.contains("hidden")) {
    const closeMenu = (event) => {
      if (!menu.contains(event.target)) {
        menu.classList.add("hidden");
        document.removeEventListener("click", closeMenu);
      }
    };
    setTimeout(() => {
      document.addEventListener("click", closeMenu);
    }, 10);
  }
}

/**
 * ターゲットアクションメニューの表示切り替え
 */
function toggleActionMenu(e) {
  e.stopPropagation();
  const menu = document.getElementById("action-menu");
  menu.classList.toggle("hidden");

  if (!menu.classList.contains("hidden")) {
    const closeActionMenu = (event) => {
      if (!menu.contains(event.target)) {
        menu.classList.add("hidden");
        document.removeEventListener("click", closeActionMenu);
      }
    };
    setTimeout(() => {
      document.addEventListener("click", closeActionMenu);
    }, 10);
  }
}

/**
 * ターゲットアクションを選択
 */
function selectAction(action, e) {
  if (e) e.stopPropagation();
  document.getElementById("target-action-label").innerText = action;
  document.getElementById("action-menu").classList.add("hidden");
  sendMsg("updateSetting:TargetAction:" + action);
}

/**
 * グローバルキーイベント (Escキーなどの共通処理)
 */
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") {
    // ホットキー入力欄にフォーカスがある時は、グローバルな遷移をさせない
    const hotkeyInput = document.getElementById("hotkey-input");
    if (hotkeyInput && document.activeElement === hotkeyInput) {
      return;
    }
    const targetMenu = document.getElementById("target-menu");
    const actionMenu = document.getElementById("action-menu");
    if (!targetMenu.classList.contains("hidden")) {
      targetMenu.classList.add("hidden");
      return;
    }
    if (actionMenu && !actionMenu.classList.contains("hidden")) {
      actionMenu.classList.add("hidden");
      return;
    }
    const triggerMenu = document.getElementById("trigger-menu");
    if (triggerMenu && !triggerMenu.classList.contains("hidden")) {
      triggerMenu.classList.add("hidden");
      return;
    }

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
 * Trigger Key メニューの表示切り替え
 */
function toggleTriggerMenu(e) {
  e.stopPropagation();
  const menu = document.getElementById("trigger-menu");
  menu.classList.toggle("hidden");

  if (!menu.classList.contains("hidden")) {
    const closeTriggerMenu = (event) => {
      if (!menu.contains(event.target)) {
        menu.classList.add("hidden");
        document.removeEventListener("click", closeTriggerMenu);
      }
    };
    setTimeout(() => {
      document.addEventListener("click", closeTriggerMenu);
    }, 10);
  }
}

/**
 * Trigger Key を選択
 */
function selectTrigger(trigger, e) {
  if (e) e.stopPropagation();
  document.getElementById("trigger-key-label").innerText = trigger;
  const mShortcut = document.getElementById("menu-transfer-shortcut");
  if (mShortcut) mShortcut.innerText = trigger;
  document.getElementById("trigger-menu").classList.add("hidden");
  sendMsg("updateSetting:TriggerKey:" + trigger);
}

/**
 * イベントリスナー
 */
textArea.addEventListener("keydown", (e) => {
  let trigger = "Ctrl + Enter";
  const labelEl = document.getElementById("trigger-key-label");
  if (labelEl) {
    trigger = labelEl.innerText;
  }
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
  } else if (msg.startsWith("updateTargetSlots:")) {
    const slots = JSON.parse(msg.substring(18));
    updateTargetSlots(slots);
  }
});

/**
 * スロット用コンテキストメニューの制御
 */
let currentContextSlot = null;

function showSlotContextMenu(e, index) {
  e.preventDefault();
  e.stopPropagation();
  currentContextSlot = index;

  const menu = document.getElementById("slot-context-menu");
  menu.style.display = "block";
  menu.style.left = e.clientX + "px";
  menu.style.top = e.clientY + "px";

  // 他のメニューを閉じる
  document.getElementById("context-menu").style.display = "none";
}

function handleSlotAction(action) {
  if (currentContextSlot === null) return;

  if (action === "lock") {
    sendMsg("toggleSlotLock:" + currentContextSlot);
  } else if (action === "clear") {
    sendMsg("clearTargetSlot:" + currentContextSlot);
  }

  document.getElementById("slot-context-menu").style.display = "none";
  currentContextSlot = null;
}

// 共通のクリック処理でメニューを閉じる
window.addEventListener("click", () => {
  const slotMenu = document.getElementById("slot-context-menu");
  if (slotMenu) slotMenu.style.display = "none";
});

/**
 * AHK側からの操作をUIコンポーネントに反映させる
 */
function updateUI(key, value) {
  const isTrue = value === "1" || value === "true" || value === true;
  switch (key) {
    case "SaveLog":
      document.getElementById("save-log-check").checked = isTrue;
      break;
    case "MinimizeOption":
      document.getElementById("minimize-option-check").checked = isTrue;
      break;
    case "TriggerKey":
      const tLabel = document.getElementById("trigger-key-label");
      if (tLabel) {
        tLabel.innerText = value;
      }
      // コンテキストメニューのショートカット表示も更新
      const mShortcut = document.getElementById("menu-transfer-shortcut");
      if (mShortcut) {
        mShortcut.innerText = value;
      }
      break;
    case "TargetAction":
      const label = document.getElementById("target-action-label");
      if (label) label.innerText = value;
      break;
  }
}
