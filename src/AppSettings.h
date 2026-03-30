#ifndef APPSETTINGS_H
#define APPSETTINGS_H

#include <QObject>
#include <QStringList>

class QNetworkAccessManager;
class QNetworkReply;

class AppSettings : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString themeMode READ themeMode WRITE setThemeMode NOTIFY themeModeChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(QString cacheDir READ cacheDir WRITE setCacheDir NOTIFY cacheDirChanged)

    Q_PROPERTY(QString apiBaseUrl READ apiBaseUrl WRITE setApiBaseUrl NOTIFY apiBaseUrlChanged)
    Q_PROPERTY(QString apiKey READ apiKey WRITE setApiKey NOTIFY apiKeyChanged)
    Q_PROPERTY(QString apiModel READ apiModel WRITE setApiModel NOTIFY apiModelChanged)
    Q_PROPERTY(QStringList apiModelList READ apiModelList NOTIFY apiModelListChanged)
    Q_PROPERTY(double modelTemperature READ modelTemperature WRITE setModelTemperature NOTIFY modelTemperatureChanged)
    Q_PROPERTY(int topK READ topK WRITE setTopK NOTIFY topKChanged)
    Q_PROPERTY(double topP READ topP WRITE setTopP NOTIFY topPChanged)
    Q_PROPERTY(int maxTokens READ maxTokens WRITE setMaxTokens NOTIFY maxTokensChanged)
    Q_PROPERTY(int agentMaxToolRounds READ agentMaxToolRounds WRITE setAgentMaxToolRounds NOTIFY agentMaxToolRoundsChanged)
    Q_PROPERTY(bool agentSandboxConfirmDestructive READ agentSandboxConfirmDestructive WRITE setAgentSandboxConfirmDestructive NOTIFY agentSandboxConfirmDestructiveChanged)
    Q_PROPERTY(QString systemPrompt READ systemPrompt WRITE setSystemPrompt NOTIFY systemPromptChanged)
    Q_PROPERTY(QString proxyMode READ proxyMode WRITE setProxyMode NOTIFY proxyModeChanged)
    Q_PROPERTY(QString proxyUrl READ proxyUrl WRITE setProxyUrl NOTIFY proxyUrlChanged)
    Q_PROPERTY(bool apiModelsRefreshing READ apiModelsRefreshing NOTIFY apiModelsRefreshingChanged)

public:
    explicit AppSettings(QObject *parent = nullptr);

    QString themeMode() const { return m_themeMode; }
    void setThemeMode(const QString &mode);
    QString language() const { return m_language; }
    void setLanguage(const QString &lang);
    QString cacheDir() const { return m_cacheDir; }
    void setCacheDir(const QString &dir);

    QString apiBaseUrl() const { return m_apiBaseUrl; }
    void setApiBaseUrl(const QString &url);
    QString apiKey() const { return m_apiKey; }
    void setApiKey(const QString &key);
    QString apiModel() const { return m_apiModel; }
    void setApiModel(const QString &model);
    QStringList apiModelList() const { return m_apiModelList; }
    void setApiModelList(const QStringList &list);
    Q_INVOKABLE void refreshApiModelList();
    double modelTemperature() const { return m_modelTemperature; }
    void setModelTemperature(double v);
    int topK() const { return m_topK; }
    void setTopK(int v);
    double topP() const { return m_topP; }
    void setTopP(double v);
    int maxTokens() const { return m_maxTokens; }
    void setMaxTokens(int v);
    int agentMaxToolRounds() const { return m_agentMaxToolRounds; }
    void setAgentMaxToolRounds(int v);
    bool agentSandboxConfirmDestructive() const { return m_agentSandboxConfirmDestructive; }
    void setAgentSandboxConfirmDestructive(bool v);
    QString systemPrompt() const { return m_systemPrompt; }
    void setSystemPrompt(const QString &prompt);
    QString proxyMode() const { return m_proxyMode; }
    void setProxyMode(const QString &mode);
    QString proxyUrl() const { return m_proxyUrl; }
    void setProxyUrl(const QString &url);

    Q_INVOKABLE QString settingsJsonPath() const;

    bool apiModelsRefreshing() const { return m_apiModelsRefreshing; }

signals:
    void themeModeChanged();
    void languageChanged();
    void cacheDirChanged();
    void apiBaseUrlChanged();
    void apiKeyChanged();
    void apiModelChanged();
    void apiModelListChanged();
    void modelTemperatureChanged();
    void topKChanged();
    void topPChanged();
    void maxTokensChanged();
    void agentMaxToolRoundsChanged();
    void agentSandboxConfirmDestructiveChanged();
    void systemPromptChanged();
    void proxyModeChanged();
    void proxyUrlChanged();
    void apiModelsRefreshingChanged();
    void apiModelListRefreshFinished(bool ok, const QString &message);

private:
    void loadFromDisk();
    void saveToDisk() const;
    void migrateLegacyQSettingsOnce();
    QJsonObject toJsonObject() const;
    void applyJsonObject(const QJsonObject &o);
    QString resolvedApiKey() const;
    void setupModelsNetworkProxy();
    void setApiModelsRefreshing(bool v);
    void finishModelsRequest(QNetworkReply *reply);

    QString m_configDir;
    QString m_themeMode;
    QString m_language;
    QString m_cacheDir;
    QString m_apiBaseUrl;
    QString m_apiKey;
    QString m_apiModel;
    QStringList m_apiModelList;
    double m_modelTemperature;
    int m_topK;
    double m_topP;
    int m_maxTokens;
    int m_agentMaxToolRounds;
    bool m_agentSandboxConfirmDestructive;
    QString m_systemPrompt;
    QString m_proxyMode;
    QString m_proxyUrl;

    QNetworkAccessManager *m_modelsNam = nullptr;
    QNetworkReply *m_modelsReply = nullptr;
    bool m_apiModelsRefreshing = false;
};

#endif // APPSETTINGS_H
