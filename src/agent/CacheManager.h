#ifndef CACHEMANAGER_H
#define CACHEMANAGER_H

#include <QObject>
#include <QJsonArray>
#include <QJsonObject>

class AppSettings;

class CacheManager : public QObject
{
    Q_OBJECT

public:
    explicit CacheManager(QObject *parent = nullptr);

    void setCacheDir(const QString &dir);
    void setAppSettings(AppSettings *settings);

    void appendHistory(const QString &role, const QString &content);
    QJsonArray loadRecentHistory(int maxEntries = 20) const;
    void clearHistory();

    void updateMemory(const QJsonArray &conversationHistory);
    QString loadMemorySummary() const;
    void saveMemoryEntry(const QString &key, const QJsonObject &value);
    QJsonObject loadMemoryEntry(const QString &key) const;

    void recordSkillUsage(const QJsonObject &entry);
    QJsonArray loadSkillPatterns() const;
    QJsonObject findBestSkillMatch(const QString &taskDescription) const;

    Q_INVOKABLE QString currentSessionId() const { return m_sessionId; }
    Q_INVOKABLE void newSession();

private:
    void ensureDirs();
    QString historyFilePath() const;
    QString memoryFilePath() const;
    QString skillFilePath() const;
    QString sessionDir() const;
    QJsonArray readJsonArrayFile(const QString &path) const;
    void writeJsonArrayFile(const QString &path, const QJsonArray &arr) const;
    QJsonObject readJsonObjectFile(const QString &path) const;
    void writeJsonObjectFile(const QString &path, const QJsonObject &obj) const;

    QString m_cacheDir;
    QString m_sessionId;
    AppSettings *m_appSettings = nullptr;
};

#endif // CACHEMANAGER_H
