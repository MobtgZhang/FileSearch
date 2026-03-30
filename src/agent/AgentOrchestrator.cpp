#include "AgentOrchestrator.h"
#include "AIBridge.h"
#include "ToolExecutor.h"
#include "ContextBuilder.h"
#include "ChatBridge.h"
#include "CacheManager.h"
#include "PromptLoader.h"
#include "PromptFallbacks.h"
#include "engine/SearchEngine.h"
#include "AppSettings.h"

#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QVariantMap>
#include <QDateTime>
#include <QtConcurrent>

namespace {
// 避免 shell/find 等超大 stdout 进入对话历史与 API 请求体时拖垮内存或 WebChannel
constexpr int kMaxToolStdoutForHistory = 96000;

QVariantMap toolResultForHistory(const QVariant &result)
{
    QVariantMap m = result.toMap();
    if (!m.contains(QStringLiteral("stdout")))
        return m;
    QString out = m.value(QStringLiteral("stdout")).toString();
    if (out.size() <= kMaxToolStdoutForHistory)
        return m;
    m[QStringLiteral("stdout")]
        = out.left(kMaxToolStdoutForHistory)
          + QStringLiteral(
                "\n\n…(内容已截断：进入模型上下文的 stdout 上限约 %1 字符，请缩小 find 范围或使用 head/wc。)")
              .arg(kMaxToolStdoutForHistory);
    m[QStringLiteral("truncated_for_context")] = true;
    return m;
}

static QString escapeTildeFenceBody(QString s)
{
    return s.replace(QLatin1String("~~~"), QLatin1String("\\~\\~\\~"));
}

/** 右侧聊天区展示用（与送入模型的 history 截断无关） */
static QString toolResultUiMarkdown(const QString &toolName, const QVariant &result)
{
    const QVariantMap m = result.toMap();
    if (m.contains(QStringLiteral("error"))) {
        return QStringLiteral("### `%1`\n\n**失败** %2\n")
            .arg(toolName, m.value(QStringLiteral("error")).toString());
    }

    if (toolName == QStringLiteral("shell")) {
        const int ec = m.value(QStringLiteral("exitCode")).toInt();
        const bool ok = m.value(QStringLiteral("success")).toBool();
        QString out = m.value(QStringLiteral("stdout")).toString();
        static constexpr int kMaxUi = 14000;
        if (out.size() > kMaxUi)
            out = out.left(kMaxUi)
                  + QStringLiteral("\n\n…(界面展示已截断；完整输出已写入对话上下文供模型使用)");
        out = escapeTildeFenceBody(out);
        return QStringLiteral("### `shell` · 标准输出\n\n**退出码** `%1` · **%2**\n\n~~~text\n%3\n~~~")
            .arg(ec)
            .arg(ok ? QStringLiteral("成功") : QStringLiteral("失败"))
            .arg(out);
    }

    if (toolName == QStringLiteral("search_files")) {
        const int count = m.value(QStringLiteral("count")).toInt();
        const int total = m.value(QStringLiteral("total_matched")).toInt();
        const bool trunc = m.value(QStringLiteral("truncated")).toBool();
        QStringList lines;
        const QVariantList files = m.value(QStringLiteral("files")).toList();
        int n = 0;
        for (const QVariant &v : files) {
            if (++n > 100)
                break;
            lines << QStringLiteral("- `%1`").arg(v.toMap().value(QStringLiteral("path")).toString());
        }
        QString body = lines.join(QLatin1Char('\n'));
        if (body.isEmpty())
            body = QStringLiteral("_无匹配文件_");
        if (trunc)
            body += QStringLiteral("\n\n*（列表最多展示 100 条，总匹配 %1 条）*").arg(total);
        return QStringLiteral("### `search_files`\n\n**本页 %1 条** · **总匹配 %2 条**\n\n%3")
            .arg(count)
            .arg(total)
            .arg(body);
    }

    if (toolName == QStringLiteral("read_file")) {
        const QString path = m.value(QStringLiteral("path")).toString();
        QString c = m.value(QStringLiteral("content")).toString();
        const bool trunc = m.value(QStringLiteral("truncated")).toBool();
        static constexpr int kMaxUi = 12000;
        if (c.size() > kMaxUi)
            c = c.left(kMaxUi) + QStringLiteral("\n\n…(界面展示已截断)");
        c = escapeTildeFenceBody(c);
        return QStringLiteral("### `read_file`\n\n**路径** `%1`%2\n\n~~~text\n%3\n~~~")
            .arg(path, trunc ? QStringLiteral(" · *读取截断*") : QString(), c);
    }

    if (toolName == QStringLiteral("web_fetch")) {
        const QString url = m.value(QStringLiteral("url")).toString();
        QString t = m.value(QStringLiteral("text")).toString();
        t = escapeTildeFenceBody(t);
        return QStringLiteral("### `web_fetch`\n\n**URL** `%1`\n\n~~~text\n%2\n~~~").arg(url, t);
    }

    QString json = QString::fromUtf8(QJsonDocument::fromVariant(QVariant(m)).toJson(QJsonDocument::Indented));
    static constexpr int kMaxJson = 10000;
    if (json.size() > kMaxJson)
        json = json.left(kMaxJson) + QStringLiteral("\n…");
    return QStringLiteral("### `%1`\n\n~~~json\n%2\n~~~").arg(toolName, json);
}
} // namespace

