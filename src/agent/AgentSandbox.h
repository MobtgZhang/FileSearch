#ifndef AGENTSANDBOX_H
#define AGENTSANDBOX_H

#include <QObject>

class AppSettings;
class QEventLoop;
class QTimer;

class AgentSandbox : public QObject
{
    Q_OBJECT

public:
    explicit AgentSandbox(QObject *parent = nullptr);

    void setAppSettings(AppSettings *settings);

    /** 阻塞直至用户在弹窗中确认或取消（仅主线程调用） */
    bool waitForDestructiveConfirm(const QString &title, const QString &detailMarkdown);

public slots:
    void resolveDestructiveConfirm(bool approved);

signals:
    /** QML 连接后弹出对话框，用户点击后调用 resolveDestructiveConfirm */
    void destructiveConfirmRequested(const QString &title, const QString &detailMarkdown);

private slots:
    void onConfirmDeadline();

private:
    AppSettings *m_appSettings = nullptr;
    QEventLoop *m_loop = nullptr;
    QTimer *m_deadlineTimer = nullptr;
    bool m_approved = false;
    /** 用户已点确认/取消，忽略仍排在队列里的超时回调 */
    bool m_confirmAnswered = false;
};

#endif
