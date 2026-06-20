import "./style.css";
import DOMPurify from "dompurify";
import { marked } from "marked";
import {
  GlobalWorkerOptions,
  TextLayer,
  getDocument,
  type PDFDocumentProxy
} from "pdfjs-dist";
import workerUrl from "pdfjs-dist/build/pdf.worker.min.mjs?url";
import {
  hasConfiguredAIProvider,
  streamChat,
  streamTranslationWithAI,
  translateText
} from "./services";
import {
  DEFAULT_SETTINGS,
  type AISettings,
  type ChatMessage,
  type OutlineItem,
  type Provider,
  type SelectionState
} from "./types";

GlobalWorkerOptions.workerSrc = workerUrl;
marked.setOptions({ breaks: true, gfm: true });

const app = document.querySelector<HTMLDivElement>("#app");
if (!app) throw new Error("Missing app root");

app.innerHTML = `
  <main class="app-shell">
    <aside class="library">
      <header class="panel-header outline-only-header">
        <div>
          <div class="brand">PaperMind</div>
          <div class="subtle">当前论文目录</div>
        </div>
      </header>
      <div class="outline-pane">
        <div class="outline-summary">
          <span id="outline-source">尚未加载目录</span>
          <span id="outline-count"></span>
        </div>
        <div class="outline-list" id="outline-list"></div>
      </div>
    </aside>

    <section class="reader">
      <header class="reader-toolbar">
        <div class="toolbar-group">
          <span class="document-title" id="document-title">尚未打开论文</span>
          <span class="subtle" id="document-status"></span>
        </div>
        <div class="toolbar-group">
          <span class="subtle" id="page-status"></span>
          <button class="secondary-button" id="original-pdf-button">原始 PDF</button>
          <button class="icon-button" id="zoom-out" title="缩小">−</button>
          <span class="zoom-value" id="zoom-value">100%</span>
          <button class="icon-button" id="zoom-in" title="放大">＋</button>
          <button class="secondary-button" id="settings-button">设置</button>
        </div>
      </header>
      <div class="pdf-scroll" id="pdf-scroll">
        <div class="empty-reader" id="empty-reader">
          <div>
            <strong>在当前标签页打开一篇 PDF</strong>
            <p>请先在浏览器打开 PDF，再点击 PaperMind 扩展图标</p>
          </div>
        </div>
        <div class="pdf-pages" id="pdf-pages"></div>
      </div>
    </section>

    <aside class="inspector">
      <header class="panel-header inspector-header">
        <div class="brand small">AI 讨论</div>
        <div class="toolbar-group">
          <button class="icon-button" id="copy-last-button" title="复制最后一个回答">复制</button>
          <button class="icon-button" id="retry-button" title="重新生成">重试</button>
          <button class="icon-button" id="new-chat-button" title="新建对话">新对话</button>
        </div>
      </header>
      <div class="chat-messages" id="chat-messages"></div>
      <div class="composer">
        <div class="selection-chip" id="selection-chip" hidden>
          <span id="selection-chip-text"></span>
          <button class="tab" id="clear-selection">移除</button>
        </div>
        <textarea id="chat-input" placeholder="询问这篇论文的问题…"></textarea>
        <div class="composer-controls">
          <select id="chat-provider" aria-label="AI Provider">
            <option value="openai">OpenAI</option>
            <option value="deepseek">DeepSeek</option>
            <option value="kimi">Kimi</option>
          </select>
          <select id="thinking-mode" aria-label="思考模式">
            <option value="fast">Fast</option>
            <option value="deep">Deep</option>
          </select>
        </div>
        <div class="composer-footer">
          <span class="status" id="chat-status"></span>
          <button class="primary-button" id="send-button">发送</button>
        </div>
      </div>
    </aside>
  </main>
  <div id="selection-popover-root"></div>
  <div id="modal-root"></div>
`;

const elements = {
  outlineList: required<HTMLDivElement>("outline-list"),
  outlineSource: required<HTMLSpanElement>("outline-source"),
  outlineCount: required<HTMLSpanElement>("outline-count"),
  documentTitle: required<HTMLSpanElement>("document-title"),
  documentStatus: required<HTMLSpanElement>("document-status"),
  pageStatus: required<HTMLSpanElement>("page-status"),
  originalPdfButton: required<HTMLButtonElement>("original-pdf-button"),
  pdfScroll: required<HTMLDivElement>("pdf-scroll"),
  pdfPages: required<HTMLDivElement>("pdf-pages"),
  emptyReader: required<HTMLDivElement>("empty-reader"),
  zoomOut: required<HTMLButtonElement>("zoom-out"),
  zoomIn: required<HTMLButtonElement>("zoom-in"),
  zoomValue: required<HTMLSpanElement>("zoom-value"),
  settingsButton: required<HTMLButtonElement>("settings-button"),
  selectionPopoverRoot: required<HTMLDivElement>("selection-popover-root"),
  selectionChip: required<HTMLDivElement>("selection-chip"),
  selectionChipText: required<HTMLSpanElement>("selection-chip-text"),
  clearSelection: required<HTMLButtonElement>("clear-selection"),
  chatMessages: required<HTMLDivElement>("chat-messages"),
  chatInput: required<HTMLTextAreaElement>("chat-input"),
  chatStatus: required<HTMLSpanElement>("chat-status"),
  chatProvider: required<HTMLSelectElement>("chat-provider"),
  thinkingMode: required<HTMLSelectElement>("thinking-mode"),
  sendButton: required<HTMLButtonElement>("send-button"),
  copyLastButton: required<HTMLButtonElement>("copy-last-button"),
  retryButton: required<HTMLButtonElement>("retry-button"),
  newChatButton: required<HTMLButtonElement>("new-chat-button"),
  modalRoot: required<HTMLDivElement>("modal-root")
};

