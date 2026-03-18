import QtQuick 2.15
import QtQuick.Shapes
import "../theme" 1.0

Shape {
    id: shape

    property var item: parent
    property real innerRadius: 0
    property real outerRadius: 0
    property real startAngleDeg: 0
    property real sweepAngleDeg: 0
    property color fillColor: Theme.accent
    property string segmentUuid: ""
    property int segmentIndex: -1
    property int depthLevel: 0
    property string path: ""
    property string label: ""
    property real size: 0
    property bool isCenter: false

    readonly property real centerX: (item && item.width > 0) ? item.width / 2 : (parent ? parent.width / 2 : 0)
    readonly property real centerY: (item && item.height > 0) ? item.height / 2 : (parent ? parent.height / 2 : 0)

    anchors.fill: parent
    containsMode: Shape.FillContains
    preferredRendererType: Shape.CurveRenderer
    asynchronous: true

    ShapePath {
        id: centerPath
        fillColor: shape.fillColor
        strokeColor: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.5)
        strokeWidth: 1
        capStyle: ShapePath.FlatCap

        startX: shape.centerX
        startY: shape.centerY

        PathAngleArc {
            centerX: shape.centerX
            centerY: shape.centerY
            radiusX: shape.isCenter ? shape.outerRadius : 0
            radiusY: shape.isCenter ? shape.outerRadius : 0
            startAngle: 0
            sweepAngle: shape.isCenter ? 360 : 0
            moveToStart: true
        }

        PathMove {
            x: shape.centerX
            y: shape.centerY
        }
    }

    ShapePath {
        id: segmentPath
        fillColor: shape.isCenter ? "transparent" : shape.fillColor
        strokeColor: shape.isCenter ? "transparent" : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.7)
        strokeWidth: shape.isCenter ? 0 : 0.8
        capStyle: ShapePath.FlatCap

        startX: shape.isCenter ? shape.centerX : (shape.centerX + shape.innerRadius * Math.cos(shape.startAngleDeg * Math.PI / 180))
        startY: shape.isCenter ? shape.centerY : (shape.centerY + shape.innerRadius * Math.sin(shape.startAngleDeg * Math.PI / 180))

        PathAngleArc {
            centerX: shape.centerX
            centerY: shape.centerY
            radiusX: shape.isCenter ? 0 : shape.innerRadius
            radiusY: shape.isCenter ? 0 : shape.innerRadius
            startAngle: shape.startAngleDeg
            sweepAngle: shape.isCenter ? 0 : shape.sweepAngleDeg
            moveToStart: false
        }

        PathAngleArc {
            centerX: shape.centerX
            centerY: shape.centerY
            radiusX: shape.isCenter ? 0 : shape.outerRadius
            radiusY: shape.isCenter ? 0 : shape.outerRadius
            startAngle: shape.startAngleDeg + shape.sweepAngleDeg
            sweepAngle: shape.isCenter ? 0 : -shape.sweepAngleDeg
            moveToStart: false
        }

        PathLine {
            x: shape.isCenter ? shape.centerX : (shape.centerX + shape.innerRadius * Math.cos(shape.startAngleDeg * Math.PI / 180))
            y: shape.isCenter ? shape.centerY : (shape.centerY + shape.innerRadius * Math.sin(shape.startAngleDeg * Math.PI / 180))
        }
    }
}