AgentOrchestrator::AgentOrchestrator(QObject *parent)
    : QObject(parent)
{
}

void AgentOrchestrator::setAIBridge(AIBridge *bridge) { m_aiBridge = bridge; }
void AgentOrchestrator::setToolExecutor(ToolExecutor *executor) { m_toolExecutor = executor; }
void AgentOrchestrator::setContextBuilder(ContextBuilder *builder) { m_contextBuilder = builder; }
void AgentOrchestrator::setChatBridge(ChatBridge *chat) { m_chatBridge = chat; }
void AgentOrchestrator::setCacheManager(CacheManager *cache) { m_cacheManager = cache; }
void AgentOrchestrator::setSearchEngine(SearchEngine *engine) { m_searchEngine = engine; }
void AgentOrchestrator::setAppSettings(AppSettings *settings) { m_appSettings = settings; }

void AgentOrchestrator::setBusy(bool busy)
{
    if (m_busy != busy) {
        m_busy = busy;
        emit busyChanged();
    }
}

void AgentOrchestrator::handleUserMessage(const QString &text)
{
    if (text.trimmed().isEmpty() || m_busy)
        return;

    if (m_appSettings && m_appSettings->agentMaxToolRounds() == 0) {
        if (m_chatBridge)
            m_chatBridge->receiveAiMessage(QStringLiteral(
                "当前设置中 **Agent 最大工具轮次为 0**（不使用 AI Agent）。请在「设置 → Agent 与沙箱」中将「工具轮次」改为 **-1**（不限制）或正整数以启用。"));
        return;
    }

    setBusy(true);
    m_toolInvocationsThisTurn = 0;

    if (m_cacheManager)
        m_cacheManager->appendHistory("user", text);

    QJsonObject userMsg;
    userMsg["role"] = "user";
    userMsg["content"] = text;
    m_conversationHistory.append(userMsg);

    processAgentLoop(text);
}

void AgentOrchestrator::processAgentLoop(const QString &userText)
{
    Q_UNUSED(userText);

    QJsonArray messages;
    messages.append(buildSystemMessage());

    if (m_cacheManager) {
        QString layered = m_cacheManager->buildMemoryHierarchyPrompt();
        if (!layered.isEmpty()) {
            QJsonObject memMsg;
            memMsg["role"] = "system";
            memMsg["content"] = layered;
            messages.append(memMsg);
        }
    }

    for (const auto &msg : m_conversationHistory)
        messages.append(msg);

    sendToLLM(messages);
}

