import QtQuick 2.15
import QtQuick.Controls 2.15
import "../theme" 1.0

Rectangle {
    id: cell
    property string label: ""
    property string size: ""
    property var gradientColors: ["#1a3a2a", "#0d2018"]

    radius: 6
    border.width: 1
    border.color: Qt.rgba(cell.gradientColors[0].r || 0.1, cell.gradientColors[0].g || 0.2, cell.gradientColors[0].b || 0.15, 0.25)

    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Qt.rgba(cell.gradientColors[0].r || 0.1, cell.gradientColors[0].g || 0.2, cell.gradientColors[0].b || 0.15, 0.15) }
        GradientStop { position: 1; color: Qt.rgba(cell.gradientColors[1].r || 0.05, cell.gradientColors[1].g || 0.12, cell.gradientColors[1].b || 0.1, 0.08) }
    }

    scale: cellMa.pressed ? 0.97 : 1.0

    Behavior on scale {
        NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        width: 3
        radius: 1.5
        color: cell.gradientColors[0]
        opacity: 0.7
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            font.pixelSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 0.05
            font.family: Theme.fontFamily
            color: Theme.bright
            text: cell.label
            elide: Text.ElideRight
        }
        Text {
            font.family: Theme.fontFamily
            font.pixelSize: 9
            color: Theme.muted
            text: cell.size
        }
    }

    MouseArea {
        id: cellMa
        anchors.fill: parent
        hoverEnabled: true
    }
}
