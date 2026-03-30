#include "AIBridge.h"
#include "AppSettings.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QNetworkProxy>
#include <QNetworkRequest>
#include <QUrl>
#include <QtGlobal>
#include <algorithm>

AIBridge::AIBridge(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
}

void AIBridge::setAppSettings(AppSettings *settings)
{
    m_appSettings = settings;
    setupProxy();
}

void AIBridge::setupProxy()
{
    if (!m_appSettings || !m_nam)
        return;

    if (m_appSettings->proxyMode() == QStringLiteral("manual") && !m_appSettings->proxyUrl().isEmpty()) {
        QUrl proxyUrl(m_appSettings->proxyUrl());
        if (!proxyUrl.scheme().isEmpty()) {
            m_nam->setProxy(QNetworkProxy(QNetworkProxy::HttpProxy, proxyUrl.host(), proxyUrl.port(8080),
                                          proxyUrl.userName(), proxyUrl.password()));
        } else {
            QString manual = m_appSettings->proxyUrl().trimmed();
            int colon = manual.indexOf(':');
            QString host = colon > 0 ? manual.left(colon) : manual;
            int port = colon > 0 ? manual.mid(colon + 1).toInt() : 8080;
            m_nam->setProxy(QNetworkProxy(QNetworkProxy::HttpProxy, host, port));
        }
    } else {
        m_nam->setProxy(QNetworkProxy::applicationProxy());
    }
}

QString AIBridge::authorizationHeader() const
{
    QString key = m_appSettings ? m_appSettings->apiKey() : QString();
    if (key.isEmpty())
        key = qEnvironmentVariable("OPENAI_API_KEY");
    if (key.isEmpty())
        key = qEnvironmentVariable("API_KEY");
    if (key.isEmpty())
        return QString();
    return QStringLiteral("Bearer ") + key;
}

void AIBridge::abortActiveRequest()
{
    if (m_activeReply) {
        m_activeReply->disconnect(this);
        m_activeReply->abort();
        m_activeReply->deleteLater();
        m_activeReply = nullptr;
    }
    m_fullReplyBody.clear();
    m_sseBuffer.clear();
    m_streamedContent.clear();
    m_finishReason.clear();
    m_partialTools.clear();
    m_responseEmitted = false;
    m_lastStreamForContent = false;
}

void AIBridge::sendChatRequest(const QJsonArray &messages, const QJsonArray &tools)
{
    if (!m_appSettings) {
        emit chatErrorOccurred(QStringLiteral("AppSettings 未设置"));
        return;
    }

    const QString auth = authorizationHeader();
    if (auth.isEmpty()) {
        emit chatErrorOccurred(QStringLiteral("未配置 API Key：请在设置中填写或设置环境变量 OPENAI_API_KEY"));
        return;
    }

    abortActiveRequest();

    QString baseUrl = m_appSettings->apiBaseUrl();
    if (baseUrl.isEmpty())
        baseUrl = QStringLiteral("https://api.openai.com/v1");
    if (baseUrl.endsWith('/'))
        baseUrl.chop(1);

    QString endpoint = baseUrl + QStringLiteral("/chat/completions");

    QJsonObject body;
    body[QStringLiteral("model")] = m_appSettings->apiModel();
    body[QStringLiteral("messages")] = messages;
    body[QStringLiteral("temperature")] = m_appSettings->modelTemperature();
    const int cap = qBound(1, m_appSettings->maxTokens(), 65535);
    body[QStringLiteral("max_tokens")] = cap;
    body[QStringLiteral("stream")] = true;

    if (m_appSettings->topP() < 1.0)
        body[QStringLiteral("top_p")] = m_appSettings->topP();

    if (!tools.isEmpty()) {
        body[QStringLiteral("tools")] = tools;
        body[QStringLiteral("tool_choice")] = QStringLiteral("auto");
    }

    QNetworkRequest request;
    request.setUrl(QUrl(endpoint));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setRawHeader("Authorization", auth.toUtf8());
    request.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    request.setTransferTimeout(120000);

    QByteArray payload = QJsonDocument(body).toJson(QJsonDocument::Compact);
    m_activeReply = m_nam->post(request, payload);

    connect(m_activeReply, &QNetworkReply::readyRead, this, &AIBridge::onStreamReadyRead);
    connect(m_activeReply, &QNetworkReply::finished, this, &AIBridge::onStreamFinished);
    connect(m_activeReply, &QNetworkReply::errorOccurred, this, &AIBridge::onStreamError);
}

void AIBridge::onStreamReadyRead()
{
    auto *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply)
        return;
    QByteArray chunk = reply->readAll();
    m_fullReplyBody += chunk;
    m_sseBuffer += chunk;
    processSseBuffer();
}

