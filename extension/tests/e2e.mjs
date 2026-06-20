import assert from "node:assert/strict";
import { createServer } from "node:http";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { chromium } from "@playwright/test";
import { createPdfFixture } from "./create-fixture.mjs";

const extensionPath = resolve("dist");
const userDataDir = await mkdtemp(join(tmpdir(), "papermind-e2e-"));
const fixture = await createPdfFixture();
const inferredFixture = await createPdfFixture({ withOutline: false });
const server = createServer((request, response) => {
  const body = request.url?.includes("inferred") ? inferredFixture : fixture;
  response.writeHead(200, {
    "content-type": "application/pdf",
    "content-length": body.length
  });
  response.end(body);
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const address = server.address();
if (!address || typeof address === "string") throw new Error("test server did not start");
const pdfUrl = `http://127.0.0.1:${address.port}/browser-test-paper.pdf`;
const inferredPdfUrl = `http://127.0.0.1:${address.port}/inferred-outline-paper.pdf`;
const context = await chromium.launchPersistentContext(userDataDir, {
  channel: "chromium",
  headless: true,
  viewport: { width: 1440, height: 1000 },
  args: [
    `--disable-extensions-except=${extensionPath}`,
    `--load-extension=${extensionPath}`
  ]
});

try {
  let worker = context.serviceWorkers()[0];
  if (!worker) worker = await context.waitForEvent("serviceworker");
  const extensionId = new URL(worker.url()).host;
  assert.ok(extensionId, "extension service worker must be loaded");

  let aiRequestCount = 0;
  let translationRequestCount = 0;
  const translatedText = "这是自动翻译结果，输出会逐步显示并保持紧凑的行距。";
  await context.route("https://translate.googleapis.com/**", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify([[[translatedText, "source"]]])
    });
  });
  for (const endpoint of [
    "https://api.openai.com/**",
    "https://api.deepseek.com/**",
    "https://api.moonshot.cn/**"
  ]) {
    await context.route(endpoint, async (route) => {
      const payload = route.request().postDataJSON();
      const isTranslation = payload.messages?.[0]?.content?.includes("专业的学术论文翻译");
      const deltas = isTranslation
        ? Array.from(translatedText).reduce((chunks, character, index) => {
            const chunkIndex = Math.floor(index / 5);
            chunks[chunkIndex] = (chunks[chunkIndex] ?? "") + character;
            return chunks;
          }, [])
        : ["这是", "测试回答。"];
      if (isTranslation) translationRequestCount += 1;
      else aiRequestCount += 1;
      const body = [
        ...deltas.map(
          (delta) => `data: ${JSON.stringify({ choices: [{ delta: { content: delta } }] })}\n\n`
        ),
        "data: [DONE]\n\n"
      ].join("");
      await route.fulfill({
        status: 200,
        headers: { "content-type": "text/event-stream" },
        body
      });
    });
  }

  const page = await context.newPage();
  const initialPageCount = context.pages().length;
  const errors = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(message.text());
  });
  await page.goto(pdfUrl);
  await worker.evaluate(async (source) => {
    const tabs = await chrome.tabs.query({});
    const tab = tabs.find((candidate) => candidate.url === source);
    if (!tab) throw new Error("PDF tab not found");
    await globalThis.__paperMindOpenTab(tab);
  }, pdfUrl);
  await page.waitForURL(`chrome-extension://${extensionId}/reader.html?source=*`);
  assert.equal(context.pages().length, initialPageCount, "PaperMind must reuse the current tab");
  await page.evaluate(async () => {
    await chrome.storage.local.set({
      aiSettings: {
        provider: "openai",
        theme: "light",
        openaiModel: "gpt-4o-mini",
        deepseekModel: "deepseek-chat",
        kimiModel: "kimi-2.5",
        openaiKey: "test-key",
        deepseekKey: "",
        kimiKey: ""
      }
    });
  });
  await page.reload();

  await page.locator("#document-status").filter({ hasText: "8 页" }).waitFor();
  assert.equal(await page.locator(".pdf-page").count(), 8, "all page placeholders must exist");
  const firstCanvas = page.locator('.pdf-page[data-page-index="0"] canvas');
  await firstCanvas.waitFor();
  const firstCanvasVisible = await firstCanvas.evaluate((canvas) => {
    const rect = canvas.getBoundingClientRect();
    return rect.bottom > 0 && rect.top < window.innerHeight && rect.width > 0 && rect.height > 0;
  });
  assert.ok(firstCanvasVisible, "the first PDF page must be visible without scrolling");
  const renderedInitially = await page.locator('.pdf-page[data-render-state="rendered"]').count();
  assert.ok(renderedInitially >= 1 && renderedInitially < 8, "pages must render lazily");

  await page.locator(".outline-item").first().waitFor();
  assert.equal(await page.locator("#outline-source").textContent(), "内置目录");
  assert.equal(await page.locator(".outline-item").count(), 8);
  await page.locator(".outline-item").nth(2).click();
  await page.waitForFunction(() => document.querySelector("#page-status")?.textContent?.includes("第 3"));
  assert.equal(
    await page.locator('.pdf-page[data-page-index="2"]').getAttribute("data-render-state"),
    "rendered"
  );

  await page.evaluate(() => {
    const span = [...document.querySelectorAll('.pdf-page[data-page-index="2"] .textLayer span')]
      .find((element) => element.textContent?.includes("objective"));
    if (!span) throw new Error("formula fixture text span not found");
    const range = document.createRange();
    range.selectNodeContents(span);
    const selection = window.getSelection();
    selection?.removeAllRanges();
    selection?.addRange(range);
    document.querySelector("#pdf-scroll")?.dispatchEvent(new MouseEvent("mouseup", { bubbles: true }));
  });
  await page.getByRole("button", { name: "解释公式" }).click();
  await page.getByText("这是测试回答。").waitFor();
  assert.equal(aiRequestCount, 1, "formula explanation must issue an AI request");
  await page.locator("#new-chat-button").click();

  await page.locator(".pdf-page").first().scrollIntoViewIfNeeded();
  const selectionText = await page.evaluate(() => {
    globalThis.__translationMutations = 0;
    new MutationObserver((records) => {
      globalThis.__translationMutations += records.length;
    }).observe(document.querySelector("#selection-popover-root"), {
      subtree: true,
      childList: true,
      characterData: true
    });
    const span = [...document.querySelectorAll('.pdf-page[data-page-index="0"] .textLayer span')]
      .find((element) => element.textContent?.includes("Abstract"));
    if (!span) throw new Error("fixture text span not found");
    const range = document.createRange();
    range.selectNodeContents(span);
    const selection = window.getSelection();
    selection?.removeAllRanges();
    selection?.addRange(range);
    document.querySelector("#pdf-scroll")?.dispatchEvent(new MouseEvent("mouseup", { bubbles: true }));
    return span.textContent;
  });
  assert.ok(selectionText?.includes("Abstract"));
  await page.getByText(translatedText).waitFor();
  assert.ok(translationRequestCount >= 2, "configured AI provider must stream translations");
  assert.ok(
    await page.evaluate(() => globalThis.__translationMutations > 4),
    "translation must render through multiple incremental updates"
  );
  const translationLineHeight = await page.locator(".translation-result").evaluate((element) =>
    Number.parseFloat(getComputedStyle(element).lineHeight)
  );
  assert.ok(translationLineHeight < 21, "translation line height must remain compact");

  await page.getByRole("button", { name: "加入对话" }).click();
  await page.locator("#selection-chip").waitFor();
  await page.locator("#chat-input").fill("这段内容是什么意思？");
  await page.locator("#send-button").click();
  await page.getByText("这是测试回答。").waitFor();
  assert.equal(aiRequestCount, 2);
  assert.equal(await page.locator(".message.user").count(), 1);
  assert.equal(await page.locator(".message.assistant").count(), 1);

  await page.locator("#retry-button").click();
  await page.waitForFunction(() => document.querySelectorAll(".message.assistant").length === 1);
  await page.getByText("这是测试回答。").waitFor();
  assert.equal(aiRequestCount, 3, "retry must issue another AI request");

  await page.locator("#settings-button").click();
  await page.locator("#theme").selectOption("dark");
  await page.locator('[data-action="save"]').click();
  assert.equal(await page.locator("html").getAttribute("data-theme"), "dark");

  await page.locator("#new-chat-button").click();
  await page.getByText("和论文聊一聊").waitFor();
  assert.equal(await page.locator(".message").count(), 0);

  await page.goto(inferredPdfUrl);
  await worker.evaluate(async (source) => {
    const tabs = await chrome.tabs.query({});
    const tab = tabs.find((candidate) => candidate.url === source);
    if (!tab) throw new Error("inferred PDF tab not found");
    await globalThis.__paperMindOpenTab(tab);
  }, inferredPdfUrl);
  await page.waitForURL(`chrome-extension://${extensionId}/reader.html?source=*`);
  await page.locator("#document-status").filter({ hasText: "8 页" }).waitFor();
  await page.locator("#outline-source").filter({ hasText: "推断目录" }).waitFor();
  assert.ok(await page.locator(".outline-item").count(), "inferred outline must contain headings");

  assert.deepEqual(errors, [], `browser errors: ${errors.join("\n")}`);
  console.log(
    JSON.stringify(
      {
        extensionId,
        sameTab: "ok",
        pages: 8,
        renderedInitially,
        outlineItems: 8,
        translation: "ok",
        translationStreamRequests: translationRequestCount,
        aiStreamRequests: aiRequestCount,
        retry: "ok",
        theme: "ok",
        inferredOutline: "ok",
        browserErrors: 0
      },
      null,
      2
    )
  );
} finally {
  await context.close();
  await new Promise((resolve) => server.close(resolve));
  await rm(userDataDir, { recursive: true, force: true });
}
