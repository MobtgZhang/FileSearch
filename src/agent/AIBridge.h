#ifndef AIBRIDGE_H
#define AIBRIDGE_H

#include <QObject>
#include <QJsonArray>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>

class AppSettings;

class AIBridge : public QObject
{
    Q_OBJECT

public:
    explicit AIBridge(QObject *parent = nullptr);

    void setAppSettings(AppSettings *settings);

    void sendChatRequest(const QJsonArray &messages, const QJsonArray &tools);

    Q_INVOKABLE void sendMessage(const QString &text);
    Q_INVOKABLE void setContext(const QString &context);

signals:
    void chatResponseReceived(const QJsonObject &response);
    void chatErrorOccurred(const QString &error);
    void responseReceived(const QString &text);
    void errorOccurred(const QString &message);
    void streamChunkReceived(const QString &chunk);

private slots:
    void onReplyFinished(QNetworkReply *reply);

private:
    void setupProxy();

    AppSettings *m_appSettings = nullptr;
    QNetworkAccessManager *m_nam = nullptr;
    QString m_context;
};

#endif // AIBRIDGE_H
