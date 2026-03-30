#include "SearchFilesTool.h"
#include "../../engine/SearchEngine.h"
#include "../../model/UnifiedFileRecord.h"
#include <QtGlobal>
#include <QVariantList>

SearchFilesTool::SearchFilesTool(SearchEngine *engine)
    : m_engine(engine)
{
}

QString SearchFilesTool::name() const
{
    return QStringLiteral("search_files");
}

QString SearchFilesTool::description() const
{
    return QStringLiteral("按关键词搜索文件，支持文件名、路径、扩展名匹配");
}

QVariant SearchFilesTool::execute(const QVariantMap &params)
{
    if (!m_engine)
        return QVariantMap{{"error", "SearchEngine 未初始化"}};

    QString pattern = params.value("pattern").toString();
    QList<UnifiedFileRecord> results = m_engine->querySync(pattern);

    static constexpr int kMaxFilesInResponse = 400;
    const int total = results.size();

    QVariantList list;
    list.reserve(qMin(total, kMaxFilesInResponse));
    const int cap = qMin(total, kMaxFilesInResponse);
    for (int i = 0; i < cap; ++i) {
        const auto &r = results[i];
        list.append(QVariantMap{
            {"path", r.path},
            {"name", r.name},
            {"size", r.size},
            {"extension", r.extension},
            {"isDirectory", r.isDirectory}
        });
    }
    return QVariantMap{
        {"count", list.size()},
        {"total_matched", total},
        {"truncated", total > kMaxFilesInResponse},
        {"files", list}
    };
}
