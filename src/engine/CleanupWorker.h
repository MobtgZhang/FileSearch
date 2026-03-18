#ifndef CLEANUPWORKER_H
#define CLEANUPWORKER_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class CleanupWorker : public QObject
{
    Q_OBJECT

public:
    explicit CleanupWorker(QObject *parent = nullptr);

    Q_INVOKABLE void scan(const QVariantList &categoryIds);
    void cancel();

signals:
    void progress(int categoryIndex, int scannedFiles, qint64 scannedSize, qint64 elapsedMs);
    void categoryReady(int categoryId, const QString &name, const QVariantList &files, qint64 totalSize);
    void finished(qint64 elapsedMs);

private:
    struct ScanResult {
        int categoryId;
        QString name;
        QVariantList files;
        qint64 totalSize = 0;
    };
    ScanResult scanCategory(int categoryId);
    qint64 collectFiles(const QString &dirPath, QVariantList &outFiles, bool recursive = true, const QStringList &nameFilters = QStringList(), bool downloadTempOnly = false);

    bool m_abort = false;
};

#endif // CLEANUPWORKER_H
