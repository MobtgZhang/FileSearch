#ifndef TOOLEXECUTOR_H
#define TOOLEXECUTOR_H

#include <QObject>
#include <QVariantMap>
#include <memory>
#include <vector>

#include "tools/IAgentTool.h"

class SearchEngine;
class FileOperationService;
class AppSettings;
class AgentSandbox;

class ToolExecutor : public QObject
{
    Q_OBJECT

public:
    explicit ToolExecutor(QObject *parent = nullptr);

    void setSearchEngine(SearchEngine *engine);
    void setFileOperationService(FileOperationService *service);
    void setAppSettings(AppSettings *settings);
    void setAgentSandbox(AgentSandbox *sandbox);

    Q_INVOKABLE QVariant execute(const QString &toolName, const QVariantMap &params);

    /** 获取已注册工具名称列表，供 LLM Function Calling 使用 */
    Q_INVOKABLE QStringList registeredToolNames() const;

signals:
    void toolStarted(const QString &name);
    void toolFinished(const QString &name, const QVariant &result);

private:
    void rebuildTools();
    IAgentTool *toolForName(const QString &name) const;
    static bool toolNeedsDestructiveConfirm(const QString &toolName, const QVariantMap &params);
    static QString toolConsentDetail(const QString &toolName, const QVariantMap &params);

    SearchEngine *m_searchEngine = nullptr;
    FileOperationService *m_fileOperationService = nullptr;
    AppSettings *m_appSettings = nullptr;
    AgentSandbox *m_sandbox = nullptr;
    std::vector<std::unique_ptr<IAgentTool>> m_tools;
};

#endif // TOOLEXECUTOR_H
