#include "AppSettings.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QNetworkAccessManager>
#include <QNetworkProxy>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSaveFile>
#include <QSettings>
#include <QStandardPaths>
#include <QUrl>

namespace {
QStringList defaultModelList()
{
    return QStringList{QStringLiteral("gpt-4o"), QStringLiteral("gpt-4o-mini"), QStringLiteral("gpt-4-turbo"),
                       QStringLiteral("gpt-3.5-turbo")};
}
}

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
    , m_modelTemperature(0.7)
    , m_topK(40)
    , m_topP(0.9)
    , m_maxTokens(65535)
    , m_agentMaxToolRounds(-1)
    , m_agentSandboxConfirmDestructive(true)
{
    m_configDir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    QDir().mkpath(m_configDir);
    loadFromDisk();
}

QString AppSettings::settingsJsonPath() const
{
    return QDir(m_configDir).filePath(QStringLiteral("settings.json"));
}

void AppSettings::loadFromDisk()
{
    const QString path = settingsJsonPath();
    QFile f(path);
    if (f.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
        applyJsonObject(doc.isObject() ? doc.object() : QJsonObject());
        return;
    }
    migrateLegacyQSettingsOnce();
    if (!QFile::exists(path)) {
        applyJsonObject(QJsonObject());
        saveToDisk();
    }
}

void AppSettings::migrateLegacyQSettingsOnce()
{
    const QString path = settingsJsonPath();
    if (QFile::exists(path))
        return;

    QSettings legacy(QStringLiteral("NexFile"), QStringLiteral("FileSearch"));
    if (legacy.allKeys().isEmpty())
        return;

    m_themeMode = legacy.value(QStringLiteral("themeMode"), QStringLiteral("dark")).toString();
    m_language = legacy.value(QStringLiteral("language"), QStringLiteral("zh")).toString();
    m_cacheDir = legacy.value(QStringLiteral("cacheDir"),
                              QDir::homePath() + QStringLiteral("/.cache/NexFile")).toString();
    m_apiBaseUrl = legacy.value(QStringLiteral("apiBaseUrl"), QStringLiteral("https://api.openai.com/v1")).toString();
    m_apiModel = legacy.value(QStringLiteral("apiModel"), QStringLiteral("gpt-4o-mini")).toString();
    m_apiModelList = legacy.value(QStringLiteral("apiModelList")).toStringList();
    if (m_apiModelList.isEmpty())
        m_apiModelList = defaultModelList();
    m_modelTemperature = legacy.value(QStringLiteral("modelTemperature"), 0.7).toDouble();
    m_topK = legacy.value(QStringLiteral("topK"), 40).toInt();
    m_topP = legacy.value(QStringLiteral("topP"), 0.9).toDouble();
    if (legacy.contains(QStringLiteral("maxTokens")))
        m_maxTokens = legacy.value(QStringLiteral("maxTokens"), 65535).toInt();
    else if (legacy.contains(QStringLiteral("maxTokensMax")))
        m_maxTokens = legacy.value(QStringLiteral("maxTokensMax"), 65535).toInt();
    else
        m_maxTokens = 65535;
    m_systemPrompt = legacy.value(QStringLiteral("systemPrompt"),
                                  QStringLiteral("你是 NexFile 的 AI 助手，帮助用户管理文件。")).toString();
    m_proxyMode = legacy.value(QStringLiteral("proxyMode"), QStringLiteral("auto")).toString();
    m_proxyUrl = legacy.value(QStringLiteral("proxyUrl")).toString();
    m_apiKey = legacy.value(QStringLiteral("apiKey")).toString();
    saveToDisk();
}

