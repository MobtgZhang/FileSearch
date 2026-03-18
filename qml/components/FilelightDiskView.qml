import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Shapes
import "../theme" 1.0

Item {
    id: filelightView
    property var directoryTree: ({})
    property real usedSize: 0
    property real totalSize: 0
    property string focusedPath: ""
    property string hoveredUuid: ""
    property int visibleDepth: 4

    property var allSegments: []

    function getViewRoot() {
        if (!focusedPath || !directoryTree || !directoryTree.children)
            return directoryTree
        return findNodeByPath(directoryTree, focusedPath) || directoryTree
    }

    function findNodeByPath(node, path) {
        if (!node || !path) return null
        var p = path.endsWith("/") ? path.slice(0, -1) : path
        var nodePath = (node.path || "").replace(/\/$/, "")
        if (nodePath === p) return node
        var children = node.children || []
        for (var i = 0; i < children.length; i++) {
            var found = findNodeByPath(children[i], path)
            if (found) return found
        }
        return null
    }

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

    function hsvToColor(h, s, v) {
        h = ((h % 360) + 360) % 360
        s = Math.max(0, Math.min(1, s))
        v = Math.max(0, Math.min(1, v))
        var c = v * s
        var x = c * (1 - Math.abs((h / 60) % 2 - 1))
        var m = v - c
        var r, g, b
        if (h < 60)       { r = c; g = x; b = 0 }
        else if (h < 120) { r = x; g = c; b = 0 }
        else if (h < 180) { r = 0; g = c; b = x }
        else if (h < 240) { r = 0; g = x; b = c }
        else if (h < 300) { r = x; g = 0; b = c }
        else               { r = c; g = 0; b = x }
        return Qt.rgba(r + m, g + m, b + m, 1)
    }

    function segmentColor(startDeg, sweepDeg, depth, isFile, isMerged) {
        var midAngle = startDeg + sweepDeg / 2
        var h = ((midAngle % 360) + 360) % 360
        var darkness = 1.0 + depth * 0.06
        if (isMerged) {
            return hsvToColor(h, 0.25, Math.min(1.0, 0.85 / darkness))
        }
        if (isFile) {
            return hsvToColor(h, 0.12, Math.min(1.0, 0.90 / darkness))
        }
        var sat = Math.max(0.35, 0.70 - depth * 0.05)
        var val = Math.min(1.0, 0.95 / darkness)
        return hsvToColor(h, sat, val)
    }

    function buildMultiRingSegments() {
        var segs = []
        var tree = getViewRoot()
        if (!tree || !tree.children || width <= 0 || height <= 0)
            return segs

        var rootSize = Number(tree.size) || 0
        if (rootSize <= 0) return segs

        var maxR = Math.min(width, height) / 2 - 16
        var centerR = Math.max(24, maxR / (visibleDepth + 2))
        var ringWidth = (maxR - centerR) / (visibleDepth + 1)
        ringWidth = Math.max(16, Math.min(55, ringWidth))

        var minAngleDeg = 1.5

        var uid = 0
        function nextUid() { return "seg_" + (uid++) }

        function buildLevel(node, depth, startDeg, sweepDeg) {
            if (depth > visibleDepth) return
            var children = node.children || []
            if (children.length === 0) return

            var parentSize = Number(node.size) || 0
            if (parentSize <= 0) return

            var innerR = centerR + depth * ringWidth
            var outerR = innerR + ringWidth

            var validChildren = []
            for (var i = 0; i < children.length; i++) {
                var sz = Number(children[i].size) || 0
                if (sz > 0) validChildren.push({ node: children[i], size: sz })
            }
            validChildren.sort(function(a, b) { return b.size - a.size })

            var acc = 0
            var mergedSize = 0
            var mergedCount = 0
            for (var j = 0; j < validChildren.length; j++) {
                var v = validChildren[j]
                var childSweep = sweepDeg * (v.size / parentSize)
                if (childSweep < minAngleDeg) {
                    mergedSize += v.size
                    mergedCount++
                    continue
                }
                var childStart = startDeg + sweepDeg * (acc / parentSize)
                acc += v.size
                var isDir = !!(v.node.children && v.node.children.length > 0)
                var isFile = !v.node.isDirectory && !isDir
                var color = segmentColor(childStart, childSweep, depth, isFile, false)

                var segId = nextUid()
                segs.push({
                    innerRadius: innerR,
                    outerRadius: outerR,
                    startAngleDeg: childStart,
                    sweepAngleDeg: childSweep,
                    label: v.node.name || "?",
                    path: v.node.path || "",
                    size: v.size,
                    color: color,
                    depth: depth,
                    uuid: segId,
                    isFile: isFile,
                    isMerged: false
                })

                if (isDir && depth < visibleDepth) {
                    buildLevel(v.node, depth + 1, childStart, childSweep)
                }
            }

            if (mergedSize > 0) {
                var mergedSweep = sweepDeg * (mergedSize / parentSize)
                if (mergedSweep >= 0.5) {
                    var mergedStart = startDeg + sweepDeg * (acc / parentSize)
                    var segId = nextUid()
                    segs.push({
                        innerRadius: innerR,
                        outerRadius: outerR,
                        startAngleDeg: mergedStart,
                        sweepAngleDeg: mergedSweep,
                        label: mergedCount + " 项",
                        path: "",
                        size: mergedSize,
                        color: segmentColor(mergedStart, mergedSweep, depth, false, true),
                        depth: depth,
                        uuid: nextUid(),
                        isFile: false,
                        isMerged: true
                    })
                }
            }
        }

        buildLevel(tree, 0, 0, 360)
        return segs
    }

    function refreshSegments() {
        allSegments = buildMultiRingSegments()
    }

    Timer {
        id: deferBuild
        interval: 50
        repeat: false
        onTriggered: refreshSegments()
    }

    Item {
        id: shapeItem
        anchors.fill: parent
        antialiasing: true
        layer.enabled: true
        layer.samples: 4

        property var zOrderedShapes: []
        property bool hasShapes: allSegments.length > 0

        function objectToArray(obj) {
            var arr = []
            for (var i in obj) arr.push(obj[i])
            return arr
        }

        onChildrenChanged: {
            var ch = objectToArray(shapeItem.children)
            ch = ch.filter(function(c) { return c && c.hasOwnProperty("segmentUuid") && c.segmentUuid !== "" })
            ch.sort(function(a, b) {
                var dA = a.depthLevel || 0
                var dB = b.depthLevel || 0
                if (dA !== dB) return dA - dB
                return (b.z || 0) - (a.z || 0)
            })
            zOrderedShapes = ch
        }

        Repeater {
            model: allSegments
            delegate: FilelightSegmentShape {
                anchors.fill: parent
                z: 100 + (modelData.depth || 0)
                item: shapeItem
                innerRadius: modelData.innerRadius
                outerRadius: modelData.outerRadius
                startAngleDeg: modelData.startAngleDeg
                sweepAngleDeg: modelData.sweepAngleDeg
                fillColor: hoveredUuid === modelData.uuid ? Qt.lighter(modelData.color, 1.3) : modelData.color
                segmentUuid: modelData.uuid
                segmentIndex: index
                depthLevel: modelData.depth || 0
                path: modelData.path || ""
                label: modelData.label || ""
                size: modelData.size || 0
            }
        }

        FilelightSegmentShape {
            id: centerCircleShape
            z: 500
            visible: shapeItem.hasShapes
            anchors.fill: parent
            item: shapeItem
            isCenter: true
            innerRadius: 0
            outerRadius: {
                if (allSegments.length === 0) return 28
                var maxR = Math.min(filelightView.width, filelightView.height) / 2 - 16
                return Math.max(24, maxR / (visibleDepth + 2))
            }
            startAngleDeg: 0
            sweepAngleDeg: 360
            fillColor: hoveredUuid === "center" ? Qt.lighter(Theme.surface, 1.1) : Theme.surface
            segmentUuid: "center"
            segmentIndex: -1
            depthLevel: -1
            path: ""
            label: ""
            size: 0
        }

        Column {
            z: 501
            anchors.centerIn: parent
            visible: shapeItem.hasShapes
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: Math.max(9, centerCircleShape.outerRadius / 3.5)
                font.bold: true
                font.family: Theme.fontFamily
                color: Theme.text
                text: {
                    var tree = getViewRoot()
                    return tree ? (tree.name || "") : ""
                }
                elide: Text.ElideMiddle
                width: centerCircleShape.outerRadius * 1.2
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: Math.max(8, centerCircleShape.outerRadius / 4.5)
                font.family: Theme.fontFamily
                color: Theme.muted
                text: formatSize(usedSize)
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !shapeItem.hasShapes
            font.pixelSize: 12
            font.family: Theme.fontFamily
            color: Theme.muted
            text: AppController.isScanning ? "扫描中..." : "选择目录并点击开始扫描"
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        function findTarget(mouse) {
            var cx = shapeItem.width / 2
            var cy = shapeItem.height / 2
            var dx = mouse.x - cx
            var dy = mouse.y - cy
            var dist = Math.sqrt(dx * dx + dy * dy)

            if (dist <= centerCircleShape.outerRadius)
                return { type: "center", segment: null }

            var angle = Math.atan2(dy, dx) * 180 / Math.PI
            if (angle < 0) angle += 360

            var bestSeg = null
            var bestDepth = -1
            for (var i = 0; i < allSegments.length; i++) {
                var s = allSegments[i]
                if (dist >= s.innerRadius && dist <= s.outerRadius) {
                    var segStart = ((s.startAngleDeg % 360) + 360) % 360
                    var segEnd = segStart + s.sweepAngleDeg
                    var testAngle = angle
                    if (testAngle < segStart) testAngle += 360
                    if (testAngle >= segStart && testAngle <= segEnd) {
                        if (s.depth > bestDepth) {
                            bestSeg = s
                            bestDepth = s.depth
                        }
                    }
                }
            }

            if (bestSeg)
                return { type: "segment", segment: bestSeg }

            return null
        }

        onPositionChanged: function(mouse) {
            var hit = findTarget(mouse)
            if (hit) {
                if (hit.type === "center") {
                    hoveredUuid = "center"
                    tooltipItem.visible = false
                } else if (hit.segment) {
                    hoveredUuid = hit.segment.uuid
                    tooltipItem.text = hit.segment.label + " — " + formatSize(hit.segment.size)
                    tooltipItem.x = mouse.x + 12
                    tooltipItem.y = mouse.y - 24
                    tooltipItem.visible = true
                }
            } else {
                hoveredUuid = ""
                tooltipItem.visible = false
            }
        }

        onExited: {
            hoveredUuid = ""
            tooltipItem.visible = false
        }

        onClicked: function(mouse) {
            var hit = findTarget(mouse)
            if (!hit) return
            if (hit.type === "center") {
                if (focusedPath) {
                    var lastSlash = focusedPath.replace(/\/$/, "").lastIndexOf("/")
                    focusedPath = lastSlash > 0 ? focusedPath.substring(0, lastSlash) : ""
                } else {
                    focusedPath = ""
                }
                return
            }
            if (hit.segment && hit.segment.path && !hit.segment.isMerged && !hit.segment.isFile)
                focusedPath = hit.segment.path
        }
    }

    Rectangle {
        id: tooltipItem
        visible: false
        z: 600
        property alias text: tooltipLabel.text
        width: tooltipLabel.implicitWidth + 16
        height: tooltipLabel.implicitHeight + 8
        radius: 4
        color: Theme.surface
        border.color: Theme.border
        border.width: 1

        Text {
            id: tooltipLabel
            anchors.centerIn: parent
            font.pixelSize: 11
            font.family: Theme.fontFamily
            color: Theme.text
            text: ""
        }
    }

    Connections {
        target: AppController
        function onIsScanningChanged() { deferBuild.restart() }
    }

    onDirectoryTreeChanged: {
        focusedPath = ""
        deferBuild.restart()
    }
    onFocusedPathChanged: deferBuild.restart()
    onWidthChanged: deferBuild.restart()
    onHeightChanged: deferBuild.restart()
    onVisibleDepthChanged: deferBuild.restart()
}
