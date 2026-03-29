/**
 * UI Utilities for Prompt Linker
 */

/**
 * 全アイコンのレンダリング
 */
function renderIcons() {
  const placeholders = document.querySelectorAll(".icon-placeholder");
  placeholders.forEach((el) => {
    const iconName = el.getAttribute("data-icon");
    if (ICONS[iconName]) {
      el.innerHTML = `<img src="assets/icons/${ICONS[iconName]}.svg" class="icon-img">`;
    }
  });
}

/**
 * 特定のアイコンを更新
 */
function updateIcon(el, iconName) {
  if (ICONS[iconName]) {
    el.innerHTML = `<img src="assets/icons/${ICONS[iconName]}.svg" class="icon-img">`;
    el.setAttribute("data-icon", iconName);
  }
}

/**
 * Linkボタンのテキスト更新
 */
function updateLinkButton(text) {
  const btn = document.getElementById("link-btn");
  const textEl = btn.querySelector(".btn-text");
  if (textEl) textEl.innerText = text;
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
 * ログディレクトリ表示の更新
 */
function updateLogDirectory(path) {
  const display = document.getElementById("log-dir-display");
  if (display) display.value = path;
}

/**
 * ターゲットスロットの表示を更新
 */
function updateTargetSlots(slots) {
  const menu = document.getElementById("target-menu");
  if (!menu) return;

  menu.innerHTML = "";
  slots.forEach((slot) => {
    const item = document.createElement("div");
    item.className = "target-item" + (slot.active ? " active" : "");
    item.onclick = (e) => {
      e.stopPropagation();
      sendMsg("switchTargetSlot:" + slot.index);
      menu.classList.add("hidden");
    };

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
    menu.appendChild(item);
  });
}

/**
 * トースト通知の表示
 * @param {string} msg
 * @param {string} type 'info' | 'error' | 'success'
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
