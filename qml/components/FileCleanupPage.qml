import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import "../theme" 1.0

// 依赖 main.qml 注入的 cleanupEngine、fileOperationService

// 文件清理页面：360 风格，分类卡片、一键扫描、勾选清理
Rectangle {
    id: cleanupPage
    color: Theme.panel
    border.color: Theme.border
    border.width: 1

    property var categoryIcons: ["📦", "🗑", "🔄", "🌐", "📂", "⬇"]
    property var categoryNames: ["系统缓存", "临时文件", "回收站", "浏览器缓存", "软件缓存", "下载缓存"]

    function startScan() {
        CleanupContext.reset()
        CleanupContext.isScanning = true
        if (typeof cleanupEngine !== "undefined" && cleanupEngine) {
            cleanupEngine.scan([0, 1, 2, 3, 4, 5])
        }
    }

    function stopScan() {
        CleanupContext.isScanning = false
        if (typeof cleanupEngine !== "undefined" && cleanupEngine) {
            cleanupEngine.stop()
        }
    }

    function doClean() {
        var paths = CleanupContext.getSelectedFiles()
        if (paths.length === 0) return
        confirmDialog.fileCount = paths.length
        confirmDialog.sizeText = CleanupContext.formatSize(CleanupContext.getSelectedSize())
        confirmDialog.open()
    }

    function performClean() {
        var paths = CleanupContext.getSelectedFiles()
        if (paths.length > 0 && typeof fileOperationService !== "undefined" && fileOperationService) {
            fileOperationService.deleteFiles(paths, false)
            CleanupContext.reset()
        }
    }

    MessageDialog {
        id: confirmDialog
        property int fileCount: 0
        property string sizeText: ""
        title: "确认清理"
        text: "即将永久删除 " + fileCount + " 个文件，释放约 " + sizeText + " 空间。此操作不可恢复，是否继续？"
        buttons: MessageDialog.Ok | MessageDialog.Cancel
        onAccepted: performClean()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── 顶部：标题 + 操作栏 ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.5)
            border.color: Theme.border
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 0.12
                        font.family: Theme.fontFamily
                        color: Theme.muted
                        text: "文件清理"
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: CleanupContext.isScanning ? "停止扫描" : "一键扫描"
                        font.pixelSize: 11
                        font.family: Theme.fontFamily
                        implicitHeight: 28
                        implicitWidth: 96
                        background: Rectangle {
                            color: CleanupContext.isScanning
                                 ? (parent.pressed ? Qt.darker(Theme.accent3, 1.2) : (parent.hovered ? Qt.lighter(Theme.accent3, 1.1) : Theme.accent3))
                                 : (parent.pressed ? Qt.darker(Theme.accent, 1.2) : (parent.hovered ? Qt.lighter(Theme.accent, 1.1) : Theme.accent))
                            radius: 6
                            border.color: CleanupContext.isScanning
                                 ? Qt.rgba(Theme.accent3.r, Theme.accent3.g, Theme.accent3.b, 0.5)
                                 : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
                        }
                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: Theme.bg
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: CleanupContext.isScanning ? stopScan() : startScan()
                    }
                }

                // 进度条
                RowLayout {
                    Layout.fillWidth: true
                    visible: CleanupContext.isScanning
                    spacing: 12

                    ProgressBar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        from: 0
                        to: 100
                        value: 0
                        indeterminate: true
                        background: Rectangle {
                            implicitWidth: 200
                            implicitHeight: 6
                            color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.3)
                            radius: 3
                        }
                        contentItem: Item {
                            implicitWidth: 200
                            implicitHeight: 6
                            Rectangle {
                                width: parent.width * 0.4
                                height: parent.height
                                radius: 3
                                color: Theme.accent
                                SequentialAnimation on x {
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0; to: parent.width - width; duration: 1200 }
                                    NumberAnimation { from: parent.width - width; to: 0; duration: 1200 }
                                }
                            }
                        }
                    }
                    Text {
                        font.pixelSize: 10
                        font.family: Theme.fontFamily
                        color: Theme.muted
                        text: "扫描中 · " + (CleanupContext.elapsedMs / 1000).toFixed(1) + "s"
                    }
                }

                // 摘要
                Text {
                    Layout.fillWidth: true
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                    color: Theme.muted
                    text: CleanupContext.categories.length > 0
                         ? "共 " + CleanupContext.categories.length + " 类 · " +
                           CleanupContext.formatSize(CleanupContext.getSelectedSize()) + " 可清理"
                         : (CleanupContext.isScanning ? "正在扫描..." : "点击「一键扫描」检测可清理文件")
                }
            }
        }

        // ── 分类卡片区域 ──
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: cardsFlow.width
            contentHeight: cardsFlow.height + 80
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 12
                contentItem: Rectangle {
                    implicitWidth: 12
                    radius: 6
                    color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.5)
                    opacity: 0.8
                }
            }

            Flow {
                id: cardsFlow
                width: cleanupPage.width - 40
                x: 20
                y: 16
                spacing: 12

                Repeater {
                    model: CleanupContext.categories

                    Rectangle {
                        id: card
                        width: Math.min(280, (cleanupPage.width - 60) / 2)
                        height: cardContent.height + 24
                        radius: 8
                        color: cardArea.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08) : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.6)
                        border.color: modelData.selected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.4)
                        border.width: 1

                        property bool expanded: false

                        ColumnLayout {
                            id: cardContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                CheckBox {
                                    id: catCheck
                                    checked: modelData.selected
                                    onCheckedChanged: {
                                        if (modelData && modelData.selected !== checked)
                                            CleanupContext.setCategorySelected(modelData.id, checked)
                                    }
                                }
                                Text {
                                    font.pixelSize: 18
                                    text: cleanupPage.categoryIcons[modelData.id] || "📁"
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        font.family: Theme.fontFamily
                                        color: Theme.text
                                        text: modelData.name || ""
                                    }
                                    Text {
                                        font.pixelSize: 11
                                        font.family: Theme.fontFamily
                                        color: Theme.muted
                                        text: CleanupContext.formatSize(modelData.size || 0) + " · " + (modelData.files ? modelData.files.length : 0) + " 个文件"
                                    }
                                }
                                Text {
                                    font.pixelSize: 11
                                    color: Theme.accent
                                    text: card.expanded ? "▲" : "▼"
                                }
                            }

                            // 文件列表（可展开）
                            Repeater {
                                model: card.expanded ? (modelData.files || []).slice(0, 8) : []
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    color: "transparent"
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 32
                                        spacing: 8
                                        Text {
                                            font.pixelSize: 10
                                            font.family: Theme.fontFamily
                                            color: Theme.muted
                                            text: (modelData.name || "").substring(0, 40) + ((modelData.name || "").length > 40 ? "…" : "")
                                            elide: Text.ElideMiddle
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            font.pixelSize: 10
                                            color: Theme.muted
                                            text: CleanupContext.formatSize(modelData.size || 0)
                                        }
                                    }
                                }
                            }
                            Text {
                                Layout.leftMargin: 32
                                font.pixelSize: 10
                                color: Theme.muted
                                visible: card.expanded && (modelData.files ? modelData.files.length > 8 : false)
                                text: "... 还有 " + (modelData.files.length - 8) + " 个文件"
                            }
                        }

                        MouseArea {
                            id: cardArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (mouseY > 50)
                                    card.expanded = !card.expanded
                            }
                        }
                    }
                }

                // 空状态
                Item {
                    width: cardsFlow.width - 40
                    height: 220
                    visible: !CleanupContext.isScanning && CleanupContext.categories.length === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            font.pixelSize: 48
                            color: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.5)
                            text: "🧹"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            font.pixelSize: 13
                            font.family: Theme.fontFamily
                            color: Theme.muted
                            text: "一键扫描，释放磁盘空间"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            font.pixelSize: 11
                            color: Theme.muted
                            text: "支持：系统缓存、临时文件、回收站、浏览器缓存等"
                        }
                    }
                }
            }
        }

        // ── 底部操作栏 ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.8)
            border.color: Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 16

                Text {
                    font.pixelSize: 11
                    font.family: Theme.fontFamily
                    color: Theme.muted
                    text: "已选 " + CleanupContext.formatSize(CleanupContext.getSelectedSize()) + " 可释放"
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "一键清理"
                    font.pixelSize: 11
                    font.family: Theme.fontFamily
                    implicitHeight: 28
                    implicitWidth: 88
                    enabled: CleanupContext.getSelectedFiles().length > 0
                    opacity: enabled ? 1 : 0.5
                    background: Rectangle {
                        color: parent.enabled
                             ? (parent.pressed ? Qt.darker(Theme.accent3, 1.2) : (parent.hovered ? Qt.lighter(Theme.accent3, 1.1) : Theme.accent3))
                             : Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.5)
                        radius: 6
                        border.color: parent.enabled ? Qt.rgba(Theme.accent3.r, Theme.accent3.g, Theme.accent3.b, 0.5) : "transparent"
                    }
                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: Theme.bg
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: doClean()
                }
            }
        }
    }

}
