# 搜索可视化 + AI Agent 文件管理器：完整架构设计

## 整体分层架构

```
┌─────────────────────────────────────────────────────────┐
│                    QML 界面层                            │
│   SearchBar / RadialMap / TreeMap / AI Chat Panel        │
├─────────────────────────────────────────────────────────┤
│                  C++ 业务逻辑层                           │
│   搜索引擎 / 扫描引擎 / AI Bridge / 文件操作服务          │
├─────────────────────────────────────────────────────────┤
│                  数据 & 存储层                            │
│   索引数据库(SQLite) / 向量数据库 / 文件系统监听          │
└─────────────────────────────────────────────────────────┘
```

---

## 一、QML 界面层

### 主布局设计

```
┌────────────────────────────────────────────────────────────┐
│  🔍 [搜索框：*.mp4 | 大小>100MB | 类型▼ | 时间▼]  [AI✨] │
├──────────────┬─────────────────────┬────────────────────────┤
│              │  名称      大小  类型│                        │
│  环形图 /    │  video.mp4  2.3G 视频│   🤖 AI 助手面板      │
│  矩形树图    │  backup.zip 800M 压缩│                        │
│              │  node_mod/  300M 目录│  "帮我找出30天内没    │
│  （交互联动）│                     │   访问的大文件"        │
│              │ [删除] [移动] [压缩] │                        │
├──────────────┴─────────────────────┤  AI 正在分析...       │
│  共 3 项，合计 3.4GB | 已索引 12万条│                        │
└────────────────────────────────────┴────────────────────────┘
```

### 核心 QML 模块划分

```
qml/
├── main.qml                  # 主窗口、布局骨架
├── components/
│   ├── SearchBar.qml         # 搜索框 + 高级过滤器
│   ├── RadialMapView.qml     # 环形图（Canvas 自绘）
│   ├── TreeMapView.qml       # 矩形树图（Canvas 自绘）
│   ├── FileListView.qml      # 虚拟化文件列表 TableView
│   ├── AIChatPanel.qml       # AI 对话面板
│   ├── FileActionBar.qml     # 批量操作工具栏
│   └── StatusBar.qml         # 状态栏
└── theme/
    └── Theme.qml             # 统一色彩/字体变量
```

### 环形图核心实现思路

```qml
// RadialMapView.qml
Canvas {
    id: canvas
    onPaint: {
        var ctx = getContext("2d");
        for (var ring of diskModel.rings) {
            for (var seg of ring.segments) {
                ctx.beginPath();
                ctx.moveTo(cx, cy);
                ctx.arc(cx, cy, seg.outerR, seg.startAngle, seg.endAngle);
                ctx.fillStyle = seg.highlighted ? "#FF6B6B" : seg.color;
                ctx.fill();
            }
        }
    }
    // 点击命中检测 → 触发右侧列表过滤
    MouseArea {
        onClicked: {
            var seg = diskModel.hitTest(mouse.x, mouse.y);
            if (seg) fileListModel.filterByPath(seg.path);
        }
    }
}
```

---

## 二、C++ 业务逻辑层

### 模块结构

```
src/
├── engine/
│   ├── IndexEngine.h/cpp       # 文件索引（NTFS MFT / inotify）
│   ├── SearchEngine.h/cpp      # 搜索执行（倒排索引+正则）
│   ├── ScanEngine.h/cpp        # 磁盘扫描（递归统计大小）
│   └── WatcherService.h/cpp    # 实时监听文件变化
├── ai/
│   ├── AIBridge.h/cpp          # AI 接口封装（本地/云端）
│   ├── ToolExecutor.h/cpp      # AI Function Calling 执行器
│   └── ContextBuilder.h/cpp    # 构建 AI 上下文（文件信息注入）
├── model/
│   ├── FileItemModel.h/cpp     # QAbstractTableModel（列表数据）
│   ├── DiskTreeModel.h/cpp     # 树形结构（环形图数据源）
│   └── UnifiedFileRecord.h     # 统一文件记录结构体
└── service/
    ├── FileOperationService.h/cpp  # 删除/移动/压缩
    └── DuplicateDetector.h/cpp     # 重复文件检测
```

