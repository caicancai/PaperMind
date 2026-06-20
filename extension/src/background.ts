async function openPaperMindInTab(tab: chrome.tabs.Tab): Promise<void> {
  if (!tab.id || !tab.url) return;

  const readerUrl = new URL(chrome.runtime.getURL("reader.html"));
  readerUrl.searchParams.set("source", tab.url);
  await chrome.tabs.update(tab.id, { url: readerUrl.toString() });
}

chrome.action.onClicked.addListener(openPaperMindInTab);

// Exposed only so the browser E2E test can invoke the exact action handler.
Object.assign(globalThis, { __paperMindOpenTab: openPaperMindInTab });
