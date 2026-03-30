#include "WebFetchTool.h"
#include "AppSettings.h"

#include <QEventLoop>
#include <QNetworkAccessManager>
#include <QNetworkProxy>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QTimer>
#include <QUrl>

WebFetchTool::WebFetchTool(AppSettings *settings)
    : m_settings(settings)
{
}

QString WebFetchTool::name() const
{
    return QStringLiteral("web_fetch");
}

QString WebFetchTool::description() const
{
    return QStringLiteral(
        "通过 HTTP GET 抓取网页正文（非搜索 API）。传入完整 URL，返回去除大部分 HTML 标签后的文本片段，"
        "用于阅读文档页、公开 API 说明等。请遵守目标站点条款。");
}

static void applyProxy(QNetworkAccessManager &nam, AppSettings *settings)
{
    if (!settings)
        return;
    if (settings->proxyMode() == QStringLiteral("manual") && !settings->proxyUrl().isEmpty()) {
        QUrl proxyUrl(settings->proxyUrl());
        if (!proxyUrl.scheme().isEmpty()) {
            nam.setProxy(QNetworkProxy(QNetworkProxy::HttpProxy, proxyUrl.host(), proxyUrl.port(8080),
                                       proxyUrl.userName(), proxyUrl.password()));
        } else {
            QString manual = settings->proxyUrl().trimmed();
            int colon = manual.indexOf(':');
            QString host = colon > 0 ? manual.left(colon) : manual;
            int port = colon > 0 ? manual.mid(colon + 1).toInt() : 8080;
            nam.setProxy(QNetworkProxy(QNetworkProxy::HttpProxy, host, port));
        }
    } else {
        nam.setProxy(QNetworkProxy::applicationProxy());
    }
}

QVariant WebFetchTool::execute(const QVariantMap &params)
{
    QString urlStr = params.value(QStringLiteral("url")).toString().trimmed();
    if (urlStr.isEmpty())
        return QVariantMap{{QStringLiteral("error"), QStringLiteral("url 不能为空")}};

    QUrl url(urlStr);
    if (!url.isValid() || url.scheme().isEmpty())
        return QVariantMap{{QStringLiteral("error"), QStringLiteral("URL 无效")}};
    if (url.scheme() != QStringLiteral("http") && url.scheme() != QStringLiteral("https"))
        return QVariantMap{{QStringLiteral("error"), QStringLiteral("仅支持 http/https")}};

    int maxBytes = params.value(QStringLiteral("max_bytes"), 262144).toInt();
    maxBytes = qBound(4096, maxBytes, 1024 * 1024);

    QNetworkAccessManager nam;
    applyProxy(nam, m_settings);

    QNetworkRequest request(url);
    request.setRawHeader("User-Agent",
                         "Mozilla/5.0 (compatible; NexFile/1.0; +https://example.local) QtWebEngine");
    request.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    request.setTransferTimeout(25000);

    QNetworkReply *reply = nam.get(request);
    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);
    timeout.setInterval(26000);
    QObject::connect(&timeout, &QTimer::timeout, reply, &QNetworkReply::abort);
    QObject::connect(&timeout, &QTimer::timeout, &loop, &QEventLoop::quit);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QObject::connect(reply, &QNetworkReply::finished, &timeout, &QTimer::stop);
    timeout.start();
    loop.exec();
    timeout.stop();

    QVariantMap result;
    result[QStringLiteral("url")] = urlStr;

    if (reply->error() != QNetworkReply::NoError) {
        result[QStringLiteral("error")] = reply->errorString();
        reply->deleteLater();
        return result;
    }

    QByteArray raw = reply->readAll();
    reply->deleteLater();
    if (raw.size() > maxBytes)
        raw.truncate(maxBytes);

    QString html = QString::fromUtf8(raw);
    html.replace(QRegularExpression(QStringLiteral("<script[^>]*>[\\s\\S]*?</script>"), QRegularExpression::CaseInsensitiveOption),
                 QStringLiteral(" "));
    html.replace(QRegularExpression(QStringLiteral("<style[^>]*>[\\s\\S]*?</style>"), QRegularExpression::CaseInsensitiveOption),
                 QStringLiteral(" "));
    html.replace(QRegularExpression(QStringLiteral("<[^>]+>")), QStringLiteral(" "));
    html.replace(QRegularExpression(QStringLiteral("\\s+")), QStringLiteral(" "));
    QString text = html.trimmed();
    if (text.size() > 8000)
        text = text.left(8000) + QStringLiteral("…");

    result[QStringLiteral("text")] = text;
    result[QStringLiteral("raw_bytes")] = raw.size();
    result[QStringLiteral("success")] = true;
    return result;
}
