#ifndef SEARCHENGINE_H
#define SEARCHENGINE_H

#include <QObject>
#include "../model/UnifiedFileRecord.h"

class SearchEngine : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString typeFilter READ typeFilter WRITE setTypeFilter NOTIFY typeFilterChanged)

public:
    explicit SearchEngine(QObject *parent = nullptr);

    Q_INVOKABLE void query(const QString &pattern);
    Q_INVOKABLE void setBaseFiles(const QList<UnifiedFileRecord> &files);
    Q_INVOKABLE void clear();

    QString typeFilter() const;
    Q_INVOKABLE void setTypeFilter(const QString &filter);

    QList<UnifiedFileRecord> querySync(const QString &pattern) const;

signals:
    void resultsReady(const QList<UnifiedFileRecord> &files);
    void searchStats(int foundCount, qint64 totalSizeBytes, qint64 elapsedMs);
    void typeFilterChanged();

private:
    bool matchesTypeFilter(const UnifiedFileRecord &rec) const;

    QList<UnifiedFileRecord> m_baseFiles;
    QString m_typeFilter;
};

#endif // SEARCHENGINE_H
