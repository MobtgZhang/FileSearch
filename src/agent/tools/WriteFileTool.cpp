#include "WriteFileTool.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>

QString WriteFileTool::name() const
{
    return QStringLiteral("write_file");
}

QString WriteFileTool::description() const
{
    return QStringLiteral("将文本写入本地文件（UTF-8）。可追加或覆盖。会先创建父目录。");
}

QVariant WriteFileTool::execute(const QVariantMap &params)
{
    QString path = params.value(QStringLiteral("path")).toString().trimmed();
    QString content = params.value(QStringLiteral("content")).toString();
    bool append = params.value(QStringLiteral("append"), false).toBool();

    if (path.isEmpty())
        return QVariantMap{{QStringLiteral("error"), QStringLiteral("path 不能为空")}};

    QFileInfo fi(path);
    QDir().mkpath(fi.absolutePath());

    QFile f(path);
    QIODevice::OpenMode mode = append ? (QIODevice::WriteOnly | QIODevice::Append) : (QIODevice::WriteOnly | QIODevice::Truncate);
    if (!f.open(mode))
        return QVariantMap{{QStringLiteral("error"), QStringLiteral("无法写入文件")}};

    QByteArray utf8 = content.toUtf8();
    if (f.write(utf8) != utf8.size()) {
        f.close();
        return QVariantMap{{QStringLiteral("error"), QStringLiteral("写入不完整")}};
    }
    f.close();

    return QVariantMap{{QStringLiteral("path"), path},
                       {QStringLiteral("bytes_written"), utf8.size()},
                       {QStringLiteral("append"), append},
                       {QStringLiteral("success"), true}};
}
