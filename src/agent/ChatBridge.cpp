#include "ChatBridge.h"

ChatBridge::ChatBridge(QObject *parent)
    : QObject(parent)
{
}

void ChatBridge::addUserMessage(const QString &text)
{
    if (!text.trimmed().isEmpty())
        emit userMessageAdded(text);
}

void ChatBridge::addAiMessage(const QString &text)
{
    emit aiMessageAdded(text);
}

void ChatBridge::addToolExecution(const QString &name, const QString &status, const QString &result)
{
    emit toolExecutionAdded(name, status, result);
}

void ChatBridge::receiveAiMessage(const QString &text)
{
    setAiThinking(false);
    emit pushAiMessage(text);
    emit aiMessageAdded(text);
}

void ChatBridge::receiveStreamChunk(const QString &chunk)
{
    emit pushStreamChunk(chunk);
}

void ChatBridge::receiveToolStatus(const QString &name, const QString &status, const QString &detail)
{
    emit pushToolStatus(name, status, detail);
    emit toolExecutionAdded(name, status, detail);
}

void ChatBridge::receiveError(const QString &error)
{
    setAiThinking(false);
    emit pushError(error);
}

void ChatBridge::setAiThinking(bool thinking)
{
    if (m_aiThinking != thinking) {
        m_aiThinking = thinking;
        emit aiThinkingChanged();
    }
}

void ChatBridge::clearMessages()
{
    emit pushClear();
}

void ChatBridge::setContextInfo(const QString &info)
{
    emit pushContextInfo(info);
}

void ChatBridge::setModelName(const QString &model)
{
    emit pushModelName(model);
}
