import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// AeroResearch: proximity (근접 센서) window. Shows the DISTANCE_SENSOR readings per direction
// as a top-down radar plus a list. Toggled from the quick tools menu (Ctrl+F).
AeroFloatingPanel {
    id:             control
    title:          qsTr("근접 센서")
    settingsKey:    "ProximityWindow"
    panelWidth:     _u * 17
    badgeText:      _closest < _warnDistance ? qsTr("근접 %1 m").arg(_closest.toFixed(1)) : ""
    badgeColor:     _closest < _dangerDistance ? "#FF4D4D" : "#FFB020"

    readonly property real _u:              ScreenTools.defaultFontPixelHeight
    readonly property real _warnDistance:   5.0
    readonly property real _dangerDistance: 2.0

    property var    _vehicle:   QGroundControl.multiVehicleManager.activeVehicle
    property var    _sensors:   _vehicle ? _vehicle.distanceSensors : null
    property real   _maxRange:  _value(_sensors ? _sensors.maxDistance : null, 0) > 0 ? _sensors.maxDistance.rawValue : 10

    // Eight horizontal sectors clockwise from the nose, then up / down
    readonly property var _sectorNames: ["rotationNone", "rotationYaw45", "rotationYaw90", "rotationYaw135",
                                         "rotationYaw180", "rotationYaw225", "rotationYaw270", "rotationYaw315"]
    readonly property var _sectorLabels: [qsTr("전방"), qsTr("전방 우"), qsTr("우측"), qsTr("후방 우"),
                                          qsTr("후방"), qsTr("후방 좌"), qsTr("좌측"), qsTr("전방 좌")]

    property var _distances: {
        var list = []
        for (var i = 0; i < _sectorNames.length; i++) {
            list.push(_value(_sensors ? _sensors[_sectorNames[i]] : null, NaN))
        }
        return list
    }
    property real _up:      _value(_sensors ? _sensors.rotationPitch90 : null, NaN)
    property real _down:    _value(_sensors ? _sensors.rotationPitch270 : null, NaN)
    property real _closest: {
        var m = Infinity
        for (var i = 0; i < _distances.length; i++) {
            if (!isNaN(_distances[i])) {
                m = Math.min(m, _distances[i])
            }
        }
        return m
    }
    property bool _hasData: _closest !== Infinity || !isNaN(_up) || !isNaN(_down)

    visible: globals.aeroProximityPanelVisible

    function _value(fact, fallback) {
        if (!fact) {
            return fallback
        }
        var v = fact.rawValue
        return (v === undefined || v === null || isNaN(v)) ? fallback : Number(v)
    }

    function _color(d) {
        if (isNaN(d)) {
            return "#33383D"
        }
        return d < _dangerDistance ? "#FF4D4D" : (d < _warnDistance ? "#FFB020" : "#3DDC84")
    }

    function _text(d) {
        return isNaN(d) ? "—" : d.toFixed(1) + " m"
    }

    RowLayout {
        Layout.fillWidth:   true
        QGCLabel {
            Layout.fillWidth:   true
            text:               control._hasData ? qsTr("최대 %1 m").arg(control._maxRange.toFixed(0)) : qsTr("센서 데이터 없음")
            color:              "#9BA1A6"
            font.pointSize:     ScreenTools.smallFontPointSize
        }
        QGCButton {
            text:           "✕"
            heightFactor:   0.3
            onClicked:      globals.aeroProximityPanelVisible = false
        }
    }

    // Top-down radar: nose up, sectors coloured by distance
    Canvas {
        id:                     radar
        Layout.alignment:       Qt.AlignHCenter
        Layout.preferredWidth:  control._u * 13
        Layout.preferredHeight: Layout.preferredWidth

        property var distances: control._distances
        onDistancesChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            var cx = width / 2
            var cy = height / 2
            var r = Math.min(cx, cy) - 2
            ctx.reset()

            // range rings
            ctx.strokeStyle = "#2A2D31"
            ctx.lineWidth = 1
            for (var ring = 1; ring <= 3; ring++) {
                ctx.beginPath()
                ctx.arc(cx, cy, r * ring / 3, 0, Math.PI * 2)
                ctx.stroke()
            }

            // sectors: 45° wedges centred on each direction, filled out to the measured distance
            for (var i = 0; i < 8; i++) {
                var d = distances[i]
                var mid = -Math.PI / 2 + i * Math.PI / 4
                var a0 = mid - Math.PI / 8 + 0.04
                var a1 = mid + Math.PI / 8 - 0.04
                var len = isNaN(d) ? r : r * Math.max(0.12, Math.min(1, d / control._maxRange))
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.arc(cx, cy, len, a0, a1)
                ctx.closePath()
                ctx.fillStyle = isNaN(d) ? "rgba(255,255,255,0.04)" : control._color(d)
                ctx.globalAlpha = isNaN(d) ? 1 : 0.55
                ctx.fill()
                ctx.globalAlpha = 1
            }

            // vehicle marker (nose up)
            ctx.fillStyle = "#FF7A1A"
            ctx.beginPath()
            ctx.moveTo(cx, cy - r * 0.1)
            ctx.lineTo(cx + r * 0.07, cy + r * 0.07)
            ctx.lineTo(cx - r * 0.07, cy + r * 0.07)
            ctx.closePath()
            ctx.fill()
        }
    }

    GridLayout {
        Layout.fillWidth:   true
        columns:            4
        columnSpacing:      control._u * 0.4
        rowSpacing:         control._u * 0.1

        Repeater {
            model: 8
            delegate: RowLayout {
                Layout.columnSpan:  2
                Layout.fillWidth:   true
                QGCLabel {
                    Layout.fillWidth:   true
                    text:               control._sectorLabels[index]
                    color:              "#9BA1A6"
                    font.pointSize:     ScreenTools.smallFontPointSize
                }
                QGCLabel {
                    text:           control._text(control._distances[index])
                    color:          control._color(control._distances[index])
                    font.bold:      true
                    font.family:    ScreenTools.fixedFontFamily
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }
        }

        RowLayout {
            Layout.columnSpan:  2
            Layout.fillWidth:   true
            QGCLabel { Layout.fillWidth: true; text: qsTr("상방"); color: "#9BA1A6"; font.pointSize: ScreenTools.smallFontPointSize }
            QGCLabel { text: control._text(control._up); color: control._color(control._up); font.bold: true; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize }
        }
        RowLayout {
            Layout.columnSpan:  2
            Layout.fillWidth:   true
            QGCLabel { Layout.fillWidth: true; text: qsTr("하방"); color: "#9BA1A6"; font.pointSize: ScreenTools.smallFontPointSize }
            QGCLabel { text: control._text(control._down); color: control._color(control._down); font.bold: true; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.smallFontPointSize }
        }
    }
}
