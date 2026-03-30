#include <QByteArray>
#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QLibraryInfo>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QTimer>
#include <QUrl>
#include <QtWebEngineQuick>
#include <QtConcurrent>
#include <QFutureWatcher>

#include "AppSettings.h"
#include "PathProvider.h"
#include "StatusContext.h"
#include "model/FileItemModel.h"
#include "model/UnifiedFileRecord.h"
#include "engine/SearchEngine.h"
#include "engine/ScanEngine.h"
#include "engine/DuplicateEngine.h"
#include "engine/CleanupEngine.h"
#include "service/FileOperationService.h"
#include "agent/ChatBridge.h"
#include "agent/ToolExecutor.h"
#include "agent/AIBridge.h"
#include "agent/ContextBuilder.h"
#include "agent/CacheManager.h"
#include "agent/AgentOrchestrator.h"
#include "agent/AgentSandbox.h"

#if defined(Q_OS_LINUX)
// 与 ChatAgent 一致：https://github.com/MobtgZhang/ChatAgent
// 官方 Qt 在线安装套件往往不带发行版打包的 fcitx5 平台插件，需把系统 qt6/plugins 并入 QT_PLUGIN_PATH。
static void setupLinuxFcitxEnvironment()
{
    // 必须在 QGuiApplication / QtWebEngineQuick::initialize 之前（ChatAgent main.cpp）
    qputenv("QT_IM_MODULES", QByteArrayLiteral("fcitx5;fcitx;wayland;ibus"));
    qputenv("QT_IM_MODULE", QByteArrayLiteral("fcitx5"));
    qputenv("XMODIFIERS", QByteArrayLiteral("@im=fcitx"));

    QStringList dirs;
    dirs << QLibraryInfo::path(QLibraryInfo::PluginsPath);
    static const char *kSystemQt6Plugins[] = {
        "/usr/lib/x86_64-linux-gnu/qt6/plugins",
        "/usr/lib/aarch64-linux-gnu/qt6/plugins",
        "/usr/lib64/qt6/plugins",
        "/usr/lib/qt6/plugins",
    };
    for (const char *p : kSystemQt6Plugins) {
        const QString d = QString::fromUtf8(p);
        if (QFileInfo::exists(d) && !dirs.contains(d))
            dirs.append(d);
    }
    QString merged = dirs.join(u':');
    const QByteArray prev = qgetenv("QT_PLUGIN_PATH");
    if (!prev.isEmpty())
        merged += u':' + QString::fromLocal8Bit(prev);
    qputenv("QT_PLUGIN_PATH", merged.toLocal8Bit());
}
#endif