### 统一文件记录结构

```cpp
struct UnifiedFileRecord {
    QString     path;          // 完整路径
    QString     name;          // 文件名
    qint64      size;          // 字节大小
    QDateTime   modified;      // 修改时间
    QDateTime   lastAccessed;  // 最后访问时间
    QString     extension;     // 扩展名
    QString     mimeType;      // MIME 类型
    QByteArray  contentHash;   // SHA256（重复检测用）
    bool        isDirectory;
    // AI 扩展字段
    QString     aiTags;        // AI 生成的语义标签
    float       embeddingVec[384]; // 向量嵌入（语义搜索）
};
```

### 双引擎协同工作流

```
用户输入 "*.log 大于100MB"
        │
        ▼
  SearchEngine::query()
        │
   ┌────┴────┐
   │倒排索引  │  ← IndexEngine 预建（启动时/增量更新）
   │过滤+排序 │
   └────┬────┘
        │ QList<UnifiedFileRecord>
        ▼
  FileItemModel::reset()   →  QML ListView 刷新
        │
        ▼
  DiskTreeModel::highlight()  →  环形图高亮对应扇区
```

---

## 三、AI Agent 模块（核心亮点）

### AI Agent 架构

```
┌─────────────────────────────────────────────────┐
│                 AI Agent 核心                    │
│                                                  │
│  用户自然语言输入                                 │
│       ↓                                          │
│  ContextBuilder（注入文件系统上下文）             │
│       ↓                                          │
│  LLM（本地 llama.cpp 或 云端 API）               │
│       ↓                                          │
│  Function Calling 解析                           │
│       ↓                                          │
│  ToolExecutor 执行具体工具                       │
│       ↓                                          │
│  结果反馈给用户 + 更新界面状态                   │
└─────────────────────────────────────────────────┘
```

### AI 可调用的 Tools 定义

```cpp
// ToolExecutor.cpp 注册的工具集
const QList<AITool> TOOLS = {
    {
        "search_files",
        "按条件搜索文件",
        {{"pattern","文件名通配符"},{"min_size","最小字节"},
         {"max_age_days","最近N天内"},{"file_type","文件类型"}}
    },
    {
        "scan_directory",
        "扫描目录并返回大小分布",
        {{"path","目录路径"},{"depth","扫描深度"}}
    },
    {
        "find_duplicates",
        "在指定目录查找重复文件",
        {{"path","目录路径"}}
    },
    {
        "delete_files",
        "删除文件列表（需用户二次确认）",
        {{"paths","文件路径列表"},{"dry_run","仅预览不执行"}}
    },
    {
        "move_files",
        "移动文件到目标目录",
        {{"sources","源路径列表"},{"destination","目标目录"}}
    },
    {
        "analyze_space",
        "分析哪些类型/目录占用空间最多",
        {{"root_path","根目录"}}
    },
    {
        "semantic_search",
        "用自然语言描述搜索文件内容",
        {{"query","语义描述"},{"top_k","返回数量"}}
    }
};
```

### AI 对话示例流程

```
用户：帮我清理 Downloads 文件夹里超过 6 个月没用过的大文件

AI 内部执行：
  1. search_files(path="~/Downloads", max_age_days=180, min_size=50MB)
     → 返回 8 个文件，共 12.3GB

  2. 展示结果给用户，生成摘要：
     "找到 8 个文件共 12.3GB，最大的是 Ubuntu.iso (4.2GB)，
      建议先确认是否需要保留后再删除"

  3. 用户确认 → delete_files(paths=[...], dry_run=false)

  4. 更新界面：环形图动画收缩，状态栏显示已释放空间
```

### LLM 接入方案（两档可选）

| 方案         | 实现                     | 优点          | 缺点         |
| ---------- | ---------------------- | ----------- | ---------- |
| **本地模型**   | llama.cpp + Qwen2.5 7B | 隐私安全、离线可用   | 需要 >8GB 内存 |
| **云端 API** | OpenAI / Claude API    | 能力更强、无需本地资源 | 需联网、有费用    |
| **混合模式**   | 本地做意图识别，云端做复杂推理        | 平衡两者        | 架构稍复杂      |

