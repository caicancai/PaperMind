async function openPaperMindInTab(tab: chrome.tabs.Tab): Promise<void> {
  if (tab.id == null || !tab.url) return;

  if (!(await isPdfSource(tab.url))) {
    await showUnsupportedSource(tab.id);
    return;
  }

  const readerUrl = new URL(chrome.runtime.getURL("reader.html"));
  readerUrl.searchParams.set("source", tab.url);
  await chrome.tabs.update(tab.id, { url: readerUrl.toString() });
}

async function isPdfSource(source: string): Promise<boolean> {
  let url: URL;
  try {
    url = new URL(source);
  } catch {
    return false;
  }

  if (!/^(https?|file):$/.test(url.protocol)) return false;
  const hasPdfExtension = /\.pdf$/i.test(url.pathname);
  if (url.protocol === "file:") return hasPdfExtension;

  try {
    const head = await fetch(source, {
      method: "HEAD",
      credentials: "include",
      cache: "no-store"
    });
    const contentType = head.headers.get("content-type")?.toLowerCase() ?? "";
    const disposition = head.headers.get("content-disposition")?.toLowerCase() ?? "";
    if (contentType.includes("application/pdf") || /filename\*?=.*\.pdf\b/.test(disposition)) {
      return true;
    }
    if (contentType && !contentType.includes("application/octet-stream")) return false;
    if (!head.ok && hasPdfExtension) return true;

    const response = await fetch(source, {
      credentials: "include",
      cache: "no-store",
      headers: { Range: "bytes=0-4" }
    });
    if (!response.ok || !response.body) return false;
    const reader = response.body.getReader();
    const { value } = await reader.read();
    await reader.cancel();
    return new TextDecoder().decode(value?.slice(0, 5)) === "%PDF-";
  } catch {
    return hasPdfExtension;
  }
}

async function showUnsupportedSource(tabId: number): Promise<void> {
  await chrome.action.setBadgeBackgroundColor({ tabId, color: "#8c4930" });
  await chrome.action.setBadgeText({ tabId, text: "!" });
  await chrome.action.setTitle({ tabId, title: "当前标签页不是可读取的 PDF" });
  setTimeout(() => {
    void Promise.all([
      chrome.action.setBadgeText({ tabId, text: "" }),
      chrome.action.setTitle({ tabId, title: "用 PaperMind 阅读当前 PDF" })
    ]).catch(() => undefined);
  }, 3000);
}

chrome.action.onClicked.addListener(openPaperMindInTab);

// Exposed only so the browser E2E test can invoke the exact action handler.
Object.assign(globalThis, { __paperMindOpenTab: openPaperMindInTab });
