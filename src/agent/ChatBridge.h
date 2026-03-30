#ifndef CHATBRIDGE_H
#define CHATBRIDGE_H

#include <QObject>

class ChatBridge : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool aiThinking READ aiThinking NOTIFY aiThinkingChanged)

public:
    explicit ChatBridge(QObject *parent = nullptr);

    bool aiThinking() const { return m_aiThinking; }

public slots:
    void addUserMessage(const QString &text);
    void addAiMessage(const QString &text);
    void addToolExecution(const QString &name, const QString &status, const QString &result);

    void receiveAiMessage(const QString &text);
    void receiveStreamChunk(const QString &chunk);
    void receiveStreamStart();
    void receiveReasoningChunk(const QString &chunk);
    void receiveThinkingChunk(const QString &text);
    void receiveThinkingClear();
    void notifyStreamComplete(const QString &text);
    void receiveToolStatus(const QString &name, const QString &status, const QString &detail);
    /** 在聊天区展示工具返回（Markdown），callId 用于 Web 端分片重组 */
    void receiveToolOutput(const QString &toolName, const QString &callId, const QString &markdown);
    void receiveError(const QString &error);

    void setAiThinking(bool thinking);
    void clearMessages();
    void setContextInfo(const QString &info);
    void setModelName(const QString &model);

signals:
    void userMessageAdded(const QString &text);
    void aiMessageAdded(const QString &text);
    void toolExecutionAdded(const QString &name, const QString &status, const QString &result);

    void pushAiMessage(const QString &text);
    void pushStreamChunk(const QString &chunk);
    void pushStreamStart();
    /** 流结束后用 C++ 侧完整正文覆盖 Web 端（避免 WebChannel 流式丢包导致截断） */
    void pushStreamBodyResync(const QString &chunk, bool isFirst, bool isLast);
    void pushStreamFinished();
    void pushReasoningChunk(const QString &chunk);
    void pushThinkingChunk(const QString &text);
    void pushThinkingClear();
    void pushToolStatus(const QString &name, const QString &status, const QString &detail);
    void pushToolOutput(const QString &toolName, const QString &callId, const QString &chunk, bool isFirst,
                        bool isLast);
    void pushError(const QString &error);
    void pushClear();
    void pushContextInfo(const QString &info);
    void pushModelName(const QString &model);
    void aiThinkingChanged();

private:
    bool m_aiThinking = false;
};

#endif // CHATBRIDGE_H
