# PaperMind

PaperMind 是一个面向论文 PDF 的阅读工作台，把阅读、翻译、笔记和 AI 讨论放在选中文本旁边，减少复制粘贴和窗口切换。

<p align="center">
  <a href="https://github.com/caicancai/PaperMind/releases"><img src="https://img.shields.io/badge/Release-GitHub-blue?logo=github" alt="Release" /></a>
  <a href="https://github.com/caicancai/PaperMind/issues"><img src="https://img.shields.io/badge/Feedback-Issues-orange?logo=github" alt="Issues" /></a>
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-blue" alt="Platform" />
  <img src="https://img.shields.io/badge/swift-5.10%2B-orange" alt="Swift" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="License" /></a>
</p>

## 能做什么

PaperMind 现在有两个入口：

| 入口 | 适合场景 | 状态 |
|---|---|---|
| macOS App | 本地论文库、锚点笔记、翻译、长期阅读工作区 | 主应用 |
| Chrome 扩展 | 在浏览器当前 PDF 标签页里快速阅读、翻译和 AI 讨论 | 浏览器伴侣 |

核心工作流：

- 阅读 PDF，支持目录和阅读优先布局。
- 选中文本后翻译、解释、加入对话或保存为笔记。
- 用 OpenAI、DeepSeek、Kimi 和当前论文对话。
- 对公式类选区使用专门的解释入口。
- macOS App 支持把笔记锚定到 PDF 选区。

## 演示

演示视频：[`docs/demo.mp4`](docs/demo.mp4)
媒体制作流程：[`docs/README-media.md`](docs/README-media.md)

## 安装

打包版本见 [GitHub Releases](https://github.com/caicancai/PaperMind/releases)。

本地开发：

```bash
git clone https://github.com/caicancai/PaperMind.git
cd PaperMind
swift build
open .build/debug/PaperMind
```

环境要求：

- macOS 13+
- Swift 5.10+

## Chrome 扩展

扩展会接管当前 PDF 标签页并复用该标签页。支持 PDF.js 懒加载、内置/推断目录、划词翻译、跨页选区、公式解释和流式 AI 对话控制。

```bash
cd extension
npm install
npm run build
```

然后打开 `chrome://extensions`，开启开发者模式，加载 `extension/dist`。

浏览器版说明：

- 本地 `file://` PDF 需要在扩展详情页开启“允许访问文件网址”。
- 浏览器版暂不包含笔记，也不持久化聊天历史。
- 扩展测试使用生成 PDF 和 mock 的 AI/翻译流：

```bash
cd extension
npm test
```

## AI Provider

在应用设置里配置 Provider、模型和 API Key。当前支持：

- OpenAI
- DeepSeek
- Kimi

API Key 保存在本地应用配置中。Provider 或 Key 缺失时会直接提示配置错误，不会静默回退 mock。

## 打包

生成本地 DMG：

```bash
./scripts/package-dmg.sh
```

生成签名和公证的发布 DMG：

```bash
./scripts/release-dmg.sh v0.2.2 \
  --identity "Developer ID Application: Your Name (TEAMID)" \
  --notary-profile "PaperMindNotary"
```

如果跳过签名或公证，macOS 可能会阻止打开应用。

## Roadmap

- 改进 PDF 上下文抽取，提高整篇论文问答质量。
- 如果扩展从伴侣模式继续扩展，考虑持久化浏览器对话历史。

## 反馈

欢迎提交问题和功能建议：<https://github.com/caicancai/PaperMind/issues>

## License

MIT，详见 [LICENSE](./LICENSE)。
