import type { AISettings, ChatMessage, Provider } from "./types";

const PROVIDERS: Record<Provider, { endpoint: string; modelKey: keyof AISettings; apiKey: keyof AISettings }> = {
  openai: {
    endpoint: "https://api.openai.com/v1/chat/completions",
    modelKey: "openaiModel",
    apiKey: "openaiKey"
  },
  deepseek: {
    endpoint: "https://api.deepseek.com/v1/chat/completions",
    modelKey: "deepseekModel",
    apiKey: "deepseekKey"
  },
  kimi: {
    endpoint: "https://api.moonshot.cn/v1/chat/completions",
    modelKey: "kimiModel",
    apiKey: "kimiKey"
  }
};

function providerConfiguration(settings: AISettings): {
  endpoint: string;
  apiKey: string;
  model: string;
} {
  const provider = PROVIDERS[settings.provider];
  return {
    endpoint: provider.endpoint,
    apiKey: String(settings[provider.apiKey]).trim(),
    model: String(settings[provider.modelKey]).trim()
  };
}

export function hasConfiguredAIProvider(settings: AISettings): boolean {
  const { apiKey, model } = providerConfiguration(settings);
  return Boolean(apiKey && model);
}

export async function translateText(text: string, target: string): Promise<string> {
  const url = new URL("https://translate.googleapis.com/translate_a/single");
  url.search = new URLSearchParams({
    client: "gtx",
    sl: "auto",
    tl: target,
    dt: "t",
    q: text
  }).toString();

  const response = await fetch(url);
  if (!response.ok) throw new Error(`翻译请求失败（HTTP ${response.status}）`);
  const payload = (await response.json()) as unknown[];
  const rows = payload[0];
  if (!Array.isArray(rows)) throw new Error("无法解析翻译结果");
  const result = rows
    .map((row) => (Array.isArray(row) && typeof row[0] === "string" ? row[0] : ""))
    .join("")
    .trim();
  if (!result) throw new Error("翻译结果为空");
  return result;
}

export async function streamChat(options: {
  settings: AISettings;
  messages: ChatMessage[];
  paperTitle: string;
  paperContext: string;
  selection?: string;
  thinkingMode: "fast" | "deep";
  signal: AbortSignal;
  onDelta: (delta: string) => void;
}): Promise<string> {
  const {
    settings,
    messages,
    paperTitle,
    paperContext,
    selection,
    thinkingMode,
    signal,
    onDelta
  } = options;
  const { endpoint, apiKey, model } = providerConfiguration(settings);
  if (!apiKey) throw new Error(`请先在设置中配置 ${settings.provider} API Key`);
  if (!model) throw new Error("模型名称不能为空");

  let system = `你是论文阅读助手。当前论文：${paperTitle}。请使用自然、准确、易读的中文回答，并优先依据论文内容。`;
  system +=
    thinkingMode === "deep"
      ? "请进行深入分析，检查论据、假设、方法限制和可能的反例，再给出结构清晰的结论。"
      : "请直接回答核心问题，避免不必要的铺陈。";
  if (paperContext) system += `\n\n[论文上下文摘录]\n${paperContext.slice(0, 8000)}`;
  if (selection) system += `\n\n[当前选区]\n${selection}`;

  return streamProviderResponse({
    endpoint,
    apiKey,
    model,
    providerName: settings.provider,
    temperature: 0.55,
    messages: [
      { role: "system", content: system },
      ...messages.map(({ role, content }) => ({ role, content }))
    ],
    signal,
    onDelta
  });
}

export async function streamTranslationWithAI(options: {
  settings: AISettings;
  text: string;
  target: string;
  signal: AbortSignal;
  onDelta: (delta: string) => void;
}): Promise<string> {
  const { settings, text, target, signal, onDelta } = options;
  const { endpoint, apiKey, model } = providerConfiguration(settings);
  if (!apiKey || !model) throw new Error("当前 AI Provider 尚未配置");

  const languageNames: Record<string, string> = {
    zh: "简体中文",
    en: "英文",
    ja: "日文",
    ko: "韩文"
  };
  const targetLanguage = languageNames[target] ?? target;

  return streamProviderResponse({
    endpoint,
    apiKey,
    model,
    providerName: settings.provider,
    temperature: 0.2,
    messages: [
      {
        role: "system",
        content:
          `你是专业的学术论文翻译。把用户提供的内容自然、准确地翻译成${targetLanguage}。` +
          "保留公式、术语和原有段落；合并 PDF 排版产生的无意义断行。只输出译文，不解释、不添加标题。"
      },
      { role: "user", content: text }
    ],
    signal,
    onDelta
  });
}

async function streamProviderResponse(options: {
  endpoint: string;
  apiKey: string;
  model: string;
  providerName: string;
  temperature: number;
  messages: Array<{ role: string; content: string }>;
  signal: AbortSignal;
  onDelta: (delta: string) => void;
}): Promise<string> {
  const {
    endpoint,
    apiKey,
    model,
    providerName,
    temperature,
    messages,
    signal,
    onDelta
  } = options;
  const response = await fetch(endpoint, {
    method: "POST",
    signal,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`
    },
    body: JSON.stringify({
      model,
      stream: true,
      temperature,
      messages
    })
  });

  if (!response.ok) {
    const detail = (await response.text()).slice(0, 500);
    throw new Error(`${providerName} 请求失败（HTTP ${response.status}）${detail ? `：${detail}` : ""}`);
  }
  if (!response.body) throw new Error("AI 响应不支持流式读取");

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let full = "";

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split("\n");
    buffer = lines.pop() ?? "";

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed.startsWith("data:")) continue;
      const data = trimmed.slice(5).trim();
      if (!data || data === "[DONE]") continue;
      try {
        const chunk = JSON.parse(data) as {
          choices?: Array<{ delta?: { content?: string } }>;
        };
        const delta = chunk.choices?.[0]?.delta?.content ?? "";
        if (delta) {
          full += delta;
          onDelta(delta);
        }
      } catch {
        // A malformed provider event should not discard the rest of the stream.
      }
    }
  }

  if (!full.trim()) throw new Error("AI 响应为空");
  return full;
}
