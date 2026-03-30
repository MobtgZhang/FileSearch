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

    Dialog {
        id: agentDestructiveDialog
        parent: Overlay.overlay
        modal: true
        anchors.centerIn: parent
        width: Math.min(580, Overlay.overlay.width - 48)
        title: ""
        padding: 0
        topPadding: 0
        bottomPadding: 0
        leftPadding: 0
        rightPadding: 0

        property string _destructiveTitle: ""
        property string _destructiveDetail: ""

        standardButtons: Dialog.NoButton
        closePolicy: Popup.CloseOnEscape

        Overlay.modal: Rectangle {
            color: Qt.rgba(0, 0, 0, Theme._mode === "light" ? 0.45 : 0.62)
        }

        background: Rectangle {
            color: Theme.surface
            radius: 16
            border.color: Theme.border
            border.width: 1
        }

        onRejected: {
            if (typeof agentSandbox !== "undefined" && agentSandbox)
                agentSandbox.resolveDestructiveConfirm(false)
        }
        onAccepted: {
            if (typeof agentSandbox !== "undefined" && agentSandbox)
                agentSandbox.resolveDestructiveConfirm(true)
        }

        contentItem: ColumnLayout {
            spacing: 0
            width: parent.width

            Rectangle {
                Layout.fillWidth: true
                height: 3
                color: Theme.accent3
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 20
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        Layout.alignment: Qt.AlignTop
                        radius: 12
                        color: Qt.rgba(Theme.accent3.r, Theme.accent3.g, Theme.accent3.b, Theme._mode === "light" ? 0.12 : 0.22)
                        border.color: Qt.rgba(Theme.accent3.r, Theme.accent3.g, Theme.accent3.b, 0.55)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "!"
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            font.family: Theme.fontDisplay
                            color: Theme.accent3
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: agentDestructiveDialog._destructiveTitle.length
                                  ? agentDestructiveDialog._destructiveTitle
                                  : "沙箱确认"
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            font.family: Theme.fontDisplay
                            color: Theme.bright
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "以下操作可能影响文件或系统。请仔细阅读后再确认。"
                            font.pixelSize: 12
                            font.family: Theme.fontDisplay
                            color: Theme.text
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 240
                    radius: 10
                    color: Theme.panel
                    border.color: Theme.border
                    border.width: 1
                    clip: true

                    ScrollView {
                        id: destructiveDetailScroll
                        anchors.fill: parent
                        anchors.margins: 1
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        Text {
                            id: destructiveDetailText
                            /* 与对话框宽度绑定，避免依赖 ScrollBar 子对象（各 Qt 版本不一致） */
                            width: Math.max(160, agentDestructiveDialog.width - 84)
                            leftPadding: 14
                            rightPadding: 14
                            topPadding: 12
                            bottomPadding: 12
                            text: agentDestructiveDialog._destructiveDetail
                            textFormat: Text.MarkdownText
                            wrapMode: Text.Wrap
                            font.pixelSize: 13
                            font.family: Theme.fontFamily
                            lineHeight: 1.45
                            color: Theme.bright
                            linkColor: Theme.accent2
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 12
                    Item { Layout.fillWidth: true }

                    Button {
                        id: sandboxCancelBtn
                        text: "取消"
                        implicitWidth: 108
                        implicitHeight: 40
                        flat: true
                        contentItem: Text {
                            text: sandboxCancelBtn.text
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            font.family: Theme.fontDisplay
                            color: Theme.bright
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            opacity: sandboxCancelBtn.enabled ? 1 : 0.45
                        }
                        background: Rectangle {
                            implicitWidth: 108
                            implicitHeight: 40
                            radius: 10
                            color: sandboxCancelBtn.down ? Theme.highlight
                                 : (sandboxCancelBtn.hovered ? Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.35) : Theme.panel)
                            border.color: Theme.border
                            border.width: 1
                        }
                        onClicked: agentDestructiveDialog.reject()
                    }

                    Button {
                        id: sandboxOkBtn
                        text: "确认执行"
                        implicitWidth: 120
                        implicitHeight: 40
                        contentItem: Text {
                            text: sandboxOkBtn.text
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            font.family: Theme.fontDisplay
                            color: Theme._mode === "light" ? "#ffffff" : "#0a0c10"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            opacity: sandboxOkBtn.enabled ? 1 : 0.5
                        }
                        background: Rectangle {
                            implicitWidth: 120
                            implicitHeight: 40
                            radius: 10
                            color: sandboxOkBtn.down ? Qt.darker(Theme.accent3, 1.12)
                                 : (sandboxOkBtn.hovered ? Qt.lighter(Theme.accent3, 1.06) : Theme.accent3)
                        }
                        onClicked: agentDestructiveDialog.accept()
                    }
                }
            }
        }
    }

    Connections {
        target: (typeof agentSandbox !== "undefined" && agentSandbox) ? agentSandbox : null
        function onDestructiveConfirmRequested(title, detailMarkdown) {
            agentDestructiveDialog._destructiveTitle = title
            agentDestructiveDialog._destructiveDetail = detailMarkdown
            agentDestructiveDialog.open()
        }
    }

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
