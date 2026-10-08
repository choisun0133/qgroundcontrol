import QtCore
import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// Bottom-right primary flight display (design "A"): ground-speed tape, artificial horizon with
// pitch ladder and roll scale, altitude tape with climb-rate bar, heading strip and summary chips.
Rectangle {
    id:             control
    implicitWidth:  _u * 30
    implicitHeight: mainColumn.implicitHeight + _pad * 2
    radius:         _u * 0.5
    color:          Qt.rgba(0.055, 0.059, 0.067, 0.94 * _userOpacity)
    border.color:   Qt.rgba(0.165, 0.176, 0.192, _userOpacity)
    border.width:   1

    // AeroResearch: user size / transparency (gear button, saved between runs)
    scale:              _userScale
    transformOrigin:    Item.BottomRight

    property real _userScale:   prefs.panelScale
    property real _userOpacity: prefs.panelOpacity
    property bool _showPrefs:   false

    Settings {
        id:         prefs
        category:   "AeroInstrumentPanel"
        property real panelScale:   1.0
        property real panelOpacity: 1.0
    }

    function _stepScale(d)      { prefs.panelScale = Math.round(Math.max(0.6, Math.min(1.6, prefs.panelScale + d)) * 10) / 10 }
    function _stepOpacity(d)    { prefs.panelOpacity = Math.round(Math.max(0.3, Math.min(1.0, prefs.panelOpacity + d)) * 10) / 10 }

    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    readonly property real  _u:         ScreenTools.defaultFontPixelHeight
    readonly property real  _pad:       _u * 0.6
    readonly property color _accent:    QGroundControl.globalPalette.brandingBlue
    readonly property color _border:    "#2A2D31"
    readonly property color _tapeBg:    "#0B0C0D"
    readonly property color _muted:     "#9BA1A6"
    readonly property color _sky:       "#2F6FA8"
    readonly property color _ground:    "#7A5432"

    function _num(fact) {
        return fact && !isNaN(fact.rawValue) ? fact.value : NaN
    }

    property real _roll:        _activeVehicle ? _num(_activeVehicle.roll) : NaN
    property real _pitch:       _activeVehicle ? _num(_activeVehicle.pitch) : NaN
    property real _heading:     _activeVehicle ? _num(_activeVehicle.heading) : NaN
    property real _speed:       _activeVehicle ? _num(_activeVehicle.groundSpeed) : NaN
    property real _alt:         _activeVehicle ? _num(_activeVehicle.altitudeRelative) : NaN
    property real _climb:       _activeVehicle ? _num(_activeVehicle.climbRate) : NaN

    function _fmt(v, d)     { return isNaN(v) ? "—" : v.toFixed(d) }
    function _signed(v, d)  { return isNaN(v) ? "—" : (v > 0.05 ? "+" : (v < -0.05 ? "−" : "")) + Math.abs(v).toFixed(d) }
    function _hdgText(h)    { return isNaN(h) ? "—" : ("00" + (Math.round(h) % 360)).slice(-3) }

    // Tick list for a moving tape centred on value; pxPerUnit sets the scale
    function _tape(value, step, pxPerUnit, halfHeight, minValue) {
        var list = []
        if (isNaN(value)) {
            return list
        }
        var base = Math.round(value / step) * step
        for (var v = base - step * 4; v <= base + step * 4; v += step) {
            var y = halfHeight + (value - v) * pxPerUnit
            // keep clear of the title (top), the value box (centre) and the bottom edge
            if (y > _u * 1.5 && y < halfHeight * 2 - _u * 0.5 && Math.abs(y - halfHeight) > _u * 1.1 && v >= minValue) {
                list.push({ y: y, label: v.toFixed(0) })
            }
        }
        return list
    }

    component Tape: Rectangle {
        id:         tape
        property string title
        property real   value:      NaN
        property int    decimals:   1
        property real   step:       2
        property real   pxPerUnit:  10
        property bool   leftSide:   true
        property real   minValue:   -1e9
        color:          control._tapeBg
        border.color:   control._border
        radius:         control._u * 0.25
        clip:           true

        QGCLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            y:              control._u * 0.2
            text:           tape.title
            color:          control._muted
            font.pointSize: ScreenTools.smallFontPointSize
            z:              2
        }

        Repeater {
            model: control._tape(tape.value, tape.step, tape.pxPerUnit, tape.height / 2, tape.minValue)

            Item {
                y:      modelData.y
                width:  tape.width
                Rectangle {
                    x:      tape.leftSide ? tape.width - width : 0
                    width:  control._u * 0.5
                    height: 2
                    color:  "#5A6066"
                }
                QGCLabel {
                    x:              tape.leftSide ? tape.width - width - control._u * 0.7 : control._u * 0.7
                    y:              -height / 2
                    text:           modelData.label
                    color:          control._muted
                    font.family:    ScreenTools.fixedFontFamily
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }
        }

        // Current value box
        Rectangle {
            x:              tape.leftSide ? control._u * 0.2 : 0
            width:          tape.width - control._u * 0.2
            height:         control._u * 1.9
            anchors.verticalCenter: parent.verticalCenter
            color:          "#0E0F11"
            border.color:   control._accent
            border.width:   2
            radius:         control._u * 0.2
            QGCLabel {
                anchors.centerIn:   parent
                text:               control._fmt(tape.value, tape.decimals)
                font.family:        ScreenTools.fixedFontFamily
                font.pointSize:     ScreenTools.mediumFontPointSize
                font.bold:          true
            }
        }
    }

    ColumnLayout {
        id:         mainColumn
        x:          control._pad
        y:          control._pad
        width:      control.width - control._pad * 2
        spacing:    control._pad
        opacity:    control._userOpacity

        RowLayout {
            Layout.fillWidth:       true
            Layout.preferredHeight: control._u * 13
            spacing:                control._pad

            Tape {
                Layout.preferredWidth:  control._u * 3.6
                Layout.fillHeight:      true
                title:                  qsTr("속도 m/s")
                value:                  control._speed
                step:                   2
                pxPerUnit:              control._u * 1.2
                leftSide:               true
                minValue:               0
            }

            // Artificial horizon
            Rectangle {
                id:                     horizon
                Layout.fillWidth:       true
                Layout.fillHeight:      true
                radius:                 control._u * 0.25
                color:                  control._sky
                border.color:           control._border
                clip:                   true

                readonly property real pxPerDeg: height / 50
                readonly property real rollDeg:  isNaN(control._roll) ? 0 : control._roll
                readonly property real pitchDeg: isNaN(control._pitch) ? 0 : control._pitch

                Item {
                    id:             horizonBody
                    width:          horizon.width * 3
                    height:         horizon.height * 4
                    x:              (horizon.width - width) / 2
                    y:              (horizon.height - height) / 2 + horizon.pitchDeg * horizon.pxPerDeg
                    transformOrigin: Item.Center
                    rotation:       -horizon.rollDeg

                    Rectangle {
                        y:      parent.height / 2
                        width:  parent.width
                        height: parent.height / 2
                        color:  control._ground
                    }
                    Rectangle {
                        y:      parent.height / 2 - 1
                        width:  parent.width
                        height: 2
                        color:  "#ECEDEE"
                    }

                    // Pitch ladder: long lines every 10°, short every 5°
                    Repeater {
                        model: [-30, -25, -20, -15, -10, -5, 5, 10, 15, 20, 25, 30]
                        Item {
                            readonly property bool major: modelData % 10 === 0
                            x:      horizonBody.width / 2
                            y:      horizonBody.height / 2 - modelData * horizon.pxPerDeg
                            Rectangle {
                                x:      -width / 2
                                width:  parent.major ? control._u * 3.2 : control._u * 1.4
                                height: 2
                                color:  "#ECEDEE"
                            }
                            QGCLabel {
                                visible:        parent.major
                                x:              control._u * 1.9
                                y:              -height / 2
                                text:           Math.abs(modelData)
                                font.family:    ScreenTools.fixedFontFamily
                                font.pointSize: ScreenTools.smallFontPointSize
                            }
                        }
                    }
                }

                // Roll scale (fixed) and roll pointer (rotates with the vehicle)
                Item {
                    id:         rollScale
                    anchors.horizontalCenter: parent.horizontalCenter
                    y:          control._u * 0.6
                    width:      1
                    height:     1
                    readonly property real radius: horizon.height * 0.42

                    Repeater {
                        model: [-60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60]
                        Rectangle {
                            width:      2
                            height:     modelData % 30 === 0 ? control._u * 0.7 : control._u * 0.4
                            color:      "#ECEDEE"
                            x:          -1
                            y:          0
                            transform:  Rotation { origin.x: 1; origin.y: rollScale.radius; angle: modelData }
                        }
                    }
                    Canvas {
                        id:         rollPointer
                        width:      control._u * 0.8
                        height:     control._u * 0.6
                        x:          -width / 2
                        y:          control._u * 0.75
                        transform:  Rotation { origin.x: rollPointer.width / 2; origin.y: rollScale.radius - control._u * 0.75; angle: -horizon.rollDeg }
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.fillStyle = control._accent
                            ctx.beginPath()
                            ctx.moveTo(width / 2, 0)
                            ctx.lineTo(width, height)
                            ctx.lineTo(0, height)
                            ctx.closePath()
                            ctx.fill()
                        }
                    }
                }

                // Fixed aircraft symbol
                Item {
                    anchors.centerIn: parent
                    width:  control._u * 7
                    height: control._u
                    Rectangle { x: 0;                          y: 0; width: parent.width * 0.3; height: control._u * 0.28; radius: height / 2; color: control._accent }
                    Rectangle { x: parent.width * 0.7;         y: 0; width: parent.width * 0.3; height: control._u * 0.28; radius: height / 2; color: control._accent }
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: -height / 2 + control._u * 0.14; width: control._u * 0.5; height: width; radius: width / 2; color: control._accent }
                }

                QGCLabel {
                    anchors.left:       parent.left
                    anchors.bottom:     parent.bottom
                    anchors.margins:    control._u * 0.4
                    text:               qsTr("롤 %1° · 피치 %2°").arg(control._signed(control._roll, 0)).arg(control._signed(control._pitch, 0))
                    font.family:        ScreenTools.fixedFontFamily
                    font.pointSize:     ScreenTools.smallFontPointSize
                    style:              Text.Outline
                    styleColor:         "#000000"
                }
            }

            Tape {
                id:                     altTape
                Layout.preferredWidth:  control._u * 4
                Layout.fillHeight:      true
                title:                  qsTr("고도 m")
                value:                  control._alt
                step:                   10
                pxPerUnit:              control._u * 0.22
                leftSide:               false

                // Climb-rate bar on the right edge: up = climbing, down = descending
                Rectangle {
                    readonly property real len: isNaN(control._climb) ? 0 : Math.min(altTape.height * 0.4, Math.abs(control._climb) * control._u * 1.2)
                    x:      altTape.width - width - 2
                    width:  control._u * 0.3
                    radius: width / 2
                    height: len
                    y:      control._climb >= 0 ? altTape.height / 2 - len : altTape.height / 2
                    color:  control._climb > 0.2 ? "#3DDC84" : (control._climb < -0.2 ? "#F5C518" : "#5A6066")
                    z:      3
                }
            }
        }

        // Heading strip
        Rectangle {
            id:                     hdgStrip
            Layout.fillWidth:       true
            Layout.preferredHeight: control._u * 1.8
            color:                  control._tapeBg
            border.color:           control._border
            radius:                 control._u * 0.25
            clip:                   true

            readonly property real pxPerDeg: width / 120

            Repeater {
                model: {
                    var list = []
                    if (isNaN(control._heading)) {
                        return list
                    }
                    var names = { 0: qsTr("북"), 90: qsTr("동"), 180: qsTr("남"), 270: qsTr("서") }
                    var base = Math.round(control._heading / 15) * 15
                    for (var d = base - 75; d <= base + 75; d += 15) {
                        var h = ((d % 360) + 360) % 360
                        var off = d - control._heading
                        if (Math.abs(off) < 10) {
                            continue
                        }
                        list.push({ x: hdgStrip.width / 2 + off * hdgStrip.pxPerDeg, label: names[h] !== undefined ? names[h] : String(h), cardinal: names[h] !== undefined })
                    }
                    return list
                }
                QGCLabel {
                    x:              modelData.x - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    text:           modelData.label
                    color:          modelData.cardinal ? "#ECEDEE" : control._muted
                    font.bold:      modelData.cardinal
                    font.family:    ScreenTools.fixedFontFamily
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }

            Rectangle {
                anchors.horizontalCenter:   parent.horizontalCenter
                height:                     parent.height
                width:                      hdgLabel.width + control._u
                color:                      "#0E0F11"
                border.color:               control._accent
                border.width:               2
                radius:                     control._u * 0.2
                QGCLabel {
                    id:                 hdgLabel
                    anchors.centerIn:   parent
                    text:               control._hdgText(control._heading) + "°"
                    font.family:        ScreenTools.fixedFontFamily
                    font.bold:          true
                }
            }
        }

        // Summary chips
        GridLayout {
            Layout.fillWidth:   true
            columns:            4
            columnSpacing:      control._pad
            rowSpacing:         control._pad

            Repeater {
                model: [
                    { k: qsTr("상승/하강"), v: control._signed(control._climb, 1) + " m/s" },
                    { k: qsTr("홈 거리"),   v: control._activeVehicle ? control._fmt(control._num(control._activeVehicle.distanceToHome), 0) + " m" : "—" },
                    { k: qsTr("비행 거리"), v: control._activeVehicle ? control._fmt(control._num(control._activeVehicle.flightDistance), 0) + " m" : "—" },
                    { k: qsTr("비행 시간"), v: control._activeVehicle ? control._activeVehicle.flightTime.valueString : "—" }
                ]
                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: chipCol.implicitHeight + control._u * 0.5
                    color:                  "#15181B"
                    border.color:           control._border
                    radius:                 control._u * 0.25
                    Column {
                        id:     chipCol
                        x:      control._u * 0.4
                        anchors.verticalCenter: parent.verticalCenter
                        QGCLabel { text: modelData.k; color: control._muted; font.pointSize: ScreenTools.smallFontPointSize }
                        QGCLabel { text: modelData.v; font.family: ScreenTools.fixedFontFamily; font.bold: true }
                    }
                }
            }
        }
    }

    // Gear button (top-right corner, always fully visible)
    Rectangle {
        id:             gearButton
        anchors.right:  parent.right
        anchors.top:    parent.top
        anchors.margins: control._u * 0.15
        width:          control._u * 1.4
        height:         width
        radius:         width / 2
        z:              10
        color:          control._showPrefs ? control._accent : "#1C1F23"
        border.color:   "#2A2D31"
        QGCLabel {
            anchors.centerIn:   parent
            text:               "⚙"
            color:              control._showPrefs ? "#0E0F11" : "#C9CDD1"
        }
        MouseArea {
            anchors.fill:   parent
            cursorShape:    Qt.PointingHandCursor
            onClicked:      control._showPrefs = !control._showPrefs
        }
    }

    // Size / transparency controls
    Rectangle {
        anchors.right:      gearButton.left
        anchors.top:        parent.top
        anchors.margins:    control._u * 0.15
        width:              prefsRow.implicitWidth + control._u
        height:             prefsRow.implicitHeight + control._u * 0.5
        radius:             control._u * 0.3
        z:                  10
        visible:            control._showPrefs
        color:              "#0E0F11"
        border.color:       "#2A2D31"

        RowLayout {
            id:                 prefsRow
            anchors.centerIn:   parent
            spacing:            control._u * 0.3

            QGCLabel { text: qsTr("크기"); color: control._muted; font.pointSize: ScreenTools.smallFontPointSize }
            QGCButton { text: "−"; heightFactor: 0.2; onClicked: control._stepScale(-0.1) }
            QGCLabel {
                Layout.preferredWidth:  control._u * 2.4
                horizontalAlignment:    Text.AlignHCenter
                text:                   Math.round(control._userScale * 100) + "%"
                font.family:            ScreenTools.fixedFontFamily
            }
            QGCButton { text: "+"; heightFactor: 0.2; onClicked: control._stepScale(0.1) }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: control._u; color: "#2A2D31" }

            QGCLabel { text: qsTr("불투명도"); color: control._muted; font.pointSize: ScreenTools.smallFontPointSize }
            QGCButton { text: "−"; heightFactor: 0.2; onClicked: control._stepOpacity(-0.1) }
            QGCLabel {
                Layout.preferredWidth:  control._u * 2.4
                horizontalAlignment:    Text.AlignHCenter
                text:                   Math.round(control._userOpacity * 100) + "%"
                font.family:            ScreenTools.fixedFontFamily
            }
            QGCButton { text: "+"; heightFactor: 0.2; onClicked: control._stepOpacity(0.1) }
        }
    }
}
