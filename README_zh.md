# PaperMind

PaperMind 是一个面向论文 PDF 的 Chrome 阅读助手。在浏览器打开 PDF，点击 PaperMind，就能在当前标签页里划词翻译、问 AI、解释公式。

<p align="center">
  <a href="https://github.com/caicancai/PaperMind/releases"><img src="https://img.shields.io/badge/Release-GitHub-blue?logo=github" alt="Release" /></a>
  <a href="https://github.com/caicancai/PaperMind/issues"><img src="https://img.shields.io/badge/Feedback-Issues-orange?logo=github" alt="Issues" /></a>
  <img src="https://img.shields.io/badge/Chrome-Manifest%20V3-blue?logo=googlechrome" alt="Chrome Manifest V3" />
  <img src="https://img.shields.io/badge/TypeScript-Extension-blue?logo=typescript" alt="TypeScript" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="License" /></a>
</p>

## 能做什么

- 在当前浏览器 PDF 标签页中打开 PaperMind。
- 使用 PDF.js 懒加载长论文。
- 显示 PDF 内置目录，或自动推断章节目录。
- 支持更顺滑的划词翻译，包括跨页选区。
- 跨页翻译时尽量避开页眉、页脚和侧边元数据。
- 支持公式解释和流式 AI 对话。
- 支持 OpenAI、DeepSeek、Kimi。

## 安装 Chrome 扩展

```bash
git clone https://github.com/caicancai/PaperMind.git
cd PaperMind
cd extension
npm install
npm run build
```

然后打开 `chrome://extensions`，开启开发者模式，加载 `extension/dist`。

浏览器版说明：

- 本地 `file://` PDF 需要在扩展详情页开启“允许访问文件网址”。
- 浏览器版暂不持久化聊天历史。

## AI 设置

在扩展设置里配置 Provider、模型和 API Key。当前支持：

- OpenAI
- DeepSeek
- Kimi

API Key 保存在本地扩展配置中。Provider 或 Key 缺失时会直接提示配置错误，不会静默回退 mock。
Google 基础翻译默认关闭；启用后，未配置 AI Provider 或 AI 翻译失败时会把选中文本发送给 Google。

## 开发

```bash
cd extension
npm test
```

## Roadmap

- 改进 PDF 上下文抽取，提高整篇论文问答质量。
- 持久化浏览器对话历史。

## 反馈

欢迎提交问题和功能建议：<https://github.com/caicancai/PaperMind/issues>

## License

MIT，详见 [LICENSE](./LICENSE)。
