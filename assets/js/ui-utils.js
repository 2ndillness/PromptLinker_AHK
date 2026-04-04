/**
 * UI Utilities for Prompt Linker
 */

/**
 * Linkボタンの待機状態を切り替え
 * @param {boolean} isWaiting 待機中かどうか
 */
function setLinkWaiting(isWaiting) {
  const btn = document.getElementById("link-btn");
  const textEl = btn.querySelector(".btn-text");
  if (!textEl) return;

  if (isWaiting) {
    btn.classList.add("recording");
    textEl.innerText = "Waiting...";
  } else {
    btn.classList.remove("recording");
    textEl.innerText = "Link Target";
  }
}

/**
 * フォントサイズの更新
 */
function updateFontSize(size) {
  const textArea = document.getElementById("main-textarea");
  document.getElementById("font-size-val").innerText = size;
  if (textArea) textArea.style.fontSize = size + "px";
}

/**
 * プロンプト保存ディレクトリ表示の更新
 */
function updateExportDirectory(path) {
  const display = document.getElementById("export-dir-display");
  if (display) display.value = path;
}

/**
 * ターゲットスロットの表示を更新
 */
function updateTargetSlots(slots) {
  const menu = document.getElementById("target-menu");
  if (!menu) return;

  const activeNumEl = document.getElementById("active-slot-num");
  const activeSlot = slots.find((s) => s.active);
  if (activeNumEl && activeSlot) {
    activeNumEl.innerText = activeSlot.index;
  }

  menu.innerHTML = "";
  slots.forEach((slot) => {
    const item = document.createElement("div");
    const isEmpty = slot.exe === "(Empty)";
    item.className =
      "target-item" +
      (slot.active ? " active" : "") +
      (isEmpty ? " is-empty" : "");

    item.onclick = (e) => {
      e.stopPropagation();
      sendMsg("switchTargetSlot", slot.index);
      menu.classList.add("hidden");
    };

    item.oncontextmenu = (e) => showSlotContextMenu(e, slot.index);

    const dot = document.createElement("span");
    dot.className = "status-dot";

    const num = document.createElement("span");
    num.className = "slot-num";
    num.innerText = slot.index;

    const name = document.createElement("span");
    name.className = "exe-name";
    name.innerText = slot.exe;

    item.appendChild(dot);
    item.appendChild(num);
    item.appendChild(name);

    if (slot.locked) {
      const lock = document.createElement("img");
      lock.src = "assets/icons/lock.svg";
      lock.className = "lock-icon";
      item.appendChild(lock);
    }

    menu.appendChild(item);
  });
}

/**
 * メインテキストエリアの内容をクリアしフォーカスする
 */
function clearTextArea() {
  const textArea = document.getElementById("main-textarea");
  if (textArea) {
    textArea.value = "";
    textArea.focus();
  }
}

/**
 * トースト通知の表示

 * @param {string} msg
 * @param {string} type 'info' | 'error' | 'warning' |'success'
 */
function showToast(msg, type = "info") {
  const container = document.getElementById("toast-container");
  if (!container) return;

  const toast = document.createElement("div");
  toast.className = `toast ${type}`;
  toast.innerText = msg;

  container.appendChild(toast);

  // 3秒後にアニメーションを伴って削除
  setTimeout(() => {
    toast.style.opacity = "0";
    toast.style.transform = "translateY(-20px)";
    toast.style.transition = "all 0.3s ease-in";
    setTimeout(() => toast.remove(), 300);
  }, 3000);
}

/**
 * 汎用ドロップダウンメニューのトグル
 * @param {string} menuId 対象メニューのID
 * @param {Event} e クリックイベント
 */
function toggleDropdown(menuId, e) {
  if (e) e.stopPropagation();
  const menu = document.getElementById(menuId);
  if (!menu) return;

  const isHidden = menu.classList.toggle("hidden");

  if (!isHidden) {
    const closeHandler = (event) => {
      if (!menu.contains(event.target)) {
        menu.classList.add("hidden");
        document.removeEventListener("click", closeHandler);
      }
    };
    // 自身のクリックイベントを無視するように微調整
    setTimeout(() => {
      document.addEventListener("click", closeHandler);
    }, 10);
  }
}