let outlineItems: OutlineItem[] = [];
let activePaperTitle = "";
let sourcePdfUrl = "";
let activeDocument: PDFDocumentProxy | undefined;
let activeDocumentUrl: string | undefined;
let scale = 1;
let renderGeneration = 0;
let paperContext = "";
let currentSelection: SelectionState | undefined;
let pinnedSelection: SelectionState | undefined;
let chatMessages: ChatMessage[] = [];
let chatAbortController: AbortController | undefined;
let pageObserver: IntersectionObserver | undefined;
let currentPageIndex = 0;
let settings = await loadSettings();

applyTheme(settings.theme);
elements.chatProvider.value = settings.provider;

elements.originalPdfButton.addEventListener("click", () => {
  if (sourcePdfUrl) location.href = sourcePdfUrl;
});
elements.zoomOut.addEventListener("click", () => void changeZoom(-0.1));
elements.zoomIn.addEventListener("click", () => void changeZoom(0.1));
elements.settingsButton.addEventListener("click", showSettings);
elements.clearSelection.addEventListener("click", clearPinnedSelection);
elements.sendButton.addEventListener("click", () => void sendMessage());
elements.copyLastButton.addEventListener("click", () => void copyLastAnswer());
elements.retryButton.addEventListener("click", () => void retryLastMessage());
elements.newChatButton.addEventListener("click", newChat);
elements.chatProvider.addEventListener("change", () => void updateChatProvider());
elements.chatInput.addEventListener("keydown", (event) => {
  if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) void sendMessage();
});
elements.pdfScroll.addEventListener("mouseup", handleReaderSelection);
elements.pdfScroll.addEventListener("scroll", updateCurrentPage, { passive: true });
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") hideSelectionPopover();
});
document.addEventListener("mousedown", (event) => {
  const target = event.target as Node;
  if (!elements.selectionPopoverRoot.contains(target) && !elements.pdfScroll.contains(target)) {
    hideSelectionPopover();
  }
});

await loadPdfFromCurrentTab();
renderChat();
updateChatButtons();

function required<T extends HTMLElement>(id: string): T {
  const element = document.getElementById(id);
  if (!element) throw new Error(`Missing element #${id}`);
  return element as T;
}

async function loadPdfFromCurrentTab(): Promise<void> {
  const source = new URL(location.href).searchParams.get("source");
  if (!source) {
    elements.originalPdfButton.hidden = true;
    renderOutline();
    return;
  }
  if (!/^(https?|file):/i.test(source)) {
    setDocumentStatus("当前页面不是可读取的 PDF 地址", true);
    elements.emptyReader.querySelector("strong")!.textContent = "无法读取当前页面";
    return;
  }

  sourcePdfUrl = source;
  activePaperTitle = paperTitleFromUrl(source);
  const generation = ++renderGeneration;
  pageObserver?.disconnect();
  chatAbortController?.abort();
  currentSelection = undefined;
  clearPinnedSelection();
  hideSelectionPopover();
  newChat();
  paperContext = "";
  outlineItems = [];
  renderOutline();
  currentPageIndex = 0;

  elements.documentTitle.textContent = activePaperTitle;
  elements.emptyReader.hidden = true;
  elements.pdfPages.replaceChildren();
  setDocumentStatus("正在打开…");
  await activeDocument?.destroy();
  if (activeDocumentUrl) URL.revokeObjectURL(activeDocumentUrl);
  activeDocumentUrl = undefined;

  try {
    activeDocument = await getDocument({ url: sourcePdfUrl, withCredentials: true }).promise;
    await fitDocumentToReader(activeDocument);
    await prepareDocument(activeDocument, generation);
    setDocumentStatus(`${activeDocument.numPages} 页`);
    updatePageStatus();
    void extractPaperContextAndOutline(activeDocument, generation);
  } catch (error) {
    const detail =
      sourcePdfUrl.startsWith("file:")
        ? "请在 chrome://extensions 的 PaperMind 详情页开启“允许访问文件网址”。"
        : "请确认当前标签页直接打开的是 PDF，且该地址仍然有效。";
    setDocumentStatus(`${errorMessage(error)} ${detail}`, true);
    elements.emptyReader.hidden = false;
    elements.emptyReader.querySelector("strong")!.textContent = "PDF 加载失败";
  }
}

