# AIOStudio 分阶段开发指南

> **项目名称**：AIOStudio  
> **定位**：跨平台 AGI 项目与资产管理工具  
> **技术栈**：Flutter (Dart) + TypeScript (浏览器扩展)  
> **UI 框架**：[fluent_ui](https://github.com/bdlukaa/fluent_ui) ^4.14.0  
> **目标平台**：Windows / macOS / Linux / iOS / Android / Web

---

## 目录

- [技术栈总览](#技术栈总览)
- [项目结构规划](#项目结构规划)
- [Phase 1 — 项目初始化与基础框架](#phase-1--项目初始化与基础框架)
- [Phase 2 — 数据层与本地存储](#phase-2--数据层与本地存储)
- [Phase 3 — 应用外壳与导航框架](#phase-3--应用外壳与导航框架)
- [Phase 4 — 项目管理模块](#phase-4--项目管理模块)
- [Phase 5 — 资产管理模块（核心）](#phase-5--资产管理模块核心)
- [Phase 6 — 资产详情与预览](#phase-6--资产详情与预览)
- [Phase 7 — AI 服务抽象层](#phase-7--ai-服务抽象层)
- [Phase 8 — 提示词管理模块](#phase-8--提示词管理模块)
- [Phase 9 — AI 对话模块](#phase-9--ai-对话模块)
- [Phase 10 — AI 图片生成模块](#phase-10--ai-图片生成模块)
- [Phase 11 — AI 视频生成模块](#phase-11--ai-视频生成模块)
- [Phase 12 — 设置与配置中心](#phase-12--设置与配置中心)
- [Phase 13 — 浏览器扩展（Chrome/Edge）](#phase-13--浏览器扩展chromeedge)
- [Phase 14 — 扩展与应用通信](#phase-14--扩展与应用通信)
- [Phase 15 — 移动端适配](#phase-15--移动端适配)
- [Phase 16 — 测试、优化与打包发布](#phase-16--测试优化与打包发布)

---

## 技术栈总览

| 类别 | 技术 | 版本 | 用途 |
|------|------|------|------|
| UI 框架 | fluent_ui | ^4.14.0 | Windows Fluent Design 风格 UI |
| 状态管理 | flutter_riverpod + riverpod_annotation | ^3.2.1 | 响应式状态管理 |
| 路由 | go_router | ^17.1.0 | 声明式路由管理 |
| 网络请求 | dio | ^5.x | HTTP 客户端，调用 AI API |
| 本地数据库 | drift + drift_dev | ^2.32.0 | SQLite ORM，类型安全 |
| 桌面窗口 | window_manager | ^0.5.1 | 桌面端窗口控制 |
| 视频播放 | media_kit | latest | 跨平台视频播放 |
| 图片缓存 | cached_network_image | latest | 网络图片缓存 |
| 文件选择 | file_picker | latest | 文件选择器 |
| 路径管理 | path_provider | latest | 获取应用目录 |
| JSON序列化 | json_annotation + json_serializable | latest | JSON 模型生成 |
| 代码生成 | build_runner | latest | 配合 drift/json_serializable |
| 浏览器扩展 | TypeScript + React | latest | Chrome/Edge 插件 |

---

## 项目结构规划

```
aio_studio/
├── lib/
│   ├── main.dart                          # 应用入口
│   ├── app.dart                           # FluentApp 根组件
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart         # 全局常量
│   │   │   └── api_constants.dart         # API 端点常量
│   │   ├── theme/
│   │   │   ├── app_theme.dart             # Fluent 主题配置
│   │   │   └── color_schemes.dart         # 配色方案
│   │   ├── router/
│   │   │   └── app_router.dart            # go_router 路由定义
│   │   ├── database/
│   │   │   ├── app_database.dart          # drift 数据库定义
│   │   │   ├── app_database.g.dart        # 生成文件
│   │   │   ├── tables/                    # 数据表定义
│   │   │   │   ├── projects.dart
│   │   │   │   ├── assets.dart
│   │   │   │   ├── prompts.dart
│   │   │   │   ├── ai_tasks.dart
│   │   │   │   └── tags.dart
│   │   │   └── daos/                      # 数据访问对象
│   │   │       ├── project_dao.dart
│   │   │       ├── asset_dao.dart
│   │   │       └── prompt_dao.dart
│   │   ├── services/
│   │   │   ├── ai/
│   │   │   │   ├── ai_service.dart        # AI 服务抽象接口
│   │   │   │   ├── openai_service.dart    # OpenAI 实现
│   │   │   │   ├── anthropic_service.dart # Claude 实现
│   │   │   │   ├── stability_service.dart # Stability AI 实现
│   │   │   │   └── custom_service.dart    # 自定义 API 实现
│   │   │   ├── storage/
│   │   │   │   ├── local_storage_service.dart   # 本地文件存储
│   │   │   │   └── asset_file_manager.dart      # 资产文件管理
│   │   │   ├── extension_bridge/
│   │   │   │   └── extension_server.dart        # 与浏览器扩展通信
│   │   │   └── notification_service.dart        # 通知服务
│   │   ├── models/
│   │   │   ├── project.dart               # 项目模型
│   │   │   ├── asset.dart                 # 资产模型
│   │   │   ├── prompt.dart                # 提示词模型
│   │   │   ├── ai_provider.dart           # AI 服务商配置模型
│   │   │   ├── ai_task.dart               # AI 任务模型
│   │   │   └── tag.dart                   # 标签模型
│   │   ├── providers/                     # Riverpod 全局 Providers
│   │   │   ├── database_provider.dart
│   │   │   ├── theme_provider.dart
│   │   │   └── settings_provider.dart
│   │   └── utils/
│   │       ├── file_utils.dart
│   │       ├── image_utils.dart
│   │       └── platform_utils.dart
│   ├── features/
│   │   ├── projects/                      # 项目管理
│   │   │   ├── providers/
│   │   │   │   └── projects_provider.dart
│   │   │   ├── views/
│   │   │   │   ├── projects_page.dart
│   │   │   │   ├── project_detail_page.dart
│   │   │   │   └── project_create_dialog.dart
│   │   │   └── widgets/
│   │   │       ├── project_card.dart
│   │   │       └── project_list_tile.dart
│   │   ├── assets/                        # 资产管理
│   │   │   ├── providers/
│   │   │   │   ├── assets_provider.dart
│   │   │   │   └── asset_filter_provider.dart
│   │   │   ├── views/
│   │   │   │   ├── assets_page.dart
│   │   │   │   ├── asset_detail_page.dart
│   │   │   │   └── asset_import_dialog.dart
│   │   │   └── widgets/
│   │   │       ├── asset_grid_view.dart
│   │   │       ├── asset_list_view.dart
│   │   │       ├── asset_thumbnail.dart
│   │   │       ├── asset_filter_bar.dart
│   │   │       └── asset_tag_editor.dart
│   │   ├── prompts/                       # 提示词管理
│   │   │   ├── providers/
│   │   │   │   └── prompts_provider.dart
│   │   │   ├── views/
│   │   │   │   ├── prompts_page.dart
│   │   │   │   └── prompt_editor_page.dart
│   │   │   └── widgets/
│   │   │       ├── prompt_card.dart
│   │   │       └── prompt_variable_editor.dart
│   │   ├── ai_chat/                       # AI 对话
│   │   │   ├── providers/
│   │   │   │   └── chat_provider.dart
│   │   │   ├── views/
│   │   │   │   └── chat_page.dart
│   │   │   └── widgets/
│   │   │       ├── chat_message_bubble.dart
│   │   │       ├── chat_input_bar.dart
│   │   │       └── model_selector.dart
│   │   ├── ai_image/                      # AI 图片生成
│   │   │   ├── providers/
│   │   │   │   └── image_gen_provider.dart
│   │   │   ├── views/
│   │   │   │   └── image_gen_page.dart
│   │   │   └── widgets/
│   │   │       ├── image_gen_form.dart
│   │   │       ├── image_gen_result.dart
│   │   │       └── image_gen_history.dart
│   │   ├── ai_video/                      # AI 视频生成
│   │   │   ├── providers/
│   │   │   │   └── video_gen_provider.dart
│   │   │   ├── views/
│   │   │   │   └── video_gen_page.dart
│   │   │   └── widgets/
│   │   │       ├── video_gen_form.dart
│   │   │       └── video_gen_queue.dart
│   │   └── settings/                      # 设置
│   │       ├── providers/
│   │       │   └── settings_provider.dart
│   │       ├── views/
│   │       │   └── settings_page.dart
│   │       └── widgets/
│   │           ├── api_key_section.dart
│   │           ├── storage_section.dart
│   │           └── theme_section.dart
│   └── shared/
│       └── widgets/
│           ├── app_shell.dart             # 导航外壳
│           ├── breadcrumb_bar.dart         # 面包屑
│           ├── empty_state.dart            # 空状态
│           ├── loading_indicator.dart      # 加载指示器
│           └── responsive_layout.dart      # 响应式布局
├── extension/                             # 浏览器扩展
│   ├── manifest.json
│   ├── src/
│   │   ├── background/
│   │   │   └── index.ts
│   │   ├── content/
│   │   │   └── index.ts
│   │   ├── popup/
│   │   │   ├── App.tsx
│   │   │   └── index.tsx
│   │   └── shared/
│   │       ├── api.ts
│   │       └── types.ts
│   ├── package.json
│   └── tsconfig.json
├── pubspec.yaml
├── analysis_options.yaml
└── docs/
    └── DEVELOPMENT_GUIDE.md              # 本文档
```

---

## Phase 1 — 项目初始化与基础框架

### 目标
创建 Flutter 项目，配置所有基础依赖，确保项目可以在桌面端启动运行。

### 交付物
- Flutter 项目基础结构
- `pubspec.yaml` 完整依赖配置
- `analysis_options.yaml` lint 规则
- 空白 FluentApp 可以在 Windows 上运行

### AI 提示词

```
你是一个资深的 Flutter 开发者。请帮我创建一个名为 aio_studio 的 Flutter 项目的基础骨架。

要求：
1. 项目名称：aio_studio
2. 使用 fluent_ui (^4.14.0) 作为 UI 框架，不使用 Material 或 Cupertino
3. 配置以下依赖：
   - fluent_ui: ^4.14.0（UI 框架）
   - flutter_riverpod: latest + riverpod_annotation: latest（状态管理）
   - go_router: ^17.1.0（路由）
   - dio: latest（网络请求）
   - drift: ^2.32.0 + sqlite3_flutter_libs: latest（本地数据库）
   - window_manager: ^0.5.1（桌面窗口管理）
   - path_provider: latest（路径管理）
   - json_annotation: latest（JSON 序列化）
   - cached_network_image: latest（图片缓存）
   - file_picker: latest（文件选择）
   - uuid: latest（ID 生成）
   - intl: latest（国际化）
   - logger: latest（日志）
   - shared_preferences: latest（轻量配置存储）
   dev_dependencies:
   - build_runner: latest
   - drift_dev: latest
   - json_serializable: latest
   - riverpod_generator: latest
   - custom_lint: latest
   - riverpod_lint: latest

4. 创建 lib/main.dart 入口文件：
   - 初始化 WidgetsFlutterBinding
   - 初始化 window_manager（仅桌面端），设置最小窗口大小 900x600，默认大小 1280x800，居中显示
   - 用 ProviderScope 包裹应用
   - 运行 FluentApp

5. 创建 lib/app.dart：
   - 使用 FluentApp.router 配合 go_router
   - 配置 FluentThemeData，亮色/暗色双主题
   - accentColor 使用 Colors.blue
   - 配置简体中文本地化（FluentLocalizations）
   - 应用标题：AIO Studio

6. 创建 analysis_options.yaml，使用 flutter_lints 并增加严格规则

7. 仅创建框架代码，确保项目能编译运行，在 Windows 上显示一个空白的 FluentApp 窗口
8. 在桌面端隐藏默认标题栏（titleBarStyle: TitleBarStyle.hidden），应用自行绘制标题栏区域
```

---

## Phase 2 — 数据层与本地存储

### 目标
建立完整的数据模型和本地 SQLite 数据库，为所有功能模块提供数据支撑。

### 交付物
- drift 数据库定义（所有表）
- DAO 数据访问对象
- 数据库 Provider
- 文件存储服务

### AI 提示词

```
基于 Phase 1 已创建的 aio_studio Flutter 项目，请帮我实现数据层。

项目使用 fluent_ui 作为 UI 框架、drift (^2.32.0) 作为数据库 ORM、flutter_riverpod 作为状态管理。

请创建以下内容：

1. 数据表定义（lib/core/database/tables/）：

   a) projects 表（项目表）：
      - id: TEXT PRIMARY KEY（UUID）
      - name: TEXT NOT NULL（项目名称）
      - description: TEXT（项目描述）
      - coverImagePath: TEXT（封面图片路径）
      - createdAt: INTEGER NOT NULL（创建时间戳）
      - updatedAt: INTEGER NOT NULL（更新时间戳）
      - isArchived: INTEGER NOT NULL DEFAULT 0（是否归档）

   b) assets 表（资产表）：
      - id: TEXT PRIMARY KEY（UUID）
      - projectId: TEXT REFERENCES projects(id)（所属项目）
      - name: TEXT NOT NULL（资产名称）
      - type: TEXT NOT NULL（类型枚举：image/video/audio/text/other）
      - filePath: TEXT NOT NULL（本地文件路径）
      - thumbnailPath: TEXT（缩略图路径）
      - originalUrl: TEXT（原始网页 URL，从浏览器扩展保存时记录）
      - sourceType: TEXT NOT NULL（来源：local_import/browser_extension/ai_generated/manual）
      - fileSize: INTEGER（文件大小 bytes）
      - width: INTEGER（图片/视频宽度）
      - height: INTEGER（图片/视频高度）
      - duration: REAL（视频/音频时长秒数）
      - metadata: TEXT（JSON 格式的额外元数据）
      - createdAt: INTEGER NOT NULL
      - updatedAt: INTEGER NOT NULL
      - isFavorite: INTEGER NOT NULL DEFAULT 0

   c) tags 表：
      - id: TEXT PRIMARY KEY
      - name: TEXT NOT NULL UNIQUE
      - color: INTEGER（颜色值）
      - createdAt: INTEGER NOT NULL

   d) asset_tags 表（资产-标签关联表）：
      - assetId: TEXT REFERENCES assets(id)
      - tagId: TEXT REFERENCES tags(id)
      - PRIMARY KEY(assetId, tagId)

   e) prompts 表（提示词表）：
      - id: TEXT PRIMARY KEY
      - projectId: TEXT REFERENCES projects(id)
      - title: TEXT NOT NULL
      - content: TEXT NOT NULL（提示词内容）
      - category: TEXT（分类：text_gen/image_gen/video_gen/optimization/other）
      - variables: TEXT（JSON 格式变量定义 [{name, defaultValue, description}]）
      - isFavorite: INTEGER NOT NULL DEFAULT 0
      - useCount: INTEGER NOT NULL DEFAULT 0
      - createdAt: INTEGER NOT NULL
      - updatedAt: INTEGER NOT NULL

   f) ai_tasks 表（AI 任务记录表）：
      - id: TEXT PRIMARY KEY
      - projectId: TEXT REFERENCES projects(id)
      - type: TEXT NOT NULL（任务类型：chat/image_gen/video_gen/prompt_optimize）
      - status: TEXT NOT NULL（状态：pending/running/completed/failed）
      - provider: TEXT NOT NULL（服务商：openai/anthropic/stability/custom）
      - model: TEXT（模型名称）
      - inputPrompt: TEXT（输入提示词）
      - inputParams: TEXT（JSON 格式参数）
      - outputText: TEXT（文本输出）
      - outputAssetId: TEXT REFERENCES assets(id)（生成的资产 ID）
      - errorMessage: TEXT
      - tokenUsage: INTEGER（Token 消耗量）
      - costEstimate: REAL（费用估算）
      - startedAt: INTEGER
      - completedAt: INTEGER
      - createdAt: INTEGER NOT NULL

   g) ai_provider_configs 表（AI 服务商配置表）：
      - id: TEXT PRIMARY KEY
      - name: TEXT NOT NULL（显示名称）
      - type: TEXT NOT NULL（类型：openai/anthropic/stability/custom）
      - apiKey: TEXT（API Key，加密存储）
      - baseUrl: TEXT（API 基础 URL，用于自定义端点）
      - defaultModel: TEXT（默认模型）
      - isEnabled: INTEGER NOT NULL DEFAULT 1
      - extraConfig: TEXT（JSON 格式的额外配置）
      - createdAt: INTEGER NOT NULL
      - updatedAt: INTEGER NOT NULL

2. 数据库定义（lib/core/database/app_database.dart）：
   - 注册所有表
   - schemaVersion 从 1 开始
   - 包含 migration 策略

3. DAO 定义（lib/core/database/daos/）：
   - ProjectDao：增删改查、归档/取消归档、按名称搜索
   - AssetDao：增删改查、按项目筛选、按类型筛选、按标签筛选、收藏/取消收藏、分页查询
   - PromptDao：增删改查、按分类筛选、递增 useCount
   - TagDao：增删改查、查询某资产的所有标签、查询某标签下的所有资产
   - AiTaskDao：增删改查、按状态查询、按项目查询

4. Riverpod Provider（lib/core/providers/database_provider.dart）：
   - 创建数据库单例 Provider
   - 为每个 DAO 创建对应的 Provider

5. 文件存储服务（lib/core/services/storage/）：
   - LocalStorageService：管理应用数据目录
     · 获取资产存储根目录（按项目分子目录）
     · 保存文件到资产目录（复制/移动）
     · 生成缩略图（图片类型）
     · 删除资产文件
     · 获取存储空间使用统计
   - AssetFileManager：资产文件的高级管理
     · 导入本地文件 → 复制到应用目录 + 创建数据库记录
     · 从 URL 下载文件 → 保存到应用目录 + 创建记录
     · 批量导入
     · 删除资产（文件 + 数据库记录）

请确保：
- 所有代码使用 drift 的声明式语法
- DAO 使用 drift 的 @DriftAccessor 注解
- 文件操作使用 path_provider 获取应用目录
- 提供运行 build_runner 的命令说明
```

---

## Phase 3 — 应用外壳与导航框架

### 目标
构建应用的主体导航框架，使用 fluent_ui 的 NavigationView 实现侧边栏导航。

### 交付物
- 应用外壳布局（NavigationView）
- 路由配置
- 自定义标题栏
- 响应式布局适配

### AI 提示词

```
基于已完成的 Phase 1-2，请帮我实现 AIO Studio 的应用外壳与导航框架。

技术栈：fluent_ui (^4.14.0)、go_router (^17.1.0)、flutter_riverpod、window_manager (^0.5.1)。

请创建以下内容：

1. 应用外壳（lib/shared/widgets/app_shell.dart）：
   - 使用 fluent_ui 的 NavigationView 组件
   - NavigationPane 采用 PaneDisplayMode.auto（窄屏自动折叠为 compact/minimal）
   - 导航项目结构：
     · 项目管理（icon: FluentIcons.project_management, 路由: /projects）
     · 资产库（icon: FluentIcons.photo_collection, 路由: /assets）
     ── 分隔线 ──
     · AI 对话（icon: FluentIcons.chat, 路由: /ai-chat）
     · 图片生成（icon: FluentIcons.image_search, 路由: /ai-image）
     · 视频生成（icon: FluentIcons.video, 路由: /ai-video）
     · 提示词库（icon: FluentIcons.text_document, 路由: /prompts）
     ── footer items ──
     · 设置（icon: FluentIcons.settings, 路由: /settings）
   - 在 NavigationView 的 appBar 区域实现自定义标题栏：
     · 左侧显示应用 Logo + "AIO Studio" 文字
     · 桌面端使用 DragToMoveArea 实现窗口拖拽
     · 右侧显示最小化、最大化、关闭按钮（仅桌面端，使用 window_manager）

2. 路由配置（lib/core/router/app_router.dart）：
   - 使用 go_router 的 ShellRoute 包裹 NavigationView
   - 子路由对应上述每个导航项
   - 项目详情使用嵌套路由：/projects/:projectId
   - 资产详情使用嵌套路由：/assets/:assetId
   - 默认重定向到 /projects
   - 路由变化时同步更新 NavigationPane 的选中状态

3. 响应式布局辅助（lib/shared/widgets/responsive_layout.dart）：
   - 定义断点：compact (<600), medium (600-1200), expanded (>1200)
   - 提供一个 ResponsiveLayout widget，根据屏幕宽度显示不同的子组件

4. 通用组件（lib/shared/widgets/）：
   - EmptyState：空状态提示组件（图标 + 标题 + 描述 + 可选操作按钮）
   - LoadingIndicator：加载指示器（使用 fluent_ui 的 ProgressRing）
   - BreadcrumbBar：面包屑导航组件（使用 fluent_ui 的 BreadcrumbBar）

5. 亮色/暗色主题切换（lib/core/theme/app_theme.dart）：
   - 定义亮色和暗色 FluentThemeData
   - 使用 Riverpod 管理主题状态
   - 主题偏好持久化到 SharedPreferences
   - 支持跟随系统主题

请确保：
- NavigationPane 的选中状态与 go_router 的当前路由保持同步
- 桌面端标题栏区域支持窗口拖拽和双击最大化
- 移动端不显示窗口控制按钮
- 每个路由页面目前先用占位页面（显示页面名称即可）
- 使用 fluent_ui 的组件而非 Material 组件
```

---

## Phase 4 — 项目管理模块

### 目标
实现 AGI 项目的完整 CRUD 功能，项目是所有资产和 AI 任务的顶层容器。

### 交付物
- 项目列表页（网格/列表双视图）
- 项目创建/编辑对话框
- 项目详情页（Tab 布局，包含资产、提示词、任务概览）
- 项目归档/删除功能

### AI 提示词

```
基于已完成的 Phase 1-3，请帮我实现 AIO Studio 的项目管理模块。

技术栈：fluent_ui (^4.14.0)、flutter_riverpod (riverpod_annotation)、drift、go_router。

项目管理是 AIO Studio 的核心模块之一，每个"项目"是一个 AGI 工作空间，包含资产、提示词、AI 任务等。

请实现以下内容：

1. 项目列表 Provider（lib/features/projects/providers/projects_provider.dart）：
   - 使用 @riverpod 注解
   - watchAllProjects：流式监听所有未归档项目，按更新时间降序
   - watchArchivedProjects：流式监听已归档项目
   - createProject(name, description, coverImagePath?)
   - updateProject(id, ...)
   - archiveProject(id) / unarchiveProject(id)
   - deleteProject(id)（同时删除关联资产文件）
   - searchProjects(query)
   - getProjectStats(id)：返回资产数量、提示词数量、AI 任务数量

2. 项目列表页（lib/features/projects/views/projects_page.dart）：
   - 页面顶部：
     · 标题 "项目" 使用 fluent_ui 的大标题样式
     · 搜索框（AutoSuggestBox）用于搜索项目
     · 视图切换按钮（网格/列表）使用 ToggleSwitch 或 CommandBar
     · "新建项目" 按钮（FilledButton）
     · "已归档" 按钮进入归档列表
   - 网格视图：
     · 使用 GridView，每个项目显示为卡片（Card）
     · 卡片包含：封面图（无则显示渐变色占位）、项目名称、描述（截断）、资产数量、更新时间
     · 鼠标悬停显示操作按钮（编辑、归档、删除）
     · 点击进入项目详情
   - 列表视图：
     · 使用 ListView + ListTile 样式
     · 显示项目名称、描述、资产数量、最后更新时间
   - 空状态：使用 EmptyState 组件，提示创建第一个项目
   - 右键上下文菜单：打开、编辑、归档、删除

3. 项目创建/编辑对话框（lib/features/projects/views/project_create_dialog.dart）：
   - 使用 fluent_ui 的 ContentDialog
   - 表单字段：
     · 项目名称（TextBox，必填，验证非空）
     · 项目描述（TextBox，多行，可选）
     · 封面图片（点击选择图片，显示预览）
   - 底部：取消 + 确认按钮
   - 编辑模式时预填充现有数据

4. 项目详情页（lib/features/projects/views/project_detail_page.dart）：
   - 使用 go_router 的 /projects/:projectId 路由
   - 顶部面包屑：项目 > 项目名称
   - 项目信息头部：封面图 + 名称 + 描述 + 编辑按钮
   - TabView 展示不同内容（使用 fluent_ui 的 TabView）：
     · Tab 1 - 资产：该项目下的资产网格（复用 Phase 5 的组件，此处先用占位）
     · Tab 2 - 提示词：该项目下的提示词列表（占位）
     · Tab 3 - AI 任务：该项目下的任务历史（占位）
     · Tab 4 - 统计：项目统计数据（资产数、生成次数等）
   - 统计 Tab 展示：
     · 总资产数、图片数、视频数
     · AI 生成次数、Token 消耗量
     · 使用 InfoBar 或自定义统计卡片展示

5. 项目卡片组件（lib/features/projects/widgets/project_card.dart）：
   - 可复用的项目卡片 widget
   - fluent_ui Card 样式
   - 支持 onTap、onEdit、onArchive、onDelete 回调

请确保：
- 所有列表使用 Riverpod 的 AsyncValue 正确处理 loading/error/data 状态
- 删除操作使用 ContentDialog 确认
- 所有 UI 使用 fluent_ui 组件（不要用 Material）
- 项目卡片有优雅的 hover 效果
- 列表支持排序（按名称、创建时间、更新时间）
```

---

## Phase 5 — 资产管理模块（核心）

### 目标
实现 AGI 资产的浏览、筛选、导入、分类、标签管理功能。资产管理是整个应用的核心功能。

### 交付物
- 资产浏览页（网格/列表/瀑布流视图）
- 资产筛选与搜索
- 资产导入（本地文件拖拽导入）
- 标签管理与批量操作
- 资产缩略图展示

### AI 提示词

```
基于已完成的 Phase 1-4，请帮我实现 AIO Studio 的资产管理模块。这是应用的核心功能。

技术栈：fluent_ui (^4.14.0)、flutter_riverpod、drift、cached_network_image、file_picker。

AGI 资产包括图片、视频、音频、文本等，可以来自本地导入、浏览器扩展抓取、AI 生成等多种来源。

请实现以下内容：

1. 资产 Provider（lib/features/assets/providers/）：

   a) assets_provider.dart：
      - watchAllAssets(projectId?): 流式监听资产列表，可选按项目筛选
      - watchAssetsByType(type): 按资产类型筛选
      - watchAssetsByTag(tagId): 按标签筛选
      - watchFavoriteAssets(): 收藏的资产
      - importLocalFiles(List<File>, projectId?): 导入本地文件
      - importFromUrl(url, projectId?): 从 URL 下载并导入
      - deleteAsset(id): 删除资产（文件 + 数据库记录）
      - deleteAssets(List<id>): 批量删除
      - toggleFavorite(id): 切换收藏状态
      - updateAsset(id, name?, projectId?, ...): 更新资产信息
      - moveToProject(assetId, projectId): 移动到其他项目
      - getAssetCount(): 资产统计

   b) asset_filter_provider.dart：
      - 管理筛选状态：当前类型筛选、标签筛选、排序方式、搜索关键词、视图模式
      - filteredAssets: 根据所有筛选条件组合后的资产列表

2. 资产浏览页（lib/features/assets/views/assets_page.dart）：
   - 顶部工具栏（CommandBar 风格）：
     · 搜索框（AutoSuggestBox）
     · 类型筛选下拉（ComboBox）：全部 / 图片 / 视频 / 音频 / 文本
     · 项目筛选下拉（ComboBox）：全部 / 各项目
     · 标签筛选：点击展开标签选择面板
     · 排序：按名称 / 创建时间 / 文件大小 / 类型
     · 视图切换：网格 / 列表 / 大图预览
     · "导入" 按钮（打开文件选择器，支持多选）
   - 筛选标签条：当有活跃筛选时，显示筛选标签条，点击 × 可移除
   - 底部状态栏：显示 "共 N 个资产 · 已选择 M 个"

   - 网格视图（默认）：
     · 固定宽度网格（crossAxisCount 根据窗口宽度自适应）
     · 每个网格项显示缩略图、类型图标角标、名称、收藏图标
     · 图片资产直接显示缩略图
     · 视频资产显示第一帧缩略图 + 播放图标 + 时长
     · 支持多选模式（Ctrl+Click 多选，Shift+Click 范围选择）
   
   - 列表视图：
     · ListTile 样式：缩略图 + 名称 + 类型 + 大小 + 来源 + 创建时间
   
   - 多选操作栏（选中资产后顶部显示）：
     · 全选 / 取消选择
     · 批量删除
     · 批量移动到项目
     · 批量添加标签
     · 批量收藏

3. 资产导入对话框（lib/features/assets/views/asset_import_dialog.dart）：
   - ContentDialog 样式
   - 拖拽区域（虚线框，支持拖拽文件进入）
   - 或点击 "选择文件" 按钮使用 file_picker
   - 选择目标项目（ComboBox）
   - 显示已选文件列表（文件名 + 大小 + 删除按钮）
   - 导入进度条（ProgressBar）

4. 标签管理：
   - 资产标签编辑组件（lib/features/assets/widgets/asset_tag_editor.dart）：
     · 显示当前标签列表（Chip 样式）
     · 点击 + 添加标签（AutoSuggestBox 搜索已有标签或创建新标签）
     · 点击标签上的 × 移除标签
   - 标签选择面板：
     · 显示所有标签，带颜色标记
     · 点击切换选中/未选中
     · 支持创建新标签（名称 + 颜色选择）

5. 资产缩略图组件（lib/features/assets/widgets/asset_thumbnail.dart）：
   - 根据资产类型显示不同内容：
     · image: 显示本地文件缩略图（使用 Image.file）
     · video: 显示缩略图 + 播放图标覆盖 + 时长文字
     · audio: 显示音频图标 + 波形占位
     · text: 显示文档图标 + 文本片段预览
     · other: 显示文件类型图标
   - 支持选中状态（蓝色边框 + 勾选图标）
   - 支持收藏图标（角落显示心形/星形）

6. 拖拽导入支持：
   - 整个资产页面支持拖拽文件导入（使用 desktop_drop 或原生拖拽）
   - 拖拽时显示覆盖层提示 "释放以导入资产"

请确保：
- 大量资产时使用懒加载（分页或虚拟滚动）
- 缩略图使用内存缓存避免重复加载
- 多选操作使用 Riverpod StateProvider 管理选中状态
- 所有 UI 严格使用 fluent_ui 组件
- 导入过程异步执行，不阻塞 UI
- 空状态有友好提示
```

---

## Phase 6 — 资产详情与预览

### 目标
实现资产的详细信息展示、全屏预览、图片/视频查看器。

### 交付物
- 资产详情页
- 图片全屏预览（支持缩放、旋转）
- 视频播放器
- 资产信息编辑
- 资产元数据展示

### AI 提示词

```
基于已完成的 Phase 1-5，请帮我实现 AIO Studio 的资产详情与预览模块。

技术栈：fluent_ui (^4.14.0)、flutter_riverpod、media_kit（视频播放）。

请实现以下内容：

1. 资产详情页（lib/features/assets/views/asset_detail_page.dart）：
   - 路由：/assets/:assetId
   - 左右分栏布局（可调整宽度）：
     · 左侧（主区域 ~70%）：预览区域
       - 图片：可缩放的图片查看器（支持鼠标滚轮缩放、双击还原、拖拽平移）
       - 视频：视频播放器（播放/暂停、进度条、音量、全屏）
       - 音频：音频播放器（波形可视化 + 播放控制）
       - 文本：文本内容展示（支持复制）
     · 右侧（信息面板 ~30%）：
       - 资产名称（可编辑，TextBox）
       - 所属项目（ComboBox，可修改）
       - 资产类型图标 + 类型文字
       - 标签编辑器（复用 asset_tag_editor）
       - 收藏按钮
       - "文件信息" 折叠面板（Expander）：
         · 文件路径、文件大小、尺寸（宽×高）、时长、格式
       - "来源信息" 折叠面板：
         · 来源类型（本地导入/浏览器抓取/AI 生成）
         · 原始 URL（如有，可点击打开浏览器）
         · 关联的 AI 任务（如有，可跳转到任务详情）
       - "时间信息" 折叠面板：
         · 创建时间、修改时间
       - 操作按钮组：
         · "在文件管理器中打开"（打开本地文件所在目录）
         · "复制到剪贴板"（图片类型）
         · "导出"（另存为到指定位置）
         · "删除"（确认对话框）
   - 顶部面包屑：资产库 > 资产名称
   - 键盘快捷键：← → 切换上一个/下一个资产

2. 图片查看器组件（lib/features/assets/widgets/image_viewer.dart）：
   - InteractiveViewer 实现缩放和平移
   - 底部工具栏：
     · 缩放比例显示和控制（-、重置、+）
     · 旋转（90° 递增）
     · 适应窗口 / 原始大小
   - 双击切换适应窗口/原始大小
   - 支持加载本地大图文件，显示加载进度

3. 视频播放器组件（lib/features/assets/widgets/video_player_widget.dart）：
   - 使用 media_kit 包
   - 播放器控制栏：
     · 播放/暂停按钮
     · 进度条（可拖拽跳转）
     · 当前时间 / 总时长
     · 音量控制
     · 播放速度选择（0.5x, 1x, 1.5x, 2x）
     · 全屏按钮
   - 点击视频区域切换播放/暂停
   - 自动播放

4. 资产前后导航：
   - 在详情页中可以通过左右箭头按钮或键盘 ← → 浏览前后资产
   - 使用当前资产列表的筛选排序状态

请确保：
- 图片查看器在大图片时性能良好
- 视频播放器在各桌面平台正常工作
- 右侧信息面板可以收起/展开
- 编辑资产名称后自动保存（debounce 500ms）
- 响应式布局：窄屏时切换为上下布局
```

---

## Phase 7 — AI 服务抽象层

### 目标
设计并实现统一的 AI 服务调用层，支持多个 AI 服务商和自定义 API。

### 交付物
- AI 服务抽象接口
- OpenAI 服务实现（Chat + DALL·E）
- Anthropic Claude 服务实现
- Stability AI 服务实现
- 自定义 API 服务实现
- 统一的错误处理和重试机制

### AI 提示词

```
基于已完成的 Phase 1-6，请帮我实现 AIO Studio 的 AI 服务抽象层。

技术栈：flutter_riverpod、dio (^5.x)，纯 Dart 实现，不依赖任何 AI SDK。

这是所有 AI 功能（对话、图片生成、视频生成、提示词优化）的底层服务，必须设计良好的抽象以支持多服务商。

请实现以下内容：

1. AI 服务抽象接口（lib/core/services/ai/ai_service.dart）：

   定义以下抽象类和模型：

   a) AiChatMessage 模型：
      - role: String (system/user/assistant)
      - content: String
      - imageUrls: List<String>?（多模态图片输入）
      - timestamp: DateTime

   b) AiChatRequest 模型：
      - messages: List<AiChatMessage>
      - model: String
      - temperature: double (0.0-2.0, 默认 0.7)
      - maxTokens: int?
      - stream: bool (默认 true)

   c) AiChatResponse 模型：
      - content: String
      - model: String
      - promptTokens: int
      - completionTokens: int
      - totalTokens: int

   d) AiImageRequest 模型：
      - prompt: String
      - negativePrompt: String?
      - model: String
      - width: int (默认 1024)
      - height: int (默认 1024)
      - count: int (生成数量，默认 1)
      - style: String?（如 vivid/natural）
      - quality: String?（如 standard/hd）

   e) AiImageResponse 模型：
      - images: List<AiGeneratedImage>
        · url: String?（远程 URL）
        · base64: String?（base64 数据）
        · revisedPrompt: String?（修正后的提示词）

   f) AiVideoRequest 模型：
      - prompt: String
      - model: String
      - width: int
      - height: int
      - duration: int（秒数）
      - imageUrl: String?（图生视频的输入图片）

   g) AiVideoResponse 模型：
      - videoUrl: String?
      - taskId: String?（异步任务 ID）
      - status: String

   h) 抽象类 AiService：
      - String get providerName
      - List<String> get supportedModels
      - bool get supportsChatCompletion
      - bool get supportsImageGeneration
      - bool get supportsVideoGeneration
      - Future<AiChatResponse> chatCompletion(AiChatRequest request)
      - Stream<String> chatCompletionStream(AiChatRequest request)
      - Future<AiImageResponse> generateImage(AiImageRequest request)
      - Future<AiVideoResponse> generateVideo(AiVideoRequest request)
      - Future<AiVideoResponse> checkVideoStatus(String taskId)
      - Future<bool> testConnection()（测试 API 连接）

2. OpenAI 服务实现（lib/core/services/ai/openai_service.dart）：
   - 实现 AiService
   - 使用 dio 直接调用 OpenAI REST API
   - 支持的 Chat 模型：gpt-4o, gpt-4o-mini, gpt-4-turbo, gpt-3.5-turbo
   - 支持的 Image 模型：dall-e-3, dall-e-2
   - SSE 流式响应解析（chatCompletionStream）
   - 支持自定义 baseUrl（兼容 API 代理/中转）
   - 正确处理速率限制（429）和错误响应

3. Anthropic Claude 服务实现（lib/core/services/ai/anthropic_service.dart）：
   - 实现 AiService（仅 Chat）
   - 调用 Anthropic Messages API
   - 支持模型：claude-3-opus, claude-3-sonnet, claude-3-haiku, claude-3.5-sonnet
   - SSE 流式响应解析
   - 支持自定义 baseUrl

4. Stability AI 服务实现（lib/core/services/ai/stability_service.dart）：
   - 实现 AiService（仅 Image）
   - 调用 Stability AI REST API
   - 支持 Stable Diffusion 3 等模型
   - 图片返回为 base64

5. 自定义 API 服务（lib/core/services/ai/custom_service.dart）：
   - 实现 AiService
   - 支持用户配置任意 OpenAI 兼容接口（如 ollama、vllm、one-api 等）
   - 请求格式兼容 OpenAI API 格式

6. AI 服务管理器（lib/core/services/ai/ai_service_manager.dart）：
   - 根据 ai_provider_configs 数据库表管理所有已配置的 AI 服务
   - getService(providerId) → AiService
   - getDefaultChatService() → AiService
   - getDefaultImageService() → AiService
   - getDefaultVideoService() → AiService
   - getAllEnabledServices() → List<AiService>

7. Riverpod Providers（lib/core/providers/ai_providers.dart）：
   - aiServiceManagerProvider：AI 服务管理器单例
   - availableModelsProvider(type)：可用模型列表
   - defaultChatServiceProvider：默认聊天服务

8. 统一错误处理：
   - AiServiceException 异常类
   - 子类型：AuthenticationError, RateLimitError, InvalidRequestError, NetworkError, ServerError
   - 每个异常包含用户友好的中文错误提示

9. HTTP 请求配置：
   - dio 拦截器：日志记录、错误转换、自动重试（指数退避，最多 3 次，仅对 429/5xx 重试）
   - 请求超时配置：连接 30s、接收 120s（生成任务可能较慢）

请确保：
- SSE 流式解析正确处理 data: [DONE] 和错误情况
- API Key 不在日志中明文输出（打码处理）
- 所有 HTTP 调用使用同一个 dio 实例（便于统一配置代理等）
- 模型类使用 json_serializable 或手写 fromJson/toJson
```

---

## Phase 8 — 提示词管理模块

### 目标
实现提示词的创建、编辑、分类、搜索和变量模板功能。

### 交付物
- 提示词列表页
- 提示词编辑器（支持变量模板）
- 提示词分类与搜索
- 提示词快速复制与使用
- AI 辅助提示词优化功能

### AI 提示词

```
基于已完成的 Phase 1-7，请帮我实现 AIO Studio 的提示词管理模块。

技术栈：fluent_ui (^4.14.0)、flutter_riverpod、drift。

提示词管理是连接用户与 AI 服务的桥梁，用户可以创建、组织、优化提示词模板。

请实现以下内容：

1. 提示词 Provider（lib/features/prompts/providers/prompts_provider.dart）：
   - watchAllPrompts(projectId?, category?): 流式监听，支持按项目和分类筛选
   - watchFavoritePrompts(): 收藏的提示词
   - createPrompt(title, content, category, variables?, projectId?)
   - updatePrompt(id, ...)
   - deletePrompt(id)
   - toggleFavorite(id)
   - incrementUseCount(id)
   - searchPrompts(query): 全文搜索
   - optimizePrompt(content): 调用 AI 服务优化提示词，返回优化后版本
   - duplicatePrompt(id): 复制提示词

2. 提示词列表页（lib/features/prompts/views/prompts_page.dart）：
   - 左右分栏布局：
     · 左侧（列表面板 ~35%）：
       - 顶部：搜索框 + "新建" 按钮
       - 分类筛选 Tab：全部 / 文本生成 / 图片生成 / 视频生成 / 优化 / 其他
       - 提示词列表（ListView）：
         · 每项显示：标题、分类图标、使用次数、收藏星标
         · 选中项高亮
         · 右键菜单：复制、编辑、复制为新提示词、删除
     · 右侧（编辑/预览面板 ~65%）：
       - 无选中时显示空状态
       - 选中时显示提示词编辑器

3. 提示词编辑器（lib/features/prompts/views/prompt_editor_page.dart）：
   - 标题输入（TextBox）
   - 分类选择（ComboBox）：text_gen / image_gen / video_gen / optimization / other
   - 所属项目选择（ComboBox，可选）
   - 提示词内容编辑区（大文本框 TextBox，多行）：
     · 支持变量模板语法：{{variable_name}}
     · 变量用不同颜色高亮显示
     · 字数统计
   - 变量编辑面板：
     · 自动从内容中提取 {{...}} 变量
     · 每个变量可设置：名称、默认值、描述
     · 添加/删除变量
   - 操作按钮：
     · "保存" — 保存提示词
     · "AI 优化" — 调用 AI 服务优化当前提示词，弹出对比对话框
     · "复制" — 将提示词内容（变量替换后）复制到剪贴板
     · "在 AI 对话中使用" — 跳转到 AI 对话页面并预填提示词
     · "用于图片生成" — 跳转到图片生成页面并预填
   - 收藏按钮

4. AI 提示词优化对话框：
   - 调用 AI 服务（默认 Chat 服务）对提示词进行优化
   - 显示优化中的 ProgressRing
   - 左右对比展示：原始版本 vs 优化版本
   - 用户可选择：采用优化版本 / 保留原始 / 手动编辑后保存
   - 优化时使用系统提示词：
     "你是一个提示词工程专家。请优化以下提示词，使其更清晰、具体、有效。
      保持用户的核心意图不变，但改善表达方式、添加必要的约束和上下文。
      分类为 {category}。直接返回优化后的提示词，不需要解释。"

5. 提示词卡片组件（lib/features/prompts/widgets/prompt_card.dart）：
   - 紧凑的列表项样式
   - 左侧分类图标（不同分类不同颜色）
   - 标题 + 内容预览（截断两行）
   - 右侧：使用次数 badge + 收藏星标

请确保：
- 变量模板 {{variable}} 在编辑器中用 RichText 高亮
- 提示词内容自动保存（debounce 1000ms）
- 分类筛选使用 fluent_ui 的 TabView 或 Pivot
- 优化功能使用 Phase 7 的 AI 服务抽象层
- 列表和编辑器的分栏可以通过拖拽调整宽度
```

---

## Phase 9 — AI 对话模块

### 目标
实现与大语言模型的对话界面，支持流式输出、多模型切换、历史记录。

### 交付物
- 对话界面（聊天 UI）
- 流式消息输出
- 模型选择与切换
- 对话历史管理
- Markdown 渲染

### AI 提示词

```
基于已完成的 Phase 1-8，请帮我实现 AIO Studio 的 AI 对话模块。

技术栈：fluent_ui (^4.14.0)、flutter_riverpod、flutter_markdown 或 markdown_widget。

请实现以下内容：

1. 对话 Provider（lib/features/ai_chat/providers/chat_provider.dart）：
   - conversations: 对话列表（内存管理，可选持久化）
   - currentConversation: 当前对话
   - createConversation(title?, model?): 创建新对话
   - sendMessage(content, imageFiles?): 发送消息并获取 AI 回复
     · 使用 chatCompletionStream 流式接收
     · 实时更新 UI 中的 assistant 消息
     · 完成后记录 token 使用量到 ai_tasks 表
   - stopGeneration(): 中断当前生成
   - deleteConversation(id)
   - clearConversation(id): 清空对话消息
   - selectedModel: 当前选择的模型
   - selectedProvider: 当前选择的服务商
   - systemPrompt: 系统提示词

2. 对话页面（lib/features/ai_chat/views/chat_page.dart）：
   - 左右分栏：
     · 左侧对话列表（~25%，可收起）：
       - "新建对话" 按钮
       - 对话列表：标题 + 最后消息时间
       - 右键菜单：重命名、删除
       - 当前对话高亮
     · 右侧聊天区域（~75%）：
       - 顶部栏：
         · 对话标题（可编辑）
         · 模型选择器（ComboBox）：显示服务商+模型名
         · 系统提示词设置按钮（点击弹出编辑对话框）
         · 清空对话按钮
       - 消息区域（可滚动 ListView）：
         · 用户消息：右对齐，蓝色背景气泡
         · AI 消息：左对齐，灰色背景气泡
         · AI 消息内容使用 Markdown 渲染（支持代码高亮、表格、列表等）
         · 每条消息底部：复制按钮、时间戳
         · AI 消息底部额外显示：token 用量
         · 流式输出时显示打字光标效果
         · AI 生成中显示 "停止生成" 按钮
       - 输入区域（底部固定）：
         · 多行文本输入框（TextBox），支持 Shift+Enter 换行
         · Enter 发送
         · 附件按钮（图片，用于多模态对话）
         · 发送按钮（生成中变为停止按钮）
         · 左下角显示当前模型名称和预估 token

3. 消息气泡组件（lib/features/ai_chat/widgets/chat_message_bubble.dart）：
   - 用户消息样式：圆角矩形，accent color 背景，白色文字
   - AI 消息样式：圆角矩形，subtle 背景，正常文字
   - Markdown 渲染（代码块带复制按钮和语法高亮）
   - 图片消息显示缩略图（点击可放大）
   - 长消息支持 "展开/收起"

4. 模型选择器组件（lib/features/ai_chat/widgets/model_selector.dart）：
   - ComboBox 样式
   - 按服务商分组显示可用模型
   - 显示模型名称和简短描述
   - 记住上次选择的模型

5. 对话历史自动保存：
   - 对话内容保存到本地数据库（可选，在设置中开关）
   - 重新打开应用时恢复上次的对话列表

请确保：
- 流式输出时消息列表自动滚动到底部
- 支持暗色主题下的正确配色
- Markdown 中的代码块有语法高亮（使用 flutter_highlight 或类似）
- 对话列表为空时显示友好的欢迎提示
- 网络错误时在消息区域内联显示错误提示（InfoBar）
- 超长对话不会导致内存问题（考虑限制上下文窗口大小）
```

---

## Phase 10 — AI 图片生成模块

### 目标
实现 AI 图片生成界面，支持配置生成参数、预览结果、将结果保存为资产。

### 交付物
- 图片生成表单
- 参数配置面板
- 生成结果预览
- 结果保存为资产
- 生成历史记录

### AI 提示词

```
基于已完成的 Phase 1-9，请帮我实现 AIO Studio 的 AI 图片生成模块。

技术栈：fluent_ui (^4.14.0)、flutter_riverpod、Phase 7 的 AI 服务抽象层。

请实现以下内容：

1. 图片生成 Provider（lib/features/ai_image/providers/image_gen_provider.dart）：
   - generateImage(request): 调用 AI 服务生成图片
     · 生成前创建 ai_tasks 记录（status: pending）
     · 调用服务生成（status: running）
     · 成功后下载/保存图片到资产目录，创建 asset 记录（status: completed）
     · 失败时记录错误（status: failed）
   - generationHistory: 历史生成任务列表
   - isGenerating: 是否正在生成
   - currentProvider / currentModel: 当前选择的服务商和模型
   - saveToAsset(imageResponse, projectId?): 将生成结果保存为资产

2. 图片生成页面（lib/features/ai_image/views/image_gen_page.dart）：
   - 左右分栏布局：
     · 左侧参数面板（~35%）：
       - 服务商选择（ComboBox）：显示支持图片生成的服务商
       - 模型选择（ComboBox）：根据服务商显示可用模型
       - 提示词输入（TextBox，多行，大面积）
         · 底部显示字数
         · "从提示词库选择" 按钮（弹出提示词选择对话框，筛选 image_gen 分类）
         · "AI 优化提示词" 按钮
       - 负面提示词输入（TextBox，多行，可折叠 Expander）
       - 图片尺寸：
         · 预设尺寸选择（1024×1024, 1024×1792, 1792×1024 等）
         · 或自定义宽×高输入
       - 生成数量（NumberBox，1-4）
       - 风格选择（ComboBox：vivid/natural，仅 DALL-E 3）
       - 质量选择（ComboBox：standard/hd，仅 DALL-E 3）
       - 高级参数（Expander 折叠）：
         · CFG Scale（Slider，仅 Stability AI）
         · Steps（Slider，仅 Stability AI）
         · Seed（NumberBox，可选）
       - "生成" 按钮（FilledButton，大号）
       - 生成中显示 ProgressRing + "取消" 按钮
       - 预估费用显示

     · 右侧结果区域（~65%）：
       - 无结果时：显示友好占位图和提示文字
       - 生成完成后：
         · 图片网格展示（如生成多张）
         · 点击单张图片放大预览
         · 每张图片下方操作按钮：
           - "保存到资产" — 选择项目后保存
           - "复制到剪贴板"
           - "另存为" — 保存到任意位置
           - "使用此图生成视频" — 跳转到视频生成（图生视频）
         · 如果 API 返回了修正后的提示词（revisedPrompt），显示在图片上方

3. 生成历史面板（lib/features/ai_image/widgets/image_gen_history.dart）：
   - 可从右侧结果区域切换到历史视图
   - 按时间倒序显示历史生成记录
   - 每条记录显示：缩略图网格、提示词摘要、时间、状态
   - 点击可查看该次生成的完整详情
   - 失败的记录显示错误信息和 "重试" 按钮

4. 保存到资产对话框：
   - 选择目标项目（ComboBox）
   - 资产名称（自动用提示词前20字，可修改）
   - 添加标签
   - 确认保存

请确保：
- 不同 AI 服务商的参数面板根据支持情况动态显示/隐藏
- 生成过程不阻塞 UI
- 大图片加载使用渐进式显示
- 保存到资产后在资产库中立即可见
- 历史记录从 ai_tasks 表读取，关联 assets 表获取缩略图
```

---

## Phase 11 — AI 视频生成模块

### 目标
实现 AI 视频生成功能，支持文生视频和图生视频。

### 交付物
- 视频生成表单（文生视频 + 图生视频）
- 异步任务队列管理
- 生成结果预览与保存

### AI 提示词

```
基于已完成的 Phase 1-10，请帮我实现 AIO Studio 的 AI 视频生成模块。

技术栈：fluent_ui (^4.14.0)、flutter_riverpod、media_kit、Phase 7 AI 服务抽象层。

视频生成通常是异步的（提交任务 → 轮询状态 → 获取结果），需要任务队列管理。

请实现以下内容：

1. 视频生成 Provider（lib/features/ai_video/providers/video_gen_provider.dart）：
   - submitVideoGeneration(request): 提交生成任务
     · 创建 ai_tasks 记录
     · 调用 AI 服务 generateVideo
     · 返回 taskId
   - pollTaskStatus(taskId): 轮询任务状态
     · 间隔 5 秒轮询
     · 更新 ai_tasks 记录状态
     · 完成时下载视频文件并创建 asset 记录
   - activeTask: 当前进行中的任务列表
   - taskHistory: 历史任务
   - cancelTask(taskId): 取消任务（如果 API 支持）
   - saveToAsset(videoUrl, projectId?)

2. 视频生成页面（lib/features/ai_video/views/video_gen_page.dart）：
   - 上下分区布局：
     · 上部（参数 + 结果 ~70%）左右分栏：
       左侧参数面板（~40%）：
         - 生成模式切换（Pivot/TabView）：文生视频 / 图生视频
         - 服务商选择（ComboBox）
         - 模型选择（ComboBox）
         - 文生视频模式：
           · 提示词输入（TextBox，多行）
           · "从提示词库选择" 按钮
           · "AI 优化提示词" 按钮
         - 图生视频模式：
           · 输入图片选择（从资产库选择 或 本地上传）
           · 图片预览
           · 运动描述提示词（TextBox）
         - 视频参数：
           · 分辨率选择（ComboBox）
           · 时长选择（ComboBox：3s/5s/10s 等）
         - "开始生成" 按钮

       右侧结果区域（~60%）：
         - 无任务时：占位提示
         - 生成中：进度指示（ProgressRing + 状态文字 + 经过时间）
         - 生成完成：视频播放器预览
         - 操作按钮：保存到资产、另存为、重新生成

     · 下部任务队列面板（~30%，可收起）：
       - 标题栏："任务队列" + 折叠按钮
       - 任务列表（横向或纵向）：
         · 每个任务显示：缩略图/状态图标、提示词摘要、状态、用时、操作按钮
         · 状态颜色：pending-灰色 running-蓝色 completed-绿色 failed-红色
         · 完成的任务可以点击查看结果
         · 失败的任务显示错误信息 + "重试" 按钮

3. 任务轮询服务：
   - 使用 Timer.periodic 或 Stream.periodic 轮询
   - 应用关闭时保存任务状态，重新打开时恢复轮询
   - 任务完成时发送桌面通知（使用 notification_service）

4. 通知服务（lib/core/services/notification_service.dart）：
   - 桌面端：使用系统通知（local_notifications 或平台通道）
   - 当 AI 任务（图片/视频）完成时弹出通知
   - 点击通知可跳转到对应任务结果

请确保：
- 多个任务可以同时排队/执行（如果 API 支持）
- 任务状态轮询不会因页面切换而中断（全局管理）
- 视频预览使用 media_kit
- 图生视频时图片预览有合适的尺寸
- 长时间任务有友好的等待提示（预计剩余时间，如果可估算）
```

---

## Phase 12 — 设置与配置中心

### 目标
实现应用的全局设置页面，包括 AI 服务商配置、存储管理、主题设置等。

### 交付物
- 设置页面（分节布局）
- AI 服务商管理（API Key 配置、连接测试）
- 存储管理（存储位置、空间统计、清理）
- 外观设置（主题、语言）

### AI 提示词

```
基于已完成的 Phase 1-11，请帮我实现 AIO Studio 的设置与配置中心。

技术栈：fluent_ui (^4.14.0)、flutter_riverpod、shared_preferences、drift。

请实现以下内容：

1. 设置 Provider（lib/features/settings/providers/settings_provider.dart）：
   - theme: ThemeMode (system/light/dark)
   - accentColor: AccentColor
   - locale: Locale
   - storageDirectory: String（资产存储根目录）
   - autoSaveChat: bool（是否自动保存对话历史）
   - extensionPort: int（浏览器扩展通信端口，默认 52140）
   - 所有设置持久化到 SharedPreferences

2. 设置页面（lib/features/settings/views/settings_page.dart）：
   - 使用 fluent_ui 的 ScaffoldPage + ListView 布局
   - 分为以下几个 Section（使用 Card 或 Expander 分组）：

   a) AI 服务商管理（最重要的部分）：
      - 已配置服务商列表：
        · 每个显示：服务商图标 + 名称 + 类型 + 启用开关 + 状态（已连接/未配置）
        · 操作：编辑、测试连接、删除
      - "添加服务商" 按钮，弹出配置对话框
      - 服务商配置对话框（ContentDialog）：
        · 服务商类型选择（ComboBox）：OpenAI / Anthropic / Stability AI / 自定义 (OpenAI 兼容)
        · 名称（TextBox，自定义显示名称）
        · API Key（PasswordBox，带显示/隐藏切换）
        · API Base URL（TextBox，可选，用于代理或自定义端点）
        · 默认模型（ComboBox，根据类型显示对应模型列表）
        · 额外配置（JSON TextBox，可选，高级用户）
        · "测试连接" 按钮 → 调用 testConnection()，显示结果
        · 保存 / 取消
      - 默认服务商设置：
        · 默认聊天服务商（ComboBox）
        · 默认图片生成服务商（ComboBox）
        · 默认视频生成服务商（ComboBox）

   b) 存储管理：
      - 资产存储位置：显示当前路径 + "更改" 按钮（选择目录）
      - 存储统计：
        · 总资产数量
        · 总占用空间（显示为 XX MB / XX GB）
        · 按类型占用：图片 XX MB / 视频 XX MB / 其他 XX MB
        · 使用 ProgressBar 可视化占用比例
      - "清理缓存" 按钮 → 清理缩略图缓存
      - "打开存储目录" 按钮 → 打开文件管理器

   c) 外观设置：
      - 主题模式（RadioButton 组）：跟随系统 / 亮色 / 暗色
      - 强调色选择：显示颜色调色板（fluent_ui 预定义颜色），点击选择
      - 界面语言（ComboBox）：简体中文 / English（预留）

   d) 浏览器扩展：
      - 扩展通信端口（NumberBox，默认 52140）
      - 连接状态显示
      - "重启通信服务" 按钮
      - 扩展下载链接（指向 Chrome Web Store / Edge Add-ons）

   e) 关于：
      - 应用名称 + 版本号 + Logo
      - 开源协议
      - 检查更新按钮
      - 反馈链接

3. API Key 安全存储：
   - API Key 在数据库中加密存储（使用 encrypt 包或 flutter_secure_storage）
   - 界面显示时使用 PasswordBox（默认遮罩）
   - 日志中不输出明文 API Key

请确保：
- 设置更改立即生效（主题切换即时预览）
- 服务商配置保存到 ai_provider_configs 数据库表
- 测试连接有明确的成功/失败反馈（InfoBar 通知）
- 存储统计异步计算，不阻塞 UI
- 密码框有显示/隐藏切换按钮
```

---

## Phase 13 — 浏览器扩展（Chrome/Edge）

### 目标
开发 Chrome/Edge 浏览器扩展，支持快速保存网页上的图片和视频到 AIO Studio。

### 交付物
- Manifest V3 扩展项目
- Content Script（页面内注入）
- Popup 界面
- Background Service Worker
- 与 AIO Studio 本地通信

### AI 提示词

```
请帮我创建 AIO Studio 的浏览器扩展项目（Chrome/Edge 通用，Manifest V3）。

技术栈：TypeScript + React + Vite（构建工具），扩展位于项目的 extension/ 目录。

扩展功能：在网页上快速识别并保存图片/视频到 AIO Studio 桌面应用。

请实现以下内容：

1. 项目结构（extension/）：
   - manifest.json（Manifest V3）
   - package.json（依赖 + 构建脚本）
   - tsconfig.json
   - vite.config.ts（多入口打包：background, content, popup）
   - src/
     ├── background/index.ts
     ├── content/index.ts
     ├── popup/App.tsx + index.tsx + index.html
     ├── shared/api.ts + types.ts + constants.ts
     └── assets/（图标等）

2. manifest.json：
   - manifest_version: 3
   - name: "AIO Studio Collector"
   - description: "快速保存网页图片和视频到 AIO Studio"
   - permissions: ["activeTab", "contextMenus", "storage", "notifications"]
   - host_permissions: ["<all_urls>"]
   - background.service_worker: background.js
   - content_scripts: 匹配所有 http/https 页面，注入 content.js
   - action.default_popup: popup.html
   - icons: 16/32/48/128

3. Content Script（src/content/index.ts）：
   - 监听页面上的图片和视频元素
   - 鼠标悬停在图片/视频上时，在元素右上角显示一个浮动的 "保存到 AIO" 小按钮：
     · 半透明圆形按钮，AIO 图标
     · hover 时变为不透明
     · 点击后弹出保存面板
   - 保存面板（注入到页面的小浮层）：
     · 显示图片/视频预览缩略图
     · 文件信息（URL、尺寸、格式）
     · 选择目标项目（下拉框，从桌面应用获取项目列表）
     · 资产名称（自动提取，可编辑）
     · "保存" 按钮
     · 保存成功/失败反馈
   - 支持右键菜单 "保存图片到 AIO Studio" / "保存视频到 AIO Studio"
   - 框选模式：按住快捷键（Alt+Shift+S）激活框选，用户可以框选页面区域截图保存

4. Background Service Worker（src/background/index.ts）：
   - 注册右键上下文菜单项：
     · "保存图片到 AIO Studio"（mediaType: image）
     · "保存视频到 AIO Studio"（mediaType: video）
     · "保存链接中的媒体到 AIO Studio"
   - 处理来自 Content Script 和 Popup 的消息
   - 与 AIO Studio 桌面应用通过 HTTP 通信：
     · 默认连接 http://localhost:52140
     · 心跳检测（每 30s 检查应用是否运行）
     · 发送保存请求（POST /api/assets/import-from-extension）
     · 获取项目列表（GET /api/projects）
   - 下载图片/视频并以 base64 或 FormData 方式发送给应用

5. Popup 界面（src/popup/App.tsx）：
   - 使用 React + 简洁的 Fluent-like CSS 样式
   - 宽度 360px
   - 内容：
     · 连接状态指示（绿色/红色圆点 + "已连接" / "未连接"）
     · 如果未连接：提示安装/启动 AIO Studio，显示下载链接
     · 如果已连接：
       - 当前页面上检测到的媒体数量统计
       - "扫描当前页面" 按钮 → 列出所有检测到的图片/视频
       - 媒体列表（缩略图 + URL + 类型 + 尺寸 + 勾选框）
       - "全选" / "取消全选"
       - 选择目标项目（下拉框）
       - "批量保存选中项" 按钮
       - 保存进度和结果反馈
     · 底部：设置入口（配置通信端口等）

6. 共享类型定义（src/shared/types.ts）：
   - MediaItem: { url, type, width, height, alt, duration?, pageUrl, pageTitle }
   - SaveRequest: { mediaUrl, mediaType, projectId, name, pageUrl, pageTitle }
   - SaveResponse: { success, assetId, error }
   - Project: { id, name }
   - ConnectionStatus: 'connected' | 'disconnected' | 'connecting'

7. API 通信模块（src/shared/api.ts）：
   - AIOStudioAPI class:
     · baseUrl: string（可配置）
     · checkConnection(): Promise<boolean>
     · getProjects(): Promise<Project[]>
     · saveMedia(request: SaveRequest): Promise<SaveResponse>
     · batchSaveMedia(requests: SaveRequest[]): Promise<SaveResponse[]>

请确保：
- Content Script 注入的 UI 不影响原网页样式（使用 Shadow DOM 隔离）
- 图片检测支持 img 标签、CSS background-image、picture/source 标签
- 视频检测支持 video 标签、iframe 嵌入（YouTube 等特殊处理）
- 扩展图标在检测到媒体时显示 badge 数量
- 所有 UI 文字使用中文
- Vite 打包配置正确处理多入口和 Chrome 扩展的特殊要求
```

---

## Phase 14 — 扩展与应用通信

### 目标
在 Flutter 应用内实现本地 HTTP 服务器，接收来自浏览器扩展的请求。

### 交付物
- 本地 HTTP 服务器
- 接收资产保存请求的 API
- 扩展连接状态管理
- 实时通知（扩展保存成功后应用内弹窗）

### AI 提示词

```
基于已完成的 Phase 1-13，请帮我在 AIO Studio Flutter 应用内实现与浏览器扩展通信的本地 HTTP 服务器。

技术栈：dart:io (HttpServer)、flutter_riverpod、shelf (^1.x) 或直接使用 dart:io。

浏览器扩展通过 HTTP 请求与本地运行的 Flutter 应用通信。

请实现以下内容：

1. 扩展通信服务（lib/core/services/extension_bridge/extension_server.dart）：
   - 使用 shelf 包或 dart:io HttpServer
   - 启动本地 HTTP 服务器，监听 localhost:52140（端口可配置）
   - 添加 CORS 头（允许来自浏览器扩展的请求）

   实现以下 API 端点：

   a) GET /api/health
      - 返回 { "status": "ok", "version": "1.0.0", "app": "AIO Studio" }
      - 用于扩展检测应用是否运行

   b) GET /api/projects
      - 返回所有未归档项目的列表
      - [{ "id": "xxx", "name": "项目名", "assetCount": 10 }]

   c) POST /api/assets/import-from-extension
      - 请求体：{
          "mediaUrl": "https://...",      // 媒体原始 URL
          "mediaBase64": "...",            // 或 base64 数据（二选一）
          "mediaType": "image",            // image / video
          "fileName": "photo.jpg",
          "projectId": "xxx",              // 可选，目标项目
          "name": "资产名称",              // 可选
          "pageUrl": "https://...",        // 来源页面 URL
          "pageTitle": "页面标题",         // 来源页面标题
          "tags": ["tag1", "tag2"]         // 可选标签
        }
      - 处理流程：
        1. 如果提供 mediaUrl → 下载文件
        2. 如果提供 mediaBase64 → 解码
        3. 保存文件到资产目录
        4. 生成缩略图（图片类型）
        5. 创建 asset 数据库记录（sourceType: browser_extension）
        6. 如有标签，创建标签关联
      - 返回 { "success": true, "assetId": "xxx" }
      - 失败返回 { "success": false, "error": "错误信息" }

   d) POST /api/assets/batch-import
      - 批量导入，请求体为数组
      - 返回每一项的结果

2. 服务生命周期管理：
   - 应用启动时自动启动 HTTP 服务器
   - 应用退出时关闭服务器
   - 端口被占用时自动尝试 +1 端口（最多尝试 10 次）
   - 记录实际使用的端口到设置

3. 实时通知：
   - 扩展成功保存资产后，在 Flutter 应用内弹出 InfoBar 通知：
     · "已从浏览器保存：资产名称"
     · 带有 "查看" 按钮跳转到资产详情
   - 使用 Riverpod StreamProvider 监听新资产事件

4. Riverpod Providers：
   - extensionServerProvider：管理 HTTP 服务器生命周期
   - extensionConnectionStatusProvider：连接状态（是否有扩展最近请求过 /api/health）
   - recentExtensionImportsProvider：最近从扩展导入的资产流

5. 安全考虑：
   - 仅监听 localhost（127.0.0.1），不暴露到网络
   - 请求来源验证（检查 Origin 或自定义 Header）
   - 请求大小限制（单个文件最大 200MB）
   - 速率限制（每秒最多 10 个请求）

请确保：
- HTTP 服务器使用 isolate 或异步处理，不阻塞 UI 线程
- 文件下载和保存使用流式处理，避免大文件占用过多内存
- 错误响应包含有用的错误信息
- 服务器在设置中可以手动启停
```

---

## Phase 15 — 移动端适配

### 目标
适配 iOS 和 Android 平台，调整布局和交互方式。

### 交付物
- 响应式布局适配
- 移动端导航调整
- 触摸手势适配
- 平台特定功能处理

### AI 提示词

```
基于已完成的 Phase 1-14，请帮我适配 AIO Studio 的移动端（iOS 和 Android）。

技术栈：fluent_ui (^4.14.0)、flutter_riverpod、go_router。

fluent_ui 支持所有平台，但移动端需要调整布局和交互以适应小屏幕和触摸操作。

请实现以下调整：

1. 响应式导航（修改 lib/shared/widgets/app_shell.dart）：
   - 桌面端（>800px）：保持 NavigationView 左侧导航面板
   - 移动端（<=800px）：
     · NavigationPane 使用 PaneDisplayMode.minimal（汉堡菜单）
     · 或改为底部 BottomNavigation 样式（选择更适合 fluent_ui 的方案）
   - 移除桌面端窗口控制按钮（最小化/最大化/关闭）
   - 移除 DragToMoveArea
   - 使用平台检测：Platform.isAndroid / Platform.isIOS

2. 资产浏览适配（修改 assets_page）：
   - 移动端默认使用 2 列网格
   - 筛选栏改为可下拉展开的面板（节省纵向空间）
   - 多选模式：长按进入多选，而非 Ctrl+Click
   - 底部操作栏替代顶部 CommandBar
   - 下拉刷新支持

3. 项目管理适配（修改 projects_page）：
   - 移动端默认使用列表视图（卡片视图在小屏幕上太密集）
   - 项目详情页：Tab 改为全宽度滑动 Tab

4. AI 对话适配（修改 chat_page）：
   - 移动端：对话列表改为全屏页面（从侧滑抽屉进入）
   - 聊天界面全屏
   - 输入框固定在底部，键盘弹出时自动调整
   - 模型选择器移到顶部 AppBar 的下拉菜单

5. 图片/视频生成适配：
   - 移动端：参数面板改为上方，结果区域在下方（垂直布局）
   - 或使用 Tab 切换：参数 Tab + 结果 Tab

6. 设置页面适配：
   - 移动端使用全宽度列表布局（已经兼容）

7. 文件操作适配：
   - 移动端文件导入使用系统相册/文件选择器
   - 移动端不支持文件拖拽导入
   - "在文件管理器中打开" 在移动端改为 "分享"（使用 share_plus）

8. 平台工具类（lib/core/utils/platform_utils.dart）：
   - isDesktop: bool（Windows/macOS/Linux）
   - isMobile: bool（iOS/Android）
   - isWeb: bool
   - 根据平台返回不同的默认值（如网格列数、面板宽度等）

请确保：
- 不破坏桌面端已有功能
- 使用 MediaQuery 或 LayoutBuilder 实现响应式，而非硬编码平台判断
- 触摸滚动和手势操作流畅
- 安全区域（SafeArea）正确处理（刘海屏、底部手势条）
- 移动端不启动本地 HTTP 服务器（浏览器扩展功能仅桌面端）
```

---

## Phase 16 — 测试、优化与打包发布

### 目标
完善测试、性能优化、多平台打包与发布准备。

### 交付物
- 单元测试和组件测试
- 性能优化
- 多平台打包配置
- 应用图标与启动画面

### AI 提示词

```
基于已完成的 Phase 1-15，请帮我完成 AIO Studio 的测试、优化与打包发布准备。

技术栈：flutter_test、mockito、integration_test、flutter build。

请实现以下内容：

1. 单元测试（test/）：
   a) 数据层测试：
      - drift 数据库 CRUD 测试（使用内存数据库）
      - 各 DAO 方法测试
      - 数据迁移测试
   b) AI 服务测试：
      - Mock HTTP 响应测试各服务的请求构建和响应解析
      - SSE 流式解析测试
      - 错误处理测试
   c) Provider 测试：
      - 使用 ProviderContainer 测试各核心 Provider
      - 异步状态变化测试

2. Widget 测试（test/widgets/）：
   - 项目卡片渲染测试
   - 资产缩略图组件测试
   - 聊天消息气泡测试
   - 导入对话框交互测试

3. 性能优化：
   a) 图片加载优化：
      - 缩略图使用固定尺寸（避免大图直接加载到网格）
      - 列表使用 ListView.builder 懒加载
      - 图片内存缓存大小限制
   b) 数据库查询优化：
      - 为常用查询添加索引（asset.projectId, asset.type, asset.createdAt）
      - 分页加载大列表（每页 50 条）
   c) 内存优化：
      - 视频播放器不在后台保持
      - 大量对话消息使用虚拟列表

4. 应用图标与启动画面：
   - 使用 flutter_launcher_icons 配置应用图标
   - 使用 flutter_native_splash 配置启动画面
   - 图标设计建议：简洁的 AI + Studio 风格图标，蓝色调
   - 提供 pubspec.yaml 中的配置代码

5. 多平台打包配置：
   a) Windows：
      - flutter build windows --release
      - 使用 msix 包打包为 MSIX 安装包
      - 或使用 Inno Setup 打包为 exe 安装程序
      - 配置应用名称、版本、图标
   b) macOS：
      - flutter build macos --release
      - 配置 Info.plist（应用名称、Bundle ID）
      - 代码签名说明
   c) Linux：
      - flutter build linux --release
      - 生成 .deb 或 AppImage
   d) Android：
      - flutter build apk --release
      - 配置 AndroidManifest.xml 权限
   e) iOS：
      - flutter build ios --release
      - 配置 Info.plist 权限描述

6. CI/CD 配置建议：
   - GitHub Actions 工作流模板
   - 多平台并行构建
   - 自动发布到 GitHub Releases

7. 版本管理：
   - 配置 pubspec.yaml 版本号策略
   - CHANGELOG.md 模板

请提供：
- 完整的测试文件代码
- pubspec.yaml 中的打包相关配置
- 各平台特定的配置文件修改说明
- GitHub Actions 工作流 YAML 文件
```

---

## 附录 A：关键 AI 提示词使用技巧

### 给 AI 的通用上下文前缀

每次开始新阶段时，在提示词最前面加上以下上下文，让 AI 了解项目整体情况：

```
当前已完成：[列出已完成的 Phase]
当前需要实现：Phase X — [阶段名称]
```

### 阶段衔接提示

当 AI 需要引用之前阶段的代码时：

```
以下是之前阶段已实现的关键文件，请基于这些代码继续开发：

[粘贴相关文件的关键代码片段]
```

## 附录 B：依赖版本速查

```yaml
# pubspec.yaml 核心依赖（截至 2026.03）
dependencies:
  flutter:
    sdk: flutter
  fluent_ui: ^4.14.0
  flutter_riverpod: ^3.2.1
  riverpod_annotation: ^3.2.1
  go_router: ^17.1.0
  dio: ^5.7.0
  drift: ^2.32.0
  sqlite3_flutter_libs: ^0.5.0
  window_manager: ^0.5.1
  path_provider: ^2.1.0
  cached_network_image: ^3.4.0
  file_picker: ^8.0.0
  json_annotation: ^4.9.0
  uuid: ^4.5.0
  intl: ^0.19.0
  logger: ^2.5.0
  shared_preferences: ^2.3.0
  media_kit: ^1.1.0
  media_kit_video: ^1.2.0
  media_kit_libs_video: ^1.0.0
  shelf: ^1.4.0
  shelf_router: ^1.1.0
  share_plus: ^10.0.0
  url_launcher: ^6.3.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.0
  drift_dev: ^2.32.0
  json_serializable: ^6.8.0
  riverpod_generator: ^3.2.1
  custom_lint: ^0.7.0
  riverpod_lint: ^3.2.1
  flutter_launcher_icons: ^0.14.0
  flutter_native_splash: ^2.4.0
  msix: ^3.16.0
  mockito: ^5.4.0
  flutter_lints: ^5.0.0
```
