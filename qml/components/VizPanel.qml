import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import "../theme" 1.0

Rectangle {
    id: vizPanel
    Layout.preferredWidth: Theme.vizPanelWidth
    Layout.fillHeight: true
    color: Theme.panel
    border.color: Theme.border
    border.width: 1

    property var categories: []
    property real usedSize: 0
    property real totalSize: 0

    FolderDialog {
        id: folderDialog
        title: "选择扫描目录"
        acceptLabel: "选择"
        rejectLabel: "取消"
        onAccepted: {
            var path = selectedFolder.toString()
            if (path.startsWith("file://"))
                path = path.substring(7)
            AppController.searchDirectoryCustom = path
            AppController.searchDirectoryIndex = 4
            dirFilterMenu.customSelection = path
            dirFilterMenu.currentIndex = 4
        }
    }

    function startScan() {
        if (typeof scanEngine !== "undefined" && scanEngine) {
            var path = AppController.resolveSearchPath()
            if (path.length > 0) {
                vizPanel.categories = []
                vizPanel.usedSize = 0
                vizPanel.totalSize = 0
                AppController.isScanning = true
                Qt.callLater(function() {
                    if (AppController.isScanning)
                        scanEngine.scan(path)
                })
            }
        }
    }

    function stopScan() {
        AppController.isScanning = false
        if (typeof scanEngine !== "undefined" && scanEngine) {
            scanEngine.stop()
        }
    }

    Connections {
        target: scanEngine
        function onScanProgress(fileCount, elapsedMs, categories) {
            vizPanel.categories = categories || []
            var total = 0
            for (var i = 0; i < categories.length; i++)
                total += Number(categories[i].size) || 0
            vizPanel.usedSize = total
            if (typeof statusContext !== "undefined" && statusContext) {
                statusContext.indexedFileCount = fileCount
                statusContext.operationTimeMs = elapsedMs
            }
        }
        function onSegmentsReady(result) {
            vizPanel.categories = result.categories || []
            vizPanel.usedSize = Number(result.usedSize) || 0
            vizPanel.totalSize = Number(result.totalSize) || 0
            if (typeof statusContext !== "undefined" && statusContext) {
                statusContext.indexedFileCount = result.fileCount || 0
                statusContext.operationTimeMs = result.elapsedMs || 0
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 面板标题 + 目录选择（与搜索栏一致）
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 72
            color: "transparent"
            border.color: Theme.border
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 0.12
                        font.family: Theme.fontFamily
                        color: Theme.muted
                        text: "磁盘视图"
                    }

                    Item { Layout.fillWidth: true }
                }

                // 目录选择 + 扫描按钮
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        font.pixelSize: 10
                        color: Theme.muted
                        text: "目录:"
                    }

                    FilterPopMenu {
                        id: dirFilterMenu
                        label: "目录"
                        chipColor: Theme.accent
                        model: ["主目录", "桌面", "文档", "下载", "选择目录..."]
                        currentIndex: AppController.searchDirectoryIndex
                        customSelection: AppController.searchDirectoryCustom
                        onItemClicked: function(idx, text) {
                            if (text === "选择目录...") {
                                folderDialog.open()
                                return true
                            }
                            return false
                        }
                        onSelected: function(idx) {
                            if (idx !== 4) {
                                AppController.searchDirectoryCustom = ""
                                dirFilterMenu.customSelection = ""
                            }
                            AppController.searchDirectoryIndex = idx
                        }
                    }

                    Binding {
                        target: dirFilterMenu
                        property: "currentIndex"
                        value: AppController.searchDirectoryIndex
                    }
                    Binding {
                        target: dirFilterMenu
                        property: "customSelection"
                        value: AppController.searchDirectoryCustom
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: AppController.isScanning ? "停止扫描" : "开始扫描"
                        font.pixelSize: 11
                        font.family: Theme.fontFamily
                        implicitHeight: 28
                        implicitWidth: 88
                        background: Rectangle {
                            color: AppController.isScanning
                                 ? (parent.pressed ? Qt.darker(Theme.accent3, 1.2) : (parent.hovered ? Qt.lighter(Theme.accent3, 1.1) : Theme.accent3))
                                 : (parent.pressed ? Qt.darker(Theme.accent, 1.2) : (parent.hovered ? Qt.lighter(Theme.accent, 1.1) : Theme.accent))
                            radius: 6
                            border.color: AppController.isScanning
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
                        onClicked: AppController.isScanning ? stopScan() : startScan()
                    }
                }
            }
        }

        // 环形图区域：按分类展示（视频、文档、图片等），图例，已用/总量在下方
        RadialMapView {
            Layout.preferredHeight: 300
            Layout.fillWidth: true
            categories: vizPanel.categories
            usedSize: vizPanel.usedSize
            totalSize: vizPanel.totalSize
        }

        // 分类方块: Movies, Documents, Pictures, Music, System, Others
        CategoryBlocksView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 14
            categories: vizPanel.categories
        }
    }
}
