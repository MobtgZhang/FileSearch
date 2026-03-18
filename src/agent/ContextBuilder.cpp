#include "ContextBuilder.h"
#include "engine/SearchEngine.h"

#include <QDir>
#include <QStorageInfo>
#include <QDateTime>
#include <QVariantMap>
#include <QVariantList>

ContextBuilder::ContextBuilder(QObject *parent)
    : QObject(parent)
{
}

void ContextBuilder::setSearchEngine(SearchEngine *engine) { m_searchEngine = engine; }
void ContextBuilder::setScanEngine(ScanEngine *engine) { m_scanEngine = engine; }

void ContextBuilder::setLastScanResult(const QVariantMap &result)
{
    m_lastScanResult = result;
}

QString ContextBuilder::buildContext(const QList<UnifiedFileRecord> &files)
{
    QString ctx;

    ctx += buildDiskSummary();

    if (!m_lastScanResult.isEmpty()) {
        ctx += "\n--- 最近扫描结果 ---\n";
        QVariantList segments = m_lastScanResult["segments"].toList();
        qint64 totalSize = m_lastScanResult["totalSize"].toLongLong();
        int fileCount = m_lastScanResult["fileCount"].toInt();
        ctx += QString("扫描路径: %1\n").arg(m_lastScanResult["rootPath"].toString());
        ctx += QString("总大小: %1, 文件数: %2\n").arg(formatSize(totalSize)).arg(fileCount);
    }

    if (!files.isEmpty()) {
        ctx += "\n--- 当前文件列表摘要 ---\n";
        int count = qMin(files.size(), 20);
        for (int i = 0; i < count; ++i) {
            const auto &f = files[i];
            ctx += QString("  %1 (%2) %3\n")
                .arg(f.name, formatSize(f.size), f.extension);
        }
        if (files.size() > count)
            ctx += QString("  ... 还有 %1 个文件\n").arg(files.size() - count);
    }

    return ctx;
}

QString ContextBuilder::buildDiskSummary() const
{
    QString summary = "--- 磁盘状态 ---\n";

    for (const QStorageInfo &si : QStorageInfo::mountedVolumes()) {
        if (!si.isReady() || si.isReadOnly())
            continue;
        if (si.rootPath().startsWith("/snap") || si.rootPath().startsWith("/boot"))
            continue;

        qint64 total = si.bytesTotal();
        qint64 avail = si.bytesAvailable();
        if (total <= 0)
            continue;

        double usedPct = 100.0 * (1.0 - (double)avail / total);
        summary += QString("%1: 总计 %2, 可用 %3 (已用 %4%)\n")
            .arg(si.rootPath(), formatSize(total), formatSize(avail))
            .arg(usedPct, 0, 'f', 1);
    }

    summary += QString("当前用户主目录: %1\n").arg(QDir::homePath());
    summary += QString("当前时间: %1\n").arg(QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss"));

    return summary;
}

QString ContextBuilder::buildRecentFileSummary() const
{
    if (!m_searchEngine)
        return QString();

    QList<UnifiedFileRecord> recent = m_searchEngine->querySync("");
    if (recent.isEmpty())
        return "暂无已索引文件。";

    QString summary = QString("已索引 %1 个文件。").arg(recent.size());
    return summary;
}

QString ContextBuilder::formatSize(qint64 bytes) const
{
    if (bytes < 1024)
        return QString::number(bytes) + " B";
    if (bytes < 1024LL * 1024)
        return QString::number(bytes / 1024.0, 'f', 1) + " KB";
    if (bytes < 1024LL * 1024 * 1024)
        return QString::number(bytes / (1024.0 * 1024.0), 'f', 1) + " MB";
    return QString::number(bytes / (1024.0 * 1024.0 * 1024.0), 'f', 1) + " GB";
}
