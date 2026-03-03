# PaperMind

一个基于 Swift/macOS 的论文阅读助手。当前版本聚焦三件事：
- 读论文（PDF）
- 划词翻译（默认 Google 翻译）
- 侧边栏和 AI 讨论（支持选区问答与公式解释）

<p align="center">
  <a href="https://github.com/caicancai/PaperMind/releases"><img src="https://img.shields.io/badge/Release-GitHub-blue?logo=github" alt="Release" /></a>
  <a href="https://github.com/caicancai/PaperMind/releases/latest"><img src="https://img.shields.io/badge/Downloads-Latest%20Assets-2ea44f?logo=github" alt="Downloads" /></a>
  <a href="https://github.com/caicancai/PaperMind/issues"><img src="https://img.shields.io/badge/Feedback-Issues-orange?logo=github" alt="Issues" /></a>
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-blue" alt="Platform" />
  <img src="https://img.shields.io/badge/swift-5.10%2B-orange" alt="Swift" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="License" /></a>
</p>

## 快速入口

| Release | Downloads | 反馈 |
|---|---|---|
| [GitHub Releases](https://github.com/caicancai/PaperMind/releases) | [最新版本资源](https://github.com/caicancai/PaperMind/releases/latest) | [提交 Issue](https://github.com/caicancai/PaperMind/issues) |

## 当前功能

- 论文库
  - 导入本地 PDF
  - 列表切换与删除
  - 可关闭当前论文（不删除文件）
- 阅读体验
  - 中间主阅读区优先布局
  - 选中文本后显示悬浮卡片
- 翻译
  - 选区自动翻译
  - 默认使用 Google 翻译
  - 悬浮卡片内可快速切换目标语言（`zh/en/ja/ko`）
  - 长翻译支持展开/收起与自动滚动
- AI 对话
  - 右侧 AI 讨论栏
  - 可基于当前选区 `Explain`
  - 不选区也可自由提问
  - 支持“解释公式”快捷入口（检测到公式时显示）
  - 支持 `OpenAI`、`DeepSeek`、`Kimi` 三家厂商
  - 首次回答前会先本地预读论文并缓存上下文
  - AI 回答支持流式输出
  - 流式结束后按 Markdown 渲染显示

## 环境要求

- macOS 13+
- Swift 5.10+

## 快速开始

```bash
git clone https://github.com/caicancai/PaperMind.git
cd PaperMind
swift build
open .build/debug/PaperMind
```

## 打包 DMG

```bash
./scripts/package-dmg.sh
```

产物路径：

```text
release/PaperMind-<version>.dmg
```

可选参数：

- `--version <vX.Y.Z>` 指定版本号
- `--debug` 使用 debug 构建打包
- `--skip-build` 不重新构建，直接使用已有二进制打包

## 正式发布 DMG（签名 + 公证）

前置条件：
- Keychain 中存在 `Developer ID Application` 证书
- 配置好 notarytool 凭据（推荐）：

```bash
xcrun notarytool store-credentials "PaperMindNotary" \
  --apple-id "<apple-id>" \
  --team-id "<team-id>" \
  --password "<app-specific-password>"
```

一键构建、签名、公证并加盖：

```bash
./scripts/release-dmg.sh v0.0.1 \
  --identity "Developer ID Application: Your Name (TEAMID)" \
  --notary-profile "PaperMindNotary"
```

若跳过签名/公证，macOS 可能提示“已损坏”或阻止打开。

## 演示

![PaperMind Demo](docs/demo.gif)

高清视频：[`docs/demo.mp4`](docs/demo.mp4)
媒体制作流程：[`docs/README-media.md`](docs/README-media.md)

## 配置 AI Provider

现在可直接在应用内 `AI 设置` 中切换 Provider/Model，API Key 会存到本地配置文件。
可通过侧栏齿轮按钮或 `Cmd + ,` 打开设置。
环境变量仍可作为兜底/初始化来源。

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
cd PaperMind
open .build/debug/PaperMind
```

使用 DeepSeek：

```bash
export AI_PROVIDER=deepseek
export DEEPSEEK_API_KEY=your_deepseek_key
cd PaperMind
open .build/debug/PaperMind
```

使用 Kimi：

```bash
export AI_PROVIDER=kimi
export KIMI_API_KEY=your_kimi_key
cd PaperMind
open .build/debug/PaperMind
```

若厂商不可用或 Key 缺失，会直接提示“未对接 AI/配置缺失”，不会静默回退 Mock。

## 公式解释交互

1. 在 PDF 中选中一段公式（如含 `=`, `^`, `\\`, `∑` 等）
2. 悬浮卡片或右侧 AI 栏会出现 `解释公式`
3. 点击后 AI 会用自然语言解释公式，重点说明直觉、关键符号和论文中的作用。

## 已知限制

- 当前测试目标未启用（当前仅维护 `swift build` 流程）
- 笔记/评论功能已在 UI 层临时下线
- API Key 当前保存在本地配置（未使用 Keychain 加密）

## 反馈与 Issue

欢迎反馈问题和功能建议。如果遇到 bug 或有改进想法，请在 GitHub 提交 Issue：

- https://github.com/caicancai/PaperMind/issues

## License

MIT，详见 [LICENSE](./LICENSE)。

## 路线图（简版）

- 更稳定的 PDF 上下文抽取（提升问答质量）
- 对话历史跨重启持久化

## 说明

详细设计与迭代约束见 [Agent.md](./Agent.md)。
