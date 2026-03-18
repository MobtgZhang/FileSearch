import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import "theme" 1.0
import "components" 1.0

ApplicationWindow {
    id: root
    visible: true
    width: 1280
    height: 800
    minimumWidth: 900
    minimumHeight: 600
    color: Theme.bg
    title: "NexFile — AI 文件管理器"

    onClosing: {
        if (typeof scanEngine !== "undefined" && scanEngine)
            scanEngine.stop()
        if (typeof duplicateEngine !== "undefined" && duplicateEngine)
            duplicateEngine.stop()
        if (typeof cleanupEngine !== "undefined" && cleanupEngine)
            cleanupEngine.stop()
    }

    SettingsDialog { id: settingsDialog }

    Connections {
        target: AppController
        function onOpenSettingsRequested() {
            settingsDialog.open()
        }
    }

    Connections {
        target: (typeof chatBridge !== "undefined" && chatBridge) ? chatBridge : null
        function onUserMessageAdded(text) { ChatHistoryContext.addUserMessage(text) }
        function onAiMessageAdded(text) { ChatHistoryContext.addAiMessage(text) }
        function onToolExecutionAdded(name, status, result) {
            ChatHistoryContext.addToolExecution(name, status, result)
        }
    }

    Connections {
        target: scanEngine
        function onSegmentsReady(result) {
            FilelightContext.updateFromResult(result)
            AppController.isScanning = false
        }
    }

    Connections {
        target: duplicateEngine
        function onProgress(scannedFiles, candidateGroups, duplicateGroups, elapsedMs) {
            DuplicateContext.updateProgress(scannedFiles, candidateGroups, duplicateGroups, elapsedMs)
        }
        function onDuplicatesReady(groups, totalScanned, elapsedMs) {
            DuplicateContext.updateFromResult(groups, totalScanned, elapsedMs)
            DuplicateContext.isScanning = false
        }
    }

    Connections {
        target: cleanupEngine
        function onCategoryReady(categoryId, name, files, totalSize) {
            CleanupContext.updateCategory(categoryId, name, files, totalSize)
        }
        function onFinished(elapsedMs) {
            CleanupContext.elapsedMs = elapsedMs
            CleanupContext.isScanning = false
        }
    }

    // 主布局
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── 搜索栏 ──
        SearchBar { }

        // ── 主体三栏 ──
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Sidebar { }

            // 左侧内容区（搜索/磁盘可视化） + 右侧 AI 对话（固定不变）
            SplitView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: Qt.Horizontal

                handle: Item {
                    implicitWidth: 6
                    Rectangle {
                        anchors.fill: parent
                        color: SplitHandle.pressed ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
                             : (SplitHandle.hovered ? Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.6) : Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.3))
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeHorCursor
                        acceptedButtons: Qt.NoButton
                    }
                }

                // 左侧内容区：根据 Sidebar 点击切换「搜索」或「磁盘可视化」
                Item {
                    SplitView.fillWidth: true
                    SplitView.minimumWidth: 400

                        StackLayout {
                        anchors.fill: parent
                        currentIndex: AppController.currentPage === "search" ? 0
                                  : (AppController.currentPage === "disk" ? 1
                                  : (AppController.currentPage === "cleanup" ? 2
                                  : (AppController.currentPage === "favorites" ? 3 : 4)))

                        // 搜索页：可视化面板 + 文件列表
                        SplitView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            orientation: Qt.Horizontal

                            handle: Item {
                                implicitWidth: 6
                                Rectangle {
                                    anchors.fill: parent
                                    color: SplitHandle.pressed ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
                                         : (SplitHandle.hovered ? Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.6) : Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.3))
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.SizeHorCursor
                                    acceptedButtons: Qt.NoButton
                                }
                            }

                            VizPanel {
                                SplitView.preferredWidth: Theme.vizPanelWidth
                                SplitView.minimumWidth: 200
                                SplitView.maximumWidth: 480
                            }

                            FileListPanel {
                                SplitView.fillWidth: true
                                SplitView.minimumWidth: 300
                            }
                        }

                        // 磁盘可视化页：Filelight 风格环形树状图
                        FilelightPage {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }

                        // 系统清理页：垃圾清理 + 重复文件（合并）
                        SystemCleanupPage {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }

                        // 收藏页：文件操作 Skill
                        FavoritesPage {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }

                        // 历史页：对话记录
                        HistoryPage {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }
                    }
                }

                // 右侧 AI 聊天面板（始终显示，不随页面切换变化）
                AIChatPanel {
                    SplitView.preferredWidth: Theme.aiPanelWidth
                    SplitView.minimumWidth: 200
                    SplitView.maximumWidth: 500
                }
            }
        }

        // ── 状态栏 ──
        StatusBar { }
    }
}
