#include "CacheManager.h"
#include "AppSettings.h"
#include "PromptLoader.h"
#include "PromptFallbacks.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDateTime>
#include <QUuid>
#include <QUrl>
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
    if (m_appSettings && !m_appSettings->cacheDir().isEmpty())
        setCacheDir(m_appSettings->cacheDir());
}

void CacheManager::ensureDirs()
{
    if (m_cacheDir.isEmpty())
        return;
    QDir dir(m_cacheDir);
    dir.mkpath(QStringLiteral("memory"));
    dir.mkpath(QStringLiteral("history"));
    dir.mkpath(QStringLiteral("skills/imported"));
}

QString CacheManager::skillsImportedPath() const
{
    return m_cacheDir + QStringLiteral("/skills/imported");
}

QString CacheManager::skillsImportedDir() const
{
    return skillsImportedPath();
}

void CacheManager::newSession()
{
    m_sessionId = QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
}

QString CacheManager::historyFilePath() const
{
    return m_cacheDir + QStringLiteral("/history/session_") + m_sessionId + QStringLiteral(".json");
}

QString CacheManager::memoryFilePath() const
{
    return m_cacheDir + QStringLiteral("/memory/longterm.json");
}

QString CacheManager::l1HotFilePath() const
{
    return m_cacheDir + QStringLiteral("/memory/l1_hot.json");
}

QString CacheManager::skillLogPath() const
{
    return m_cacheDir + QStringLiteral("/skills/skill_log.json");
}

QString CacheManager::sessionDir() const
{
    return m_cacheDir + QStringLiteral("/history");
}

bool CacheManager::importSkillMarkdown(const QString &localPath)
{
    QString path = QUrl(localPath).toLocalFile();
    if (path.isEmpty())
        path = localPath;
    QFileInfo fi(path);
    if (!fi.exists() || !fi.isFile())
        return false;
    ensureDirs();
    QDir destDir(skillsImportedPath());
    destDir.mkpath(QStringLiteral("."));
    const QString dest = destDir.filePath(fi.completeBaseName() + QStringLiteral("_")
                                          + QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_hhmmss"))
                                          + QStringLiteral(".md"));
    return QFile::copy(localPath, dest);
}

