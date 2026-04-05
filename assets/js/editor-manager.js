/**
 * Editor and Context Menu Management
 */

document.addEventListener("DOMContentLoaded", () => {
  const textArea = document.getElementById("main-textarea");
  const contextMenu = document.getElementById("context-menu");

  if (!textArea || !contextMenu) return;

  /**
   * 右クリックメニューの表示制御
   */
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

    // 画面端での折り返し処理
    if (x + menuWidth > winWidth) x -= menuWidth;
    if (y + menuHeight > winHeight) y -= menuHeight;

    if (x < 0) x = 0;
    if (y < 0) y = 0;

    contextMenu.style.left = x + "px";
    contextMenu.style.top = y + "px";
    contextMenu.style.visibility = "visible";
  });

  /**
   * TABキーの挙動制御
   */
  textArea.addEventListener("keydown", (e) => {
    if (e.key === "Tab" && !e.ctrlKey && !e.shiftKey && !e.altKey && !e.metaKey) {
      const behavior = window.ahkSettings.TabBehavior || "Move Focus";
      if (behavior === "Move Focus") return;

      e.preventDefault();
      const start = textArea.selectionStart;
      const end = textArea.selectionEnd;
      let insertText = "";

      switch (behavior) {
        case "Tab (\\t)":
          insertText = "\t";
          break;
        case "2 Spaces":
          insertText = "  ";
          break;
        case "4 Spaces":
          insertText = "    ";
          break;
      }

      if (insertText) {
        textArea.setRangeText(insertText, start, end, "end");
        textArea.dispatchEvent(new Event("input"));
      }
    }
  });

  /**
   * メニュー外クリックで閉じる
   */
  window.addEventListener("click", (e) => {
    if (!contextMenu.contains(e.target)) {
      contextMenu.style.display = "none";
    }
  });
});

/**
 * テキスト編集コマンドの実行
 * @param {string} command 'cut' | 'copy' | 'paste' | 'selectAll'
 */
async function runEditorCommand(command) {
  const textArea = document.getElementById("main-textarea");
  const contextMenu = document.getElementById("context-menu");

  textArea.focus();
  const start = textArea.selectionStart;
  const end = textArea.selectionEnd;
  const selected = textArea.value.substring(start, end);

  try {
    switch (command) {
      case "transfer":
        sendMsg("transfer", textArea.value);
        break;
      case "cut":
        if (start !== end) {
          await navigator.clipboard.writeText(selected);
          textArea.setRangeText("", start, end, "end");
          textArea.dispatchEvent(new Event("input"));
        }
        break;
      case "copy":
        if (start !== end) {
          await navigator.clipboard.writeText(selected);
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
    console.error(`Editor command ${command} failed: `, err);
  } finally {
    contextMenu.style.display = "none";
  }
}
