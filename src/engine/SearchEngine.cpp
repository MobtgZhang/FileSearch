#include "SearchEngine.h"
#include <QElapsedTimer>
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
    m_baseFiles = files;
}

QString SearchEngine::typeFilter() const
{
    return m_typeFilter;
}

void SearchEngine::setTypeFilter(const QString &filter)
{
    if (m_typeFilter != filter) {
        m_typeFilter = filter;
        emit typeFilterChanged();
    }
}

bool SearchEngine::matchesTypeFilter(const UnifiedFileRecord &rec) const
{
    if (m_typeFilter.isEmpty() || m_typeFilter == "全部")
        return true;

    if (m_typeFilter == "文件夹")
        return rec.isDirectory;
    if (m_typeFilter == "视频")
        return !rec.isDirectory && VIDEO_EXTS.contains(rec.extension.toLower());
    if (m_typeFilter == "文档")
        return !rec.isDirectory && DOC_EXTS.contains(rec.extension.toLower());
    if (m_typeFilter == "图片")
        return !rec.isDirectory && PICTURE_EXTS.contains(rec.extension.toLower());
    if (m_typeFilter == "音频")
        return !rec.isDirectory && MUSIC_EXTS.contains(rec.extension.toLower());
    if (m_typeFilter == "压缩包")
        return !rec.isDirectory && ARCHIVE_EXTS.contains(rec.extension.toLower());
    if (m_typeFilter == "可执行文件")
        return !rec.isDirectory && EXEC_EXTS.contains(rec.extension.toLower());

    return true;
}

void SearchEngine::query(const QString &pattern)
{
    QElapsedTimer timer;
    timer.start();

    QList<UnifiedFileRecord> results;
    QString lowerPattern = pattern.trimmed().toLower();

    if (lowerPattern.isEmpty()) {
        for (const auto &f : m_baseFiles) {
            if (matchesTypeFilter(f))
                results.append(f);
        }
    } else {
        for (const auto &f : m_baseFiles) {
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
    m_baseFiles.clear();
}

QList<UnifiedFileRecord> SearchEngine::querySync(const QString &pattern) const
{
    QString lowerPattern = pattern.trimmed().toLower();
    if (lowerPattern.isEmpty())
        return m_baseFiles;

    QList<UnifiedFileRecord> results;
    for (const auto &f : m_baseFiles) {
        if (f.name.toLower().contains(lowerPattern)
            || f.path.toLower().contains(lowerPattern)
            || f.extension.toLower().contains(lowerPattern)) {
            results.append(f);
        }
    }
    return results;
}
