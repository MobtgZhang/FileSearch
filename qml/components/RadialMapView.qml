import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../theme" 1.0

ColumnLayout {
    id: radialMap
    Layout.preferredHeight: 260
    Layout.fillWidth: true
    spacing: 0

    property var categories: []
    property real usedSize: 0
    property real totalSize: 0

    readonly property bool isScanning: AppController.isScanning
    readonly property bool hasData: usedSize > 0 || totalSize > 0
    readonly property bool scanComplete: !isScanning && totalSize > 0

    readonly property var categoryLabels: ["视频", "文档", "图片", "音频", "系统", "其他"]
    readonly property var categoryColors: ["#4af0b4", "#7b6ff0", "#f07b6f", "#f0c46f", "#6b8e23", "#5a6478"]

    function formatSize(bytes) {
        var b = Number(bytes) || 0
        if (b >= 1024 * 1024 * 1024 * 1024)
            return (b / (1024 * 1024 * 1024 * 1024)).toFixed(1) + " TB"
        if (b >= 1024 * 1024 * 1024)
            return (b / (1024 * 1024 * 1024)).toFixed(1) + " GB"
        if (b >= 1024 * 1024)
            return (b / (1024 * 1024)).toFixed(1) + " MB"
        if (b >= 1024)
            return (b / 1024).toFixed(1) + " KB"
        return Math.round(b) + " B"
    }

    function getSizeForLabel(label) {
        for (var i = 0; i < radialMap.categories.length; i++) {
            if (radialMap.categories[i].labelShort === label)
                return radialMap.categories[i].sizeFormatted || "0 B"
        }
        return "0 B"
    }

    function getRawSizeForLabel(label) {
        for (var i = 0; i < radialMap.categories.length; i++) {
            if (radialMap.categories[i].labelShort === label)
                return Number(radialMap.categories[i].size) || 0
        }
        return 0
    }

    function getColorForLabel(label) {
        var idx = categoryLabels.indexOf(label)
        if (idx >= 0 && idx < categoryColors.length)
            return categoryColors[idx]
        return "#5a6478"
    }

    function getUsagePercent() {
        if (totalSize <= 0) return 0
        return Math.round(usedSize / totalSize * 100)
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 180
        Layout.topMargin: 8

        Canvas {
            id: canvas
            anchors.centerIn: parent
            width: 170
            height: 170

            property int hoveredIndex: -1

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var w = width, h = height
                var cx = w / 2, cy = h / 2
                var outerR = 72, innerR = 46
                var gap = 0.03

                ctx.beginPath()
                ctx.arc(cx, cy, innerR - 1, 0, 2 * Math.PI)
                ctx.fillStyle = Theme.panel
                ctx.fill()

                var cats = radialMap.categories
                var total = radialMap.totalSize > 0 ? radialMap.totalSize : radialMap.usedSize

                if (total <= 0 && (!cats || cats.length === 0)) {
                    ctx.strokeStyle = Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.3)
                    ctx.lineWidth = outerR - innerR
                    ctx.beginPath()
                    ctx.arc(cx, cy, (outerR + innerR) / 2, 0, 2 * Math.PI)
                    ctx.stroke()
                } else {
                    var startAngle = -Math.PI / 2

                    if (cats && cats.length > 0) {
                        var sum = 0
                        for (var i = 0; i < cats.length; i++)
                            sum += Number(cats[i].size) || 0
                        var displayTotal = sum > 0 ? sum : total

                        for (var j = 0; j < cats.length; j++) {
                            var seg = cats[j]
                            var sz = Number(seg.size) || 0
                            if (sz <= 0) continue
                            var ratio = sz / displayTotal
                            if (ratio < 0.003) continue

                            var endAngle = startAngle + 2 * Math.PI * ratio
                            var color = seg.color || radialMap.categoryColors[j] || Theme.accent

                            var segOuterR = (hoveredIndex === j) ? outerR + 3 : outerR

                            ctx.beginPath()
                            ctx.arc(cx, cy, segOuterR, startAngle + gap, endAngle - gap)
                            ctx.arc(cx, cy, innerR, endAngle - gap, startAngle + gap, true)
                            ctx.closePath()
                            ctx.fillStyle = color
                            ctx.fill()

                            startAngle = endAngle
                        }

                        if (sum < displayTotal && displayTotal > 0) {
                            var remainRatio = 1 - sum / displayTotal
                            if (remainRatio > 0.01) {
                                var remainEnd = startAngle + 2 * Math.PI * remainRatio
                                ctx.beginPath()
                                ctx.arc(cx, cy, outerR, startAngle + gap, remainEnd - gap)
                                ctx.arc(cx, cy, innerR, remainEnd - gap, startAngle + gap, true)
                                ctx.closePath()
                                ctx.fillStyle = Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.25)
                                ctx.fill()
                            }
                        }
                    } else {
                        var used = radialMap.usedSize
                        var usedRatio = total > 0 ? Math.min(1, used / total) : 0
                        ctx.beginPath()
                        ctx.arc(cx, cy, outerR, -Math.PI / 2 + gap, -Math.PI / 2 + 2 * Math.PI * usedRatio - gap)
                        ctx.arc(cx, cy, innerR, -Math.PI / 2 + 2 * Math.PI * usedRatio - gap, -Math.PI / 2 + gap, true)
                        ctx.closePath()
                        ctx.fillStyle = Theme.accent
                        ctx.fill()

                        if (usedRatio < 0.99) {
                            ctx.beginPath()
                            ctx.arc(cx, cy, outerR, -Math.PI / 2 + 2 * Math.PI * usedRatio + gap, -Math.PI / 2 + 2 * Math.PI - gap)
                            ctx.arc(cx, cy, innerR, -Math.PI / 2 + 2 * Math.PI - gap, -Math.PI / 2 + 2 * Math.PI * usedRatio + gap, true)
                            ctx.closePath()
                            ctx.fillStyle = Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.25)
                            ctx.fill()
                        }
                    }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.Bold
                color: Theme.bright
                text: radialMap.getUsagePercent() + "%"
                visible: radialMap.scanComplete
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.letterSpacing: 0.5
                color: Theme.muted
                text: "已用空间"
                visible: radialMap.scanComplete
            }

            Text {
                id: scanningText
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.accent
                text: "扫描中"
                visible: radialMap.isScanning
                opacity: scanTextPulse.pulseVal

                QtObject {
                    id: scanTextPulse
                    property real pulseVal: 1.0
                    SequentialAnimation on pulseVal {
                        running: radialMap.isScanning
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.3; duration: 700; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
                    }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: Theme.fontFamily
                font.pixelSize: 9
                color: Theme.muted
                text: radialMap.formatSize(radialMap.usedSize)
                visible: radialMap.isScanning && radialMap.usedSize > 0
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: Theme.muted
                text: "等待扫描"
                visible: !radialMap.isScanning && !radialMap.hasData
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        Layout.leftMargin: 20
        Layout.rightMargin: 20
        Layout.topMargin: 2
        Layout.bottomMargin: 4
        visible: radialMap.hasData

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: 6

            Rectangle {
                width: parent.width
                height: 4
                radius: 2
                color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.4)

                Rectangle {
                    width: {
                        if (radialMap.isScanning) return parent.width
                        var t = radialMap.totalSize > 0 ? radialMap.totalSize : radialMap.usedSize
                        if (t <= 0) return 0
                        return parent.width * Math.min(1, radialMap.usedSize / t)
                    }
                    height: parent.height
                    radius: 2
                    color: {
                        var pct = radialMap.getUsagePercent()
                        if (pct > 90) return Theme.accent3
                        if (pct > 70) return Theme.accent4
                        return Theme.accent
                    }

                    Behavior on width {
                        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                    }

                    opacity: radialMap.isScanning ? scanBarPulse.pulseVal : 1.0

                    QtObject {
                        id: scanBarPulse
                        property real pulseVal: 1.0
                        SequentialAnimation on pulseVal {
                            running: radialMap.isScanning
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.4; duration: 600 }
                            NumberAnimation { from: 0.4; to: 1.0; duration: 600 }
                        }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                Text {
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Theme.bright
                    text: radialMap.isScanning
                          ? "已扫描 " + radialMap.formatSize(radialMap.usedSize)
                          : radialMap.formatSize(radialMap.usedSize)
                }
                Text {
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.muted
                    text: "/"
                    visible: !radialMap.isScanning && radialMap.totalSize > 0
                }
                Text {
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.muted
                    text: radialMap.formatSize(radialMap.totalSize)
                    visible: !radialMap.isScanning && radialMap.totalSize > 0
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 14
        Layout.rightMargin: 14
        spacing: 3

        Repeater {
            model: radialMap.categoryLabels

            Rectangle {
                Layout.fillWidth: true
                height: 24
                radius: 4
                color: legendMa.containsMouse ? Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.4) : "transparent"

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: radialMap.getColorForLabel(modelData)
                    }

                    Text {
                        Layout.preferredWidth: 26
                        font.pixelSize: 10
                        font.family: Theme.fontFamily
                        color: Theme.text
                        text: modelData
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 3
                        radius: 1.5
                        color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.5)

                        Rectangle {
                            width: {
                                var catSize = radialMap.getRawSizeForLabel(modelData)
                                var total = radialMap.usedSize > 0 ? radialMap.usedSize : 1
                                return parent.width * Math.min(1, catSize / total)
                            }
                            height: parent.height
                            radius: 1.5
                            color: radialMap.getColorForLabel(modelData)

                            Behavior on width {
                                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    Text {
                        Layout.preferredWidth: 52
                        horizontalAlignment: Text.AlignRight
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        color: Theme.muted
                        text: radialMap.getSizeForLabel(modelData)
                    }
                }

                MouseArea {
                    id: legendMa
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
        }
    }

    onCategoriesChanged: canvas.requestPaint()
    onUsedSizeChanged: canvas.requestPaint()
    onTotalSizeChanged: canvas.requestPaint()
}