void AppSettings::applyJsonObject(const QJsonObject &o)
{
    const QString defaultCache = QDir::homePath() + QStringLiteral("/.cache/NexFile");

    m_themeMode = o.value(QStringLiteral("themeMode")).toString(QStringLiteral("dark"));
    m_language = o.value(QStringLiteral("language")).toString(QStringLiteral("zh"));
    m_cacheDir = o.value(QStringLiteral("cacheDir")).toString(defaultCache);
    m_apiBaseUrl = o.value(QStringLiteral("apiBaseUrl")).toString(QStringLiteral("https://api.openai.com/v1"));
    m_apiKey = o.value(QStringLiteral("apiKey")).toString();
    m_apiModel = o.value(QStringLiteral("apiModel")).toString(QStringLiteral("gpt-4o-mini"));

    QJsonArray modelArr = o.value(QStringLiteral("apiModelList")).toArray();
    m_apiModelList.clear();
    for (const QJsonValue &v : modelArr)
        m_apiModelList.append(v.toString());
    if (m_apiModelList.isEmpty())
        m_apiModelList = defaultModelList();

    m_modelTemperature = o.value(QStringLiteral("modelTemperature")).toDouble(0.7);
    m_topK = o.value(QStringLiteral("topK")).toInt(40);
    m_topP = o.value(QStringLiteral("topP")).toDouble(0.9);
    m_maxTokens = o.value(QStringLiteral("maxTokens")).toInt(65535);
    m_agentMaxToolRounds = o.value(QStringLiteral("agentMaxToolRounds")).toInt(-1);
    m_agentSandboxConfirmDestructive = o.value(QStringLiteral("agentSandboxConfirmDestructive")).toBool(true);
    m_systemPrompt = o.value(QStringLiteral("systemPrompt")).toString(
        QStringLiteral("你是 NexFile 的 AI 助手，帮助用户管理文件。"));
    m_proxyMode = o.value(QStringLiteral("proxyMode")).toString(QStringLiteral("auto"));
    m_proxyUrl = o.value(QStringLiteral("proxyUrl")).toString();
}

QJsonObject AppSettings::toJsonObject() const
{
    QJsonObject o;
    o[QStringLiteral("themeMode")] = m_themeMode;
    o[QStringLiteral("language")] = m_language;
    o[QStringLiteral("cacheDir")] = m_cacheDir;
    o[QStringLiteral("apiBaseUrl")] = m_apiBaseUrl;
    o[QStringLiteral("apiKey")] = m_apiKey;
    o[QStringLiteral("apiModel")] = m_apiModel;
    QJsonArray models;
    for (const QString &m : m_apiModelList)
        models.append(m);
    o[QStringLiteral("apiModelList")] = models;
    o[QStringLiteral("modelTemperature")] = m_modelTemperature;
    o[QStringLiteral("topK")] = m_topK;
    o[QStringLiteral("topP")] = m_topP;
    o[QStringLiteral("maxTokens")] = m_maxTokens;
    o[QStringLiteral("agentMaxToolRounds")] = m_agentMaxToolRounds;
    o[QStringLiteral("agentSandboxConfirmDestructive")] = m_agentSandboxConfirmDestructive;
    o[QStringLiteral("systemPrompt")] = m_systemPrompt;
    o[QStringLiteral("proxyMode")] = m_proxyMode;
    o[QStringLiteral("proxyUrl")] = m_proxyUrl;
    return o;
}

void AppSettings::saveToDisk() const
{
    QSaveFile f(settingsJsonPath());
    if (!f.open(QIODevice::WriteOnly))
        return;
    f.write(QJsonDocument(toJsonObject()).toJson(QJsonDocument::Indented));
    f.commit();
}

void AppSettings::setThemeMode(const QString &mode)
{
    if (m_themeMode != mode) {
        m_themeMode = mode;
        saveToDisk();
        emit themeModeChanged();
    }
}

void AppSettings::setLanguage(const QString &lang)
{
    if (m_language != lang) {
        m_language = lang;
        saveToDisk();
        emit languageChanged();
    }
}

void AppSettings::setCacheDir(const QString &dir)
{
    if (m_cacheDir != dir) {
        m_cacheDir = dir;
        saveToDisk();
        emit cacheDirChanged();
    }
}

