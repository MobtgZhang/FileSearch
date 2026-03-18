#ifndef CONTEXTBUILDER_H
#define CONTEXTBUILDER_H

#include <QObject>
#include "../model/UnifiedFileRecord.h"

class SearchEngine;
class ScanEngine;

class ContextBuilder : public QObject
{
    Q_OBJECT

public:
    explicit ContextBuilder(QObject *parent = nullptr);

    void setSearchEngine(SearchEngine *engine);
    void setScanEngine(ScanEngine *engine);

    Q_INVOKABLE QString buildContext(const QList<UnifiedFileRecord> &files);
    QString buildDiskSummary() const;
    QString buildRecentFileSummary() const;

    void setLastScanResult(const QVariantMap &result);

private:
    QString formatSize(qint64 bytes) const;

    SearchEngine *m_searchEngine = nullptr;
    ScanEngine *m_scanEngine = nullptr;
    QVariantMap m_lastScanResult;
};

#endif // CONTEXTBUILDER_H
