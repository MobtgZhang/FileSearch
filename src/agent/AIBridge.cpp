#include "AIBridge.h"
#include "AppSettings.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkRequest>
#include <QNetworkProxy>
#include <QUrl>
#include <QSslConfiguration>

AIBridge::AIBridge(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
    connect(m_nam, &QNetworkAccessManager::finished, this, &AIBridge::onReplyFinished);
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

    if (m_appSettings->proxyMode() == "manual" && !m_appSettings->proxyUrl().isEmpty()) {
        QUrl proxyUrl(m_appSettings->proxyUrl());
        if (!proxyUrl.scheme().isEmpty()) {
            m_nam->setProxy(QNetworkProxy(QNetworkProxy::HttpProxy,
                proxyUrl.host(), proxyUrl.port(8080),
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

void AIBridge::sendChatRequest(const QJsonArray &messages, const QJsonArray &tools)
{
    if (!m_appSettings) {
        emit chatErrorOccurred("AppSettings 未设置");
        return;
    }

    QString baseUrl = m_appSettings->apiBaseUrl();
    if (baseUrl.isEmpty())
        baseUrl = "https://api.openai.com/v1";
    if (baseUrl.endsWith('/'))
        baseUrl.chop(1);

    QString endpoint = baseUrl + "/chat/completions";

    QJsonObject body;
    body["model"] = m_appSettings->apiModel();
    body["messages"] = messages;
    body["temperature"] = m_appSettings->modelTemperature();
    body["max_tokens"] = m_appSettings->maxTokens();

    if (m_appSettings->topP() < 1.0)
        body["top_p"] = m_appSettings->topP();

    if (!tools.isEmpty()) {
        body["tools"] = tools;
        body["tool_choice"] = "auto";
    }

    QNetworkRequest request;
    request.setUrl(QUrl(endpoint));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    QString apiKey = qEnvironmentVariable("OPENAI_API_KEY");
    if (apiKey.isEmpty())
        apiKey = qEnvironmentVariable("API_KEY");
    if (!apiKey.isEmpty())
        request.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());

    request.setTransferTimeout(120000);

    QByteArray payload = QJsonDocument(body).toJson(QJsonDocument::Compact);
    m_nam->post(request, payload);
}

void AIBridge::onReplyFinished(QNetworkReply *reply)
{
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        QString errorMsg = reply->errorString();
        QByteArray responseData = reply->readAll();
        if (!responseData.isEmpty()) {
            QJsonObject errObj = QJsonDocument::fromJson(responseData).object();
            if (errObj.contains("error")) {
                QJsonObject e = errObj["error"].toObject();
                errorMsg = e["message"].toString();
                if (errorMsg.isEmpty())
                    errorMsg = reply->errorString();
            }
        }
        emit chatErrorOccurred(errorMsg);
        return;
    }

    QByteArray data = reply->readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (doc.isNull()) {
        emit chatErrorOccurred("无法解析 API 响应");
        return;
    }

    emit chatResponseReceived(doc.object());
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
