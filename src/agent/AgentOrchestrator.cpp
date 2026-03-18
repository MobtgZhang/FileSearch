#include "AgentOrchestrator.h"
#include "AIBridge.h"
#include "ToolExecutor.h"
#include "ContextBuilder.h"
#include "ChatBridge.h"
#include "CacheManager.h"
#include "engine/SearchEngine.h"
#include "AppSettings.h"

#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QVariantMap>
#include <QDateTime>
#include <QtConcurrent>

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

    setBusy(true);

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
        QString memoryContext = m_cacheManager->loadMemorySummary();
        if (!memoryContext.isEmpty()) {
            QJsonObject memMsg;
            memMsg["role"] = "system";
            memMsg["content"] = "以下是你的长期记忆摘要:\n" + memoryContext;
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
    fullPrompt += "你是一个文件管理 Agent，遵循 ReAct（Reason+Act）范式工作。\n";
    fullPrompt += "每一步你需要：\n";
    fullPrompt += "1. 思考（Thought）：分析用户需求和当前状态\n";
    fullPrompt += "2. 行动（Action）：调用合适的工具执行操作\n";
    fullPrompt += "3. 观察（Observation）：根据工具返回结果生成回复\n\n";
    fullPrompt += "可用工具：\n";

    if (m_toolExecutor) {
        QJsonArray tools = buildToolDefinitions();
        for (const auto &t : tools) {
            QJsonObject fn = t.toObject()["function"].toObject();
            fullPrompt += "- " + fn["name"].toString() + ": " + fn["description"].toString() + "\n";
        }
    }

    if (!context.isEmpty())
        fullPrompt += "\n当前文件系统上下文:\n" + context;

    fullPrompt += "\n回复时请使用中文。当需要执行文件操作（如删除）时，先通过 dry_run 预览，并等待用户确认后再实际执行。";

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
        addTool("search_files", "按条件搜索文件", params);
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
        props["command"] = QJsonObject{{"type", "string"}, {"description", "要执行的 shell 命令"}};
        props["timeoutMs"] = QJsonObject{{"type", "integer"}, {"description", "超时毫秒数"}, {"default", 30000}};
        params["properties"] = props;
        params["required"] = QJsonArray{"command"};
        addTool("shell", "在本地执行 shell 命令", params);
    }

    {
        QJsonObject params;
        params["type"] = "object";
        QJsonObject props;
        props["query"] = QJsonObject{{"type", "string"}, {"description", "搜索关键词"}};
        params["properties"] = props;
        params["required"] = QJsonArray{"query"};
        addTool("web_search", "在网页上搜索信息", params);
    }

    return tools;
}

void AgentOrchestrator::sendToLLM(const QJsonArray &messages)
{
    if (!m_aiBridge) {
        emitAIResponse("AI 服务未就绪，请检查设置。");
        setBusy(false);
        return;
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

    if (finishReason == "tool_calls" || message.contains("tool_calls")) {
        m_conversationHistory.append(message);

        QJsonArray toolCalls = message["tool_calls"].toArray();
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

    QString content = message["content"].toString();
    if (content.isEmpty())
        content = "抱歉，我无法生成回复，请重试。";

    QJsonObject assistantMsg;
    assistantMsg["role"] = "assistant";
    assistantMsg["content"] = content;
    m_conversationHistory.append(assistantMsg);

    emitAIResponse(content);

    if (m_cacheManager) {
        m_cacheManager->appendHistory("assistant", content);
        m_cacheManager->updateMemory(m_conversationHistory);
    }

    setBusy(false);
}

void AgentOrchestrator::executeToolCall(const QString &toolName, const QJsonObject &arguments, const QString &toolCallId)
{
    emitToolStatus(toolName, "running", "执行中...");

    QVariantMap params = arguments.toVariantMap();
    QVariant result;

    if (m_toolExecutor)
        result = m_toolExecutor->execute(toolName, params);
    else
        result = QVariantMap{{"error", "ToolExecutor 未初始化"}};

    QString resultJson = QString::fromUtf8(
        QJsonDocument::fromVariant(result).toJson(QJsonDocument::Compact));

    QJsonObject toolMsg;
    toolMsg["role"] = "tool";
    toolMsg["tool_call_id"] = toolCallId;
    toolMsg["content"] = resultJson;
    m_conversationHistory.append(toolMsg);

    QVariantMap resultMap = result.toMap();
    QString detail;
    if (resultMap.contains("error"))
        detail = "失败: " + resultMap["error"].toString();
    else if (resultMap.contains("count"))
        detail = "完成 (" + QString::number(resultMap["count"].toInt()) + " 结果)";
    else if (resultMap.contains("success"))
        detail = resultMap["success"].toBool() ? "完成" : "失败";
    else
        detail = "完成";

    emitToolStatus(toolName, "done", detail);

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
    if (m_chatBridge)
        m_chatBridge->receiveAiMessage(text);
}

void AgentOrchestrator::emitToolStatus(const QString &name, const QString &status, const QString &detail)
{
    if (m_chatBridge)
        m_chatBridge->addToolExecution(name, status, detail);
}