bool AIBridge::processOneSseEventBlock(const QByteArray &eventBlock)
{
    if (eventBlock.isEmpty())
        return false;

    QByteArray dataPayload;
    int start = 0;
    while (start < eventBlock.size()) {
        int nl = eventBlock.indexOf('\n', start);
        QByteArray line = (nl < 0 ? eventBlock.mid(start) : eventBlock.mid(start, nl - start)).trimmed();
        start = nl < 0 ? eventBlock.size() : nl + 1;

        if (line.startsWith(':'))
            continue;
        if (!line.startsWith("data:"))
            continue;
        QByteArray piece = line.mid(5).trimmed();
        if (!dataPayload.isEmpty())
            dataPayload += '\n';
        dataPayload += piece;
    }

    if (dataPayload.isEmpty())
        return false;

    if (dataPayload == "[DONE]") {
        finalizeStreamAssembledResponse();
        return true;
    }

    if (dataPayload.startsWith("\xEF\xBB\xBF"))
        dataPayload = dataPayload.mid(3);

    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(dataPayload, &err);
    if (doc.isObject()) {
        handleSseEventObject(doc.object());
        return false;
    }

    qWarning() << "AIBridge: SSE JSON 解析失败:" << err.errorString() << "offset" << err.offset
               << "payload 字节:" << dataPayload.size();
    return false;
}

void AIBridge::handleSseEventObject(const QJsonObject &obj)
{
    QJsonArray choices = obj[QStringLiteral("choices")].toArray();
    if (choices.isEmpty())
        return;
    QJsonObject c0 = choices[0].toObject();
    if (c0.contains(QStringLiteral("finish_reason"))) {
        QString fr = c0[QStringLiteral("finish_reason")].toString();
        if (!fr.isEmpty())
            m_finishReason = fr;
    }

    QJsonObject delta = c0[QStringLiteral("delta")].toObject();
    if (delta.contains(QStringLiteral("content"))) {
        QString piece;
        const QJsonValue cv = delta[QStringLiteral("content")];
        if (cv.isString()) {
            piece = cv.toString();
        } else if (cv.isArray()) {
            for (const QJsonValue &v : cv.toArray()) {
                if (v.isString())
                    piece += v.toString();
                else if (v.isObject()) {
                    const QJsonObject o = v.toObject();
                    if (o[QStringLiteral("type")].toString() == QStringLiteral("text"))
                        piece += o[QStringLiteral("text")].toString();
                }
            }
        }
        if (!piece.isEmpty()) {
            m_streamedContent += piece;
            emit streamContentDelta(piece);
        }
    }

    const QStringList reasoningKeys{QStringLiteral("reasoning_content"), QStringLiteral("reasoning"),
                                      QStringLiteral("thinking")};
    for (const QString &k : reasoningKeys) {
        if (delta.contains(k)) {
            QString r = delta[k].toString();
            if (!r.isEmpty())
                emit streamReasoningDelta(r);
        }
    }

    if (delta.contains(QStringLiteral("tool_calls"))) {
        QJsonArray tcs = delta[QStringLiteral("tool_calls")].toArray();
        for (const QJsonValue &v : tcs) {
            QJsonObject tc = v.toObject();
            int idx = tc[QStringLiteral("index")].toInt(-1);
            if (idx < 0) {
                idx = 0;
                while (m_partialTools.contains(idx))
                    ++idx;
            }
            PartialToolCall &p = m_partialTools[idx];
            if (tc.contains(QStringLiteral("id")))
                p.id = tc[QStringLiteral("id")].toString();
            if (tc.contains(QStringLiteral("type")))
                p.type = tc[QStringLiteral("type")].toString();
            QJsonObject fn = tc[QStringLiteral("function")].toObject();
            if (fn.contains(QStringLiteral("name")))
                p.name = fn[QStringLiteral("name")].toString();
            if (fn.contains(QStringLiteral("arguments")))
                p.arguments += fn[QStringLiteral("arguments")].toString();
        }
    }
}

void AIBridge::processSseBuffer()
{
    m_sseBuffer.replace("\r\n", "\n");
    while (true) {
        int sep = m_sseBuffer.indexOf("\n\n");
        if (sep < 0)
            break;

        QByteArray eventBlock = m_sseBuffer.left(sep).trimmed();
        m_sseBuffer = m_sseBuffer.mid(sep + 2);

        if (processOneSseEventBlock(eventBlock)) {
            m_sseBuffer.clear();
            return;
        }
    }
}

void AIBridge::tryEmitBulkJsonResponse(const QByteArray &data)
{
    QByteArray trimmed = data.trimmed();
    if (!trimmed.startsWith('{'))
        return;
    QJsonDocument doc = QJsonDocument::fromJson(trimmed);
    if (!doc.isObject())
        return;
    QJsonObject o = doc.object();
    if (!o.contains(QStringLiteral("choices")))
        return;
    m_lastStreamForContent = false;
    m_responseEmitted = true;
    emit chatResponseReceived(o);
}

