import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme" 1.0

Rectangle {
    id: listPanel
    Layout.fillWidth: true
    Layout.fillHeight: true
    color: Theme.bg

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ActionBar { }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.colHeaderHeight
            color: Theme.panel
            border.color: Theme.border
            border.width: 1
            clip: true

            Item {
                id: headerArea
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14 + fileListView.scrollBarW

                readonly property real p0: 0
                readonly property real p1: fileListView.colNameWidth
                readonly property real p2: p1 + fileListView.colPathWidth
                readonly property real p3: p2 + fileListView.colTypeWidth
                readonly property real p4: p3 + fileListView.colSizeWidth

                Item {
                    x: headerArea.p0; width: headerArea.p1 - headerArea.p0
                    height: parent.height; clip: true
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 2
                        spacing: 4
                        Text {
                            font.pixelSize: 10; font.weight: Font.Bold
                            font.letterSpacing: 0.12; color: Theme.accent
                            text: "文件名"
                        }
                        Text {
                            font.pixelSize: 9; color: Theme.accent; text: "↓"
                        }
                    }
                }
                Item {
                    x: headerArea.p1; width: headerArea.p2 - headerArea.p1
                    height: parent.height; clip: true
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 6
                        font.pixelSize: 10; font.weight: Font.Bold
                        font.letterSpacing: 0.12; color: Theme.muted; text: "路径"
                    }
                }
                Item {
                    x: headerArea.p2; width: headerArea.p3 - headerArea.p2
                    height: parent.height; clip: true
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 6
                        font.pixelSize: 10; font.weight: Font.Bold
                        font.letterSpacing: 0.12; color: Theme.muted; text: "类型"
                    }
                }
                Item {
                    x: headerArea.p3; width: headerArea.p4 - headerArea.p3
                    height: parent.height; clip: true
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 6
                        font.pixelSize: 10; font.weight: Font.Bold
                        font.letterSpacing: 0.12; color: Theme.muted; text: "大小"
                    }
                }
                Item {
                    x: headerArea.p4; width: fileListView.colDateWidth
                    height: parent.height; clip: true
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 6
                        font.pixelSize: 10; font.weight: Font.Bold
                        font.letterSpacing: 0.12; color: Theme.muted; text: "修改时间"
                    }
                }

                Rectangle {
                    x: headerArea.p1 - 0.5; width: 1; height: parent.height
                    color: h1ma.containsMouse || h1ma.pressed
                        ? Theme.accent : Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.3)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    MouseArea {
                        id: h1ma
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0; width: 8; height: parent.height
                        hoverEnabled: true; cursorShape: Qt.SizeHorCursor; preventStealing: true
                        property real gx0; property real w0a; property real w0b
                        onPressed: function(m) {
                            gx0 = mapToGlobal(m.x, 0).x
                            w0a = fileListView.colNameWidth; w0b = fileListView.colPathWidth
                        }
                        onPositionChanged: function(m) {
                            if (!pressed) return
                            var d = mapToGlobal(m.x, 0).x - gx0
                            d = Math.max(80 - w0a, Math.min(w0b - 40, d))
                            fileListView.colNameWidth = w0a + d
                            fileListView.colPathWidth = w0b - d
                        }
                    }
                }

                Rectangle {
                    x: headerArea.p2 - 0.5; width: 1; height: parent.height
                    color: h2ma.containsMouse || h2ma.pressed
                        ? Theme.accent : Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.3)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    MouseArea {
                        id: h2ma
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0; width: 8; height: parent.height
                        hoverEnabled: true; cursorShape: Qt.SizeHorCursor; preventStealing: true
                        property real gx0; property real w0a; property real w0b
                        onPressed: function(m) {
                            gx0 = mapToGlobal(m.x, 0).x
                            w0a = fileListView.colPathWidth; w0b = fileListView.colTypeWidth
                        }
                        onPositionChanged: function(m) {
                            if (!pressed) return
                            var d = mapToGlobal(m.x, 0).x - gx0
                            d = Math.max(40 - w0a, Math.min(w0b - 50, d))
                            fileListView.colPathWidth = w0a + d
                            fileListView.colTypeWidth = w0b - d
                        }
                    }
                }

                Rectangle {
                    x: headerArea.p3 - 0.5; width: 1; height: parent.height
                    color: h3ma.containsMouse || h3ma.pressed
                        ? Theme.accent : Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.3)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    MouseArea {
                        id: h3ma
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0; width: 8; height: parent.height
                        hoverEnabled: true; cursorShape: Qt.SizeHorCursor; preventStealing: true
                        property real gx0; property real w0a; property real w0b
                        onPressed: function(m) {
                            gx0 = mapToGlobal(m.x, 0).x
                            w0a = fileListView.colTypeWidth; w0b = fileListView.colSizeWidth
                        }
                        onPositionChanged: function(m) {
                            if (!pressed) return
                            var d = mapToGlobal(m.x, 0).x - gx0
                            d = Math.max(50 - w0a, Math.min(w0b - 50, d))
                            fileListView.colTypeWidth = w0a + d
                            fileListView.colSizeWidth = w0b - d
                        }
                    }
                }

                Rectangle {
                    x: headerArea.p4 - 0.5; width: 1; height: parent.height
                    color: h4ma.containsMouse || h4ma.pressed
                        ? Theme.accent : Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.3)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    MouseArea {
                        id: h4ma
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0; width: 8; height: parent.height
                        hoverEnabled: true; cursorShape: Qt.SizeHorCursor; preventStealing: true
                        property real gx0; property real w0a; property real w0b
                        onPressed: function(m) {
                            gx0 = mapToGlobal(m.x, 0).x
                            w0a = fileListView.colSizeWidth; w0b = fileListView.colDateWidth
                        }
                        onPositionChanged: function(m) {
                            if (!pressed) return
                            var d = mapToGlobal(m.x, 0).x - gx0
                            d = Math.max(50 - w0a, Math.min(w0b - 80, d))
                            fileListView.colSizeWidth = w0a + d
                            fileListView.colDateWidth = w0b - d
                        }
                    }
                }
            }
        }

        ListView {
            id: fileListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            focus: true
            activeFocusOnTab: true
            model: fileModel
            delegate: FileRowDelegate { }

            property real colNameWidth: 180
            property real colPathWidth: 200
            property real colTypeWidth: 70
            property real colSizeWidth: 80
            property real colDateWidth: 130
            property real colActionsWidth: 60
            readonly property real scrollBarW: vScrollBar.visible ? 12 : 0

            function recalcPathWidth() {
                var avail = width - 28 - scrollBarW
                var used = colNameWidth + colTypeWidth + colSizeWidth + colDateWidth + colActionsWidth
                colPathWidth = Math.max(40, avail - used)
            }

            onWidthChanged: recalcPathWidth()
            onScrollBarWChanged: recalcPathWidth()
            Component.onCompleted: recalcPathWidth()

            Keys.onPressed: function(event) {
                if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_A) {
                    if (typeof fileModel !== "undefined" && fileModel)
                        fileModel.selectAll()
                    event.accepted = true
                }
                if (event.key === Qt.Key_Escape) {
                    if (typeof fileModel !== "undefined" && fileModel)
                        fileModel.selectNone()
                    event.accepted = true
                }
            }

            ScrollBar.vertical: ScrollBar {
                id: vScrollBar
                policy: ScrollBar.AsNeeded
                width: 12
                contentItem: Rectangle {
                    implicitWidth: 12
                    radius: 6
                    color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.5)
                    opacity: 0.8
                }
            }
        }
    }
}
