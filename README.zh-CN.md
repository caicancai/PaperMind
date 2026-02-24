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
  - 默认使用 Google 翻译，失败自动回退到 Mock
- AI 对话
  - 右侧 AI 讨论栏
  - 可基于当前选区 `Explain` / `Summarize`
  - 支持“解释公式”快捷入口（检测到公式时显示）

## 环境要求

- macOS 13+
- Swift 5.10+

## 快速开始

```bash
cd /Users/cc.cai/magic/PaperMind
swift build
swift run
```

## 配置 AI Provider

当前通过环境变量选择：

- 设置了 `OPENAI_API_KEY`：使用 OpenAI（失败自动回退 Mock）
- 未设置 `OPENAI_API_KEY`：使用 Mock

示例：

```bash
export OPENAI_API_KEY=your_api_key
cd /Users/cc.cai/magic/PaperMind
swift run
```

## 公式解释交互

1. 在 PDF 中选中一段公式（如含 `=`, `^`, `\\`, `∑` 等）
2. 悬浮卡片或右侧 AI 栏会出现 `解释公式`
3. 点击后 AI 会按固定结构回答：
- 一句话直觉
- 符号对照表
- 公式作用
- 简单代入示例

## 项目结构

```text
PaperMind/
  Agent.md
  Package.swift
  Sources/PaperMind/
    App/
    Core/
    Features/
    Services/
```

## 已知限制

- 当前测试目标未启用（仅维护 `swift build` / `swift run` 流程）
- 笔记/评论功能已在 UI 层临时下线
- API Key 目前从环境变量读取（尚未接入 Keychain）

## 路线图（简版）

- Provider/模型切换 UI（而非仅环境变量）
- 更稳定的 PDF 上下文抽取（提升问答质量）
- Keychain 管理 API Key

## 说明

详细设计与迭代约束见 [Agent.md](./Agent.md)。
