import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme" 1.0

Rectangle {
    id: sidebar
    Layout.preferredWidth: Theme.sidebarWidth
    Layout.fillHeight: true
    color: Theme.surface
    border.color: Theme.border
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        spacing: 6

        NavIcon {
            icon: "🔍"
            active: AppController.currentPage === "search"
            tooltip: "搜索"
            onClicked: function() { AppController.currentPage = "search" }
        }
        NavIcon {
            icon: "◎"
            active: AppController.currentPage === "disk"
            tooltip: "磁盘可视化"
            onClicked: function() { AppController.currentPage = "disk" }
        }
        NavIcon {
            icon: "🧹"
            active: AppController.currentPage === "cleanup"
            tooltip: "系统清理"
            onClicked: function() { AppController.currentPage = "cleanup" }
        }

        Rectangle {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 1
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            Layout.bottomMargin: 6
            color: Theme.border
        }

        NavIcon {
            icon: "☆"
            active: AppController.currentPage === "favorites"
            tooltip: "收藏"
            onClicked: function() { AppController.currentPage = "favorites" }
        }
        NavIcon {
            icon: "⟳"
            active: AppController.currentPage === "history"
            tooltip: "历史"
            onClicked: function() { AppController.currentPage = "history" }
        }

        Item { Layout.fillHeight: true }

        NavIcon {
            icon: "⚙"
            tooltip: "设置"
            onClicked: function() { AppController.openSettingsRequested() }
        }
    }
}
