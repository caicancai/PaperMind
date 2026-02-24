# Agent.md

## 项目名称
PaperMind（Swift 论文阅读助手）

## 目标
构建一个基于 Swift/macOS 的论文阅读应用，核心能力：
1. 导入并阅读论文（优先 PDF）。
2. 划词/划句翻译（中英互译）。
3. 就论文内容与大模型对话（问答、总结、解释术语）。
4. 做结构化笔记（按论文、按片段、按时间）。

## MVP 范围
1. 论文库：本地导入、列表展示、最近阅读。
2. 阅读器：显示 PDF，支持文本选择事件。
3. 翻译：对选中文本调用翻译服务并展示结果。
4. AI 对话：以“当前论文 + 当前选中内容”为上下文发起问答。
5. 笔记：创建/编辑/删除笔记，支持绑定到论文和引用片段。
6. 本地持久化：论文元数据、会话和笔记持久化。

## 非目标（当前阶段）
1. 云同步与多端实时同步。
2. OCR（扫描版 PDF 识别）。
3. 团队协作与分享。
4. 复杂引用管理（BibTeX/EndNote 深度集成）。

## 技术栈
1. 语言与框架：Swift 5.10+，SwiftUI，PDFKit。
2. 架构：MVVM + Service Layer + Repository。
3. 存储：首版可用 JSON/SQLite；后续迁移 SwiftData/CoreData。
4. 网络：URLSession。
5. LLM/翻译：Provider 抽象，支持后续接 OpenAI/DeepL/Google/自建服务。

## 建议目录结构
```text
PaperMind/
  App/
    PaperMindApp.swift
    RootView.swift
  Features/
    Library/
    Reader/
    Translate/
    Chat/
    Notes/
  Core/
    Models/
    Protocols/
    Utils/
  Services/
    LLM/
    Translation/
    Storage/
    Parsing/
  Resources/
  Tests/
```

## 领域模型（最小集）
1. Paper
- `id: UUID`
- `title: String`
- `authors: [String]`
- `fileURL: URL`
- `tags: [String]`
- `createdAt: Date`
- `lastOpenedAt: Date?`

2. TextSelection
- `paperID: UUID`
- `pageIndex: Int`
- `selectedText: String`
- `contextBefore: String?`
- `contextAfter: String?`

3. TranslationRecord
- `id: UUID`
- `selection: TextSelection`
- `sourceLang: String`
- `targetLang: String`
- `translatedText: String`
- `createdAt: Date`

4. ChatMessage
- `id: UUID`
- `sessionID: UUID`
- `role: user | assistant | system`
- `content: String`
- `createdAt: Date`

5. Note
- `id: UUID`
- `paperID: UUID`
- `title: String`
- `content: String`
- `quote: String?`
- `pageIndex: Int?`
- `tags: [String]`
- `createdAt: Date`
- `updatedAt: Date`

## 核心协议（先抽象后实现）
```swift
protocol TranslationService {
    func translate(text: String, source: String?, target: String) async throws -> String
}

protocol LLMService {
    func chat(messages: [ChatMessage], context: PaperContext?) async throws -> String
}

protocol PaperRepository {
    func listPapers() async throws -> [Paper]
    func addPaper(fileURL: URL) async throws -> Paper
    func removePaper(id: UUID) async throws
}

protocol NoteRepository {
    func listNotes(paperID: UUID) async throws -> [Note]
    func save(note: Note) async throws
    func delete(noteID: UUID) async throws
}
```

## UI 交互要求
1. 主界面三栏：论文列表 | 阅读区 | 侧边栏（翻译/聊天/笔记）。
2. 在阅读区选择文本后，应立即出现快捷操作：
- `翻译`
- `问 AI`
- `加入笔记`
3. 当前交互基线：选中后在阅读区出现就地悬浮窗（自动翻译 + 快捷操作），减少视线跳转。
4. 所有网络请求状态都必须有可见反馈：`loading/success/error`。

## Prompt 约定（给 LLM）
1. 回答尽量基于“当前论文内容 + 选中文本”。
2. 当信息不足时，明确说“依据不足”，并给出需要的上下文。
3. 支持两种模式：
- `Explain`: 解释术语/段落。
- `Summarize`: 摘要当前章节/选区。

## 安全与隐私
1. 默认本地存储，不上传整篇论文；只上传用户触发的选中文本与必要上下文。
2. API Key 使用系统 Keychain 存储，不写入明文文件。
3. 提供“清空会话与缓存”能力。

## 开发阶段计划
1. Phase 1: 项目骨架 + 模型 + Mock Service + 基础 UI。
2. Phase 2: PDF 阅读与选择事件接入。
3. Phase 3: 接入真实翻译与 LLM Provider。
4. Phase 4: 笔记持久化与检索。
5. Phase 5: 性能优化与可用性打磨。

