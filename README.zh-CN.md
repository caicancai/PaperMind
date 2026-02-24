# PaperMind

一个基于 Swift/macOS 的论文阅读助手。当前版本聚焦三件事：
- 读论文（PDF）
- 划词翻译（默认 Google 翻译）
- 侧边栏和 AI 讨论（支持选区问答与公式解释）

## 当前功能

- 论文库
  - 导入本地 PDF
  - 列表切换与删除
- 阅读体验
  - 中间主阅读区优先布局
  - 选中文本后显示悬浮卡片
- 翻译
  - 选区自动翻译
  - 默认使用 Google 翻译
- AI 对话
  - 右侧 AI 讨论栏
  - 可基于当前选区 `Explain`
  - 不选区也可自由提问
  - 支持“解释公式”快捷入口（检测到公式时显示）
  - 支持 `OpenAI`、`DeepSeek`、`Kimi` 三家厂商
  - 首次回答前会先本地预读论文并缓存上下文
  - AI 回答按 Markdown 渲染显示

## 环境要求

- macOS 13+
- Swift 5.10+

## 快速开始

```bash
cd /Users/cc.cai/magic/PaperMind
swift build
open .build/debug/PaperMind
```

## 配置 AI Provider

当前通过环境变量选择厂商。

### 厂商切换

- `AI_PROVIDER=openai`
- `AI_PROVIDER=deepseek`
- `AI_PROVIDER=kimi`
- `AI_PROVIDER=auto`（默认，按 OpenAI -> DeepSeek -> Kimi 顺序尝试，前提是对应 Key 已配置）

也支持在项目根目录使用 `.env.local` 存放这些变量，应用会自动读取。

### 各厂商 Key 与可选模型

- OpenAI
  - `OPENAI_API_KEY`
  - 可选：`OPENAI_MODEL`（默认：`gpt-4o-mini`）
- DeepSeek
  - `DEEPSEEK_API_KEY`
  - 可选：`DEEPSEEK_MODEL`（默认：`deepseek-chat`）
- Kimi（Moonshot）
  - `KIMI_API_KEY`
  - 可选：`KIMI_MODEL`（默认：`moonshot-v1-8k`）

### 示例

使用 OpenAI：

```bash
export AI_PROVIDER=openai
export OPENAI_API_KEY=your_openai_key
cd /Users/cc.cai/magic/PaperMind
open .build/debug/PaperMind
```

使用 DeepSeek：

```bash
export AI_PROVIDER=deepseek
export DEEPSEEK_API_KEY=your_deepseek_key
cd /Users/cc.cai/magic/PaperMind
open .build/debug/PaperMind
```

使用 Kimi：

```bash
export AI_PROVIDER=kimi
export KIMI_API_KEY=your_kimi_key
cd /Users/cc.cai/magic/PaperMind
open .build/debug/PaperMind
```

若厂商不可用或 Key 缺失，会直接提示“未对接 AI/配置缺失”，不会静默回退 Mock。

## 公式解释交互

1. 在 PDF 中选中一段公式（如含 `=`, `^`, `\\`, `∑` 等）
2. 悬浮卡片或右侧 AI 栏会出现 `解释公式`
3. 点击后 AI 会按固定结构回答：
- 一句话直觉
- 符号对照表
- 公式作用
- 简单代入示例

## 已知限制

- 当前测试目标未启用（当前仅维护 `swift build` 流程）
- 笔记/评论功能已在 UI 层临时下线
- API Key 目前从环境变量或 `.env.local` 读取（尚未接入 Keychain）

## License

MIT，详见 [LICENSE](./LICENSE)。

## 路线图（简版）

- Provider/模型切换 UI（而非仅环境变量）
- 更稳定的 PDF 上下文抽取（提升问答质量）
- Keychain 管理 API Key

## 说明

详细设计与迭代约束见 [Agent.md](./Agent.md)。
