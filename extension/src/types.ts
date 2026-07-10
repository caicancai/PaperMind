export type Provider = "openai" | "deepseek" | "kimi";

export interface AISettings {
  provider: Provider;
  theme: "light" | "dark";
  googleTranslateEnabled: boolean;
  openaiModel: string;
  deepseekModel: string;
  kimiModel: string;
  openaiKey: string;
  deepseekKey: string;
  kimiKey: string;
}

export interface SelectionState {
  text: string;
  pageIndex: number;
  rect: DOMRect;
}

export interface ChatMessage {
  id: string;
  role: "user" | "assistant";
  content: string;
}

export interface OutlineItem {
  id: string;
  title: string;
  pageIndex: number;
  level: number;
  source: "embedded" | "inferred";
}

export const DEFAULT_SETTINGS: AISettings = {
  provider: "openai",
  theme: "light",
  googleTranslateEnabled: false,
  openaiModel: "gpt-4o-mini",
  deepseekModel: "deepseek-chat",
  kimiModel: "kimi-2.5",
  openaiKey: "",
  deepseekKey: "",
  kimiKey: ""
};
