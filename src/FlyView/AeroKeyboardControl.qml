import QtCore
import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import QGroundControl
import QGroundControl.Controls

// AeroResearch keyboard flight control (mode 2 layout) for a paused / hovering multirotor.
//   Left stick  : W/S climb/descend, A/D yaw left/right
//   Right stick : arrow keys forward/back/left/right
//   Shift faster, Space stop, Esc off
// While on, the vehicle is in GUIDED and a body-frame velocity is streamed at 10 Hz. Releasing every
// key holds position; if the stream stops (focus lost, link lost) the FC stops by itself (GUID_TIMEOUT).
// The pressed keys are shown semi-transparently on screen.
Item {
    id:             control
    anchors.fill:   parent

    readonly property real  _u:         ScreenTools.defaultFontPixelHeight
    readonly property color _accent:    "#FF7A1A"

    property var  _vehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool _supported:   _vehicle ? _vehicle.guidedModeBodyVelocitySupported() : false
    property bool _flying:      _vehicle ? _vehicle.flying : false
    property bool _active:      globals.aeroKeyboardControlActive
    property bool _seenGuided:  false
    property bool _hasFocus:    keyInput.activeFocus

    // Pressed keys
    property bool _kUp:     false   // W
    property bool _kDown:   false   // S
    property bool _kYawL:   false   // A
    property bool _kYawR:   false   // D
    property bool _kFwd:    false   // Up
    property bool _kBack:   false   // Down
    property bool _kLeft:   false   // Left
    property bool _kRight:  false   // Right
    property bool _kFast:   false   // Shift

    Settings {
        id:         prefs
        category:   "AeroKeyboardControl"
        property real horizSpeed:   2.0     // m/s
        property real vertSpeed:    1.0     // m/s
        property real yawRate:      30      // deg/s
        property real displayOpacity: 0.8   // key display transparency (0.2 - 1.0)
    }

    readonly property real _boost:      _kFast ? 2 : 1
    readonly property real _cmdForward: ((_kFwd ? 1 : 0) - (_kBack ? 1 : 0)) * prefs.horizSpeed * _boost
    readonly property real _cmdRight:   ((_kRight ? 1 : 0) - (_kLeft ? 1 : 0)) * prefs.horizSpeed * _boost
    readonly property real _cmdUp:      ((_kUp ? 1 : 0) - (_kDown ? 1 : 0)) * prefs.vertSpeed * _boost
    readonly property real _cmdYaw:     ((_kYawR ? 1 : 0) - (_kYawL ? 1 : 0)) * prefs.yawRate * _boost

    // Shown when keyboard control can be started (paused / guided hover)
    readonly property bool _canOffer: _vehicle && _supported && _flying
                                      && (_vehicle.flightMode === _vehicle.pauseFlightMode || _vehicle.guidedMode)

    property string _notice: ""

    function _notify(text) {
        _notice = text
        noticeTimer.restart()
    }

    Timer {
        id:         noticeTimer
        interval:   5000
        onTriggered: control._notice = ""
    }

    function _clearKeys() {
        _kUp = false; _kDown = false; _kYawL = false; _kYawR = false
        _kFwd = false; _kBack = false; _kLeft = false; _kRight = false; _kFast = false
    }

    function _sendStop() {
        if (_vehicle) {
            _vehicle.guidedModeSetBodyVelocity(0, 0, 0, 0)
        }
    }

    function _activate() {
        if (!_vehicle || !_supported) {
            control._notify(qsTr("이 기체는 키보드 조종을 지원하지 않습니다 (멀티콥터 ArduPilot 전용)."))
            globals.aeroKeyboardControlActive = false
            return
        }
        if (!_flying) {
            control._notify(qsTr("비행 중일 때만 키보드 조종을 켤 수 있습니다."))
            globals.aeroKeyboardControlActive = false
            return
        }
        _clearKeys()
        _seenGuided = _vehicle.guidedMode
        if (!_vehicle.guidedMode) {
            _vehicle.guidedMode = true
        }
        guidedWaitTimer.restart()
        keyInput.forceActiveFocus()
    }

    // holdPosition: switch to the pause mode so the vehicle keeps hovering after control ends
    function _deactivate(holdPosition) {
        _clearKeys()
        _sendStop()
        guidedWaitTimer.stop()
        if (holdPosition && _vehicle && _vehicle.guidedMode && _vehicle.flying) {
            _vehicle.pauseVehicle()
        }
        if (globals.aeroKeyboardControlActive) {
            globals.aeroKeyboardControlActive = false
        }
    }

    on_ActiveChanged: {
        if (_active) {
            _activate()
        } else {
            _clearKeys()
            _sendStop()
            guidedWaitTimer.stop()
        }
    }

    // Leave keyboard control if the mode changes (RC / other GCS / RTL), the vehicle lands or disconnects
    Connections {
        target: control._vehicle
        function onGuidedModeChanged(guided) {
            if (!control._active) {
                return
            }
            if (guided) {
                control._seenGuided = true
                guidedWaitTimer.stop()
            } else if (control._seenGuided) {
                control._deactivate(false)
                control._notify(qsTr("비행 모드가 바뀌어 키보드 조종을 껐습니다."))
            }
        }
        function onFlyingChanged(flying) {
            if (control._active && !flying) {
                control._deactivate(false)
            }
        }
    }
    on_VehicleChanged: {
        if (_active) {
            _deactivate(false)
        }
    }

    Timer {
        id:         guidedWaitTimer
        interval:   5000
        onTriggered: {
            if (control._active && control._vehicle && !control._vehicle.guidedMode) {
                control._deactivate(false)
                control._notify(qsTr("GUIDED 모드로 바꾸지 못해 키보드 조종을 껐습니다."))
            }
        }
    }

    // 10 Hz command stream
    Timer {
        interval:   100
        repeat:     true
        running:    control._active
        onTriggered: {
            if (control._vehicle && control._vehicle.guidedMode) {
                control._vehicle.guidedModeSetBodyVelocity(control._cmdForward, control._cmdRight, -control._cmdUp, control._cmdYaw)
            }
        }
    }

    // Keep keyboard focus while active, except when the operator is typing into a text field
    Timer {
        interval:   300
        repeat:     true
        running:    control._active && !keyInput.activeFocus
        onTriggered: {
            var item = control.Window.activeFocusItem
            var typing = item && item.hasOwnProperty("cursorPosition") && item.hasOwnProperty("selectByMouse")
            if (!typing && Qt.application.state === Qt.ApplicationActive) {
                keyInput.forceActiveFocus()
            }
        }
    }

    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state !== Qt.ApplicationActive) {
                control._clearKeys()   // key releases are lost while the window is inactive
            }
        }
    }

    // Invisible key receiver. Letter keys also matched by Windows scan code so the Korean IME mode
    // does not matter.
    Item {
        id:         keyInput
        focus:      false

        onActiveFocusChanged: {
            if (!activeFocus) {
                control._clearKeys()
            }
        }

        function _set(event, down) {
            var sc = event.nativeScanCode
            switch (event.key) {
            case Qt.Key_W:      control._kUp = down;    return true
            case Qt.Key_S:      control._kDown = down;  return true
            case Qt.Key_A:      control._kYawL = down;  return true
            case Qt.Key_D:      control._kYawR = down;  return true
            case Qt.Key_Up:     control._kFwd = down;   return true
            case Qt.Key_Down:   control._kBack = down;  return true
            case Qt.Key_Left:   control._kLeft = down;  return true
            case Qt.Key_Right:  control._kRight = down; return true
            case Qt.Key_Shift:  control._kFast = down;  return true
            }
            if (Qt.platform.os === "windows") {
                switch (sc) {
                case 0x11: control._kUp = down;   return true
                case 0x1F: control._kDown = down; return true
                case 0x1E: control._kYawL = down; return true
                case 0x20: control._kYawR = down; return true
                }
            }
            return false
        }

        Keys.onPressed: (event) => {
            if (!control._active) {
                return
            }
            event.accepted = true
            if (event.isAutoRepeat) {
                return
            }
            if (event.key === Qt.Key_Escape) {
                control._deactivate(true)
            } else if (event.key === Qt.Key_Space) {
                control._clearKeys()
                control._sendStop()
            } else {
                event.accepted = _set(event, true)
            }
        }
        Keys.onReleased: (event) => {
            if (!control._active) {
                return
            }
            event.accepted = true
            if (!event.isAutoRepeat) {
                _set(event, false)
            }
        }
    }

    // ---- Start / stop pill (top centre) ----------------------------------------------------------
    Rectangle {
        id:                         togglePill
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                parent.top
        anchors.topMargin:          control._u * 0.5
        visible:                    control._active || control._canOffer
        height:                     control._u * 1.9
        width:                      pillRow.implicitWidth + control._u * 1.4
        radius:                     height / 2
        color:                      control._active ? Qt.rgba(1, 0.48, 0.1, 0.9) : (pillMouse.containsMouse ? "#1C1F23" : Qt.rgba(0.055, 0.059, 0.067, 0.85))
        border.color:               control._accent

        RowLayout {
            id:                 pillRow
            anchors.centerIn:   parent
            spacing:            control._u * 0.4
            QGCLabel {
                text:           "⌨"
                color:          control._active ? "#0E0F11" : control._accent
            }
            QGCLabel {
                text:           control._active ? (control._hasFocus ? qsTr("키보드 조종 중 · 끄기 (Esc)") : qsTr("키보드 조종 중 · 입력 대기"))
                                                : qsTr("키보드 조종")
                color:          control._active ? "#0E0F11" : "#ECEDEE"
                font.bold:      true
            }
        }

        MouseArea {
            id:             pillMouse
            anchors.fill:   parent
            hoverEnabled:   true
            cursorShape:    Qt.PointingHandCursor
            onClicked: {
                if (control._active) {
                    control._deactivate(true)
                } else {
                    globals.aeroKeyboardControlActive = true
                }
            }
        }
    }

    // Short notice under the pill (why control could not start / was turned off)
    Rectangle {
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                togglePill.visible ? togglePill.bottom : parent.top
        anchors.topMargin:          control._u * 0.4
        visible:                    control._notice !== ""
        width:                      noticeLabel.implicitWidth + control._u
        height:                     noticeLabel.implicitHeight + control._u * 0.5
        radius:                     control._u * 0.3
        color:                      Qt.rgba(0.055, 0.059, 0.067, 0.9)
        border.color:               "#FFB020"
        QGCLabel {
            id:                 noticeLabel
            anchors.centerIn:   parent
            text:               control._notice
            color:              "#FFB020"
        }
    }

    // ---- Semi-transparent key display (mode 2) ---------------------------------------------------
    component KeyCap: Rectangle {
        property string glyph
        property string caption
        property bool   pressed: false
        width:          control._u * 2.6
        height:         control._u * 2.6
        radius:         control._u * 0.35
        color:          pressed ? Qt.rgba(1, 0.48, 0.1, 0.85) : Qt.rgba(1, 1, 1, 0.10)
        border.color:   pressed ? control._accent : Qt.rgba(1, 1, 1, 0.25)
        Column {
            anchors.centerIn: parent
            QGCLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           glyph
                font.bold:      true
                color:          pressed ? "#0E0F11" : "#ECEDEE"
            }
            QGCLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           caption
                color:          pressed ? "#0E0F11" : Qt.rgba(1, 1, 1, 0.6)
                font.pointSize: ScreenTools.smallFontPointSize * 0.85
            }
        }
    }

    component StickPad: Column {
        property string title
        property alias  up:     upKey
        property alias  down:   downKey
        property alias  left:   leftKey
        property alias  right:  rightKey
        spacing: control._u * 0.2
        QGCLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text:           title
            color:          Qt.rgba(1, 1, 1, 0.7)
            font.pointSize: ScreenTools.smallFontPointSize
        }
        KeyCap { id: upKey; anchors.horizontalCenter: parent.horizontalCenter }
        Row {
            spacing: control._u * 0.2
            KeyCap { id: leftKey }
            KeyCap { id: downKey }
            KeyCap { id: rightKey }
        }
    }

    Rectangle {
        id:                         keyDisplay
        anchors.horizontalCenter:   parent.horizontalCenter
        y:                          parent.height * 0.58
        visible:                    control._active
        opacity:                    prefs.displayOpacity
        width:                      displayColumn.implicitWidth + control._u * 1.6
        height:                     displayColumn.implicitHeight + control._u * 1.2
        radius:                     control._u * 0.6
        color:                      Qt.rgba(0, 0, 0, 0.35)
        border.color:               Qt.rgba(1, 1, 1, 0.12)

        Column {
            id:                 displayColumn
            anchors.centerIn:   parent
            spacing:            control._u * 0.5

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: control._u * 2

                StickPad {
                    title:          qsTr("왼쪽 · 고도/회전")
                    up.glyph:       "W";    up.caption:     qsTr("상승");   up.pressed:     control._kUp
                    down.glyph:     "S";    down.caption:   qsTr("하강");   down.pressed:   control._kDown
                    left.glyph:     "A";    left.caption:   qsTr("좌회전"); left.pressed:   control._kYawL
                    right.glyph:    "D";    right.caption:  qsTr("우회전"); right.pressed:  control._kYawR
                }

                // Shift / Space
                Column {
                    anchors.bottom: parent.bottom
                    spacing:        control._u * 0.2
                    KeyCap {
                        width:      control._u * 4
                        glyph:      "Shift"
                        caption:    qsTr("빠르게 ×2")
                        pressed:    control._kFast
                    }
                    KeyCap {
                        width:      control._u * 4
                        glyph:      "Space"
                        caption:    qsTr("정지")
                    }
                }

                StickPad {
                    title:          qsTr("오른쪽 · 이동")
                    up.glyph:       "↑";    up.caption:     qsTr("전진");   up.pressed:     control._kFwd
                    down.glyph:     "↓";    down.caption:   qsTr("후진");   down.pressed:   control._kBack
                    left.glyph:     "←";    left.caption:   qsTr("좌");     left.pressed:   control._kLeft
                    right.glyph:    "→";    right.caption:  qsTr("우");     right.pressed:  control._kRight
                }
            }

            // Current command and speed limit
            RowLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: control._u * 0.4

                QGCLabel {
                    text: qsTr("전후 %1 · 좌우 %2 · 상하 %3 m/s · 회전 %4°/s")
                              .arg(control._cmdForward.toFixed(1)).arg(control._cmdRight.toFixed(1))
                              .arg(control._cmdUp.toFixed(1)).arg(control._cmdYaw.toFixed(0))
                    font.family:    ScreenTools.fixedFontFamily
                    font.pointSize: ScreenTools.smallFontPointSize
                    color:          Qt.rgba(1, 1, 1, 0.85)
                }
                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: control._u; color: Qt.rgba(1, 1, 1, 0.25) }
                QGCLabel { text: qsTr("속도"); color: Qt.rgba(1, 1, 1, 0.7); font.pointSize: ScreenTools.smallFontPointSize }
                QGCButton {
                    text:           "−"
                    heightFactor:   0.2
                    focusPolicy:    Qt.NoFocus
                    onClicked:      prefs.horizSpeed = Math.max(0.5, Math.round((prefs.horizSpeed - 0.5) * 10) / 10)
                }
                QGCLabel {
                    text:           prefs.horizSpeed.toFixed(1) + " m/s"
                    font.family:    ScreenTools.fixedFontFamily
                    color:          "#ECEDEE"
                }
                QGCButton {
                    text:           "+"
                    heightFactor:   0.2
                    focusPolicy:    Qt.NoFocus
                    onClicked:      prefs.horizSpeed = Math.min(5, Math.round((prefs.horizSpeed + 0.5) * 10) / 10)
                }

                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: control._u; color: Qt.rgba(1, 1, 1, 0.25) }
                QGCLabel { text: qsTr("투명도"); color: Qt.rgba(1, 1, 1, 0.7); font.pointSize: ScreenTools.smallFontPointSize }
                QGCButton {
                    text:           "−"
                    heightFactor:   0.2
                    focusPolicy:    Qt.NoFocus
                    onClicked:      prefs.displayOpacity = Math.max(0.2, Math.round((prefs.displayOpacity - 0.1) * 10) / 10)
                }
                QGCLabel {
                    text:           Math.round(prefs.displayOpacity * 100) + "%"
                    font.family:    ScreenTools.fixedFontFamily
                    color:          "#ECEDEE"
                }
                QGCButton {
                    text:           "+"
                    heightFactor:   0.2
                    focusPolicy:    Qt.NoFocus
                    onClicked:      prefs.displayOpacity = Math.min(1.0, Math.round((prefs.displayOpacity + 0.1) * 10) / 10)
                }
            }

            QGCLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                visible:        !control._hasFocus
                text:           qsTr("글자 입력 중에는 조종이 멈춥니다 · 입력 칸을 벗어나면 다시 조종됩니다")
                color:          "#FFB020"
                font.pointSize: ScreenTools.smallFontPointSize
            }
        }
    }
}
