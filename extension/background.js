// Create Context Menu
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "save-to-lock-n-key",
    title: "Save to LOCK N' KEY",
    contexts: ["selection"]
  });
});

// Handle Click
chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (info.menuItemId === "save-to-lock-n-key" && info.selectionText) {
    // Store the selected text
    chrome.storage.local.set({ "pendingSecret": info.selectionText }, () => {
      // Open the popup window to let user edit/save
      chrome.windows.create({
        url: "popup.html",
        type: "popup",
        width: 400,
        height: 500
      });
    });
  }
});
