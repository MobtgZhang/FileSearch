import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import "../theme" 1.0

// 历史页：显示右侧对话部分的对话记录
Rectangle {
    id: historyPage
    color: Theme.panel
    border.color: Theme.border
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── 顶部标题 ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.5)
            border.color: Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 0.12
                        font.family: Theme.fontFamily
                        color: Theme.muted
                        text: "历史 · 对话记录"
                    }
                    Text {
                        font.pixelSize: 12
                        color: Theme.text
                        text: "来自右侧 AI 对话面板的聊天记录"
                    }
                }

                Button {
                    text: "清空"
                    font.pixelSize: 11
                    font.family: Theme.fontFamily
                    implicitHeight: 28
                    implicitWidth: 64
                    visible: ChatHistoryContext.history.length > 0
                    onClicked: clearConfirmDialog.open()
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(Theme.accent3, 1.2) : (parent.hovered ? Qt.lighter(Theme.accent3, 1.1) : Qt.rgba(Theme.accent3.r, Theme.accent3.g, Theme.accent3.b, 0.2))
                        border.color: Theme.accent3
                        border.width: 1
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: Theme.accent3
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // ── 对话列表 ──
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: historyPage.width - 24
                Layout.alignment: Qt.AlignTop
                anchors.margins: 12
                spacing: 16

                Repeater {
                    model: ChatHistoryContext.history

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: msgContent.implicitHeight + 36
                        color: modelData.role === "user"
                               ? Qt.rgba(Theme.accent2.r, Theme.accent2.g, Theme.accent2.b, 0.08)
                               : (modelData.role === "tool"
                                  ? Qt.rgba(Theme.accent4.r, Theme.accent4.g, Theme.accent4.b, 0.08)
                                  : Qt.rgba(0, 0, 0, 0.03))
                        border.color: Theme.border
                        border.width: 1
                        radius: 8

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                // 角色标签：更清晰的视觉区分
                                Rectangle {
                                    implicitWidth: roleLabel.width + 14
                                    implicitHeight: 20
                                    radius: 4
                                    color: modelData.role === "user"
                                           ? Qt.rgba(Theme.accent2.r, Theme.accent2.g, Theme.accent2.b, 0.15)
                                           : (modelData.role === "tool"
                                              ? Qt.rgba(Theme.accent4.r, Theme.accent4.g, Theme.accent4.b, 0.15)
                                              : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12))
                                    border.color: modelData.role === "user"
                                                   ? Qt.rgba(Theme.accent2.r, Theme.accent2.g, Theme.accent2.b, 0.35)
                                                   : (modelData.role === "tool"
                                                      ? Qt.rgba(Theme.accent4.r, Theme.accent4.g, Theme.accent4.b, 0.35)
                                                      : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25))
                                    border.width: 1

                                    Text {
                                        id: roleLabel
                                        anchors.centerIn: parent
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        font.family: Theme.fontFamily
                                        color: modelData.role === "user"
                                               ? Theme.accent2
                                               : (modelData.role === "tool" ? Theme.accent4 : Theme.accent)
                                        text: modelData.role === "user"
                                              ? "我"
                                              : (modelData.role === "tool" ? "工具" : "NexFile AI")
                                    }
                                }
                                Text {
                                    font.pixelSize: 10
                                    color: Theme.muted
                                    text: modelData.timestamp || ""
                                    visible: modelData.timestamp && modelData.timestamp.length > 0
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Item { Layout.fillWidth: true }
                            }

                            Text {
                                id: msgContent
                                Layout.fillWidth: true
                                font.pixelSize: 12
                                color: Theme.text
                                text: modelData.content
                                textFormat: Text.MarkdownText
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                // 空状态
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    visible: ChatHistoryContext.history.length === 0

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            font.pixelSize: 24
                            color: Theme.muted
                            text: "⟳"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            font.pixelSize: 12
                            color: Theme.muted
                            text: "暂无对话记录"
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }
    }

    MessageDialog {
        id: clearConfirmDialog
        title: "清空历史"
        text: "确定要清空所有对话记录吗？此操作不可恢复。"
        buttons: MessageDialog.Ok | MessageDialog.Cancel
        onAccepted: ChatHistoryContext.clearHistory()
    }
}
