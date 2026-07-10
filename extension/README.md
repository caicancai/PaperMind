# PaperMind Chrome Extension

这是 PaperMind 的 Chrome 扩展版本，用于在浏览器当前 PDF 标签页中阅读、翻译并与 AI 讨论论文。

## 当前功能

- 在浏览器当前标签页打开 PDF 后，点击扩展即可直接接管当前标签页
- 不需要导入 PDF，也不会新建标签页或窗口
- 长文档按视口懒加载，支持缩放和当前页显示
- 支持 PDF 内置目录，并为无目录 PDF 推断章节
- PDF 文本选择、页码识别和自动翻译，可切换中/英/日/韩
- 已配置 AI Provider 时使用模型进行真正的流式学术翻译；Google 基础翻译需要在设置中明确启用
- 将选区附加到 AI 对话，支持普通解释和公式解释
- OpenAI、DeepSeek、Kimi 流式回答
- Fast / Deep 模式、停止生成、重试、复制和新建对话
- 论文总结、方法分析和实验审查快捷问题
- 浅色/深色主题
- Chrome 扩展本地 AI 设置

按产品范围，浏览器版不提供笔记功能，也不持久化聊天记录。

## 构建

需要 Node.js 20 或更高版本：

```bash
cd extension
npm install
npm run typecheck
npm run build
```

完整自动化验证：

```bash
npx playwright install chromium
npm test
```

测试会在隔离 Chromium 配置中加载真实扩展，生成测试 PDF，并模拟翻译与 AI
接口；不会使用真实 API Key。

## 安装到 Chrome

1. 打开 `chrome://extensions`
2. 开启右上角“开发者模式”
3. 点击“加载已解压的扩展程序”
4. 选择本目录生成的 `dist` 文件夹
5. 将 PaperMind 固定到 Chrome 工具栏

## 使用

1. 在 Chrome 当前标签页直接打开论文 PDF
2. 点击工具栏中的 PaperMind 图标
3. 当前标签页会直接切换到 PaperMind 阅读界面并加载这篇 PDF
4. 点击“原始 PDF”或浏览器后退，可以返回原 PDF

也可以使用快捷键：

- macOS：`Command + Shift + Y`
- Windows/Linux：`Ctrl + Shift + Y`

本地 `file://` PDF 需要打开 `chrome://extensions`，进入 PaperMind 详情页并开启
“允许访问文件网址”。

扩展需要“读取和更改所有网站上的数据”权限，是为了从当前论文 URL 读取 PDF 内容，
以及调用用户选择的翻译和 AI Provider；它不会把 PDF 保存进 PaperMind 论文库。

修改代码后重新运行 `npm run build`，再到扩展管理页点击刷新。

## 数据与安全

- PDF 直接从当前标签页的原始地址读取，不保存进 PaperMind 论文库。
- API Key 保存在 `chrome.storage.local`，不会同步到 PaperMind 服务端，但未进行额外加密。
- AI 请求会发送当前问题、可选选区及最多约 8,000 字符的论文抽取上下文。
- Google 基础翻译默认关闭；启用后会把选中文本发送到 Google 的非正式公开接口，后续正式发布前应替换为稳定服务。
