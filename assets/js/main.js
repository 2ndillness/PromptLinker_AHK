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

  // Ctrl + S で保存
  document.addEventListener("keydown", (e) => {
    if (e.ctrlKey && e.key === "s") {
      e.preventDefault();
      exportCurrentText();
    }
  });
});

/**
 * AHKへメッセージを送信
 */
function sendMsg(type, payload = null) {
  if (window.chrome && window.chrome.webview) {
    window.chrome.webview.postMessage({
      type: type,
      payload: payload,
    });
  }
}





function selectAction(action, e) {
  if (e) e.stopPropagation();
  document.getElementById("target-action-label").innerText = action;
  document.getElementById("action-menu").classList.add("hidden");
  sendMsg("updateSetting", {
    key: "TargetAction",
    value: action,
  });
}

document.addEventListener("keydown", (e) => {
  if (e.altKey && e.key === "ArrowLeft") {
    const isMainVisible = !document
      .getElementById("main-view")
      .classList.contains("hidden");
    if (!isMainVisible) {
      e.preventDefault();
      showView("main-view");
    }
    return;
  }

  if (e.key === "Escape") {
    const hotkeyInput = document.getElementById("hotkey-input");
    if (hotkeyInput && document.activeElement === hotkeyInput) return;

    // 1. 各種メニュー・コンテキストメニューを閉じる
    const menus = [
      "target-menu",
      "action-menu",
      "export-menu",
      "trigger-menu",
      "tab-behavior-menu",
      "context-menu",
      "slot-context-menu",
    ];
    menus.forEach((id) => {
      const el = document.getElementById(id);
      if (el) {
        if (id.includes("context")) {
          el.style.display = "none";
        } else {
          el.classList.add("hidden");
        }
      }
    });

    // 2. リンク待機中(Waiting...)であればキャンセル
    const linkBtn = document.getElementById("link-btn");
    if (linkBtn && linkBtn.classList.contains("recording")) {
      sendMsg("toggleLink");
    }

    // 3. テキストエリアの選択状態を解除（ブラウザ標準で不足する分を補完）
    if (document.activeElement === textArea) {
      const start = textArea.selectionStart;
      const end = textArea.selectionEnd;
      if (start !== end) {
        // 選択されている場合は、カーソルを選択開始位置に移動して解除
        textArea.setSelectionRange(start, start);
      }
    }
  }
});


function selectTrigger(trigger, e) {
  if (e) e.stopPropagation();
  document.getElementById("trigger-key-label").innerText = trigger;
  const mShortcut = document.getElementById("menu-transfer-shortcut");
  if (mShortcut) mShortcut.innerText = trigger;
  document.getElementById("trigger-menu").classList.add("hidden");
  sendMsg("updateSetting", {
    key: "TriggerKey",
    value: trigger,
  });
}


function selectExportExt(ext, e) {
  if (e) e.stopPropagation();
  document.getElementById("export-ext-label").innerText = ext;
  document.getElementById("export-menu").classList.add("hidden");
  sendMsg("updateSetting", {
    key: "ExportExtension",
    value: ext,
  });
}

/**
 * タブキーの挙動を選択
 * @param {string} behavior
 * @param {Event} e
 */
function selectTabBehavior(behavior, e) {
  const label = document.getElementById("tab-behavior-label");
  if (label) label.innerText = behavior;
  window.ahkSettings.TabBehavior = behavior;
  sendMsg("updateSetting", {
    key: "TabBehavior",
    value: behavior,
  });
  const menu = document.getElementById("tab-behavior-menu");
  if (menu) menu.classList.add("hidden");
  if (e) e.stopPropagation();
}

/**
 * 現在のプロンプトを保存
 */
function exportCurrentText() {
  const content = textArea.value;
  if (content.trim() === "") {
    showToast("No text to save", "warning");
    return;
  }
  sendMsg("export", content);
}

textArea.addEventListener("keydown", (e) => {
  let trigger = "Ctrl + Enter";
  const labelEl = document.getElementById("trigger-key-label");
  if (labelEl) trigger = labelEl.innerText;

  const isCtrlT = trigger === "Ctrl + Enter" && e.ctrlKey && !e.shiftKey;
  const isShiftT = trigger === "Shift + Enter" && e.shiftKey && !e.ctrlKey;

  if ((isCtrlT || isShiftT) && e.key === "Enter") {
    e.preventDefault();
    sendMsg("transfer", textArea.value);
  }

  if (e.altKey && e.key === "c") {
    clearTextArea();
  }
});

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

let currentContextSlot = null;

function showSlotContextMenu(e, index) {
  e.preventDefault();
  e.stopPropagation();
  currentContextSlot = index;

  const menu = document.getElementById("slot-context-menu");
  document.getElementById("context-menu").style.display = "none";

  menu.style.visibility = "hidden";
  menu.style.display = "block";

  const menuWidth = menu.offsetWidth;
  const menuHeight = menu.offsetHeight;
  const winWidth = window.innerWidth;
  const winHeight = window.innerHeight;

  let x = e.clientX;
  let y = e.clientY;

  if (x + menuWidth > winWidth) x -= menuWidth;
  if (y + menuHeight > winHeight) y -= menuHeight;
  if (x < 0) x = 0;
  if (y < 0) y = 0;

  menu.style.left = x + "px";
  menu.style.top = y + "px";
  menu.style.visibility = "visible";
}

function handleSlotAction(action) {
  if (currentContextSlot === null) return;
  if (action === "lock") {
    sendMsg("toggleSlotLock", currentContextSlot);
  } else if (action === "clear") {
    sendMsg("clearTargetSlot", currentContextSlot);
  }
  document.getElementById("slot-context-menu").style.display = "none";
  currentContextSlot = null;
}

window.addEventListener("click", () => {
  const slotMenu = document.getElementById("slot-context-menu");
  if (slotMenu) slotMenu.style.display = "none";
});

/**
 * AHK側からの操作をUIに反映
 */
function updateUI(key, value) {
  const isTrue = value === "1" || value === "true" || value === true;
  switch (key) {
    case "ExportExtension":
      const extLabel = document.getElementById("export-ext-label");
      if (extLabel) extLabel.innerText = value;
      const exportBtn = document.getElementById("export-btn");
      if (exportBtn) {
        exportBtn.title = "Save as " + value.replace(".", "");
      }
      break;
    case "MinimizeOption":
      document.getElementById("minimize-option-check").checked = isTrue;
      break;
    case "AlwaysOnTop":
      document.getElementById("always-on-top-check").checked = isTrue;
      break;
    case "ClearTextAtTransfer":
      document.getElementById("clear-transfer-check").checked = isTrue;
      break;
    case "ClearTextAtSave":
      document.getElementById("clear-save-check").checked = isTrue;
      break;
    case "TriggerKey":
      const tLabel = document.getElementById("trigger-key-label");
      if (tLabel) tLabel.innerText = value;
      const mS = document.getElementById("menu-transfer-shortcut");
      if (mS) mS.innerText = value;
      break;
    case "TargetAction":
      const label = document.getElementById("target-action-label");
      if (label) label.innerText = value;
      break;
    case "TabBehavior":
      const tLabel2 = document.getElementById("tab-behavior-label");
      if (tLabel2) tLabel2.innerText = value;
      break;
  }
}
