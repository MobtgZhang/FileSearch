#ifndef DUPLICATEWORKER_H
#define DUPLICATEWORKER_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class DuplicateWorker : public QObject
{
    Q_OBJECT

public:
    enum HashAlgo { MD5, SHA1, SHA256 };
    enum FileTypeFilter { All, Images, Videos, Documents, Archives };
    enum MinSizeFilter { NoLimit, Skip1KB, Skip100KB, Skip1MB };

    explicit DuplicateWorker(QObject *parent = nullptr);

    Q_INVOKABLE void scan(const QString &path, int hashAlgo, int fileTypeFilter, qint64 minSizeBytes);
    void cancel();

signals:
    void progress(int scannedFiles, int candidateGroups, int duplicateGroups, qint64 elapsedMs);
    void finished(const QVariantList &duplicateGroups, int totalScanned, qint64 elapsedMs);

private:
    bool m_abort = false;
};

#endif // DUPLICATEWORKER_H