QJsonObject AgentOrchestrator::buildSystemMessage() const
{
    QString systemPrompt;
    if (m_appSettings)
        systemPrompt = m_appSettings->systemPrompt();
    if (systemPrompt.isEmpty())
        systemPrompt = "你是 NexFile 的 AI 助手，帮助用户管理文件。";

    QString context;
    if (m_contextBuilder)
        context = m_contextBuilder->buildContext({});

    QString fullPrompt = systemPrompt + "\n\n";
    QString reactBlock = PromptLoader::loadUtf8WithFallback(QStringLiteral("agent_react_workflow.md"),
                                                            PromptFallbacks::agentReactWorkflow());
    fullPrompt += reactBlock;
    fullPrompt += QStringLiteral("可用工具：\n");

    if (m_toolExecutor) {
        QJsonArray tools = buildToolDefinitions();
        for (const auto &t : tools) {
            QJsonObject fn = t.toObject()["function"].toObject();
            fullPrompt += "- " + fn["name"].toString() + ": " + fn["description"].toString() + "\n";
        }
    }

    if (!context.isEmpty())
        fullPrompt += "\n当前文件系统上下文:\n" + context;

    QString footer = PromptLoader::loadUtf8WithFallback(QStringLiteral("agent_reply_guidelines.md"),
                                                         PromptFallbacks::agentReplyGuidelines());
    fullPrompt += QLatin1Char('\n') + footer;

    QJsonObject msg;
    msg["role"] = "system";
    msg["content"] = fullPrompt;
    return msg;
}

QJsonArray AgentOrchestrator::buildToolDefinitions() const
{
    QJsonArray tools;

    auto addTool = [&tools](const QString &name, const QString &desc, const QJsonObject &params) {
        QJsonObject fn;
        fn["name"] = name;
        fn["description"] = desc;
        fn["parameters"] = params;

        QJsonObject tool;
        tool["type"] = "function";
        tool["function"] = fn;
        tools.append(tool);
    };

    {
        QJsonObject params;
        params["type"] = "object";
        QJsonObject props;
        props["pattern"] = QJsonObject{{"type", "string"}, {"description", "搜索关键词，支持文件名、路径、扩展名"}};
        params["properties"] = props;
        params["required"] = QJsonArray{"pattern"};
        addTool("search_files", "按条件搜索本地索引中的文件", params);
    }

    {
        QJsonObject params;
        params["type"] = "object";
        QJsonObject props;
        props["path"] = QJsonObject{{"type", "string"}, {"description", "绝对或相对路径"}};
        props["max_bytes"] = QJsonObject{{"type", "integer"}, {"description", "最多读取字节数"}, {"default", 524288}};
        params["properties"] = props;
        params["required"] = QJsonArray{"path"};
        addTool("read_file", "读取本地文本文件（UTF-8）", params);
    }

    {
        QJsonObject params;
        params["type"] = "object";
        QJsonObject props;
        props["path"] = QJsonObject{{"type", "string"}, {"description", "目标文件路径"}};
        props["content"] = QJsonObject{{"type", "string"}, {"description", "要写入的文本"}};
        props["append"] = QJsonObject{{"type", "boolean"}, {"description", "是否追加"}, {"default", false}};
        params["properties"] = props;
        params["required"] = QJsonArray{"path", "content"};
        addTool("write_file", "写入或追加文本到本地文件", params);
    }

    {
        QJsonObject params;
        params["type"] = "object";
        QJsonObject props;
        props["paths"] = QJsonObject{{"type", "array"}, {"items", QJsonObject{{"type", "string"}}}, {"description", "待删除文件路径列表"}};
        props["dryRun"] = QJsonObject{{"type", "boolean"}, {"description", "true 则仅预览不实际删除"}, {"default", true}};
        params["properties"] = props;
        params["required"] = QJsonArray{"paths"};
        addTool("delete_files", "删除文件列表（支持 dry_run 预览）", params);
    }

    {
        QJsonObject params;
        params["type"] = "object";
        QJsonObject props;
        props["sources"] = QJsonObject{{"type", "array"}, {"items", QJsonObject{{"type", "string"}}}, {"description", "源文件路径列表"}};
        props["destination"] = QJsonObject{{"type", "string"}, {"description", "目标目录路径"}};
        params["properties"] = props;
        params["required"] = QJsonArray{"sources", "destination"};
        addTool("move_files", "将文件移动到目标目录", params);
    }

    {
        QJsonObject params;
        params["type"] = "object";
        QJsonObject props;
        props["command"] = QJsonObject{{"type", "string"}, {"description", "Shell 命令（Windows 为 cmd 链，其它为 bash -c）"}};
        props["timeoutMs"] = QJsonObject{{"type", "integer"}, {"description", "超时毫秒数"}, {"default", 30000}};
        params["properties"] = props;
        params["required"] = QJsonArray{"command"};
        addTool("shell", "在本地执行 shell 命令（自动适配 Windows / Linux / macOS）", params);
    }

    {
        QJsonObject params;
        params["type"] = "object";
        QJsonObject props;
        props["url"] = QJsonObject{{"type", "string"}, {"description", "完整 http(s) URL，非搜索 API"}};
        props["max_bytes"] = QJsonObject{{"type", "integer"}, {"description", "最多下载字节数"}, {"default", 262144}};
        params["properties"] = props;
        params["required"] = QJsonArray{"url"};
        addTool("web_fetch", "HTTP GET 抓取网页并抽取纯文本（非搜索 API）", params);
    }

    return tools;
}

