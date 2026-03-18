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
    void receiveToolStatus(const QString &name, const QString &status, const QString &detail);
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
    void pushToolStatus(const QString &name, const QString &status, const QString &detail);
    void pushError(const QString &error);
    void pushClear();
    void pushContextInfo(const QString &info);
    void pushModelName(const QString &model);
    void aiThinkingChanged();

private:
    bool m_aiThinking = false;
};

#endif // CHATBRIDGE_H