## 验收标准（MVP）
1. 可导入至少 3 篇 PDF 并切换阅读。
2. 任意选中文本可在 2 秒内返回翻译（Mock/真实均可）。
3. 能围绕选中内容发起至少 3 轮问答，消息可回看。
4. 笔记可增删改查，并能定位到所属论文。

## 当前实现状态（2026-02-24）
1. 已完成：SwiftUI 三栏主界面、PDF 阅读与选区事件、AI 对话面板、笔记面板。
2. 已完成：`PaperRepository` / `NoteRepository` JSON 持久化。
3. 已完成：翻译默认使用 Google（失败自动回退到 Mock）。
4. 已完成：LLM 支持 OpenAI Provider（未配置 `OPENAI_API_KEY` 时回退到 Mock）。
5. 已完成：阅读区“划词悬浮翻译窗”（选中即自动翻译，支持重试/问 AI/加入笔记）。
6. 已完成：阅读区宽度优先（中栏最小宽度提升）与悬浮窗位置跟随动画、自适应宽度。
7. 当前限制：测试目标已从 `Package.swift` 移除，项目当前按“仅构建运行”维护。
8. 变更说明：按产品决策，笔记/评论功能已在 UI 层临时下线，当前主流程聚焦“阅读 + 划词翻译 + AI 对话”。
9. 交互更新：右侧侧栏已调整为 AI 专用讨论区，支持基于当前选区发起 Explain/Summarize 对话。

## 最近核心改动（交互层）
1. 由“侧边栏翻译为主”调整为“阅读区就地翻译为主”，减少跨栏操作成本。
2. 选区变化触发防抖自动翻译，避免频繁请求导致闪烁与无效调用。
3. 悬浮窗采用上方优先、下方兜底的定位策略，并对边界进行裁剪防止越界。
4. 阅读列宽度显著提高，确保论文正文可读性优先于工具面板。

## 评论式笔记方案（参考 Google Docs）
1. 目标交互：把“笔记”演进为“评论线程（Comment Thread）”，每条评论绑定选区锚点。
2. 入口交互：选中文本后，迷你工具条提供 `高亮` `评论` `翻译` `问 AI`。
3. 线程布局：右侧显示评论线程列表，按“未解决/已解决”分组，可折叠。
4. 双向联动：点击文中高亮片段可定位到线程；点击线程可回跳到文中片段。
5. 线程能力：支持回复、解决、恢复、编辑首条评论、删除线程。
6. 数据模型建议：新增 `CommentThread` 与 `CommentMessage`，并保留与 `Note` 的向后兼容迁移。
7. MVP 演进顺序：先做单层评论（无回复）-> 再做回复与状态 -> 最后做筛选与搜索。

## 实现注意点（必须遵守）
1. 阅读优先：任何新功能不得明显压缩阅读区宽度，必要时自动折叠侧栏。
2. 锚点稳定性：PDF 高亮锚点不能只依赖纯文本匹配，至少保存 `paperID + pageIndex + quote + rect`。
3. 性能：选区事件必须做防抖和取消，避免快速拖选触发并发翻译请求。
4. 可恢复性：评论/笔记操作写入失败时要有错误提示且不丢本地草稿。
5. 一致性：悬浮窗中的“加入笔记/评论”与右侧列表状态必须实时同步。
6. 可扩展：继续坚持协议层抽象，禁止把 Provider 细节直接写进 ViewModel。
7. 隐私：默认仅发送选区和必要上下文，不上传整篇论文正文。

## 待完善清单（按优先级）
1. 高优先级：完善 PDF 上下文抽取（`contextBefore/contextAfter`），提升翻译和问答准确性。
2. 高优先级：对话历史持久化（按论文保存 session，重启后可恢复）。
3. 高优先级：笔记升级为“评论线程”交互（锚点、高亮、线程、解决状态、双向定位）。
4. 高优先级：线程基础能力（编辑/回复/删除/解决）与本地持久化。
5. 中优先级：接入 Keychain 管理 API Key，避免从环境变量读取。
6. 中优先级：翻译服务增强（语言检测、术语保留、失败重试与更清晰错误提示）。
7. 中优先级：LLM Prompt 分层（Explain/Summarize 分离模板，并加入 token/上下文长度控制）。
8. 中优先级：导入体验优化（重复导入提示、文件不可读提示、批量导入）。
9. 低优先级：存储升级评估（JSON -> SwiftData/CoreData）及迁移策略。
10. 低优先级：恢复自动化测试（在可用 Xcode/XCTest 环境下重新启用 `testTarget` 与基础单测）。

## 协作规则（给后续 Agent）
1. 每次改动先说明目的，再最小化修改范围。
2. 先实现协议，再补具体 Provider，避免强耦合。
3. 新增依赖前必须说明必要性与替代方案。
4. 所有异步请求必须处理超时、取消和错误态。
5. 关键逻辑必须配单元测试（至少覆盖成功和失败路径）。