```cpp
// AIBridge.cpp 抽象接口，支持切换后端
class AIBackend {
public:
    virtual QFuture<QString> chat(
        const QString& systemPrompt,
        const QList<Message>& history,
        const QList<AITool>& tools
    ) = 0;
};

class LocalLlamaBackend  : public AIBackend { ... }; // llama.cpp
class OpenAIBackend      : public AIBackend { ... }; // OpenAI API
class AnthropicBackend   : public AIBackend { ... }; // Claude API
```

---

## 四、数据与存储层

```
data/
├── index.db          # SQLite：文件索引（路径/大小/时间/哈希）
├── vectors.db        # 向量数据库（sqlite-vss 或 Faiss）：语义搜索
└── config.json       # 用户配置（监听目录、AI 后端设置等）
```

### SQLite 索引表结构

```sql
CREATE TABLE file_index (
    id          INTEGER PRIMARY KEY,
    path        TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    size        INTEGER,
    modified    INTEGER,  -- Unix timestamp
    accessed    INTEGER,
    extension   TEXT,
    is_dir      BOOLEAN,
    content_hash TEXT,    -- SHA256，重复检测
    ai_tags     TEXT      -- JSON 数组
);

CREATE INDEX idx_name      ON file_index(name);
CREATE INDEX idx_size      ON file_index(size);
CREATE INDEX idx_extension ON file_index(extension);
CREATE INDEX idx_modified  ON file_index(modified);
```

---

## 五、跨平台适配层

```cpp
// platform/FileSystemAdapter.h
class FileSystemAdapter {
public:
    // 工厂方法，根据平台返回对应实现
    static FileSystemAdapter* create();

    virtual void buildInitialIndex() = 0;
    virtual void startWatching(const QString& path) = 0;
    virtual qint64 getFileSize(const QString& path) = 0;
};

// Windows 实现：直接读 NTFS MFT，速度最快
class WindowsMFTAdapter : public FileSystemAdapter { ... };

// Linux 实现：inotify + 递归遍历
class LinuxInotifyAdapter : public FileSystemAdapter { ... };

// macOS 实现：FSEvents API
class MacFSEventsAdapter : public FileSystemAdapter { ... };
```

---

## 六、推荐技术栈总览

| 层次     | 技术选型                             | 理由                    |
| ------ | -------------------------------- | --------------------- |
| UI 框架  | **Qt 6.7 + QML**                 | 跨平台、性能好、TableView 虚拟化 |
| 图形渲染   | **QML Canvas + Qt Quick Shapes** | 环形图/树图自绘              |
| 语言     | **C++20**                        | 性能关键路径                |
| 数据库    | **SQLite + FTS5**                | 内嵌、支持全文检索             |
| 向量搜索   | **sqlite-vss 或 Faiss**           | 语义搜索支持                |
| 本地 LLM | **llama.cpp（C++ 绑定）**            | 无需 Python 环境          |
| 构建系统   | **CMake + vcpkg**                | 跨平台依赖管理               |
| 异步并发   | **Qt Concurrent + QFuture**      | 不阻塞 UI 线程             |

---

## 七、开发路线图建议

```
Phase 1（MVP）
  ✅ 文件索引 + 基础搜索（类 Everything）
  ✅ 磁盘扫描 + 环形图（类 Filelight）
  ✅ 搜索↔图表双向联动

Phase 2（AI 接入）
  ✅ 自然语言搜索（AI 转换为结构化查询）
  ✅ AI 分析建议（"哪些文件可以清理"）
  ✅ Function Calling 执行文件操作

Phase 3（高级功能）
  ✅ 语义搜索（向量数据库）
  ✅ 重复文件检测
  ✅ 文件内容理解（AI 读图/读文档摘要）
```

---

这个架构的核心优势是**搜索引擎、可视化引擎、AI Agent 三者共享同一份 `UnifiedFileRecord` 数据模型**，任何一层的操作都能实时反映到其他两层，实现真正的联动体验。需要我针对某个具体模块写出更详细的代码骨架吗？
