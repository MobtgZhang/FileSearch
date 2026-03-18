import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme" 1.0

Popup {
    id: settingsPopup
    width: Math.min(820, parent ? parent.width - 60 : 820)
    height: Math.min(600, parent ? parent.height - 60 : 600)
    modal: true
    focus: true
    anchors.centerIn: parent
    padding: 0
    closePolicy: Popup.CloseOnEscape

    property int currentPage: 0

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.96; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120; easing.type: Easing.InCubic }
    }

    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.55) }

    background: Rectangle {
        color: Theme.bg
        radius: 14
        border.color: Theme.border
        border.width: 1
    }

    contentItem: RowLayout {
        spacing: 0

        // ══════════════════════════════════════════════════
        //  左侧导航栏
        // ══════════════════════════════════════════════════
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 180
            color: Theme.panel
            radius: 14

            Rectangle {
                anchors.right: parent.right
                width: 14
                height: parent.height
                color: parent.color
            }

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: Theme.border
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 20
                anchors.bottomMargin: 16
                spacing: 0

                RowLayout {
                    Layout.leftMargin: 20
                    Layout.bottomMargin: 24
                    spacing: 10

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 8
                        color: Theme.settingsAccent

                        Text {
                            anchors.centerIn: parent
                            text: "N"
                            color: "white"
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            font.family: Theme.fontDisplay
                        }
                    }

                    Text {
                        text: "设置"
                        color: Theme.bright
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        font.family: Theme.fontDisplay
                    }
                }

                Repeater {
                    model: [
                        { label: "通用", desc: "语言、主题、缓存" },
                        { label: "AI 模型", desc: "API 与模型选择" },
                        { label: "参数", desc: "采样与提示词" },
                        { label: "网络", desc: "搜索引擎与代理" }
                    ]

                    delegate: Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: {
                                if (index === settingsPopup.currentPage)
                                    return Qt.rgba(Theme.settingsAccent.r, Theme.settingsAccent.g, Theme.settingsAccent.b, 0.12)
                                if (navMouse.containsMouse)
                                    return Theme.highlight
                                return "transparent"
                            }
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Rectangle {
                            visible: index === settingsPopup.currentPage
                            width: 3
                            height: 20
                            radius: 2
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.settingsAccent
                        }

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: modelData.label
                                color: index === settingsPopup.currentPage ? Theme.bright : Theme.text
                                font.pixelSize: 13
                                font.weight: index === settingsPopup.currentPage ? Font.Medium : Font.Normal
                                font.family: Theme.fontDisplay
                            }
                            Text {
                                text: modelData.desc
                                color: Theme.muted
                                font.pixelSize: 10
                                font.family: Theme.fontDisplay
                            }
                        }

                        MouseArea {
                            id: navMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                settingsPopup.currentPage = index
                                contentFlick.contentY = 0
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    Layout.leftMargin: 20
                    text: "设置自动保存"
                    color: Theme.muted
                    font.pixelSize: 10
                    font.family: Theme.fontDisplay
                    opacity: 0.7
                }
            }
        }

        // ══════════════════════════════════════════════════
        //  右侧内容区
        // ══════════════════════════════════════════════════
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                Layout.leftMargin: 28
                Layout.rightMargin: 16

                Text {
                    text: ["通用设置", "AI 模型配置", "参数调整", "网络设置"][settingsPopup.currentPage]
                    color: Theme.bright
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    font.family: Theme.fontDisplay
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    color: closeHover.containsMouse ? Theme.highlight : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\u2715"
                        font.pixelSize: 13
                        color: closeHover.containsMouse ? Theme.bright : Theme.muted
                    }

                    MouseArea {
                        id: closeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsPopup.close()
                    }
                }
            }

            Flickable {
                id: contentFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: contentPages.implicitHeight + 40
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: Theme.muted
                        opacity: 0.3
                    }
                }

                ColumnLayout {
                    id: contentPages
                    width: contentFlick.width - 56
                    x: 28
                    y: 8
                    spacing: 16

                    // ────────────────────────────────────────
                    //  Page 0: 通用设置
                    // ────────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        visible: settingsPopup.currentPage === 0

                        SettingsCard {
                            cardTitle: "外观"

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 16
                                    Layout.rightMargin: 16
                                    Layout.topMargin: 4
                                    spacing: 12

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text { text: "语言"; color: Theme.text; font.pixelSize: 13; font.weight: Font.Medium; font.family: Theme.fontDisplay }
                                        Text { text: "选择界面显示语言"; color: Theme.muted; font.pixelSize: 11; font.family: Theme.fontDisplay }
                                    }

                                    StyledComboBox {
                                        id: langCombo
                                        model: ["zh", "en"]
                                        currentIndex: model.indexOf(appSettings ? appSettings.language : "zh")
                                        onActivated: if (appSettings) appSettings.language = model[currentIndex]
                                    }
                                }

                                CardDivider {}

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 16
                                    Layout.rightMargin: 16
                                    Layout.bottomMargin: 4
                                    spacing: 12

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text { text: "主题"; color: Theme.text; font.pixelSize: 13; font.weight: Font.Medium; font.family: Theme.fontDisplay }
                                        Text { text: "选择深色或浅色界面"; color: Theme.muted; font.pixelSize: 11; font.family: Theme.fontDisplay }
                                    }

                                    Rectangle {
                                        width: themeSegRow.implicitWidth + 6
                                        height: 34
                                        radius: 8
                                        color: Theme.input
                                        border.color: Theme.border

                                        Row {
                                            id: themeSegRow
                                            anchors.centerIn: parent
                                            spacing: 2

                                            Rectangle {
                                                width: darkLbl.implicitWidth + 24
                                                height: 28
                                                radius: 6
                                                color: (appSettings && appSettings.themeMode !== "light") ? Theme.settingsAccent : "transparent"
                                                Behavior on color { ColorAnimation { duration: 150 } }

                                                Text {
                                                    id: darkLbl
                                                    anchors.centerIn: parent
                                                    text: "深色"
                                                    color: (appSettings && appSettings.themeMode !== "light") ? "white" : Theme.text
                                                    font.pixelSize: 12
                                                    font.weight: Font.Medium
                                                    font.family: Theme.fontDisplay
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: if (appSettings) appSettings.themeMode = "dark"
                                                }
                                            }

                                            Rectangle {
                                                width: lightLbl.implicitWidth + 24
                                                height: 28
                                                radius: 6
                                                color: (appSettings && appSettings.themeMode === "light") ? Theme.settingsAccent : "transparent"
                                                Behavior on color { ColorAnimation { duration: 150 } }

                                                Text {
                                                    id: lightLbl
                                                    anchors.centerIn: parent
                                                    text: "浅色"
                                                    color: (appSettings && appSettings.themeMode === "light") ? "white" : Theme.text
                                                    font.pixelSize: 12
                                                    font.weight: Font.Medium
                                                    font.family: Theme.fontDisplay
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: if (appSettings) appSettings.themeMode = "light"
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        SettingsCard {
                            cardTitle: "存储"

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 16
                                Layout.rightMargin: 16
                                spacing: 8

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "缓存目录"; color: Theme.text; font.pixelSize: 13; font.weight: Font.Medium; font.family: Theme.fontDisplay }
                                    Text { text: "历史记录与会话配置存储位置"; color: Theme.muted; font.pixelSize: 11; font.family: Theme.fontDisplay }
                                }

                                FieldInput {
                                    id: cacheDirField
                                    Layout.fillWidth: true
                                    text: appSettings ? appSettings.cacheDir : ""
                                    placeholderText: "~/.cache/FileSearch/"
                                    onEditingFinished: if (appSettings) appSettings.cacheDir = text
                                }
                            }
                        }
                    }

                    // ────────────────────────────────────────
                    //  Page 1: AI 模型配置
                    // ────────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        visible: settingsPopup.currentPage === 1

                        SettingsCard {
                            cardTitle: "API 配置"

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 16
                                    Layout.rightMargin: 16
                                    Layout.topMargin: 4
                                    spacing: 8

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text { text: "API 地址"; color: Theme.text; font.pixelSize: 13; font.weight: Font.Medium; font.family: Theme.fontDisplay }
                                        Text { text: "OpenAI 兼容 API 端点"; color: Theme.muted; font.pixelSize: 11; font.family: Theme.fontDisplay }
                                    }

                                    FieldInput {
                                        id: apiUrlField
                                        Layout.fillWidth: true
                                        text: appSettings ? appSettings.apiBaseUrl : ""
                                        placeholderText: "https://api.openai.com/v1"
                                        onEditingFinished: if (appSettings) appSettings.apiBaseUrl = text
                                    }
                                }

                                CardDivider {}

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 16
                                    Layout.rightMargin: 16
                                    Layout.bottomMargin: 4
                                    spacing: 8

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text { text: "模型"; color: Theme.text; font.pixelSize: 13; font.weight: Font.Medium; font.family: Theme.fontDisplay }
                                        Text { text: "选择对话使用的模型"; color: Theme.muted; font.pixelSize: 11; font.family: Theme.fontDisplay }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        StyledComboBox {
                                            id: modelCombo
                                            Layout.fillWidth: true
                                            model: appSettings ? appSettings.apiModelList : []
                                            currentIndex: model.indexOf(appSettings ? appSettings.apiModel : "")
                                            onActivated: if (appSettings) appSettings.apiModel = model[currentIndex]
                                        }

                                        Rectangle {
                                            width: refreshRow.implicitWidth + 20
                                            height: 34
                                            radius: 8
                                            color: refreshMouse.containsMouse ? Theme.highlight : Theme.input
                                            border.color: Theme.border
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            Row {
                                                id: refreshRow
                                                anchors.centerIn: parent
                                                spacing: 6

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "\u21BB"
                                                    color: Theme.settingsAccent
                                                    font.pixelSize: 14
                                                }
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "刷新"
                                                    color: Theme.text
                                                    font.pixelSize: 12
                                                    font.family: Theme.fontDisplay
                                                }
                                            }

                                            MouseArea {
                                                id: refreshMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: if (appSettings) appSettings.refreshApiModelList()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ────────────────────────────────────────
                    //  Page 2: 参数调整
                    // ────────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        visible: settingsPopup.currentPage === 2

                        SettingsCard {
                            cardTitle: "采样参数"

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 16
                                Layout.rightMargin: 16
                                spacing: 0

                                SliderSection {
                                    label: "温度 (Temperature)"
                                    hint: "控制回复随机性，越高越随机"
                                    value: appSettings ? appSettings.modelTemperature : 0.7
                                    from: 0; to: 1; stepSize: 0.05
                                    scrollView: contentFlick
                                    onMoved: (v) => { if (appSettings) appSettings.modelTemperature = v }
                                }

                                CardDivider { Layout.leftMargin: -16; Layout.rightMargin: -16 }

                                SliderSection {
                                    label: "Top-K"
                                    hint: "采样时考虑的 token 数量"
                                    value: appSettings ? appSettings.topK : 40
                                    from: 1; to: 100; stepSize: 1; isInt: true
                                    scrollView: contentFlick
                                    onMoved: (v) => { if (appSettings) appSettings.topK = Math.round(v) }
                                }

                                CardDivider { Layout.leftMargin: -16; Layout.rightMargin: -16 }

                                SliderSection {
                                    label: "Top-P"
                                    hint: "核采样概率阈值"
                                    value: appSettings ? appSettings.topP : 0.9
                                    from: 0; to: 1; stepSize: 0.01
                                    scrollView: contentFlick
                                    onMoved: (v) => { if (appSettings) appSettings.topP = v }
                                }

                                CardDivider { Layout.leftMargin: -16; Layout.rightMargin: -16 }

                                SliderSection {
                                    label: "Max Tokens"
                                    hint: "单次回复最大 token 数"
                                    value: appSettings ? appSettings.maxTokens : 4096
                                    from: 64; to: 128000; stepSize: 256; isInt: true
                                    scrollView: contentFlick
                                    onMoved: (v) => { if (appSettings) appSettings.maxTokens = Math.round(v) }
                                }
                            }
                        }

                        SettingsCard {
                            cardTitle: "系统提示词"

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 16
                                Layout.rightMargin: 16
                                spacing: 8

                                Text {
                                    text: "定义 AI 的角色与行为"
                                    color: Theme.muted
                                    font.pixelSize: 11
                                    font.family: Theme.fontDisplay
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 120
                                    color: Theme.input
                                    radius: 8
                                    border.color: systemPromptArea.activeFocus ? Theme.settingsAccent : Theme.border
                                    border.width: systemPromptArea.activeFocus ? 2 : 1
                                    Behavior on border.color { ColorAnimation { duration: 100 } }

                                    ScrollView {
                                        id: systemPromptScroll
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        contentWidth: availableWidth
                                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                                        TextArea {
                                            id: systemPromptArea
                                            width: systemPromptScroll.width - 8
                                            text: appSettings ? appSettings.systemPrompt : ""
                                            onTextChanged: if (appSettings && activeFocus) appSettings.systemPrompt = text
                                            color: Theme.text
                                            font.pixelSize: 13
                                            font.family: Theme.fontDisplay
                                            wrapMode: TextArea.Wrap
                                            background: null
                                            selectByMouse: true
                                            placeholderText: "输入系统提示词..."
                                            placeholderTextColor: Theme.muted
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ────────────────────────────────────────
                    //  Page 3: 网络设置
                    // ────────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        visible: settingsPopup.currentPage === 3

                        SettingsCard {
                            cardTitle: "搜索"

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 16
                                Layout.rightMargin: 16
                                spacing: 12

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "搜索引擎"; color: Theme.text; font.pixelSize: 13; font.weight: Font.Medium; font.family: Theme.fontDisplay }
                                    Text { text: "联网搜索使用的引擎"; color: Theme.muted; font.pixelSize: 11; font.family: Theme.fontDisplay }
                                }

                                StyledComboBox {
                                    id: searchEngineCombo
                                    model: ["bing", "baidu", "duckduckgo"]
                                    currentIndex: model.indexOf(appSettings ? appSettings.webSearchEngine : "bing")
                                    onActivated: if (appSettings) appSettings.webSearchEngine = model[currentIndex]
                                }
                            }
                        }

                        SettingsCard {
                            cardTitle: "代理"

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 16
                                Layout.rightMargin: 16
                                spacing: 14

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text { text: "代理模式"; color: Theme.text; font.pixelSize: 13; font.weight: Font.Medium; font.family: Theme.fontDisplay }
                                        Text { text: "自动代理使用系统设置，手动需输入地址"; color: Theme.muted; font.pixelSize: 11; font.family: Theme.fontDisplay }
                                    }

                                    RowLayout {
                                        spacing: 10

                                        Text {
                                            text: "自动"
                                            color: (appSettings && appSettings.proxyMode !== "manual") ? Theme.bright : Theme.muted
                                            font.pixelSize: 12
                                            font.family: Theme.fontDisplay
                                            font.weight: (appSettings && appSettings.proxyMode !== "manual") ? Font.Medium : Font.Normal
                                        }

                                        Rectangle {
                                            id: proxySwitch
                                            width: 44
                                            height: 24
                                            radius: 12
                                            color: proxyIsManual ? Theme.settingsAccent : Theme.border
                                            property bool proxyIsManual: appSettings && appSettings.proxyMode === "manual"
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            Rectangle {
                                                width: 18
                                                height: 18
                                                radius: 9
                                                anchors.verticalCenter: parent.verticalCenter
                                                x: proxySwitch.proxyIsManual ? parent.width - width - 3 : 3
                                                color: "white"
                                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (appSettings)
                                                        appSettings.proxyMode = appSettings.proxyMode === "manual" ? "auto" : "manual"
                                                }
                                            }
                                        }

                                        Text {
                                            text: "手动"
                                            color: (appSettings && appSettings.proxyMode === "manual") ? Theme.bright : Theme.muted
                                            font.pixelSize: 12
                                            font.family: Theme.fontDisplay
                                            font.weight: (appSettings && appSettings.proxyMode === "manual") ? Font.Medium : Font.Normal
                                        }
                                    }
                                }

                                Text {
                                    visible: appSettings && appSettings.proxyMode === "auto"
                                    text: "当前使用系统代理配置"
                                    color: Theme.muted
                                    font.pixelSize: 11
                                    font.family: Theme.fontDisplay
                                    font.italic: true
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    visible: appSettings && appSettings.proxyMode === "manual"

                                    Text {
                                        text: "代理地址"
                                        color: Theme.text
                                        font.pixelSize: 12
                                        font.family: Theme.fontDisplay
                                    }

                                    FieldInput {
                                        id: proxyField
                                        Layout.fillWidth: true
                                        text: appSettings ? appSettings.proxyUrl : ""
                                        placeholderText: "http://127.0.0.1:7890"
                                        onEditingFinished: if (appSettings) appSettings.proxyUrl = text
                                    }
                                }
                            }
                        }
                    }

                    Item { height: 12 }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════
    //  内联组件定义
    // ══════════════════════════════════════════════════════════════

    component SettingsCard: Rectangle {
        property string cardTitle: ""
        default property alias content: cardContent.data

        Layout.fillWidth: true
        implicitHeight: cardInner.implicitHeight
        color: Theme.panel
        radius: 10
        border.color: Theme.border
        border.width: 1

        ColumnLayout {
            id: cardInner
            width: parent.width
            spacing: 0

            Text {
                visible: cardTitle !== ""
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.bottomMargin: 8
                text: cardTitle.toUpperCase()
                color: Theme.muted
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.family: Theme.fontDisplay
                font.letterSpacing: 1.2
            }

            ColumnLayout {
                id: cardContent
                Layout.fillWidth: true
                Layout.bottomMargin: 16
                Layout.topMargin: cardTitle !== "" ? 0 : 16
                spacing: 0
            }
        }
    }

    component CardDivider: Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 14
        Layout.bottomMargin: 14
        height: 1
        color: Theme.border
        opacity: 0.4
    }

    component FieldInput: TextField {
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        color: Theme.text
        font.pixelSize: 13
        font.family: Theme.fontDisplay
        placeholderTextColor: Theme.muted
        selectByMouse: true
        leftPadding: 12
        background: Rectangle {
            radius: 8
            color: Theme.input
            border.color: parent.activeFocus ? Theme.settingsAccent : Theme.border
            border.width: parent.activeFocus ? 2 : 1
            Behavior on border.color { ColorAnimation { duration: 100 } }
        }
    }

    component StyledComboBox: ComboBox {
        Layout.preferredWidth: 160
        Layout.preferredHeight: 34

        contentItem: Text {
            leftPadding: 12
            rightPadding: 28
            text: parent.displayText
            color: Theme.text
            font.pixelSize: 13
            font.family: Theme.fontDisplay
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        indicator: Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "\u25BE"
            color: Theme.muted
            font.pixelSize: 11
        }

        background: Rectangle {
            radius: 8
            color: Theme.input
            border.color: parent.activeFocus ? Theme.settingsAccent : Theme.border
            border.width: parent.activeFocus ? 2 : 1
            Behavior on border.color { ColorAnimation { duration: 100 } }
        }

        popup.background: Rectangle {
            color: Theme.popupBg
            radius: 8
            border.color: Theme.border
            border.width: 1
        }

        delegate: ItemDelegate {
            width: parent ? parent.width : 160
            leftPadding: 12
            hoverEnabled: true
            contentItem: Text {
                text: modelData
                color: Theme.text
                font.pixelSize: 13
                font.family: Theme.fontDisplay
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: (parent.highlighted || parent.hovered) ? Theme.highlight : "transparent"
                radius: 6
            }
        }
    }

    component SliderSection: ColumnLayout {
        property string label: ""
        property string hint: ""
        property real value: 0
        property real from: 0
        property real to: 1
        property real stepSize: 0.01
        property bool isInt: false
        property Item scrollView: null
        signal moved(real value)

        property real displayValue: value

        Layout.fillWidth: true
        spacing: 4

        onValueChanged: {
            if (!sliderCtrl.pressed && !valEdit.activeFocus) {
                sliderCtrl.value = value
                displayValue = value
                valEdit.text = fmtVal(value)
            }
        }

        function fmtVal(v) { return isInt ? Math.round(v).toString() : v.toFixed(2) }
        function clampVal(v) { return Math.max(from, Math.min(to, v)) }

        Component.onCompleted: {
            sliderCtrl.value = value
            displayValue = value
            valEdit.text = fmtVal(value)
        }

        Text {
            text: parent.label
            color: Theme.text
            font.pixelSize: 13
            font.weight: Font.Medium
            font.family: Theme.fontDisplay
        }
        Text {
            text: parent.hint
            color: Theme.muted
            font.pixelSize: 11
            font.family: Theme.fontDisplay
            visible: parent.hint !== ""
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Slider {
                id: sliderCtrl
                Layout.fillWidth: true
                Layout.minimumHeight: 28
                from: parent.parent.from
                to: parent.parent.to
                stepSize: parent.parent.stepSize
                value: 0

                onPressedChanged: {
                    if (pressed) sliderCtrl.forceActiveFocus()
                    if (scrollView && scrollView.contentItem) {
                        scrollView.contentItem.interactive = !pressed
                    } else if (scrollView) {
                        scrollView.interactive = !pressed
                    }
                }
                onMoved: {
                    parent.parent.displayValue = value
                    parent.parent.moved(value)
                    valEdit.text = parent.parent.fmtVal(value)
                }
                onValueChanged: {
                    if (pressed) {
                        parent.parent.displayValue = value
                        parent.parent.moved(value)
                        valEdit.text = parent.parent.fmtVal(value)
                    }
                }

                background: Rectangle {
                    x: sliderCtrl.leftPadding + (sliderCtrl.availableWidth - width) / 2
                    y: sliderCtrl.topPadding + (sliderCtrl.availableHeight - height) / 2
                    width: sliderCtrl.availableWidth - sliderCtrl.leftPadding - sliderCtrl.rightPadding
                    implicitWidth: 200
                    implicitHeight: 4
                    height: 4
                    radius: 2
                    color: Theme.border

                    Rectangle {
                        width: sliderCtrl.visualPosition * parent.width
                        height: parent.height
                        radius: 2
                        color: Theme.settingsAccent
                    }
                }

                handle: Rectangle {
                    x: sliderCtrl.leftPadding + sliderCtrl.visualPosition * (sliderCtrl.availableWidth - width)
                    y: sliderCtrl.topPadding + (sliderCtrl.availableHeight - height) / 2
                    implicitWidth: 16
                    implicitHeight: 16
                    width: 16
                    height: 16
                    radius: 8
                    color: sliderCtrl.pressed ? Qt.darker(Theme.settingsAccent, 1.1) : Theme.settingsAccent
                    border.color: Qt.darker(Theme.settingsAccent, 1.2)
                    border.width: 1

                    Rectangle {
                        visible: sliderCtrl.pressed
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        radius: 12
                        color: Qt.rgba(Theme.settingsAccent.r, Theme.settingsAccent.g, Theme.settingsAccent.b, 0.2)
                    }
                }
            }

            TextField {
                id: valEdit
                Layout.preferredWidth: 72
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: TextInput.AlignRight
                color: Theme.text
                font.pixelSize: 13
                font.family: Theme.fontDisplay
                selectByMouse: true
                leftPadding: 8
                rightPadding: 8
                background: Rectangle {
                    radius: 8
                    color: Theme.input
                    border.color: parent.activeFocus ? Theme.settingsAccent : Theme.border
                    border.width: parent.activeFocus ? 2 : 1
                    Behavior on border.color { ColorAnimation { duration: 100 } }
                }

                onEditingFinished: {
                    var ss = parent.parent
                    var v = parseFloat(text)
                    if (!isNaN(v)) {
                        if (ss.isInt) v = Math.round(v)
                        v = ss.clampVal(v)
                        ss.displayValue = v
                        ss.moved(v)
                        sliderCtrl.value = v
                        text = ss.fmtVal(v)
                    } else {
                        text = ss.fmtVal(ss.displayValue)
                    }
                }
                onTextChanged: {
                    if (!activeFocus) return
                    var v = parseFloat(text)
                    if (!isNaN(v)) parent.parent.displayValue = parent.parent.clampVal(v)
                }
            }
        }
    }

    onOpened: {
        settingsPopup.forceActiveFocus()
        currentPage = 0
        if (appSettings) {
            cacheDirField.text = appSettings.cacheDir
            apiUrlField.text = appSettings.apiBaseUrl
            modelCombo.model = appSettings.apiModelList
            modelCombo.currentIndex = modelCombo.model.indexOf(appSettings.apiModel)
            systemPromptArea.text = appSettings.systemPrompt
            searchEngineCombo.currentIndex = searchEngineCombo.model.indexOf(appSettings.webSearchEngine)
            proxyField.text = appSettings.proxyUrl
        }
    }
}
