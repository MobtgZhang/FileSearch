#ifndef AIBRIDGE_H
#define AIBRIDGE_H

#include <QMap>
#include <QObject>
#include <QJsonArray>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QString>

class AppSettings;

class AIBridge : public QObject
{
    Q_OBJECT

public:
    explicit AIBridge(QObject *parent = nullptr);

    void setAppSettings(AppSettings *settings);

    void sendChatRequest(const QJsonArray &messages, const QJsonArray &tools);

    bool lastCompletionWasStreamed() const { return m_lastStreamForContent; }

    Q_INVOKABLE void sendMessage(const QString &text);
    Q_INVOKABLE void setContext(const QString &context);

signals:
    void chatResponseReceived(const QJsonObject &response);
    void chatErrorOccurred(const QString &error);
    void responseReceived(const QString &text);
    void errorOccurred(const QString &message);

    void streamContentDelta(const QString &chunk);
    void streamReasoningDelta(const QString &chunk);

private slots:
    void onStreamReadyRead();
    void onStreamFinished();
    void onStreamError(QNetworkReply::NetworkError code);

private:
    struct PartialToolCall {
        QString id;
        QString type;
        QString name;
        QString arguments;
    };

    void setupProxy();
    void abortActiveRequest();
    void processSseBuffer();
    /** @return true 表示已收到 [DONE]，应停止继续解析缓冲区 */
    bool processOneSseEventBlock(const QByteArray &eventBlock);
    void handleSseEventObject(const QJsonObject &obj);
    void finalizeStreamAssembledResponse();
    void tryEmitBulkJsonResponse(const QByteArray &data);

    QString authorizationHeader() const;

    AppSettings *m_appSettings = nullptr;
    QNetworkAccessManager *m_nam = nullptr;
    QString m_context;

    QNetworkReply *m_activeReply = nullptr;
    QByteArray m_fullReplyBody;
    QByteArray m_sseBuffer;
    QString m_streamedContent;
    QString m_finishReason;
    QMap<int, PartialToolCall> m_partialTools;
    bool m_responseEmitted = false;
    bool m_lastStreamForContent = false;
};

#endif // AIBRIDGE_H
