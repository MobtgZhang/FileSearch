#include "CacheManager.h"
#include "AppSettings.h"

#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDateTime>
#include <QUuid>

CacheManager::CacheManager(QObject *parent)
    : QObject(parent)
    , m_sessionId(QUuid::createUuid().toString(QUuid::WithoutBraces).left(8))
{
}

void CacheManager::setCacheDir(const QString &dir)
{
    m_cacheDir = dir;
    ensureDirs();
}

void CacheManager::setAppSettings(AppSettings *settings)
{
    m_appSettings = settings;
    if (m_appSettings && m_cacheDir.isEmpty())
        setCacheDir(m_appSettings->cacheDir());
}

void CacheManager::ensureDirs()
{
    if (m_cacheDir.isEmpty())
        return;
    QDir dir(m_cacheDir);
    dir.mkpath("memory");
    dir.mkpath("history");
    dir.mkpath("skill");
}

void CacheManager::newSession()
{
    m_sessionId = QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
}

QString CacheManager::historyFilePath() const
{
    return m_cacheDir + "/history/session_" + m_sessionId + ".json";
}

QString CacheManager::memoryFilePath() const
{
    return m_cacheDir + "/memory/memory.json";
}

QString CacheManager::skillFilePath() const
{
    return m_cacheDir + "/skill/skill_log.json";
}

QString CacheManager::sessionDir() const
{
    return m_cacheDir + "/history";
}

void CacheManager::appendHistory(const QString &role, const QString &content)
{
    QJsonArray history = readJsonArrayFile(historyFilePath());

    QJsonObject entry;
    entry["role"] = role;
    entry["content"] = content;
    entry["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    entry["session"] = m_sessionId;
    history.append(entry);

    writeJsonArrayFile(historyFilePath(), history);
}

QJsonArray CacheManager::loadRecentHistory(int maxEntries) const
{
    QJsonArray history = readJsonArrayFile(historyFilePath());
    if (history.size() <= maxEntries)
        return history;

    QJsonArray recent;
    for (int i = history.size() - maxEntries; i < history.size(); ++i)
        recent.append(history[i]);
    return recent;
}

void CacheManager::clearHistory()
{
    writeJsonArrayFile(historyFilePath(), QJsonArray());
}

void CacheManager::updateMemory(const QJsonArray &conversationHistory)
{
    QJsonObject memory = readJsonObjectFile(memoryFilePath());

    QJsonArray summaries = memory["summaries"].toArray();

    if (conversationHistory.size() >= 6) {
        QString summary;
        int count = 0;
        for (int i = conversationHistory.size() - 6; i < conversationHistory.size(); ++i) {
            QJsonObject msg = conversationHistory[i].toObject();
            if (msg["role"].toString() == "user" || msg["role"].toString() == "assistant") {
                QString content = msg["content"].toString();
                if (content.length() > 100)
                    content = content.left(100) + "...";
                summary += msg["role"].toString() + ": " + content + "\n";
                count++;
            }
        }

        if (count > 0) {
            QJsonObject entry;
            entry["summary"] = summary.trimmed();
            entry["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
            entry["session"] = m_sessionId;
            summaries.append(entry);

            while (summaries.size() > 50)
                summaries.removeFirst();
        }
    }

    memory["summaries"] = summaries;
    memory["last_updated"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    writeJsonObjectFile(memoryFilePath(), memory);
}

QString CacheManager::loadMemorySummary() const
{
    QJsonObject memory = readJsonObjectFile(memoryFilePath());
    QJsonArray summaries = memory["summaries"].toArray();
    if (summaries.isEmpty())
        return QString();

    QString result;
    int start = qMax(0, summaries.size() - 5);
    for (int i = start; i < summaries.size(); ++i) {
        QJsonObject entry = summaries[i].toObject();
        result += "[" + entry["timestamp"].toString() + "]\n";
        result += entry["summary"].toString() + "\n\n";
    }
    return result.trimmed();
}

void CacheManager::saveMemoryEntry(const QString &key, const QJsonObject &value)
{
    QString path = m_cacheDir + "/memory/" + key + ".json";
    writeJsonObjectFile(path, value);
}

QJsonObject CacheManager::loadMemoryEntry(const QString &key) const
{
    QString path = m_cacheDir + "/memory/" + key + ".json";
    return readJsonObjectFile(path);
}

void CacheManager::recordSkillUsage(const QJsonObject &entry)
{
    QJsonArray skills = readJsonArrayFile(skillFilePath());
    skills.append(entry);

    while (skills.size() > 200)
        skills.removeFirst();

    writeJsonArrayFile(skillFilePath(), skills);
}

QJsonArray CacheManager::loadSkillPatterns() const
{
    return readJsonArrayFile(skillFilePath());
}

QJsonObject CacheManager::findBestSkillMatch(const QString &taskDescription) const
{
    Q_UNUSED(taskDescription);
    return QJsonObject();
}

QJsonArray CacheManager::readJsonArrayFile(const QString &path) const
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return QJsonArray();
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    return doc.isArray() ? doc.array() : QJsonArray();
}

void CacheManager::writeJsonArrayFile(const QString &path, const QJsonArray &arr) const
{
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return;
    file.write(QJsonDocument(arr).toJson(QJsonDocument::Indented));
}

QJsonObject CacheManager::readJsonObjectFile(const QString &path) const
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return QJsonObject();
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    return doc.isObject() ? doc.object() : QJsonObject();
}

void CacheManager::writeJsonObjectFile(const QString &path, const QJsonObject &obj) const
{
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return;
    file.write(QJsonDocument(obj).toJson(QJsonDocument::Indented));
}
