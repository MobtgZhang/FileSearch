import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import "../theme" 1.0

Rectangle {
    id: root
    color: Theme.panel
    border.color: Theme.border
    border.width: 1

    property int activeTab: 0   // 0=垃圾清理, 1=重复文件
    property int hashAlgoIndex: 0
    property int fileTypeIndex: 0
    property int minSizeIndex: 0
    property var categoryIcons: ["📦", "🗑", "🔄", "🌐", "📂", "⬇"]

    readonly property bool currentIsScanning:
        activeTab === 0 ? CleanupContext.isScanning : DuplicateContext.isScanning

    // ── Dialogs ──

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

    MessageDialog {
        id: cleanupConfirmDialog
        property int fileCount: 0
        property string sizeText: ""
        title: "确认清理"
        text: "即将永久删除 " + fileCount + " 个文件，释放约 " + sizeText + " 空间。此操作不可恢复，是否继续？"
        buttons: MessageDialog.Ok | MessageDialog.Cancel
        onAccepted: performClean()
    }

    MessageDialog {
        id: duplicateConfirmDialog
        property int fileCount: 0
        property string sizeText: ""
        title: "确认删除重复文件"
        text: "即将删除 " + fileCount + " 个重复文件（每组保留第一个），释放约 " + sizeText + " 空间。此操作不可恢复，是否继续？"
        buttons: MessageDialog.Ok | MessageDialog.Cancel
        onAccepted: performDeleteDuplicates()
    }

    // ── Helper functions ──

    function getMinSizeBytes() {
        if (minSizeIndex === 1) return 1024
        if (minSizeIndex === 2) return 102400
        if (minSizeIndex === 3) return 1048576
        return 0
    }

    function startDuplicateScan() {
        if (typeof duplicateEngine !== "undefined" && duplicateEngine) {
            var path = AppController.resolveSearchPath()
            if (path.length > 0) {
                DuplicateContext.isScanning = true
                DuplicateContext.duplicateGroupsList = []
                Qt.callLater(function() {
                    if (DuplicateContext.isScanning)
                        duplicateEngine.scan(path, hashAlgoIndex, fileTypeIndex, getMinSizeBytes())
                })
            }
        }
    }

    function stopDuplicateScan() {
        DuplicateContext.isScanning = false
        if (typeof duplicateEngine !== "undefined" && duplicateEngine)
            duplicateEngine.stop()
    }

    function startCleanupScan() {
        CleanupContext.reset()
        CleanupContext.isScanning = true
        if (typeof cleanupEngine !== "undefined" && cleanupEngine)
            cleanupEngine.scan([0, 1, 2, 3, 4, 5])
    }

    function stopCleanupScan() {
        CleanupContext.isScanning = false
        if (typeof cleanupEngine !== "undefined" && cleanupEngine)
            cleanupEngine.stop()
    }

    function calcWastedSize() {
        var total = 0
        for (var i = 0; i < DuplicateContext.duplicateGroupsList.length; i++) {
            var g = DuplicateContext.duplicateGroupsList[i]
            var cnt = g.count || 0
            var sz = g.size || 0
            if (cnt > 1) total += sz * (cnt - 1)
        }
        return total
    }

    function doClean() {
        var paths = CleanupContext.getSelectedFiles()
        if (paths.length === 0) return
        cleanupConfirmDialog.fileCount = paths.length
        cleanupConfirmDialog.sizeText = CleanupContext.formatSize(CleanupContext.getSelectedSize())
        cleanupConfirmDialog.open()
    }

    function performClean() {
        var paths = CleanupContext.getSelectedFiles()
        if (paths.length > 0 && typeof fileOperationService !== "undefined" && fileOperationService) {
            fileOperationService.deleteFiles(paths, false)
            CleanupContext.reset()
        }
    }

    function getAllDuplicatePaths() {
        var paths = []
        for (var i = 0; i < DuplicateContext.duplicateGroupsList.length; i++) {
            var g = DuplicateContext.duplicateGroupsList[i]
            var files = g.files || []
            for (var j = 1; j < files.length; j++) {
                if (files[j].path) paths.push(files[j].path)
            }
        }
        return paths
    }

    function deleteAllDuplicates() {
        var paths = getAllDuplicatePaths()
        if (paths.length === 0) return
        duplicateConfirmDialog.fileCount = paths.length
        duplicateConfirmDialog.sizeText = DuplicateContext.formatSize(calcWastedSize())
        duplicateConfirmDialog.open()
    }

    function performDeleteDuplicates() {
        var paths = getAllDuplicatePaths()
        if (paths.length > 0 && typeof fileOperationService !== "undefined" && fileOperationService) {
            fileOperationService.deleteFiles(paths, false)
            DuplicateContext.duplicateGroupsList = []
        }
    }

    // ── Main Layout ──

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ═══════════════════════════════════════
        //  顶部：标签页 + 扫描控制 + 进度
        // ═══════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: headerCol.implicitHeight + 28
            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.5)
            border.color: Theme.border
            border.width: 1

            ColumnLayout {
                id: headerCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 10

                // ── Row 1: 标签栏 + 扫描按钮 ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        width: 264
                        height: 36
                        radius: 8
                        color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.12)
                        border.color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.18)
                        border.width: 1

                        Rectangle {
                            width: 128
                            height: 30
                            x: root.activeTab === 0 ? 3 : 133
                            y: 3
                            radius: 6
                            color: Theme.accent

                            Behavior on x {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                        }

                        Row {
                            anchors.fill: parent

                            Item {
                                width: 132; height: 36

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Text {
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "🧹"
                                    }
                                    Text {
                                        font.pixelSize: 12
                                        font.family: Theme.fontFamily
                                        font.weight: root.activeTab === 0 ? Font.DemiBold : Font.Normal
                                        color: root.activeTab === 0 ? Theme.bg : Theme.muted
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "垃圾清理"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activeTab = 0
                                }
                            }

                            Item {
                                width: 132; height: 36

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Text {
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "⧉"
                                    }
                                    Text {
                                        font.pixelSize: 12
                                        font.family: Theme.fontFamily
                                        font.weight: root.activeTab === 1 ? Font.DemiBold : Font.Normal
                                        color: root.activeTab === 1 ? Theme.bg : Theme.muted
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "重复文件"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activeTab = 1
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: root.currentIsScanning
                              ? "停止扫描"
                              : (root.activeTab === 0 ? "一键扫描" : "开始扫描")
                        font.pixelSize: 11
                        font.family: Theme.fontFamily
                        implicitHeight: 30
                        implicitWidth: 96
                        background: Rectangle {
                            color: root.currentIsScanning
                                 ? (parent.pressed ? Qt.darker(Theme.accent3, 1.2) : (parent.hovered ? Qt.lighter(Theme.accent3, 1.1) : Theme.accent3))
                                 : (parent.pressed ? Qt.darker(Theme.accent, 1.2) : (parent.hovered ? Qt.lighter(Theme.accent, 1.1) : Theme.accent))
                            radius: 6
                            border.color: root.currentIsScanning
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
                        onClicked: {
                            if (root.activeTab === 0)
                                CleanupContext.isScanning ? root.stopCleanupScan() : root.startCleanupScan()
                            else
                                DuplicateContext.isScanning ? root.stopDuplicateScan() : root.startDuplicateScan()
                        }
                    }
                }

                // ── Row 2: 重复文件筛选项（仅 Tab 1 可见） ──
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.activeTab === 1
                    spacing: 8

                    Text { font.pixelSize: 10; color: Theme.muted; text: "目录:" }
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
                    Binding { target: dirFilterMenu; property: "currentIndex"; value: AppController.searchDirectoryIndex }
                    Binding { target: dirFilterMenu; property: "customSelection"; value: AppController.searchDirectoryCustom }

                    Text { font.pixelSize: 10; color: Theme.muted; text: "类型:" }
                    FilterPopMenu {
                        label: "类型"
                        chipColor: Theme.accent2
                        model: ["全部", "图片", "视频", "文档", "压缩包"]
                        currentIndex: root.fileTypeIndex
                        onSelected: function(idx) { root.fileTypeIndex = idx }
                    }

                    Text { font.pixelSize: 10; color: Theme.muted; text: "最小:" }
                    FilterPopMenu {
                        label: "最小"
                        chipColor: Theme.accent4
                        model: ["不限制", "跳过 < 1KB", "跳过 < 100KB", "跳过 < 1MB"]
                        currentIndex: root.minSizeIndex
                        onSelected: function(idx) { root.minSizeIndex = idx }
                    }

                    Text { font.pixelSize: 10; color: Theme.muted; text: "哈希:" }
                    FilterPopMenu {
                        label: "哈希"
                        chipColor: Theme.accent3
                        model: ["MD5 (快)", "SHA1", "SHA256"]
                        currentIndex: root.hashAlgoIndex
                        onSelected: function(idx) { root.hashAlgoIndex = idx }
                    }
                }

                // ── Row 3: 进度条（扫描时可见） ──
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.currentIsScanning
                    spacing: 12

                    ProgressBar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        from: 0; to: 100; value: 0
                        indeterminate: true
                        background: Rectangle {
                            implicitWidth: 200; implicitHeight: 6
                            color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.3)
                            radius: 3
                        }
                        contentItem: Item {
                            implicitWidth: 200; implicitHeight: 6
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
                        text: root.activeTab === 0
                            ? "扫描中 · " + (CleanupContext.elapsedMs / 1000).toFixed(1) + "s"
                            : "已扫描 " + DuplicateContext.scannedFiles + " 个文件 · " +
                              DuplicateContext.duplicateGroups + " 组重复 · " +
                              (DuplicateContext.elapsedMs / 1000).toFixed(1) + "s"
                    }
                }

                // ── Row 4: 摘要 ──
                Text {
                    Layout.fillWidth: true
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                    color: Theme.muted
                    text: {
                        if (root.activeTab === 0) {
                            if (CleanupContext.categories.length > 0)
                                return "共 " + CleanupContext.categories.length + " 类 · " +
                                       CleanupContext.formatSize(CleanupContext.getSelectedSize()) + " 可清理"
                            return CleanupContext.isScanning ? "正在扫描..." : "点击「一键扫描」检测可清理文件"
                        } else {
                            if (DuplicateContext.duplicateGroupsList.length > 0)
                                return "共 " + DuplicateContext.duplicateGroupsList.length + " 组重复 · " +
                                       DuplicateContext.totalScanned + " 个文件已扫描 · " +
                                       DuplicateContext.formatSize(root.calcWastedSize()) + " 可释放"
                            return DuplicateContext.isScanning ? "扫描中..." : "选择目录并点击「开始扫描」查找重复文件"
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════
        //  内容区域（StackLayout 切换）
        // ═══════════════════════════════════════
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.activeTab

            // ──────────────────────────
            //  Tab 0: 垃圾清理
            // ──────────────────────────
            Flickable {
                clip: true
                contentWidth: cardsFlow.width
                contentHeight: cardsFlow.height + 80
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 12
                    contentItem: Rectangle {
                        implicitWidth: 12; radius: 6
                        color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.5)
                        opacity: 0.8
                    }
                }

                Flow {
                    id: cardsFlow
                    width: root.width - 40
                    x: 20; y: 16
                    spacing: 12

                    Repeater {
                        model: CleanupContext.categories

                        Rectangle {
                            id: card
                            width: Math.min(280, (root.width - 60) / 2)
                            height: cardContent.height + 24
                            radius: 10
                            color: cardArea.containsMouse
                                 ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                                 : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.6)
                            border.color: modelData.selected
                                 ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
                                 : Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.4)
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
                                        checked: modelData.selected
                                        onCheckedChanged: CleanupContext.setCategorySelected(modelData.id, checked)
                                    }

                                    Text {
                                        font.pixelSize: 20
                                        text: root.categoryIcons[modelData.id] || "📁"
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
                                            text: CleanupContext.formatSize(modelData.size || 0) + " · " +
                                                  (modelData.files ? modelData.files.length : 0) + " 个文件"
                                        }
                                    }

                                    Text {
                                        font.pixelSize: 11
                                        color: Theme.accent
                                        text: card.expanded ? "▲" : "▼"
                                    }
                                }

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
                                                text: {
                                                    var n = modelData.name || ""
                                                    return n.length > 40 ? n.substring(0, 40) + "…" : n
                                                }
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

            // ──────────────────────────
            //  Tab 1: 重复文件
            // ──────────────────────────
            Rectangle {
                color: Theme.bg

                Flickable {
                    anchors.fill: parent
                    clip: true
                    contentWidth: dupColumn.width
                    contentHeight: dupColumn.height
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        width: 12
                        contentItem: Rectangle {
                            implicitWidth: 12; radius: 6
                            color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.5)
                            opacity: 0.8
                        }
                    }

                    Column {
                        id: dupColumn
                        width: root.width - 20
                        spacing: 8
                        topPadding: 12
                        bottomPadding: 12

                        Repeater {
                            model: DuplicateContext.duplicateGroupsList

                            Rectangle {
                                width: parent.width - 24
                                x: 12
                                height: groupCol.height + 20
                                radius: 10
                                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.5)
                                border.color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.4)
                                border.width: 1

                                property bool groupExpanded: true

                                Column {
                                    id: groupCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 10
                                    spacing: 4

                                    // 组标题
                                    Rectangle {
                                        width: parent.width
                                        height: 38
                                        color: groupMA.containsMouse
                                             ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.06)
                                             : "transparent"
                                        radius: 6

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 8

                                            Text {
                                                font.pixelSize: 13
                                                color: Theme.accent
                                                text: groupExpanded ? "▼" : "▶"
                                            }

                                            Rectangle {
                                                width: 24; height: 24; radius: 12
                                                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                                                Text {
                                                    anchors.centerIn: parent
                                                    font.pixelSize: 11
                                                    font.weight: Font.Bold
                                                    color: Theme.accent
                                                    text: (index + 1).toString()
                                                }
                                            }

                                            Text {
                                                font.pixelSize: 12
                                                font.family: Theme.fontFamily
                                                font.weight: Font.Medium
                                                color: Theme.text
                                                text: (modelData.count || 0) + " 个相同文件 · " +
                                                      DuplicateContext.formatSize(modelData.size || 0)
                                            }

                                            Item { Layout.fillWidth: true }

                                            Button {
                                                text: "保留第一个"
                                                font.pixelSize: 10
                                                font.family: Theme.fontFamily
                                                implicitHeight: 24
                                                visible: groupExpanded && (modelData.count || 0) > 1
                                                background: Rectangle {
                                                    color: parent.pressed
                                                         ? Qt.darker(Theme.surface, 1.1)
                                                         : (parent.hovered ? Qt.lighter(Theme.surface, 1.05) : Theme.surface)
                                                    radius: 4
                                                    border.color: Theme.border
                                                }
                                                contentItem: Text {
                                                    text: parent.text
                                                    font: parent.font
                                                    color: Theme.text
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                onClicked: {
                                                    var g = DuplicateContext.duplicateGroupsList[index]
                                                    var files = g.files || []
                                                    var paths = []
                                                    for (var j = 1; j < files.length; j++) {
                                                        if (files[j].path) paths.push(files[j].path)
                                                    }
                                                    if (paths.length > 0 && typeof fileOperationService !== "undefined" && fileOperationService)
                                                        fileOperationService.deleteFiles(paths, false)
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: groupMA
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: groupExpanded = !groupExpanded
                                        }
                                    }

                                    // 分隔线
                                    Rectangle {
                                        width: parent.width
                                        height: 1
                                        color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.25)
                                        visible: groupExpanded
                                    }

                                    // 组内文件列表
                                    Repeater {
                                        model: groupExpanded ? (modelData.files || []) : []
                                        delegate: Rectangle {
                                            width: parent.width
                                            height: 34
                                            color: fileMA.containsMouse
                                                 ? Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.12)
                                                 : "transparent"
                                            radius: 4

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 16
                                                anchors.rightMargin: 8
                                                spacing: 8

                                                Rectangle {
                                                    width: 6; height: 6; radius: 3
                                                    color: index === 0 ? Theme.accent : Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.4)
                                                }

                                                Text {
                                                    font.pixelSize: 11
                                                    font.family: Theme.fontFamily
                                                    color: index === 0 ? Theme.accent : Theme.bright
                                                    text: (modelData.name || "") + (index === 0 ? "  ✓ 保留" : "")
                                                    elide: Text.ElideMiddle
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    font.pixelSize: 10
                                                    font.family: Theme.fontFamily
                                                    color: Theme.muted
                                                    text: DuplicateContext.formatSize(modelData.size || 0)
                                                }

                                                Button {
                                                    text: "删除"
                                                    font.pixelSize: 10
                                                    font.family: Theme.fontFamily
                                                    implicitHeight: 22
                                                    implicitWidth: 48
                                                    visible: index > 0
                                                    background: Rectangle {
                                                        color: parent.pressed
                                                             ? Qt.darker(Theme.accent3, 1.2)
                                                             : (parent.hovered
                                                                ? Qt.lighter(Theme.accent3, 0.9)
                                                                : Qt.rgba(Theme.accent3.r, Theme.accent3.g, Theme.accent3.b, 0.15))
                                                        radius: 4
                                                        border.color: Qt.rgba(Theme.accent3.r, Theme.accent3.g, Theme.accent3.b, 0.4)
                                                    }
                                                    contentItem: Text {
                                                        text: parent.text
                                                        font: parent.font
                                                        color: Theme.accent3
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                    }
                                                    onClicked: {
                                                        if (typeof fileOperationService !== "undefined" && fileOperationService && modelData.path)
                                                            fileOperationService.deleteFiles([modelData.path], false)
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: fileMA
                                                anchors.fill: parent
                                                hoverEnabled: true
                                            }

                                            ToolTip.visible: fileMA.containsMouse
                                            ToolTip.text: modelData.path || ""
                                            ToolTip.delay: 500
                                        }
                                    }
                                }
                            }
                        }

                        // 空状态
                        Item {
                            width: parent.width - 20
                            height: 200
                            visible: !DuplicateContext.isScanning && DuplicateContext.duplicateGroupsList.length === 0

                            Column {
                                anchors.centerIn: parent
                                spacing: 12

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    font.pixelSize: 48
                                    color: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.5)
                                    text: "⧉"
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    font.pixelSize: 13
                                    font.family: Theme.fontFamily
                                    color: Theme.muted
                                    text: "暂无重复文件"
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    font.pixelSize: 11
                                    color: Theme.muted
                                    text: "选择目录并点击「开始扫描」开始查找"
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════
        //  底部操作栏
        // ═══════════════════════════════════════
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
                    text: root.activeTab === 0
                        ? "已选 " + CleanupContext.formatSize(CleanupContext.getSelectedSize()) + " 可释放"
                        : (DuplicateContext.duplicateGroupsList.length > 0
                            ? DuplicateContext.duplicateGroupsList.length + " 组重复 · " +
                              DuplicateContext.formatSize(root.calcWastedSize()) + " 可释放"
                            : "暂无可清理的重复文件")
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: root.activeTab === 0 ? "一键清理" : "一键去重"
                    font.pixelSize: 11
                    font.family: Theme.fontFamily
                    implicitHeight: 30
                    implicitWidth: 96
                    enabled: root.activeTab === 0
                        ? CleanupContext.getSelectedFiles().length > 0
                        : DuplicateContext.duplicateGroupsList.length > 0
                    opacity: enabled ? 1 : 0.5

                    background: Rectangle {
                        color: parent.enabled
                             ? (parent.pressed ? Qt.darker(Theme.accent3, 1.2) : (parent.hovered ? Qt.lighter(Theme.accent3, 1.1) : Theme.accent3))
                             : Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.5)
                        radius: 6
                        border.color: parent.enabled
                             ? Qt.rgba(Theme.accent3.r, Theme.accent3.g, Theme.accent3.b, 0.5)
                             : "transparent"
                    }
                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: Theme.bg
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: root.activeTab === 0 ? root.doClean() : root.deleteAllDuplicates()
                }
            }
        }
    }
}