void AppSettings::setApiBaseUrl(const QString &url)
{
    if (m_apiBaseUrl != url) {
        m_apiBaseUrl = url;
        saveToDisk();
        emit apiBaseUrlChanged();
    }
}

void AppSettings::setApiKey(const QString &key)
{
    if (m_apiKey != key) {
        m_apiKey = key;
        saveToDisk();
        emit apiKeyChanged();
    }
}

void AppSettings::setApiModel(const QString &model)
{
    if (m_apiModel != model) {
        m_apiModel = model;
        saveToDisk();
        emit apiModelChanged();
    }
}

void AppSettings::setApiModelList(const QStringList &list)
{
    if (m_apiModelList != list) {
        m_apiModelList = list;
        saveToDisk();
        emit apiModelListChanged();
    }
}

QString AppSettings::resolvedApiKey() const
{
    if (!m_apiKey.isEmpty())
        return m_apiKey;
    const QByteArray a = qgetenv("OPENAI_API_KEY");
    if (!a.isEmpty())
        return QString::fromUtf8(a);
    const QByteArray b = qgetenv("API_KEY");
    if (!b.isEmpty())
        return QString::fromUtf8(b);
    return QString();
}

void AppSettings::setupModelsNetworkProxy()
{
    if (!m_modelsNam)
        return;
    if (m_proxyMode == QStringLiteral("manual") && !m_proxyUrl.isEmpty()) {
        QUrl proxyUrl(m_proxyUrl);
        if (!proxyUrl.scheme().isEmpty()) {
            m_modelsNam->setProxy(QNetworkProxy(QNetworkProxy::HttpProxy, proxyUrl.host(), proxyUrl.port(8080),
                                                 proxyUrl.userName(), proxyUrl.password()));
        } else {
            QString manual = m_proxyUrl.trimmed();
            int colon = manual.indexOf(':');
            QString host = colon > 0 ? manual.left(colon) : manual;
            int port = colon > 0 ? manual.mid(colon + 1).toInt() : 8080;
            m_modelsNam->setProxy(QNetworkProxy(QNetworkProxy::HttpProxy, host, port));
        }
    } else {
        m_modelsNam->setProxy(QNetworkProxy::applicationProxy());
    }
}

void AppSettings::setApiModelsRefreshing(bool v)
{
    if (m_apiModelsRefreshing != v) {
        m_apiModelsRefreshing = v;
        emit apiModelsRefreshingChanged();
    }
}

void AppSettings::finishModelsRequest(QNetworkReply *reply)
{
    setApiModelsRefreshing(false);

    if (!reply) {
        emit apiModelListRefreshFinished(false, QStringLiteral("网络请求无效"));
        return;
    }

    if (reply == m_modelsReply)
        m_modelsReply = nullptr;

    if (reply->error() == QNetworkReply::OperationCanceledError) {
        reply->deleteLater();
        return;
    }

    if (reply->error() != QNetworkReply::NoError) {
        const QString err = reply->errorString();
        reply->deleteLater();
        emit apiModelListRefreshFinished(false, err);
        return;
    }

    const QByteArray raw = reply->readAll();
    reply->deleteLater();

    const QJsonDocument doc = QJsonDocument::fromJson(raw);
    if (!doc.isObject()) {
        emit apiModelListRefreshFinished(false, QStringLiteral("无法解析模型列表 JSON"));
        return;
    }

    const QJsonObject root = doc.object();
    QJsonArray data = root[QStringLiteral("data")].toArray();
    if (data.isEmpty())
        data = root[QStringLiteral("models")].toArray();

    QStringList ids;
    ids.reserve(data.size());
    for (const QJsonValue &v : data) {
        if (v.isObject()) {
            const QString id = v.toObject()[QStringLiteral("id")].toString();
            if (!id.isEmpty())
                ids.append(id);
        } else if (v.isString()) {
            const QString s = v.toString();
            if (!s.isEmpty())
                ids.append(s);
        }
    }

    ids.removeDuplicates();
    ids.sort(Qt::CaseInsensitive);

    if (ids.isEmpty()) {
        emit apiModelListRefreshFinished(false, QStringLiteral("API 未返回模型 id（请确认 Base URL 支持 GET /models）"));
        return;
    }

    if (!m_apiModel.isEmpty()) {
        bool hasCur = false;
        for (const QString &id : ids) {
            if (id.compare(m_apiModel, Qt::CaseInsensitive) == 0) {
                hasCur = true;
                break;
            }
        }
        if (!hasCur)
            ids.prepend(m_apiModel);
    }

    setApiModelList(ids);
    emit apiModelListRefreshFinished(true, QStringLiteral("已更新 %1 个模型").arg(ids.size()));
}