void AgentOrchestrator::sendToLLM(const QJsonArray &messages)
{
    if (!m_aiBridge) {
        emitAIResponse(QStringLiteral("AI 服务未就绪，请检查设置。"));
        setBusy(false);
        return;
    }

    if (m_chatBridge) {
        m_chatBridge->receiveThinkingClear();
        m_chatBridge->receiveStreamStart();
        m_chatBridge->receiveThinkingChunk(QStringLiteral("正在汇总 L3→L1 分级记忆与上下文，并建立流式通道…"));
    }

    QJsonArray tools = buildToolDefinitions();
    m_aiBridge->sendChatRequest(messages, tools);
}

void AgentOrchestrator::handleLLMResponse(const QJsonObject &response)
{
    QJsonObject choices0;
    QJsonArray choices = response["choices"].toArray();
    if (!choices.isEmpty())
        choices0 = choices[0].toObject();

    QJsonObject message = choices0["message"].toObject();
    QString finishReason = choices0["finish_reason"].toString();

    if (finishReason == QStringLiteral("tool_calls") || message.contains(QStringLiteral("tool_calls"))) {
        const int roundLimit = m_appSettings ? m_appSettings->agentMaxToolRounds() : -1;
        if (roundLimit >= 0) {
            ++m_toolInvocationsThisTurn;
            if (m_toolInvocationsThisTurn > roundLimit) {
                const QString stopMsg = QStringLiteral(
                    "已达到设置中的 **Agent 最大工具轮次（%1）**，已停止继续调用工具。可在「设置 → Agent 与沙箱」中调高该值，或拆分任务。")
                                              .arg(roundLimit);
                QJsonObject assistantStop;
                assistantStop[QStringLiteral("role")] = QStringLiteral("assistant");
                assistantStop[QStringLiteral("content")] = stopMsg;
                m_conversationHistory.append(assistantStop);
                emitAIResponse(stopMsg);
                if (m_cacheManager) {
                    m_cacheManager->appendHistory(QStringLiteral("assistant"), stopMsg);
                    m_cacheManager->updateMemory(m_conversationHistory);
                }
                setBusy(false);
                return;
            }
        }

        m_conversationHistory.append(message);

        QJsonArray toolCalls = message[QStringLiteral("tool_calls")].toArray();
        for (const auto &tc : toolCalls) {
            QJsonObject call = tc.toObject();
            QString toolCallId = call["id"].toString();
            QJsonObject function = call["function"].toObject();
            QString toolName = function["name"].toString();
            QString argsStr = function["arguments"].toString();
            QJsonObject args = QJsonDocument::fromJson(argsStr.toUtf8()).object();

            executeToolCall(toolName, args, toolCallId);
        }

        processAgentLoop(QString());
        return;
    }

    QString content = message[QStringLiteral("content")].toString();
    if (content.isEmpty())
        content = QStringLiteral("抱歉，我无法生成回复，请重试。");

    if (finishReason == QStringLiteral("length")) {
        content += QStringLiteral(
            "\n\n---\n*（本次输出因模型「最大生成长度」达到上限而结束。请在设置中提高 max_tokens / 最大输出，或请模型分条简略回答。）*");
    }

    QJsonObject assistantMsg;
    assistantMsg[QStringLiteral("role")] = QStringLiteral("assistant");
    assistantMsg[QStringLiteral("content")] = content;
    m_conversationHistory.append(assistantMsg);

    emitAIResponse(content);

    if (m_cacheManager) {
        m_cacheManager->appendHistory(QStringLiteral("assistant"), content);
        m_cacheManager->updateMemory(m_conversationHistory);
        QString lastUser;
        for (int i = m_conversationHistory.size() - 1; i >= 0; --i) {
            QJsonObject m = m_conversationHistory[i].toObject();
            if (m[QStringLiteral("role")].toString() == QStringLiteral("user")) {
                lastUser = m[QStringLiteral("content")].toString();
                break;
            }
        }
        m_cacheManager->appendL1Turn(lastUser, content);
    }

    setBusy(false);
}