int main(int argc, char *argv[])
{
#if defined(Q_OS_LINUX)
    setupLinuxFcitxEnvironment();
#endif
    QtWebEngineQuick::initialize();
    QCoreApplication::setOrganizationName(QStringLiteral("NexFile"));
    QCoreApplication::setApplicationName(QStringLiteral("FileSearch"));
    QGuiApplication app(argc, argv);

    AppSettings appSettings;
    PathProvider pathProvider;
    StatusContext statusContext;
    FileItemModel fileModel;
    SearchEngine searchEngine;
    ScanEngine scanEngine;
    DuplicateEngine duplicateEngine;
    CleanupEngine cleanupEngine;
    FileOperationService fileOperationService;
    ChatBridge chatBridge;
    ToolExecutor toolExecutor;
    AIBridge aiBridge;
    ContextBuilder contextBuilder;
    CacheManager cacheManager;
    AgentOrchestrator agentOrchestrator;
    AgentSandbox agentSandbox;

    agentSandbox.setAppSettings(&appSettings);
    toolExecutor.setSearchEngine(&searchEngine);
    toolExecutor.setFileOperationService(&fileOperationService);
    toolExecutor.setAppSettings(&appSettings);
    toolExecutor.setAgentSandbox(&agentSandbox);

    aiBridge.setAppSettings(&appSettings);
    contextBuilder.setSearchEngine(&searchEngine);

    cacheManager.setAppSettings(&appSettings);
    QObject::connect(&appSettings, &AppSettings::cacheDirChanged, &cacheManager, [&appSettings, &cacheManager]() {
        if (!appSettings.cacheDir().isEmpty())
            cacheManager.setCacheDir(appSettings.cacheDir());
    });

    agentOrchestrator.setAIBridge(&aiBridge);
    agentOrchestrator.setToolExecutor(&toolExecutor);
    agentOrchestrator.setContextBuilder(&contextBuilder);
    agentOrchestrator.setChatBridge(&chatBridge);
    agentOrchestrator.setCacheManager(&cacheManager);
    agentOrchestrator.setSearchEngine(&searchEngine);
    agentOrchestrator.setAppSettings(&appSettings);

    QObject::connect(&chatBridge, &ChatBridge::userMessageAdded,
                     &agentOrchestrator, &AgentOrchestrator::handleUserMessage);

    QObject::connect(&aiBridge, &AIBridge::chatResponseReceived,
                     &agentOrchestrator, &AgentOrchestrator::handleLLMResponse);

    QObject::connect(&aiBridge, &AIBridge::chatErrorOccurred, &chatBridge, [&chatBridge](const QString &error) {
        chatBridge.receiveError(error);
    });

    QObject::connect(&agentOrchestrator, &AgentOrchestrator::busyChanged, &chatBridge, [&agentOrchestrator, &chatBridge]() {
        chatBridge.setAiThinking(agentOrchestrator.busy());
    });

    QObject::connect(&aiBridge, &AIBridge::streamContentDelta, &chatBridge, &ChatBridge::receiveStreamChunk);
    QObject::connect(&aiBridge, &AIBridge::streamReasoningDelta, &chatBridge, &ChatBridge::receiveReasoningChunk);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("appSettings", &appSettings);
    engine.rootContext()->setContextProperty("pathProvider", &pathProvider);
    engine.rootContext()->setContextProperty("statusContext", &statusContext);
    engine.rootContext()->setContextProperty("fileModel", &fileModel);
    engine.rootContext()->setContextProperty("searchEngine", &searchEngine);
    engine.rootContext()->setContextProperty("scanEngine", &scanEngine);
    engine.rootContext()->setContextProperty("duplicateEngine", &duplicateEngine);
    engine.rootContext()->setContextProperty("cleanupEngine", &cleanupEngine);
    engine.rootContext()->setContextProperty("fileOperationService", &fileOperationService);
    engine.rootContext()->setContextProperty("chatBridge", &chatBridge);
    engine.rootContext()->setContextProperty("toolExecutor", &toolExecutor);
    engine.rootContext()->setContextProperty("agentOrchestrator", &agentOrchestrator);
    engine.rootContext()->setContextProperty("cacheManager", &cacheManager);
    engine.rootContext()->setContextProperty("agentSandbox", &agentSandbox);

    QObject::connect(&searchEngine, &SearchEngine::resultsReady, &fileModel, [&fileModel](const QList<UnifiedFileRecord> &files) {
        fileModel.setFiles(files);
    });
    QObject::connect(&searchEngine, &SearchEngine::searchStats, &statusContext, [&statusContext](int count, qint64 totalSize, qint64 ms) {
        statusContext.setFoundFileCount(count);
        statusContext.setFoundTotalSize(totalSize);
        statusContext.setOperationTimeMs(static_cast<int>(ms));
    });

    QObject::connect(&scanEngine, &ScanEngine::segmentsReady, &app, [&app, &searchEngine, &fileModel, &contextBuilder](const QVariantMap &result) {
        contextBuilder.setLastScanResult(result);

        QVariantList list = result["fileList"].toList();
        if (list.isEmpty()) {
            QTimer::singleShot(0, &app, [&searchEngine]() {
                searchEngine.setBaseFiles(QList<UnifiedFileRecord>());
                searchEngine.query("");
            });
            return;
        }
        const int cap = qMin(list.size(), 15000);
        auto convert = [list, cap]() -> QList<UnifiedFileRecord> {
            QList<UnifiedFileRecord> records;
            records.reserve(cap);
            for (int i = 0; i < cap; i++) {
                QVariantMap m = list[i].toMap();
                UnifiedFileRecord r;
                r.path = m["path"].toString();
                r.name = m["name"].toString();
                r.size = m["size"].toLongLong();
                r.modified = QDateTime::fromString(m["modified"].toString(), Qt::ISODate);
                r.extension = m["extension"].toString();
                r.isDirectory = m["isDirectory"].toBool();
                records.append(r);
            }
            return records;
        };
        auto *watcher = new QFutureWatcher<QList<UnifiedFileRecord>>(&app);
        QObject::connect(watcher, &QFutureWatcher<QList<UnifiedFileRecord>>::finished, &app, [watcher, &searchEngine]() {
            QList<UnifiedFileRecord> records = watcher->result();
            watcher->deleteLater();
            QTimer::singleShot(0, qApp, [records, &searchEngine]() {
                searchEngine.setBaseFiles(records);
                searchEngine.query("");
            });
        });
        watcher->setFuture(QtConcurrent::run(convert));
    });

    QDir appDir(QCoreApplication::applicationDirPath());
    QStringList searchDirs;
    searchDirs << appDir.absolutePath()
               << appDir.absoluteFilePath("..")
               << appDir.absoluteFilePath("../..")
               << appDir.absoluteFilePath("../src")
               << QDir::currentPath();

    QString qmlBasePath;
    for (const QString &dir : searchDirs) {
        QDir d(dir);
        if (d.exists("qml")) {
            qmlBasePath = d.absoluteFilePath("qml");
            break;
        }
    }

    if (!qmlBasePath.isEmpty()) {
        engine.addImportPath(qmlBasePath);
    } else {
        engine.addImportPath("qrc:/");
    }

    QString aiChatHtmlPath = qmlBasePath.isEmpty()
        ? QString()
        : QDir(qmlBasePath).absoluteFilePath("ai-chat/index.html");
    engine.rootContext()->setContextProperty("aiChatHtmlPath", aiChatHtmlPath);

    QUrl url;
    if (!qmlBasePath.isEmpty()) {
        url = QUrl::fromLocalFile(QDir(qmlBasePath).absoluteFilePath("main.qml"));
    } else {
        url = QUrl("qrc:/qml/main.qml");
    }

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.load(url);

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
