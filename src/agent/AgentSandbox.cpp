#include "AgentSandbox.h"
#include "AppSettings.h"

#include <QEventLoop>
#include <QTimer>

AgentSandbox::AgentSandbox(QObject *parent)
    : QObject(parent)
{
}

void AgentSandbox::setAppSettings(AppSettings *settings)
{
    m_appSettings = settings;
}

void AgentSandbox::onConfirmDeadline()
{
    if (m_confirmAnswered)
        return;
    m_approved = false;
    if (m_loop)
        m_loop->quit();
}

bool AgentSandbox::waitForDestructiveConfirm(const QString &title, const QString &detailMarkdown)
{
    if (!m_appSettings || !m_appSettings->agentSandboxConfirmDestructive())
        return true;

    m_approved = false;
    m_confirmAnswered = false;
    emit destructiveConfirmRequested(title, detailMarkdown);

    QEventLoop loop;
    m_loop = &loop;

    QTimer timer;
    timer.setSingleShot(true);
    timer.setInterval(300000);
    m_deadlineTimer = &timer;
    QObject::connect(&timer, &QTimer::timeout, this, &AgentSandbox::onConfirmDeadline);
    timer.start();
    loop.exec(QEventLoop::DialogExec);
    timer.stop();
    QObject::disconnect(&timer, &QTimer::timeout, this, &AgentSandbox::onConfirmDeadline);
    m_deadlineTimer = nullptr;
    m_loop = nullptr;
    m_confirmAnswered = false;
    return m_approved;
}

void AgentSandbox::resolveDestructiveConfirm(bool approved)
{
    m_confirmAnswered = true;
    if (m_deadlineTimer) {
        QObject::disconnect(m_deadlineTimer, &QTimer::timeout, this, &AgentSandbox::onConfirmDeadline);
        m_deadlineTimer->stop();
        m_deadlineTimer = nullptr;
    }
    m_approved = approved;
    if (m_loop)
        m_loop->quit();
}