async function fitDocumentToReader(documentProxy: PDFDocumentProxy): Promise<void> {
  const firstPage = await documentProxy.getPage(1);
  const baseViewport = firstPage.getViewport({ scale: 1 });
  const availableWidth = Math.max(320, elements.pdfScroll.clientWidth - 56);
  scale = Math.min(1.35, Math.max(0.6, availableWidth / baseViewport.width));
  elements.zoomValue.textContent = `${Math.round(scale * 100)}%`;
}

function paperTitleFromUrl(source: string): string {
  try {
    const url = new URL(source);
    const fileName = decodeURIComponent(url.pathname.split("/").filter(Boolean).at(-1) ?? "");
    return fileName.replace(/\.pdf$/i, "") || url.hostname || "当前论文";
  } catch {
    return "当前论文";
  }
}

async function prepareDocument(documentProxy: PDFDocumentProxy, generation: number): Promise<void> {
  pageObserver?.disconnect();
  elements.pdfPages.replaceChildren();

  pageObserver = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          const pageIndex = Number((entry.target as HTMLElement).dataset.pageIndex);
          void renderPage(pageIndex, generation);
        }
      }
    },
    { root: elements.pdfScroll, rootMargin: "1200px 0px" }
  );

  for (let pageIndex = 0; pageIndex < documentProxy.numPages; pageIndex += 1) {
    if (generation !== renderGeneration) return;
    const page = await documentProxy.getPage(pageIndex + 1);
    const viewport = page.getViewport({ scale });
    const container = document.createElement("section");
    container.className = "pdf-page pending";
    container.dataset.pageIndex = String(pageIndex);
    container.dataset.renderState = "pending";
    container.style.width = `${viewport.width}px`;
    container.style.height = `${viewport.height}px`;
    const label = document.createElement("span");
    label.className = "page-number";
    label.textContent = `P${pageIndex + 1}`;
    container.append(label);
    elements.pdfPages.append(container);
    pageObserver.observe(container);
  }

  await renderPage(0, generation);
}

async function renderPage(pageIndex: number, generation: number): Promise<void> {
  if (!activeDocument || generation !== renderGeneration) return;
  const container = elements.pdfPages.querySelector<HTMLElement>(
    `.pdf-page[data-page-index="${pageIndex}"]`
  );
  if (!container || container.dataset.renderState !== "pending") return;
  container.dataset.renderState = "rendering";

  try {
    const page = await activeDocument.getPage(pageIndex + 1);
    if (generation !== renderGeneration) return;
    const viewport = page.getViewport({ scale });
    const outputScale = window.devicePixelRatio || 1;
    const canvas = document.createElement("canvas");
    canvas.width = Math.floor(viewport.width * outputScale);
    canvas.height = Math.floor(viewport.height * outputScale);
    canvas.style.width = `${viewport.width}px`;
    canvas.style.height = `${viewport.height}px`;
    const context = canvas.getContext("2d", { alpha: false });
    if (!context) throw new Error("浏览器无法创建 PDF 画布");

    const textContainer = document.createElement("div");
    textContainer.className = "textLayer";
    const pageLabel = container.querySelector(".page-number") ?? document.createElement("span");
    container.prepend(canvas, textContainer);
    container.append(pageLabel);
    await page.render({
      canvas,
      canvasContext: context,
      viewport,
      transform: outputScale === 1 ? undefined : [outputScale, 0, 0, outputScale, 0, 0]
    }).promise;

    const textContent = await page.getTextContent();
    await new TextLayer({
      textContentSource: textContent,
      container: textContainer,
      viewport
    }).render();
    container.dataset.renderState = "rendered";
    container.classList.remove("pending");
    pageObserver?.unobserve(container);
  } catch (error) {
    container.dataset.renderState = "pending";
    setDocumentStatus(`第 ${pageIndex + 1} 页渲染失败：${errorMessage(error)}`, true);
  }
}

async function extractPaperContextAndOutline(
  documentProxy: PDFDocumentProxy,
  generation: number
): Promise<void> {
  const embedded = await buildEmbeddedOutline(documentProxy);
  const parts: string[] = [];
  const inferred: OutlineItem[] = [];
  let characterCount = 0;

  for (let pageIndex = 0; pageIndex < documentProxy.numPages; pageIndex += 1) {
    if (generation !== renderGeneration) return;
    const page = await documentProxy.getPage(pageIndex + 1);
    const content = await page.getTextContent();
    const textItems = content.items.filter(
      (item): item is (typeof content.items)[number] & { str: string; height: number } =>
        "str" in item && typeof item.str === "string"
    );
    const pageText = textItems
      .map((item) => item.str)
      .join(" ")
      .replace(/\s+/g, " ")
      .trim();
    if (pageText && characterCount < 24_000) {
      const part = `[Page ${pageIndex + 1}] ${pageText.slice(0, 900)}`;
      parts.push(part);
      characterCount += part.length;
    }
    if (embedded.length === 0) {
      inferred.push(...inferOutlineCandidates(textItems, pageIndex));
    }
  }

  if (generation !== renderGeneration) return;
  paperContext = parts.join("\n\n").slice(0, 24_000);
  outlineItems = embedded.length > 0 ? embedded : dedupeOutline(inferred).slice(0, 100);
  renderOutline();
}