void AppSettings::refreshApiModelList()
{
    const QString key = resolvedApiKey();
    if (key.isEmpty()) {
        emit apiModelListRefreshFinished(false, QStringLiteral("请先填写 API Key 或设置 OPENAI_API_KEY"));
        return;
    }

    QString baseUrl = m_apiBaseUrl;
    if (baseUrl.isEmpty())
        baseUrl = QStringLiteral("https://api.openai.com/v1");
    while (baseUrl.endsWith('/'))
        baseUrl.chop(1);

    if (!m_modelsNam)
        m_modelsNam = new QNetworkAccessManager(this);

    setupModelsNetworkProxy();

    if (m_modelsReply) {
        m_modelsReply->disconnect();
        m_modelsReply->abort();
        m_modelsReply->deleteLater();
        m_modelsReply = nullptr;
    }

    QUrl url(baseUrl + QStringLiteral("/models"));
    QNetworkRequest req(url);
    req.setRawHeader("Authorization", (QStringLiteral("Bearer ") + key).toUtf8());
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    req.setTransferTimeout(60000);

    setApiModelsRefreshing(true);
    QNetworkReply *r = m_modelsNam->get(req);
    m_modelsReply = r;
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        finishModelsRequest(r);
    });
}

void AppSettings::setModelTemperature(double v)
{
    v = qBound(0.0, v, 1.0);
    if (!qFuzzyCompare(m_modelTemperature, v)) {
        m_modelTemperature = v;
        saveToDisk();
        emit modelTemperatureChanged();
    }
}

void AppSettings::setTopK(int v)
{
    v = qBound(1, v, 100);
    if (m_topK != v) {
        m_topK = v;
        saveToDisk();
        emit topKChanged();
    }
}

void AppSettings::setTopP(double v)
{
    v = qBound(0.0, v, 1.0);
    if (!qFuzzyCompare(m_topP, v)) {
        m_topP = v;
        saveToDisk();
        emit topPChanged();
    }
}

void AppSettings::setMaxTokens(int v)
{
    v = qBound(64, v, 65535);
    if (m_maxTokens != v) {
        m_maxTokens = v;
        saveToDisk();
        emit maxTokensChanged();
    }
}

void AppSettings::setAgentMaxToolRounds(int v)
{
    v = qBound(-1, v, 2048);
    if (m_agentMaxToolRounds != v) {
        m_agentMaxToolRounds = v;
        saveToDisk();
        emit agentMaxToolRoundsChanged();
    }
}

void AppSettings::setAgentSandboxConfirmDestructive(bool v)
{
    if (m_agentSandboxConfirmDestructive != v) {
        m_agentSandboxConfirmDestructive = v;
        saveToDisk();
        emit agentSandboxConfirmDestructiveChanged();
    }
}

void AppSettings::setSystemPrompt(const QString &prompt)
{
    if (m_systemPrompt != prompt) {
        m_systemPrompt = prompt;
        saveToDisk();
        emit systemPromptChanged();
    }
}

void AppSettings::setProxyMode(const QString &mode)
{
    if (m_proxyMode != mode) {
        m_proxyMode = mode;
        saveToDisk();
        emit proxyModeChanged();
    }
}

void AppSettings::setProxyUrl(const QString &url)
{
    if (m_proxyUrl != url) {
        m_proxyUrl = url;
        saveToDisk();
        emit proxyUrlChanged();
    }
}
