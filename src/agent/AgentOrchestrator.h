#ifndef AGENTORCHESTRATOR_H
#define AGENTORCHESTRATOR_H

#include <QObject>
#include <QJsonArray>
#include <QJsonObject>

class AIBridge;
class ToolExecutor;
class ContextBuilder;
class ChatBridge;
class CacheManager;
class SearchEngine;
class AppSettings;

class AgentOrchestrator : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit AgentOrchestrator(QObject *parent = nullptr);

    void setAIBridge(AIBridge *bridge);
    void setToolExecutor(ToolExecutor *executor);
    void setContextBuilder(ContextBuilder *builder);
    void setChatBridge(ChatBridge *chat);
    void setCacheManager(CacheManager *cache);
    void setSearchEngine(SearchEngine *engine);
    void setAppSettings(AppSettings *settings);

    bool busy() const { return m_busy; }

public slots:
    void handleUserMessage(const QString &text);
    void handleLLMResponse(const QJsonObject &response);

signals:
    void busyChanged();

private:
    void processAgentLoop(const QString &userText);
    QJsonArray buildToolDefinitions() const;
    QJsonObject buildSystemMessage() const;
    void sendToLLM(const QJsonArray &messages);
    void executeToolCall(const QString &toolName, const QJsonObject &arguments, const QString &toolCallId);
    void emitAIResponse(const QString &text);
    void emitToolStatus(const QString &name, const QString &status, const QString &detail);
    void setBusy(bool busy);

    AIBridge *m_aiBridge = nullptr;
    ToolExecutor *m_toolExecutor = nullptr;
    ContextBuilder *m_contextBuilder = nullptr;
    ChatBridge *m_chatBridge = nullptr;
    CacheManager *m_cacheManager = nullptr;
    SearchEngine *m_searchEngine = nullptr;
    AppSettings *m_appSettings = nullptr;

    QJsonArray m_conversationHistory;
    bool m_busy = false;
    int m_maxToolRounds = 5;
};

#endif // AGENTORCHESTRATOR_H
