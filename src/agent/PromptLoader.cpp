#include "PromptLoader.h"

#include <QCoreApplication>
#include <QFile>
#include <QFileInfo>

QString PromptLoader::loadUtf8WithFallback(const QString &fileName, const QString &fallback)
{
    const QString path = QCoreApplication::applicationDirPath() + QStringLiteral("/prompts/") + fileName;
    const QFileInfo fi(path);
    if (!fi.exists() || !fi.isFile() || fi.size() <= 0)
        return fallback;

    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return fallback;

    const QString s = QString::fromUtf8(f.readAll());
    if (s.trimmed().isEmpty())
        return fallback;
    return s;
}

QString PromptLoader::loadUtf8(const QString &fileName)
{
    return loadUtf8WithFallback(fileName, QString());
}
