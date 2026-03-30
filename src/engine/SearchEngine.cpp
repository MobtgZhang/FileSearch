#include "SearchEngine.h"
#include <QElapsedTimer>
#include <QMutexLocker>
#include <algorithm>

namespace {
const QStringList VIDEO_EXTS = {"mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v", "mpg", "mpeg", "3gp"};
const QStringList DOC_EXTS = {"pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "md", "odt", "ods", "odp", "rtf", "csv"};
const QStringList PICTURE_EXTS = {"jpg", "jpeg", "png", "gif", "webp", "bmp", "svg", "ico", "tiff", "tif", "raw", "heic"};
const QStringList MUSIC_EXTS = {"mp3", "flac", "wav", "ogg", "m4a", "aac", "wma"};
const QStringList ARCHIVE_EXTS = {"zip", "tar", "gz", "bz2", "xz", "7z", "rar", "iso", "vmdk"};
const QStringList EXEC_EXTS = {"exe", "msi", "sh", "bin", "appimage", "deb", "rpm", "flatpak"};
}

SearchEngine::SearchEngine(QObject *parent)
    : QObject(parent)
{
}

void SearchEngine::setBaseFiles(const QList<UnifiedFileRecord> &files)
{
    QMutexLocker lock(&m_mutex);
    m_baseFiles = files;
}

QString SearchEngine::typeFilter() const
{
    return m_typeFilter;
}

void SearchEngine::setTypeFilter(const QString &filter)
{
    bool changed = false;
    {
        QMutexLocker lock(&m_mutex);
        if (m_typeFilter != filter) {
            m_typeFilter = filter;
            changed = true;
        }
    }
    if (changed)
        emit typeFilterChanged();
}

bool SearchEngine::matchesTypeFilter(const UnifiedFileRecord &rec) const
{
    QString tf;
    {
        QMutexLocker lock(&m_mutex);
        tf = m_typeFilter;
    }
    if (tf.isEmpty() || tf == "全部")
        return true;

    if (tf == "文件夹")
        return rec.isDirectory;
    if (tf == "视频")
        return !rec.isDirectory && VIDEO_EXTS.contains(rec.extension.toLower());
    if (tf == "文档")
        return !rec.isDirectory && DOC_EXTS.contains(rec.extension.toLower());
    if (tf == "图片")
        return !rec.isDirectory && PICTURE_EXTS.contains(rec.extension.toLower());
    if (tf == "音频")
        return !rec.isDirectory && MUSIC_EXTS.contains(rec.extension.toLower());
    if (tf == "压缩包")
        return !rec.isDirectory && ARCHIVE_EXTS.contains(rec.extension.toLower());
    if (tf == "可执行文件")
        return !rec.isDirectory && EXEC_EXTS.contains(rec.extension.toLower());

    return true;
}

void SearchEngine::query(const QString &pattern)
{
    QElapsedTimer timer;
    timer.start();

    QList<UnifiedFileRecord> baseCopy;
    {
        QMutexLocker lock(&m_mutex);
        baseCopy = m_baseFiles;
    }

    QList<UnifiedFileRecord> results;
    QString lowerPattern = pattern.trimmed().toLower();

    if (lowerPattern.isEmpty()) {
        for (const auto &f : baseCopy) {
            if (matchesTypeFilter(f))
                results.append(f);
        }
    } else {
        for (const auto &f : baseCopy) {
            if (f.name.toLower().contains(lowerPattern)
                || f.path.toLower().contains(lowerPattern)
                || f.extension.toLower().contains(lowerPattern)) {
                if (matchesTypeFilter(f))
                    results.append(f);
            }
        }
    }

    std::stable_sort(results.begin(), results.end(), [](const UnifiedFileRecord &a, const UnifiedFileRecord &b) {
        if (a.isDirectory != b.isDirectory)
            return a.isDirectory > b.isDirectory;
        return false;
    });

    qint64 totalSize = 0;
    for (const auto &f : results)
        totalSize += f.size;

    qint64 elapsed = timer.elapsed();
    emit resultsReady(results);
    emit searchStats(results.size(), totalSize, elapsed);
}

void SearchEngine::clear()
{
    QMutexLocker lock(&m_mutex);
    m_baseFiles.clear();
}

QList<UnifiedFileRecord> SearchEngine::querySync(const QString &pattern) const
{
    QList<UnifiedFileRecord> baseCopy;
    {
        QMutexLocker lock(&m_mutex);
        baseCopy = m_baseFiles;
    }

    QString lowerPattern = pattern.trimmed().toLower();
    if (lowerPattern.isEmpty())
        return baseCopy;

    QList<UnifiedFileRecord> results;
    for (const auto &f : baseCopy) {
        if (f.name.toLower().contains(lowerPattern)
            || f.path.toLower().contains(lowerPattern)
            || f.extension.toLower().contains(lowerPattern)) {
            results.append(f);
        }
    }
    return results;
}