async function buildEmbeddedOutline(documentProxy: PDFDocumentProxy): Promise<OutlineItem[]> {
  const root = await documentProxy.getOutline();
  if (!root) return [];
  const result: OutlineItem[] = [];

  const visit = async (
    items: Awaited<ReturnType<PDFDocumentProxy["getOutline"]>>,
    level: number
  ): Promise<void> => {
    if (!items) return;
    for (const item of items) {
      try {
        const destination =
          typeof item.dest === "string" ? await documentProxy.getDestination(item.dest) : item.dest;
        if (destination) {
          const pageReference = destination[0];
          const pageIndex =
            typeof pageReference === "number"
              ? pageReference
              : await documentProxy.getPageIndex(pageReference);
          result.push({
            id: `embedded-${result.length}`,
            title: item.title.trim() || `第 ${pageIndex + 1} 页`,
            pageIndex,
            level,
            source: "embedded"
          });
        }
      } catch {
        // Keep processing the rest of a partially broken PDF outline.
      }
      await visit(item.items, level + 1);
    }
  };

  await visit(root, 0);
  return result;
}

function inferOutlineCandidates(
  items: Array<{ str: string; height: number }>,
  pageIndex: number
): OutlineItem[] {
  const heights = items.map((item) => Math.abs(item.height)).filter((height) => height > 0);
  const sorted = [...heights].sort((a, b) => a - b);
  const median = sorted[Math.floor(sorted.length / 2)] || 10;
  const headingPattern =
    /^(abstract|introduction|background|related work|method(?:ology)?|approach|experiments?|results?|discussion|conclusion|references|摘要|引言|背景|相关工作|方法|实验|结果|讨论|结论|参考文献)$/i;
  const numberedPattern = /^(?:\d+(?:\.\d+){0,3}|[IVX]+)[.)]?\s+\S+/i;
  const result: OutlineItem[] = [];

  for (const item of items) {
    const title = item.str.replace(/\s+/g, " ").trim();
    if (title.length < 3 || title.length > 100) continue;
    const isHeading =
      headingPattern.test(title) ||
      numberedPattern.test(title) ||
      (Math.abs(item.height) >= median * 1.45 && title.split(/\s+/).length <= 14);
    if (!isHeading) continue;
    const levelMatch = title.match(/^(\d+(?:\.\d+)*)/);
    result.push({
      id: `inferred-${pageIndex}-${result.length}`,
      title,
      pageIndex,
      level: levelMatch ? Math.max(0, levelMatch[1].split(".").length - 1) : 0,
      source: "inferred"
    });
  }
  return result;
}