void AIBridge::finalizeStreamAssembledResponse()
{
    if (m_responseEmitted)
        return;
    m_responseEmitted = true;

    QJsonObject message;
    message[QStringLiteral("role")] = QStringLiteral("assistant");
    message[QStringLiteral("content")] = m_streamedContent;

    QJsonArray toolCalls;
    const QList<int> idxKeys = m_partialTools.keys();
    QList<int> sorted = idxKeys;
    std::sort(sorted.begin(), sorted.end());
    for (int idx : sorted) {
        const PartialToolCall &p = m_partialTools[idx];
        if (p.id.isEmpty() && p.name.isEmpty() && p.arguments.trimmed().isEmpty())
            continue;
        QJsonObject fn;
        fn[QStringLiteral("name")] = p.name;
        fn[QStringLiteral("arguments")] = p.arguments.isEmpty() ? QStringLiteral("{}") : p.arguments;
        QJsonObject tc;
        tc[QStringLiteral("id")] = p.id;
        tc[QStringLiteral("type")] = p.type.isEmpty() ? QStringLiteral("function") : p.type;
        tc[QStringLiteral("function")] = fn;
        toolCalls.append(tc);
    }

    const bool hasTools = !toolCalls.isEmpty();
    if (hasTools)
        message[QStringLiteral("tool_calls")] = toolCalls;

    QString finish = m_finishReason;
    if (finish.isEmpty())
        finish = hasTools ? QStringLiteral("tool_calls") : QStringLiteral("stop");

    QJsonObject choice;
    choice[QStringLiteral("message")] = message;
    choice[QStringLiteral("finish_reason")] = finish;

    QJsonObject response;
    response[QStringLiteral("choices")] = QJsonArray{choice};

    m_lastStreamForContent = !hasTools && !m_streamedContent.isEmpty();
    emit chatResponseReceived(response);
}

void AIBridge::onStreamFinished()
{
    auto *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply)
        return;

    if (reply->error() != QNetworkReply::NoError && !m_responseEmitted) {
        QString err = reply->errorString();
        const QByteArray errBody = reply->readAll();
        QJsonDocument edoc = QJsonDocument::fromJson(errBody);
        if (edoc.isObject()) {
            QJsonObject eo = edoc.object();
            if (eo.contains(QStringLiteral("error"))) {
                QJsonObject e = eo[QStringLiteral("error")].toObject();
                const QString apiMsg = e[QStringLiteral("message")].toString();
                const QString apiCode = e[QStringLiteral("code")].toString();
                if (!apiMsg.isEmpty()) {
                    err = apiMsg;
                    if (!apiCode.isEmpty())
                        err = apiCode + QStringLiteral(": ") + err;
                }
            }
        } else if (!errBody.trimmed().isEmpty()) {
            err += QStringLiteral(" — ") + QString::fromUtf8(errBody.left(500));
        }
        emit chatErrorOccurred(err);
        m_responseEmitted = true;
        reply->deleteLater();
        if (m_activeReply == reply)
            m_activeReply = nullptr;
        return;
    }

    QByteArray rest = reply->readAll();
    m_fullReplyBody += rest;
    m_sseBuffer += rest;
    processSseBuffer();

    if (!m_responseEmitted) {
        m_sseBuffer.replace("\r\n", "\n");
        const QByteArray tail = m_sseBuffer.trimmed();
        if (!tail.isEmpty()) {
            m_sseBuffer.clear();
            processOneSseEventBlock(tail);
        }
    }

    if (!m_responseEmitted)
        tryEmitBulkJsonResponse(m_fullReplyBody);
    if (!m_responseEmitted)
        finalizeStreamAssembledResponse();

    reply->deleteLater();
    if (m_activeReply == reply)
        m_activeReply = nullptr;
}

void AIBridge::onStreamError(QNetworkReply::NetworkError code)
{
    Q_UNUSED(code);
    auto *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply)
        return;
    if (m_responseEmitted) {
        reply->deleteLater();
        return;
    }
    QString err = reply->errorString();
    QByteArray body = reply->readAll();
    reply->deleteLater();
    if (m_activeReply == reply)
        m_activeReply = nullptr;

    QJsonDocument doc = QJsonDocument::fromJson(body);
    if (doc.isObject()) {
        QJsonObject o = doc.object();
        if (o.contains(QStringLiteral("error"))) {
            QJsonObject e = o[QStringLiteral("error")].toObject();
            QString msg = e[QStringLiteral("message")].toString();
            if (!msg.isEmpty())
                err = msg;
        }
    }
    emit chatErrorOccurred(err);
    m_responseEmitted = true;
}

void AIBridge::sendMessage(const QString &text)
{
    Q_UNUSED(text);
    emit responseReceived(QString());
}

void AIBridge::setContext(const QString &context)
{
    m_context = context;
}
