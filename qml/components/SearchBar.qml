import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import "../theme" 1.0

Rectangle {
    id: searchBar
    Layout.fillWidth: true
    Layout.preferredHeight: Theme.searchBarHeight
    clip: false
    color: Theme.panel
    border.color: Theme.border
    border.width: 1

    property string lastQueryText: ""

    function requery() {
        if (typeof searchEngine !== "undefined" && searchEngine)
            searchEngine.query(lastQueryText)
    }

    FolderDialog {
        id: folderDialog
        title: "选择查找目录"
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

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 12
        layoutDirection: Qt.LeftToRight

        SearchIcon {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter
            color: Theme.accent
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.minimumWidth: 200
            Layout.preferredHeight: 34
            Layout.alignment: Qt.AlignVCenter
            radius: 8
            clip: true
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                spacing: 0

                TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.minimumWidth: 80
                    Layout.alignment: Qt.AlignVCenter
                    placeholderText: "输入搜索条件..."
                    text: ""
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.bright
                    background: Item {}
                    verticalAlignment: TextInput.AlignVCenter
                    topPadding: 4
                    bottomPadding: 4
                    leftPadding: 4
                    rightPadding: 4
                    onTextChanged: {
                        searchBar.lastQueryText = text
                        if (typeof searchEngine !== "undefined" && searchEngine)
                            searchEngine.query(text)
                    }
                    Component.onCompleted: {
                        if (typeof searchEngine !== "undefined" && searchEngine)
                            searchEngine.query("")
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 18
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    color: Theme.border
                    Layout.alignment: Qt.AlignVCenter
                }

                TextField {
                    id: dirField
                    Layout.preferredWidth: 140
                    Layout.alignment: Qt.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.muted
                    background: Item {}
                    verticalAlignment: TextInput.AlignVCenter
                    topPadding: 2
                    bottomPadding: 2
                    leftPadding: 4
                    rightPadding: 4
                    selectByMouse: true
                    placeholderText: "主目录"
                    onEditingFinished: {
                        var val = text.trim()
                        if (val.length > 0) {
                            dirFilterMenu.customSelection = val
                            dirFilterMenu.currentIndex = 2
                        }
                    }
                }

                Binding {
                    target: dirField
                    property: "text"
                    value: {
                        if (AppController.searchDirectoryCustom.length > 0)
                            return AppController.searchDirectoryCustom
                        var idx = AppController.searchDirectoryIndex
                        if (idx === 0 && typeof pathProvider !== "undefined" && pathProvider)
                            return pathProvider.homePath
                        if (idx === 1 && typeof pathProvider !== "undefined" && pathProvider)
                            return pathProvider.desktopPath
                        if (idx === 2 && typeof pathProvider !== "undefined" && pathProvider)
                            return pathProvider.documentsPath
                        if (idx === 3 && typeof pathProvider !== "undefined" && pathProvider)
                            return pathProvider.downloadPath
                        return "主目录"
                    }
                    when: !dirField.activeFocus
                }
            }
        }

        Row {
            spacing: 8
            Layout.alignment: Qt.AlignVCenter

            FilterPopMenu {
                id: dirFilterMenu
                label: "📁 查找目录"
                chipColor: Theme.accent
                model: ["主目录", "桌面", "文档", "下载", "选择目录..."]
                currentIndex: AppController.searchDirectoryIndex
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

            FilterPopMenu {
                id: typeFilterMenu
                label: "类型"
                chipColor: Theme.accent2
                model: ["全部", "文件夹", "视频", "文档", "图片", "音频", "压缩包", "可执行文件"]
                currentIndex: 0
                onSelected: function(idx) {
                    var types = ["全部", "文件夹", "视频", "文档", "图片", "音频", "压缩包", "可执行文件"]
                    if (typeof searchEngine !== "undefined" && searchEngine) {
                        searchEngine.setTypeFilter(types[idx])
                        searchBar.requery()
                    }
                }
            }

            FilterPopMenu {
                label: "大小"
                chipColor: Theme.accent3
                model: ["全部", "> 100 MB", "> 500 MB", "> 1 GB", "> 10 GB", "< 1 MB"]
                currentIndex: 0
                onSelected: function(idx) { /* TODO: wire up size filter */ }
            }

            FilterPopMenu {
                label: "最近"
                chipColor: Theme.accent4
                model: ["全部", "7 天", "30 天", "90 天", "1 年"]
                currentIndex: 0
                onSelected: function(idx) { /* TODO: wire up date filter */ }
            }
        }
    }
}
