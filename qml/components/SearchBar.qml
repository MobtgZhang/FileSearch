import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme" 1.0

Rectangle {
    id: searchBar
    Layout.fillWidth: true
    Layout.preferredHeight: Theme.searchBarHeight
    clip: true
    color: Theme.panel
    border.color: Theme.border
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 12
        layoutDirection: Qt.LeftToRight

        Text {
            text: "⌕"
            font.pixelSize: 18
            color: Theme.accent
            Layout.alignment: Qt.AlignVCenter
        }

        // 搜索输入框
        Rectangle {
            Layout.fillWidth: true
            Layout.minimumWidth: 120
            Layout.preferredHeight: 32
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
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                spacing: 10

                TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.minimumWidth: 60
                    Layout.alignment: Qt.AlignVCenter
                    placeholderText: "输入搜索条件..."
                    text: "*.mp4  size:>500MB"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.bright
                    background: Item {}
                    verticalAlignment: TextInput.AlignVCenter
                    topPadding: 3
                    bottomPadding: 3
                    leftPadding: 4
                    rightPadding: 4
                }

                Text {
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.muted
                    text: "— 找到 23 个结果，共 48.6 GB"
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        // 筛选标签
        Row {
            spacing: 6
            Layout.alignment: Qt.AlignVCenter
            FilterChip { label: "📁 类型: 视频"; chipColor: Theme.accent2 }
            FilterChip { label: "⬆ 大小 >500MB"; chipColor: Theme.accent3 }
            FilterChip { label: "🕐 最近 90 天"; chipColor: Theme.accent4 }
        }

        // AI 按钮
        Rectangle {
            Layout.preferredWidth: 100
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter
            radius: 8
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(74/255, 240/255, 180/255, 0.15) }
                GradientStop { position: 1; color: Qt.rgba(123/255, 111/255, 240/255, 0.15) }
            }
            border.color: Qt.rgba(74/255, 240/255, 180/255, 0.35)
            border.width: 1

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    width: 7
                    height: 7
                    radius: 4
                    color: Theme.accent
                    opacity: 0.8
                }

                Text {
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.05
                    color: Theme.accent
                    text: "AI 助手"
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: parent.opacity = 0.9
                onExited: parent.opacity = 1
                onClicked: { /* 打开 AI 面板 */ }
            }
        }
    }
}
