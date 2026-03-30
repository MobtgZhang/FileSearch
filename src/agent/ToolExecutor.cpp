#include "ToolExecutor.h"
#include "AgentSandbox.h"
#include "tools/SearchFilesTool.h"
#include "tools/DeleteFilesTool.h"
#include "tools/MoveFilesTool.h"
#include "tools/ShellTool.h"
#include "tools/ReadFileTool.h"
#include "tools/WriteFileTool.h"
#include "tools/WebFetchTool.h"
#include "engine/SearchEngine.h"
#include "service/FileOperationService.h"
#include "AppSettings.h"

#include <QJsonDocument>

ToolExecutor::ToolExecutor(QObject *parent)
    : QObject(parent)
{
}

void ToolExecutor::setSearchEngine(SearchEngine *engine)
{
    m_searchEngine = engine;
    rebuildTools();
}

void ToolExecutor::setFileOperationService(FileOperationService *service)
{
    m_fileOperationService = service;
    rebuildTools();
}

void ToolExecutor::setAppSettings(AppSettings *settings)
{
    m_appSettings = settings;
    rebuildTools();
}

void ToolExecutor::setAgentSandbox(AgentSandbox *sandbox)
{
    m_sandbox = sandbox;
}

bool ToolExecutor::toolNeedsDestructiveConfirm(const QString &toolName, const QVariantMap &params)
{
    if (toolName == QStringLiteral("delete_files"))
        return !params.value(QStringLiteral("dryRun"), true).toBool();
    if (toolName == QStringLiteral("shell"))
        return true;
    if (toolName == QStringLiteral("write_file"))
        return true;
    if (toolName == QStringLiteral("move_files"))
        return true;
    return false;
}

QString ToolExecutor::toolConsentDetail(const QString &toolName, const QVariantMap &params)
{
    const QString json = QString::fromUtf8(QJsonDocument::fromVariant(QVariant(params)).toJson(QJsonDocument::Indented));
    return QStringLiteral("**工具** `%1`\n\n**参数预览**\n```json\n%2\n```")
        .arg(toolName, json.left(8000));
}


void ToolExecutor::rebuildTools()
{
    m_tools.clear();
    if (m_searchEngine)
        m_tools.push_back(std::make_unique<SearchFilesTool>(m_searchEngine));
    m_tools.push_back(std::make_unique<ReadFileTool>());
    m_tools.push_back(std::make_unique<WriteFileTool>());
    if (m_fileOperationService) {
        m_tools.push_back(std::make_unique<DeleteFilesTool>(m_fileOperationService));
        m_tools.push_back(std::make_unique<MoveFilesTool>(m_fileOperationService));
    }
    m_tools.push_back(std::make_unique<ShellTool>());
    if (m_appSettings)
        m_tools.push_back(std::make_unique<WebFetchTool>(m_appSettings));
}

IAgentTool *ToolExecutor::toolForName(const QString &name) const
{
    for (const auto &t : m_tools) {
        if (t && t->name() == name)
            return t.get();
    }
    return nullptr;
}

QVariant ToolExecutor::execute(const QString &toolName, const QVariantMap &params)
{
    emit toolStarted(toolName);
    if (m_sandbox && toolNeedsDestructiveConfirm(toolName, params)) {
        const QString title = QStringLiteral("Agent 沙箱 · 确认执行");
        if (!m_sandbox->waitForDestructiveConfirm(title, toolConsentDetail(toolName, params))) {
            QVariantMap denied{{QStringLiteral("error"), QStringLiteral("用户未在沙箱对话框中确认，已取消")},
                               {QStringLiteral("cancelled"), true}};
            emit toolFinished(toolName, denied);
            return denied;
        }
    }
    IAgentTool *tool = toolForName(toolName);
    QVariant result;
    if (tool) {
        result = tool->execute(params);
    } else {
        result = QVariantMap{{"error", "未知工具: " + toolName}};
    }
    emit toolFinished(toolName, result);
    return result;
}

QStringList ToolExecutor::registeredToolNames() const
{
    QStringList names;
    for (const auto &t : m_tools) {
        if (t)
            names << t->name();
    }
    return names;
}