void AgentOrchestrator::executeToolCall(const QString &toolName, const QJsonObject &arguments, const QString &toolCallId)
{
    if (m_chatBridge)
        m_chatBridge->receiveThinkingChunk(QStringLiteral("工具链 · ") + toolName + QStringLiteral(" · 开始执行"));
    emitToolStatus(toolName, QStringLiteral("running"), QStringLiteral("执行中…"));

    QVariantMap params = arguments.toVariantMap();
    QVariant result;

    if (m_toolExecutor)
        result = m_toolExecutor->execute(toolName, params);
    else
        result = QVariantMap{{"error", "ToolExecutor 未初始化"}};

    const QVariantMap historyMap = toolResultForHistory(result);
    QString resultJson = QString::fromUtf8(
        QJsonDocument::fromVariant(historyMap).toJson(QJsonDocument::Compact));

    QJsonObject toolMsg;
    toolMsg["role"] = "tool";
    toolMsg["tool_call_id"] = toolCallId;
    toolMsg["content"] = resultJson;
    m_conversationHistory.append(toolMsg);

    QVariantMap resultMap = result.toMap();
    QString detail;
    if (resultMap.contains("error"))
        detail = "失败: " + resultMap["error"].toString();
    else if (resultMap.contains("count")) {
        const int shown = resultMap["count"].toInt();
        if (resultMap.value(QStringLiteral("truncated")).toBool())
            detail = QStringLiteral("完成 (展示 %1 / 匹配 %2 条)").arg(shown).arg(
                resultMap.value(QStringLiteral("total_matched")).toInt());
        else
            detail = QStringLiteral("完成 (%1 结果)").arg(shown);
    }
    else if (resultMap.contains("success"))
        detail = resultMap["success"].toBool() ? "完成" : "失败";
    else
        detail = "完成";

    const bool failed = resultMap.contains(QStringLiteral("error"))
        || (resultMap.contains(QStringLiteral("success")) && !resultMap.value(QStringLiteral("success")).toBool());
    emitToolStatus(toolName, failed ? QStringLiteral("error") : QStringLiteral("done"), detail);

    if (m_chatBridge) {
        const QString outId = toolCallId.isEmpty()
            ? (QStringLiteral("tool_") + QString::number(QDateTime::currentMSecsSinceEpoch()))
            : toolCallId;
        m_chatBridge->receiveToolOutput(toolName, outId, toolResultUiMarkdown(toolName, result));
    }

    if (m_cacheManager) {
        QJsonObject skillEntry;
        skillEntry["tool"] = toolName;
        skillEntry["params"] = arguments;
        skillEntry["result_summary"] = detail;
        skillEntry["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
        m_cacheManager->recordSkillUsage(skillEntry);
    }
}

void AgentOrchestrator::emitAIResponse(const QString &text)
{
    if (!m_chatBridge)
        return;
    if (m_aiBridge && m_aiBridge->lastCompletionWasStreamed())
        m_chatBridge->notifyStreamComplete(text);
    else
        m_chatBridge->receiveAiMessage(text);
}

void AgentOrchestrator::emitToolStatus(const QString &name, const QString &status, const QString &detail)
{
    if (m_chatBridge)
        m_chatBridge->receiveToolStatus(name, status, detail);
}
