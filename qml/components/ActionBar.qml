import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme" 1.0

Rectangle {
    id: actionBar
    Layout.fillWidth: true
    Layout.preferredHeight: Theme.actionBarHeight
    clip: true
    color: Qt.rgba(74/255, 240/255, 180/255, 0.06)
    border.color: Qt.rgba(74/255, 240/255, 180/255, 0.15)
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        spacing: 8

        Text {
            font.family: Theme.fontFamily
            font.pixelSize: 11
            color: Theme.accent
            text: "✓ 已选 3 个文件，共 7.2 GB"
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        ActionButton {
            label: "🗑 删除"
            textColor: Theme.accent3
            borderColor: Qt.rgba(240/255, 123/255, 111/255, 0.3)
            bgColor: Qt.rgba(240/255, 123/255, 111/255, 0.08)
            Layout.alignment: Qt.AlignVCenter
        }
        ActionButton {
            label: "→ 移动"
            textColor: Theme.accent2
            borderColor: Qt.rgba(123/255, 111/255, 240/255, 0.3)
            bgColor: Qt.rgba(123/255, 111/255, 240/255, 0.08)
            Layout.alignment: Qt.AlignVCenter
        }
        ActionButton {
            label: "⬛ 压缩"
            textColor: Theme.accent4
            borderColor: Qt.rgba(240/255, 196/255, 111/255, 0.3)
            bgColor: Qt.rgba(240/255, 196/255, 111/255, 0.08)
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
