#include "ReadFileTool.h"

#include <QFile>
#include <QFileInfo>

QString ReadFileTool::name() const
{
    return QStringLiteral("read_file");
}

QString ReadFileTool::description() const
{
    return QStringLiteral("读取本地文本文件内容（UTF-8），用于分析日志、配置等");
}

QVariant ReadFileTool::execute(const QVariantMap &params)
{
    QString path = params.value(QStringLiteral("path")).toString().trimmed();
    if (path.isEmpty())
        return QVariantMap{{QStringLiteral("error"), QStringLiteral("path 不能为空")}};

    QFileInfo fi(path);
    if (!fi.exists())
        return QVariantMap{{QStringLiteral("error"), QStringLiteral("文件不存在")}};
    if (!fi.isFile())
        return QVariantMap{{QStringLiteral("error"), QStringLiteral("不是普通文件")}};

    int maxBytes = params.value(QStringLiteral("max_bytes"), 524288).toInt();
    maxBytes = qBound(1024, maxBytes, 2 * 1024 * 1024);

    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return QVariantMap{{QStringLiteral("error"), QStringLiteral("无法打开文件")}};

    QByteArray data = f.read(maxBytes + 1);
    bool truncated = data.size() > maxBytes;
    if (truncated)
        data.truncate(maxBytes);

    return QVariantMap{{QStringLiteral("path"), path},
                       {QStringLiteral("content"), QString::fromUtf8(data)},
                       {QStringLiteral("truncated"), truncated},
                       {QStringLiteral("size_bytes"), data.size()}};
}