void CacheManager::appendHistory(const QString &role, const QString &content)
{
    QJsonArray history = readJsonArrayFile(historyFilePath());

    QJsonObject entry;
    entry[QStringLiteral("role")] = role;
    entry[QStringLiteral("content")] = content;
    entry[QStringLiteral("timestamp")] = QDateTime::currentDateTime().toString(Qt::ISODate);
    entry[QStringLiteral("session")] = m_sessionId;
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

void CacheManager::appendL1Turn(const QString &userLine, const QString &assistantLine)
{
    QJsonArray arr = readJsonArrayFile(l1HotFilePath());
    QJsonObject e;
    e[QStringLiteral("user")] = userLine.left(800);
    e[QStringLiteral("assistant")] = assistantLine.left(800);
    e[QStringLiteral("timestamp")] = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
    arr.append(e);
    while (arr.size() > 12)
        arr.removeFirst();
    writeJsonArrayFile(l1HotFilePath(), arr);
}

QString CacheManager::loadL1HotText() const
{
    QJsonArray arr = readJsonArrayFile(l1HotFilePath());
    if (arr.isEmpty())
        return QStringLiteral("(空)");
    QString out;
    for (int i = qMax(0, arr.size() - 6); i < arr.size(); ++i) {
        QJsonObject o = arr[i].toObject();
        out += QStringLiteral("用户: ") + o[QStringLiteral("user")].toString() + QStringLiteral("\n");
        out += QStringLiteral("助手: ") + o[QStringLiteral("assistant")].toString() + QStringLiteral("\n\n");
    }
    return out.trimmed();
}

QString CacheManager::loadImportedSkillsExcerpt(int maxChars) const
{
    QDir d(skillsImportedPath());
    if (!d.exists())
        return QString();
    const QStringList files = d.entryList(QStringList{QStringLiteral("*.md")}, QDir::Files, QDir::Name);
    QString combined;
    for (const QString &fn : files) {
        QFile f(d.filePath(fn));
        if (!f.open(QIODevice::ReadOnly))
            continue;
        QString body = QString::fromUtf8(f.readAll());
        combined += QStringLiteral("### ") + fn + QStringLiteral("\n") + body + QStringLiteral("\n\n");
        if (combined.size() > maxChars)
            break;
    }
    if (combined.size() > maxChars)
        combined = combined.left(maxChars) + QStringLiteral("\n…(截断)");
    return combined.trimmed();
}

QString CacheManager::loadRecentSessionHistoryExcerpt(int maxEntries) const
{
    QJsonArray history = readJsonArrayFile(historyFilePath());
    if (history.isEmpty())
        return QStringLiteral("(本会话尚无落盘记录)");
    QString out;
    int start = qMax(0, history.size() - maxEntries);
    for (int i = start; i < history.size(); ++i) {
        QJsonObject o = history[i].toObject();
        QString role = o[QStringLiteral("role")].toString();
        QString c = o[QStringLiteral("content")].toString();
        if (c.length() > 240)
            c = c.left(240) + QStringLiteral("…");
        out += role + QStringLiteral(": ") + c + QStringLiteral("\n");
    }
    return out.trimmed();
}

QString CacheManager::buildMemoryHierarchyPrompt() const
{
    QString block = PromptLoader::loadUtf8WithFallback(QStringLiteral("memory_hierarchy_intro.md"),
                                                       PromptFallbacks::memoryHierarchyIntro());
    if (!block.endsWith(QLatin1Char('\n')))
        block += QLatin1Char('\n');
    if (!block.endsWith(QLatin1String("\n\n")))
        block += QLatin1Char('\n');

    QString l3skills = loadImportedSkillsExcerpt(10000);
    QString l3mem = loadMemorySummary();
    block += QStringLiteral("—— L3 技能正文 ——\n");
    block += l3skills.isEmpty() ? QStringLiteral("(未导入技能)") : l3skills;
    block += QStringLiteral("\n\n—— L3 长期摘要 ——\n");
    block += l3mem.isEmpty() ? QStringLiteral("(无)") : l3mem;

    block += QStringLiteral("\n\n—— L2 会话节选 ——\n");
    block += loadRecentSessionHistoryExcerpt(10);

    block += QStringLiteral("\n\n—— L1 热行 ——\n");
    block += loadL1HotText();

    return block.trimmed();
}

void CacheManager::updateMemory(const QJsonArray &conversationHistory)
{
    QJsonObject memory = readJsonObjectFile(memoryFilePath());

    QJsonArray summaries = memory[QStringLiteral("summaries")].toArray();

    if (conversationHistory.size() >= 6) {
        QString summary;
        int count = 0;
        for (int i = conversationHistory.size() - 6; i < conversationHistory.size(); ++i) {
            QJsonObject msg = conversationHistory[i].toObject();
            if (msg[QStringLiteral("role")].toString() == QStringLiteral("user")
                || msg[QStringLiteral("role")].toString() == QStringLiteral("assistant")) {
                QString content = msg[QStringLiteral("content")].toString();
                if (content.length() > 100)
                    content = content.left(100) + QStringLiteral("...");
                summary += msg[QStringLiteral("role")].toString() + QStringLiteral(": ") + content + QStringLiteral("\n");
                count++;
            }
        }

        if (count > 0) {
            QJsonObject entry;
            entry[QStringLiteral("summary")] = summary.trimmed();
            entry[QStringLiteral("timestamp")] = QDateTime::currentDateTime().toString(Qt::ISODate);
            entry[QStringLiteral("session")] = m_sessionId;
            summaries.append(entry);

            while (summaries.size() > 80)
                summaries.removeFirst();
        }
    }

    memory[QStringLiteral("summaries")] = summaries;
    memory[QStringLiteral("last_updated")] = QDateTime::currentDateTime().toString(Qt::ISODate);
    writeJsonObjectFile(memoryFilePath(), memory);
}

QString CacheManager::loadMemorySummary() const
{
    QJsonObject memory = readJsonObjectFile(memoryFilePath());
    QJsonArray summaries = memory[QStringLiteral("summaries")].toArray();
    if (summaries.isEmpty())
        return QString();

    QString result;
    int start = qMax(0, summaries.size() - 8);
    for (int i = start; i < summaries.size(); ++i) {
        QJsonObject entry = summaries[i].toObject();
        result += QStringLiteral("[") + entry[QStringLiteral("timestamp")].toString() + QStringLiteral("]\n");
        result += entry[QStringLiteral("summary")].toString() + QStringLiteral("\n\n");
    }
    return result.trimmed();
}

void CacheManager::saveMemoryEntry(const QString &key, const QJsonObject &value)
{
    QString path = m_cacheDir + QStringLiteral("/memory/") + key + QStringLiteral(".json");
    writeJsonObjectFile(path, value);
}

QJsonObject CacheManager::loadMemoryEntry(const QString &key) const
{
    QString path = m_cacheDir + QStringLiteral("/memory/") + key + QStringLiteral(".json");
    return readJsonObjectFile(path);
}

void CacheManager::recordSkillUsage(const QJsonObject &entry)
{
    QJsonArray skills = readJsonArrayFile(skillLogPath());
    skills.append(entry);

    while (skills.size() > 400)
        skills.removeFirst();

    writeJsonArrayFile(skillLogPath(), skills);
}

QJsonArray CacheManager::loadSkillPatterns() const
{
    return readJsonArrayFile(skillLogPath());
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
