/* Prompt Linker Logic */
const textArea = document.getElementById('main-textarea');

// AHKから注入される設定値を反映
document.addEventListener('DOMContentLoaded', () => {
    if (window.ahkSettings) {
        initSettings(window.ahkSettings);
    }
});

// AHKから設定を受け取ってUIに反映する関数
function initSettings(settings) {
    // SendMode
    document.getElementById('send-mode').value = settings.SendMode;
    // FontSize
    updateFontSizeDisplay(settings.FontSize);
    // SaveLog
    document.getElementById('save-log-check').checked = settings.SaveLog;
    // LogDir
    document.getElementById('log-dir-display').value = settings.LogDir;
}

function sendMsg(msg) {
    window.chrome.webview.postMessage(msg);
}

function updateBtn(text) {
    document.getElementById('link-btn').innerText = text;
}

function updateStatus(text, color) {
    const el = document.getElementById('status-label');
    el.innerText = text;
    el.style.color = color;
}

function updateFontSizeDisplay(size) {
    document.getElementById('font-size-val').innerText = size;
    textArea.style.fontSize = size + 'px';
}

function updateLogDirDisplay(path) {
    document.getElementById('log-dir-display').value = path;
}

// View Toggle Control
function toggleSettingsView() {
    const mainView = document.getElementById('main-view');
    const setView = document.getElementById('settings-view');
    mainView.classList.toggle('hidden');
    setView.classList.toggle('hidden');
    if (!mainView.classList.contains('hidden')) {
        textArea.focus();
    }
}

textArea.addEventListener('keydown', (e) => {
    if (e.ctrlKey && e.key === 'Enter') {
        sendMsg('transfer:' + textArea.value);
    }
});

// Context Menu Logic
const contextMenu = document.getElementById('context-menu');

textArea.addEventListener('contextmenu', (e) => {
    e.preventDefault();
    const x = e.clientX;
    const y = e.clientY;

    // 画面からはみ出さないように調整 (簡易)
    contextMenu.style.left = `${x}px`;
    contextMenu.style.top = `${y}px`;
    contextMenu.style.display = 'block';
});

window.addEventListener('click', (e) => {
    // メニュー外クリックで閉じる
    if (!contextMenu.contains(e.target)) {
        contextMenu.style.display = 'none';
    }
});

function execCmd(cmd) {
    // テキストエリアにフォーカスを戻してから実行
    textArea.focus();
    document.execCommand(cmd);
    contextMenu.style.display = 'none';
}

textArea.focus();
