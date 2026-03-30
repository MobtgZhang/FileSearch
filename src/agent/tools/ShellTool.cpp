#include "ShellTool.h"

#include <QtGlobal>
#include <QProcess>

ShellTool::ShellTool()
{
}

QString ShellTool::name() const
{
    return QStringLiteral("shell");
}

QString ShellTool::description() const
{
#ifdef Q_OS_WIN
    return QStringLiteral("在 Windows 上通过 cmd.exe 执行命令（传入单行或链式命令）");
#else
    return QStringLiteral("在 Linux / macOS 上通过 /bin/bash -c 执行 shell 命令");
#endif
}

QVariant ShellTool::execute(const QVariantMap &params)
{
    QString command = params.value(QStringLiteral("command")).toString().trimmed();
    if (command.isEmpty())
        return QVariantMap{{QStringLiteral("error"), QStringLiteral("命令不能为空")}};

    int timeoutMs = params.value(QStringLiteral("timeoutMs"), 30000).toInt();
    timeoutMs = qBound(5000, timeoutMs, 120000);

    QProcess process;
    process.setProcessChannelMode(QProcess::MergedChannels);

#ifdef Q_OS_WIN
    process.start(QStringLiteral("cmd.exe"), QStringList{QStringLiteral("/c"), command});
#else
    process.start(QStringLiteral("/bin/bash"), QStringList{QStringLiteral("-c"), command});
#endif

    if (!process.waitForStarted(3000))
        return QVariantMap{{QStringLiteral("error"), QStringLiteral("无法启动进程")},
                           {QStringLiteral("success"), false}};

    // 使用 QProcess 自带超时等待，避免自建 QEventLoop + QTimer 与栈对象生命周期竞态导致段错误。
    if (!process.waitForFinished(timeoutMs)) {
        process.kill();
        process.waitForFinished(2000);
    }

    // MergedChannels：标准错误已合并到标准输出
    static constexpr int kMaxCapture = 2 * 1024 * 1024;
    QByteArray rawOut = process.readAllStandardOutput();
    bool truncated = false;
    if (rawOut.size() > kMaxCapture) {
        rawOut.truncate(kMaxCapture);
        truncated = true;
    }
    QString stdoutStr = QString::fromUtf8(rawOut);
    if (truncated)
        stdoutStr += QStringLiteral("\n\n…(stdout 已超过 2MB，已截断以防崩溃或卡死)");
    QString stderrStr;
    int exitCode = process.exitCode();

    return QVariantMap{{QStringLiteral("exitCode"), exitCode},
                       {QStringLiteral("stdout"), stdoutStr.trimmed()},
                       {QStringLiteral("stderr"), stderrStr.trimmed()},
                       {QStringLiteral("success"), exitCode == 0}};
}
