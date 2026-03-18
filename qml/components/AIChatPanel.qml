import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtWebEngine
import QtWebChannel
import "../theme" 1.0

Rectangle {
    id: aiPanel
    Layout.preferredWidth: Theme.aiPanelWidth
    Layout.fillHeight: true
    color: Theme.surface
    border.color: Theme.border
    border.width: 1

    function applyThemeToWeb() {
        var wv = webLoader.item && webLoader.item.children && webLoader.item.children[0]
        if (!wv) return
        var mode = (typeof appSettings !== "undefined" && appSettings) ? appSettings.themeMode : "dark"
        wv.runJavaScript(
            "(function(){ setTimeout(function(){ var d=document.documentElement; if(d) d.setAttribute('data-theme','" + mode + "'); }, 0); })()"
        )
    }

    function pushJsCall(jsCode) {
        var wv = webLoader.item && webLoader.item.children && webLoader.item.children[0]
        if (wv) wv.runJavaScript(jsCode)
    }

    Connections {
        target: (typeof appSettings !== "undefined" && appSettings) ? appSettings : null
        function onThemeModeChanged() { aiPanel.applyThemeToWeb() }
    }

    Loader {
        id: webLoader
        anchors.fill: parent
        active: typeof aiChatHtmlPath !== "undefined" && aiChatHtmlPath !== ""

        sourceComponent: Component {
            Item {
                anchors.fill: parent
                QtObject {
                    id: channelBridge
                    WebChannel.id: "chatBridge"

                    function addUserMessage(text) {
                        if (typeof chatBridge !== "undefined" && chatBridge)
                            chatBridge.addUserMessage(text)
                    }
                    function addAiMessage(text) {
                        if (typeof chatBridge !== "undefined" && chatBridge)
                            chatBridge.addAiMessage(text)
                    }
                    function addToolExecution(name, status, result) {
                        if (typeof chatBridge !== "undefined" && chatBridge)
                            chatBridge.addToolExecution(name, status, result)
                    }
                    function setModelName(model) {
                        if (typeof chatBridge !== "undefined" && chatBridge)
                            chatBridge.setModelName(model)
                    }

                    property bool aiThinking: (typeof chatBridge !== "undefined" && chatBridge) ? chatBridge.aiThinking : false
                }

                WebEngineView {
                    id: webView
                    anchors.fill: parent
                    property string _theme: (typeof appSettings !== "undefined" && appSettings) ? appSettings.themeMode : "dark"
                    url: "file://" + aiChatHtmlPath + "?theme=" + _theme
                    backgroundColor: Theme.surface
                    webChannel.registeredObjects: [channelBridge]
                    userScripts.collection: [{
                        name: "qtwebchanneljs",
                        sourceUrl: "qrc:/qtwebchannel/qwebchannel.js",
                        injectionPoint: WebEngineScript.DocumentCreation,
                        worldId: WebEngineScript.MainWorld
                    }]
                    onLoadProgressChanged: function(progress) {
                        if (progress === 100) {
                            aiPanel.applyThemeToWeb()
                            themeSyncTimer.restart()
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: themeSyncTimer
        interval: 150
        repeat: false
        onTriggered: aiPanel.applyThemeToWeb()
    }

    Rectangle {
        anchors.fill: parent
        visible: !webLoader.active
        color: Theme.surface

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12

            Text {
                text: "✦"
                font.pixelSize: 32
                color: Theme.accent
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: "NexFile AI"
                font.pixelSize: 14
                font.weight: Font.Bold
                color: Theme.bright
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: "需要 Qt WebEngineQuick 模块\n请确保 ai-chat/index.html 路径正确"
                font.pixelSize: 11
                color: Theme.muted
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