function dedupeOutline(items: OutlineItem[]): OutlineItem[] {
  const seen = new Set<string>();
  return items.filter((item) => {
    const key = `${item.pageIndex}:${item.title.toLowerCase()}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function renderOutline(): void {
  elements.outlineList.replaceChildren();
  const source = outlineItems[0]?.source;
  elements.outlineSource.textContent =
    source === "embedded" ? "内置目录" : source === "inferred" ? "推断目录" : "尚未加载目录";
  elements.outlineCount.textContent = outlineItems.length ? `${outlineItems.length} 项` : "";

  if (outlineItems.length === 0) {
    const empty = document.createElement("div");
    empty.className = "sidebar-empty";
    empty.textContent = activeDocument ? "正在提取目录，或该 PDF 没有可识别章节" : "请先打开论文";
    elements.outlineList.append(empty);
    return;
  }

  for (const item of outlineItems) {
    const button = document.createElement("button");
    button.className = "outline-item";
    button.dataset.pageIndex = String(item.pageIndex);
    button.style.paddingLeft = `${10 + item.level * 12}px`;
    const title = document.createElement("span");
    title.textContent = item.title;
    const page = document.createElement("small");
    page.textContent = `P${item.pageIndex + 1}`;
    button.append(title, page);
    button.addEventListener("click", () => void navigateToPage(item.pageIndex));
    elements.outlineList.append(button);
  }
}

async function navigateToPage(pageIndex: number): Promise<void> {
  const target = elements.pdfPages.querySelector<HTMLElement>(
    `.pdf-page[data-page-index="${pageIndex}"]`
  );
  if (!target) return;
  await renderPage(pageIndex, renderGeneration);
  target.scrollIntoView({ behavior: "smooth", block: "start" });
  currentPageIndex = pageIndex;
  updatePageStatus();
}

function updateCurrentPage(): void {
  const viewportTop = elements.pdfScroll.getBoundingClientRect().top + 70;
  let bestIndex = currentPageIndex;
  let bestDistance = Number.POSITIVE_INFINITY;
  for (const page of elements.pdfPages.querySelectorAll<HTMLElement>(".pdf-page")) {
    const distance = Math.abs(page.getBoundingClientRect().top - viewportTop);
    if (distance < bestDistance) {
      bestDistance = distance;
      bestIndex = Number(page.dataset.pageIndex);
    }
  }
  if (bestIndex !== currentPageIndex) {
    currentPageIndex = bestIndex;
    updatePageStatus();
  }
}

function updatePageStatus(): void {
  elements.pageStatus.textContent = activeDocument
    ? `第 ${currentPageIndex + 1} / ${activeDocument.numPages} 页`
    : "";
  for (const item of elements.outlineList.querySelectorAll<HTMLElement>(".outline-item")) {
    item.classList.toggle("active", Number(item.dataset.pageIndex) === currentPageIndex);
  }
}

async function changeZoom(delta: number): Promise<void> {
  if (!activeDocument) return;
  scale = Math.min(2.2, Math.max(0.6, Math.round((scale + delta) * 10) / 10));
  elements.zoomValue.textContent = `${Math.round(scale * 100)}%`;
  const generation = ++renderGeneration;
  setDocumentStatus("正在重新布局…");
  try {
    await prepareDocument(activeDocument, generation);
    await navigateToPage(currentPageIndex);
    setDocumentStatus(`${activeDocument.numPages} 页`);
  } catch (error) {
    setDocumentStatus(errorMessage(error), true);
  }
}

function handleReaderSelection(): void {
  window.setTimeout(() => {
    const selection = window.getSelection();
    const text = normalizeSelectedText(selection?.toString() ?? "");
    if (!selection || selection.rangeCount === 0 || !text) {
      hideSelectionPopover();
      return;
    }

    const range = selection.getRangeAt(0);
    const node = range.commonAncestorContainer;
    const element = node.nodeType === Node.ELEMENT_NODE ? (node as Element) : node.parentElement;
    const page = element?.closest<HTMLElement>(".pdf-page");
    if (!page) return;

    currentSelection = {
      text,
      pageIndex: Number(page.dataset.pageIndex ?? 0),
      rect: range.getBoundingClientRect()
    };
    showSelectionPopover(currentSelection);
  }, 0);
}

function normalizeSelectedText(text: string): string {
  return text
    .replace(/\r\n?/g, "\n")
    .replace(/[ \t]*\n[ \t]*\n+[ \t]*/g, "\n\n")
    .split("\n\n")
    .map((paragraph) => {
      const lines = paragraph
        .split("\n")
        .map((line) => line.replace(/[ \t]+/g, " ").trim())
        .filter(Boolean);
      return lines.reduce((merged, line) => {
        if (!merged) return line;
        if (/[A-Za-z]-$/.test(merged) && /^[a-z]/.test(line)) {
          return `${merged.slice(0, -1)}${line}`;
        }
        return `${merged} ${line}`;
      }, "");
    })
    .filter(Boolean)
    .join("\n\n")
    .trim();
}

function showSelectionPopover(selection: SelectionState): void {
  const mathSelection = isLikelyFormula(selection.text);
  const popover = document.createElement("div");
  popover.className = "selection-popover";
  popover.innerHTML = `
    <div class="selection-actions">
      <select aria-label="目标语言">
        <option value="zh">中文</option>
        <option value="en">English</option>
        <option value="ja">日本語</option>
        <option value="ko">한국어</option>
      </select>
      <button class="secondary-button" data-action="chat">加入对话</button>
      <button class="secondary-button" data-action="explain">${mathSelection ? "解释公式" : "AI 解释"}</button>
      <span class="subtle">P${selection.pageIndex + 1}</span>
    </div>
    <div class="translation-result">翻译中…</div>
  `;

  const result = popover.querySelector<HTMLDivElement>(".translation-result")!;
  const target = popover.querySelector<HTMLSelectElement>("select")!;
  let translationRequest = 0;
  let translationAnimation: AbortController | undefined;
  const runTranslation = async () => {
    const request = ++translationRequest;
    translationAnimation?.abort();
    translationAnimation = new AbortController();
    result.textContent = "翻译中…";
    try {
      if (hasConfiguredAIProvider(settings)) {
        result.textContent = "";
        result.classList.add("streaming");
        try {
          await streamTranslationWithAI({
            settings,
            text: selection.text,
            target: target.value,
            signal: translationAnimation.signal,
            onDelta: (delta) => {
              if (request !== translationRequest) return;
              result.textContent += delta;
              result.scrollTop = result.scrollHeight;
              positionPopover(popover, selection.rect);
            }
          });
          result.classList.remove("streaming");
        } catch (error) {
          result.classList.remove("streaming");
          if ((error as DOMException)?.name === "AbortError") throw error;
          result.textContent = "AI 翻译暂不可用，正在切换基础翻译…";
          const translated = await translateText(selection.text, target.value);
          if (request !== translationRequest) return;
          await streamTranslationResult(result, translated, translationAnimation.signal);
        }
      } else {
        const translated = await translateText(selection.text, target.value);
        if (request !== translationRequest) return;
        await streamTranslationResult(result, translated, translationAnimation.signal);
      }
    } catch (error) {
      result.classList.remove("streaming");
      if (request === translationRequest && (error as DOMException)?.name !== "AbortError") {
        result.textContent = errorMessage(error);
      }
    }
    positionPopover(popover, selection.rect);
  };
  target.addEventListener("change", () => void runTranslation());
  popover.querySelector('[data-action="chat"]')?.addEventListener("click", () => {
    pinSelection(selection);
    hideSelectionPopover();
    elements.chatInput.focus();
  });
  popover.querySelector('[data-action="explain"]')?.addEventListener("click", () => {
    pinSelection(selection);
    hideSelectionPopover();
    const prompt = mathSelection
      ? "请解释这个公式的直觉、关键符号、推导关系，以及它在论文中的作用。"
      : "请解释选中内容的核心含义、上下文和它在论文中的作用。";
    void sendPrompt(prompt);
  });

  elements.selectionPopoverRoot.replaceChildren(popover);
  positionPopover(popover, selection.rect);
  void runTranslation();
}

async function streamTranslationResult(
  container: HTMLElement,
  text: string,
  signal: AbortSignal
): Promise<void> {
  container.textContent = "";
  container.classList.add("streaming");
  const characters = Array.from(text);
  const segments: string[] = [];
  for (let index = 0; index < characters.length; index += 8) {
    segments.push(characters.slice(index, index + 8).join(""));
  }

  try {
    for (const segment of segments) {
      if (signal.aborted) throw new DOMException("Translation stream cancelled", "AbortError");
      container.textContent += segment;
      container.scrollTop = container.scrollHeight;
      await new Promise<void>((resolve) => requestAnimationFrame(() => resolve()));
    }
  } finally {
    container.classList.remove("streaming");
  }
}

function positionPopover(popover: HTMLElement, anchor: DOMRect): void {
  const margin = 12;
  const width = popover.offsetWidth || 420;
  const height = popover.offsetHeight || 130;
  const left = Math.min(
    window.innerWidth - width - margin,
    Math.max(margin, anchor.left + anchor.width / 2 - width / 2)
  );
  const preferredTop = anchor.bottom + 10;
  const rawTop =
    preferredTop + height < window.innerHeight - margin
      ? preferredTop
      : Math.max(margin, anchor.top - height - 10);
  const top = Math.min(window.innerHeight - height - margin, Math.max(margin, rawTop));
  popover.style.left = `${left}px`;
  popover.style.top = `${top}px`;
}

function hideSelectionPopover(): void {
  elements.selectionPopoverRoot.replaceChildren();
}

function pinSelection(selection: SelectionState): void {
  pinnedSelection = selection;
  renderSelectionChip();
}

function clearPinnedSelection(): void {
  pinnedSelection = undefined;
  renderSelectionChip();
}

function renderSelectionChip(): void {
  elements.selectionChip.hidden = !pinnedSelection;
  elements.selectionChipText.textContent = pinnedSelection
    ? `已附加选区 P${pinnedSelection.pageIndex + 1} · ${pinnedSelection.text.length} 字`
    : "";
}

function isLikelyFormula(text: string): boolean {
  const mathSymbols = /[=^_∑∏√∞≈≤≥±×÷∫]|\\(?:frac|sum|prod|alpha|beta|theta)/;
  const variableExpression = /\b[a-zA-Z]\s*[=<>]\s*[\w(]/;
  return mathSymbols.test(text) || variableExpression.test(text);
}

async function sendMessage(): Promise<void> {
  if (chatAbortController) {
    chatAbortController.abort();
    return;
  }
  const content = elements.chatInput.value.trim();
  if (!content) return;
  elements.chatInput.value = "";
  await sendPrompt(content);
}

async function sendPrompt(content: string): Promise<void> {
  if (chatAbortController) return;
  if (!activeDocument) {
    setChatStatus("请先在浏览器打开 PDF，再点击扩展图标", true);
    return;
  }

  const userMessage: ChatMessage = { id: crypto.randomUUID(), role: "user", content };
  const requestMessages = [...chatMessages, userMessage];
  const assistantMessage: ChatMessage = {
    id: crypto.randomUUID(),
    role: "assistant",
    content: ""
  };
  chatMessages = [...requestMessages, assistantMessage];
  renderChat();

  chatAbortController = new AbortController();
  elements.sendButton.textContent = "停止";
  setChatStatus("正在生成…");
  updateChatButtons();

  try {
    await streamChat({
      settings,
      messages: requestMessages,
      paperTitle: activePaperTitle,
      paperContext,
      selection: pinnedSelection?.text,
      thinkingMode: elements.thinkingMode.value as "fast" | "deep",
      signal: chatAbortController.signal,
      onDelta: (delta) => {
        assistantMessage.content += delta;
        updateLastAssistantMessage(assistantMessage.content, false);
      }
    });
    updateLastAssistantMessage(assistantMessage.content, true);
    setChatStatus("");
  } catch (error) {
    if ((error as DOMException)?.name === "AbortError") {
      setChatStatus("已停止");
      if (!assistantMessage.content) {
        chatMessages = chatMessages.filter((message) => message.id !== assistantMessage.id);
        renderChat();
      }
    } else {
      assistantMessage.content ||= `请求失败：${errorMessage(error)}`;
      updateLastAssistantMessage(assistantMessage.content, true);
      setChatStatus(errorMessage(error), true);
    }
  } finally {
    chatAbortController = undefined;
    elements.sendButton.textContent = "发送";
    updateChatButtons();
  }
}

function renderChat(): void {
  elements.chatMessages.replaceChildren();
  if (chatMessages.length === 0) {
    const empty = document.createElement("div");
    empty.className = "chat-empty";
    empty.innerHTML = `
      <strong>和论文聊一聊</strong>
      <p>选择一段内容，或直接从下面的问题开始。</p>
      <div class="prompt-grid">
        <button>总结这篇论文的核心贡献</button>
        <button>解释论文采用的方法和关键假设</button>
        <button>审查实验设计、结果和局限性</button>
      </div>
    `;
    for (const button of empty.querySelectorAll("button")) {
      button.addEventListener("click", () => void sendPrompt(button.textContent ?? ""));
    }
    elements.chatMessages.append(empty);
    updateChatButtons();
    return;
  }

  for (const message of chatMessages) {
    const wrapper = document.createElement("article");
    wrapper.className = `message ${message.role}`;
    wrapper.dataset.messageId = message.id;
    const header = document.createElement("div");
    header.className = "message-header";
    const role = document.createElement("div");
    role.className = "message-role";
    role.textContent = message.role === "user" ? "你" : "PaperMind";
    header.append(role);
    if (message.role === "assistant" && message.content) {
      const copy = document.createElement("button");
      copy.className = "message-action";
      copy.textContent = "复制";
      copy.addEventListener("click", () => void copyText(message.content));
      header.append(copy);
    }
    const body = document.createElement("div");
    body.className = "message-body";
    renderMessageBody(body, message.content, message.role === "assistant");
    wrapper.append(header, body);
    elements.chatMessages.append(wrapper);
  }
  elements.chatMessages.scrollTop = elements.chatMessages.scrollHeight;
  updateChatButtons();
}

function updateLastAssistantMessage(content: string, markdown: boolean): void {
  const message = chatMessages.at(-1);
  if (!message || message.role !== "assistant") return;
  message.content = content;
  const body = elements.chatMessages.querySelector<HTMLElement>(
    `[data-message-id="${message.id}"] .message-body`
  );
  if (!body) return;
  renderMessageBody(body, content, markdown);
  elements.chatMessages.scrollTop = elements.chatMessages.scrollHeight;
}

function renderMessageBody(container: HTMLElement, content: string, markdown: boolean): void {
  if (!markdown) {
    container.textContent = content || "…";
    return;
  }
  const html = marked.parse(content);
  container.innerHTML = DOMPurify.sanitize(typeof html === "string" ? html : "");
}

function newChat(): void {
  chatAbortController?.abort();
  chatMessages = [];
  clearPinnedSelection();
  elements.chatInput.value = "";
  setChatStatus("");
  renderChat();
}

async function retryLastMessage(): Promise<void> {
  if (chatAbortController) return;
  let userIndex = -1;
  for (let index = chatMessages.length - 1; index >= 0; index -= 1) {
    if (chatMessages[index].role === "user") {
      userIndex = index;
      break;
    }
  }
  if (userIndex < 0) return;
  const prompt = chatMessages[userIndex].content;
  chatMessages = chatMessages.slice(0, userIndex);
  await sendPrompt(prompt);
}

async function copyLastAnswer(): Promise<void> {
  const answer = [...chatMessages].reverse().find((message) => message.role === "assistant");
  if (!answer?.content) return;
  await copyText(answer.content);
}

async function copyText(text: string): Promise<void> {
  await navigator.clipboard.writeText(text);
  setChatStatus("已复制");
}

function updateChatButtons(): void {
  const hasUser = chatMessages.some((message) => message.role === "user");
  const hasAnswer = chatMessages.some(
    (message) => message.role === "assistant" && message.content.length > 0
  );
  elements.retryButton.disabled = !hasUser || Boolean(chatAbortController);
  elements.copyLastButton.disabled = !hasAnswer;
  elements.newChatButton.disabled = chatMessages.length === 0 && !pinnedSelection;
}

async function updateChatProvider(): Promise<void> {
  settings = { ...settings, provider: elements.chatProvider.value as Provider };
  await chrome.storage.local.set({ aiSettings: settings });
}

function showSettings(): void {
  const backdrop = document.createElement("div");
  backdrop.className = "modal-backdrop";
  backdrop.innerHTML = `
    <section class="modal" role="dialog" aria-modal="true" aria-label="AI 设置">
      <h2>设置</h2>
      <div class="subtle">API Key 仅保存在当前 Chrome 配置的扩展本地存储中，未进行额外加密。</div>
      <div class="settings-grid">
        <label for="theme">外观</label>
        <select id="theme">
          <option value="light">浅色</option>
          <option value="dark">深色</option>
        </select>
        <label for="provider">默认 Provider</label>
        <select id="provider">
          <option value="openai">OpenAI</option>
          <option value="deepseek">DeepSeek</option>
          <option value="kimi">Kimi</option>
        </select>
        <label for="openai-model">OpenAI 模型</label>
        <input id="openai-model" />
        <label for="openai-key">OpenAI Key</label>
        <input id="openai-key" type="password" autocomplete="off" />
        <label for="deepseek-model">DeepSeek 模型</label>
        <input id="deepseek-model" />
        <label for="deepseek-key">DeepSeek Key</label>
        <input id="deepseek-key" type="password" autocomplete="off" />
        <label for="kimi-model">Kimi 模型</label>
        <input id="kimi-model" />
        <label for="kimi-key">Kimi Key</label>
        <input id="kimi-key" type="password" autocomplete="off" />
      </div>
      <div class="modal-actions">
        <button class="secondary-button" data-action="cancel">取消</button>
        <button class="primary-button" data-action="save">保存</button>
      </div>
    </section>
  `;

  const theme = backdrop.querySelector<HTMLSelectElement>("#theme")!;
  const provider = backdrop.querySelector<HTMLSelectElement>("#provider")!;
  const openaiModel = backdrop.querySelector<HTMLInputElement>("#openai-model")!;
  const openaiKey = backdrop.querySelector<HTMLInputElement>("#openai-key")!;
  const deepseekModel = backdrop.querySelector<HTMLInputElement>("#deepseek-model")!;
  const deepseekKey = backdrop.querySelector<HTMLInputElement>("#deepseek-key")!;
  const kimiModel = backdrop.querySelector<HTMLInputElement>("#kimi-model")!;
  const kimiKey = backdrop.querySelector<HTMLInputElement>("#kimi-key")!;
  theme.value = settings.theme;
  provider.value = settings.provider;
  openaiModel.value = settings.openaiModel;
  openaiKey.value = settings.openaiKey;
  deepseekModel.value = settings.deepseekModel;
  deepseekKey.value = settings.deepseekKey;
  kimiModel.value = settings.kimiModel;
  kimiKey.value = settings.kimiKey;

  backdrop.querySelector('[data-action="cancel"]')?.addEventListener("click", () => {
    elements.modalRoot.replaceChildren();
  });
  backdrop.querySelector('[data-action="save"]')?.addEventListener("click", async () => {
    settings = {
      theme: theme.value as AISettings["theme"],
      provider: provider.value as AISettings["provider"],
      openaiModel: openaiModel.value.trim(),
      openaiKey: openaiKey.value.trim(),
      deepseekModel: deepseekModel.value.trim(),
      deepseekKey: deepseekKey.value.trim(),
      kimiModel: kimiModel.value.trim(),
      kimiKey: kimiKey.value.trim()
    };
    await chrome.storage.local.set({ aiSettings: settings });
    elements.chatProvider.value = settings.provider;
    applyTheme(settings.theme);
    elements.modalRoot.replaceChildren();
    setChatStatus("设置已保存");
  });

  backdrop.addEventListener("mousedown", (event) => {
    if (event.target === backdrop) elements.modalRoot.replaceChildren();
  });
  elements.modalRoot.replaceChildren(backdrop);
}

function applyTheme(theme: AISettings["theme"]): void {
  document.documentElement.dataset.theme = theme;
}

async function loadSettings(): Promise<AISettings> {
  const stored = await chrome.storage.local.get("aiSettings");
  return { ...DEFAULT_SETTINGS, ...(stored.aiSettings as Partial<AISettings> | undefined) };
}

function setDocumentStatus(message: string, error = false): void {
  elements.documentStatus.textContent = message;
  elements.documentStatus.classList.toggle("danger", error);
}

function setChatStatus(message: string, error = false): void {
  elements.chatStatus.textContent = message;
  elements.chatStatus.classList.toggle("error", error);
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
