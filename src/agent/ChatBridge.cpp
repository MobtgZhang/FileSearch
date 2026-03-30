#include "ChatBridge.h"

namespace {
// Qt WebChannel 单次传递过长 QString 可能被截断，大块内容拆成多段信号
constexpr int kMaxWebChannelPayloadChars = 4000;

void emitChunked(ChatBridge *bridge, void (ChatBridge::*signal)(const QString &), const QString &text)
{
    if (text.size() <= kMaxWebChannelPayloadChars) {
        emit (bridge->*signal)(text);
        return;
    }
    for (int i = 0; i < text.size(); i += kMaxWebChannelPayloadChars)
        emit (bridge->*signal)(text.mid(i, kMaxWebChannelPayloadChars));
}

void emitStreamBodyResync(ChatBridge *bridge, const QString &text)
{
    if (text.isEmpty()) {
        emit bridge->pushStreamBodyResync(QString(), true, true);
        return;
    }
    if (text.size() <= kMaxWebChannelPayloadChars) {
        emit bridge->pushStreamBodyResync(text, true, true);
        return;
    }
    for (int i = 0; i < text.size(); i += kMaxWebChannelPayloadChars) {
        const bool first = (i == 0);
        const bool last = (i + kMaxWebChannelPayloadChars >= text.size());
        emit bridge->pushStreamBodyResync(text.mid(i, kMaxWebChannelPayloadChars), first, last);
    }
}
} // namespace

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
    if (text.size() <= kMaxWebChannelPayloadChars) {
        emit pushAiMessage(text);
    } else {
        emit pushStreamStart();
        emitChunked(this, &ChatBridge::pushStreamChunk, text);
        emitStreamBodyResync(this, text);
        emit pushStreamFinished();
    }
    emit aiMessageAdded(text);
}

void ChatBridge::receiveStreamChunk(const QString &chunk)
{
    emitChunked(this, &ChatBridge::pushStreamChunk, chunk);
}

void ChatBridge::receiveStreamStart()
{
    emit pushStreamStart();
}

void ChatBridge::receiveReasoningChunk(const QString &chunk)
{
    emitChunked(this, &ChatBridge::pushReasoningChunk, chunk);
}

void ChatBridge::receiveThinkingChunk(const QString &text)
{
    emitChunked(this, &ChatBridge::pushThinkingChunk, text);
}

void ChatBridge::receiveThinkingClear()
{
    emit pushThinkingClear();
}

void ChatBridge::notifyStreamComplete(const QString &text)
{
    setAiThinking(false);
    emitStreamBodyResync(this, text);
    emit pushStreamFinished();
    emit aiMessageAdded(text);
}

void ChatBridge::receiveToolStatus(const QString &name, const QString &status, const QString &detail)
{
    emit pushToolStatus(name, status, detail);
    emit toolExecutionAdded(name, status, detail);
}

void ChatBridge::receiveToolOutput(const QString &toolName, const QString &callId, const QString &markdown)
{
    if (markdown.isEmpty()) {
        emit pushToolOutput(toolName, callId, QString(), true, true);
        return;
    }
    for (int i = 0; i < markdown.size(); i += kMaxWebChannelPayloadChars) {
        const bool first = (i == 0);
        const bool last = (i + kMaxWebChannelPayloadChars >= markdown.size());
        emit pushToolOutput(toolName, callId, markdown.mid(i, kMaxWebChannelPayloadChars), first, last);
    }
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
