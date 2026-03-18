import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme" 1.0

Rectangle {
    id: row
    width: ListView.view ? ListView.view.width : parent.width
    height: Theme.fileRowHeight

    readonly property var fileListView: ListView.view
    readonly property int rowIndex: index
    readonly property bool isSelected: model.selected
    readonly property bool isDir: model.isDirectory

    color: {
        if (isSelected) return Qt.rgba(74/255, 240/255, 180/255, 0.10)
        if (mouseArea.containsMouse) return Qt.rgba(74/255, 240/255, 180/255, 0.04)
        if (isDir) return Qt.rgba(123/255, 111/255, 240/255, 0.03)
        return "transparent"
    }

    Behavior on color {
        ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height - 8
        width: 3
        radius: 1.5
        color: Theme.accent
        opacity: row.isSelected ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.border
        opacity: 0.3
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14 + (fileListView ? fileListView.scrollBarW : 0)
        spacing: 0

        Item {
            width: fileListView ? fileListView.colNameWidth : 180
            height: parent.height
            clip: true

            Text {
                id: iconText
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 2
                width: 18
                text: model.icon
                font.pixelSize: row.isDir ? 16 : 14
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: iconText.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 4
                font.pixelSize: 12
                font.bold: row.isDir
                color: row.isSelected ? Theme.accent : (row.isDir ? Theme.accent2 : Theme.bright)
                text: model.name
                elide: Text.ElideRight
            }
        }

        Item {
            width: fileListView ? fileListView.colPathWidth : 200
            height: parent.height
            clip: true

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.right: parent.right
                anchors.rightMargin: 4
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.muted
                text: model.path
                elide: Text.ElideMiddle
            }
        }

        Item {
            width: fileListView ? fileListView.colTypeWidth : 70
            height: parent.height
            clip: true

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 8, typeBadgeText.implicitWidth + 16)
                height: 18
                radius: 4
                color: typeColor(model.type)

                Text {
                    id: typeBadgeText
                    anchors.centerIn: parent
                    font.pixelSize: 9
                    font.family: Theme.fontFamily
                    font.letterSpacing: 0.06
                    color: typeTextColor(model.type)
                    text: model.type
                }
            }
        }

        Item {
            width: fileListView ? fileListView.colSizeWidth : 80
            height: parent.height
            clip: true

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.right: parent.right
                anchors.rightMargin: 4
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: Theme.text
                text: model.size
                elide: Text.ElideRight
            }
        }

        Item {
            width: fileListView ? fileListView.colDateWidth : 130
            height: parent.height
            clip: true

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.right: parent.right
                anchors.rightMargin: 4
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.muted
                text: model.date
                elide: Text.ElideRight
            }
        }

        Item {
            width: fileListView ? fileListView.colActionsWidth : 60
            height: parent.height

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4
                opacity: mouseArea.containsMouse ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    width: 20; height: 20; radius: 4
                    color: Theme.border
                    Text {
                        anchors.centerIn: parent
                        font.pixelSize: 11; text: "👁"
                    }
                }
                Rectangle {
                    width: 20; height: 20; radius: 4
                    color: Theme.border
                    Text {
                        anchors.centerIn: parent
                        font.pixelSize: 11; text: "⋯"
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        onClicked: function(mouse) {
            var view = row.fileListView
            if (!view || !view.model) return
            view.forceActiveFocus()

            var mdl = view.model
            var idx = row.rowIndex
            var isCtrl = !!(mouse.modifiers & Qt.ControlModifier) || !!(mouse.modifiers & Qt.MetaModifier)
            var isShift = !!(mouse.modifiers & Qt.ShiftModifier)

            if (isShift) {
                var anchor = mdl.selectionAnchor()
                if (anchor < 0) anchor = idx
                mdl.selectNone()
                mdl.selectRange(anchor, idx)
            } else if (isCtrl) {
                mdl.toggleSelection(idx)
                mdl.setSelectionAnchor(idx)
            } else {
                mdl.selectSingle(idx)
            }
        }
    }

    ToolTip.visible: mouseArea.containsMouse && mouseArea.mouseX >= 14
                     && mouseArea.mouseX < 14 + (fileListView ? fileListView.colNameWidth : 180)
    ToolTip.text: {
        var p = model.path || ""
        var lastSlash = p.lastIndexOf('/')
        return lastSlash >= 0 ? p.substring(0, lastSlash + 1) : p
    }
    ToolTip.delay: 400

    function typeColor(type) {
        if (type === "文件夹") return Qt.rgba(123/255, 111/255, 240/255, 0.18)
        if (type === "MKV" || type === "MP4") return Qt.rgba(74/255, 240/255, 180/255, 0.12)
        if (type === "ISO" || type === "VMDK") return Qt.rgba(240/255, 196/255, 111/255, 0.12)
        if (type === "MOV") return Qt.rgba(240/255, 123/255, 111/255, 0.12)
        if (type === "JPG" || type === "PNG" || type === "GIF" || type === "WEBP") return Qt.rgba(240/255, 196/255, 111/255, 0.12)
        if (type === "MP3" || type === "FLAC" || type === "WAV") return Qt.rgba(74/255, 240/255, 180/255, 0.12)
        if (type === "PDF" || type === "DOC" || type === "DOCX") return Qt.rgba(240/255, 123/255, 111/255, 0.12)
        if (type === "ZIP" || type === "TAR" || type === "GZ") return Qt.rgba(240/255, 196/255, 111/255, 0.12)
        return Qt.rgba(123/255, 111/255, 240/255, 0.12)
    }
    function typeTextColor(type) {
        if (type === "文件夹") return Theme.accent2
        if (type === "MKV" || type === "MP4") return Theme.accent
        if (type === "ISO" || type === "VMDK") return Theme.accent4
        if (type === "MOV") return Theme.accent3
        if (type === "JPG" || type === "PNG" || type === "GIF" || type === "WEBP") return Theme.accent4
        if (type === "MP3" || type === "FLAC" || type === "WAV") return Theme.accent
        if (type === "PDF" || type === "DOC" || type === "DOCX") return Theme.accent3
        if (type === "ZIP" || type === "TAR" || type === "GZ") return Theme.accent4
        return Theme.accent2
    }
}
