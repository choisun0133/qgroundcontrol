import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// AeroResearch: payload buttons on the fly view, switched on from Ctrl+F (globals.aeroPayloadMode).
//  - "hook":    hook (SERVO12) open/close + winch line (SERVO13) up/stop/down, MAV_CMD_DO_SET_SERVO
//  - "gripper": grab / release through the flight controller's gripper, MAV_CMD_DO_GRIPPER
// Not a window: just the buttons, moved by the grip handle, horizontal or vertical, position saved.
// Releasing a load (hook open, gripper release) asks for confirmation first.
// Gripper state: released when a vehicle connects (the gripper boots open), then follows the
// flight controller's acknowledgement of each grab / release; the active state's button is filled.
Item {
    id:         control
    width:      body.width
    height:     body.height
    visible:    mode !== "off" && !!_vehicle
    z:          5

    readonly property string mode:          globals.aeroPayloadMode
    readonly property var    _vehicle:      QGroundControl.multiVehicleManager.activeVehicle
    readonly property real   _u:            ScreenTools.defaultFontPixelHeight
    readonly property real   _button:       _u * 4.6
    readonly property real   _gap:          _u * 0.35
    property string          _last:         ""      // id of the last button pressed (highlighted)
    property string          gripperState:  "release"   // "grab" | "release", from the FC's command ACK
    property string          _gripperPending: ""

    on_VehicleChanged: {
        gripperState = "release"
        _gripperPending = ""
        _servoBusy = false
        _servoQueue = []
        servoWatchdog.stop()
    }

    readonly property int _failureDuplicate: 2      // Vehicle::MavCmdResultFailureDuplicateCommand

    Connections {
        target: control._vehicle
        function onMavCommandResult(vehicleId, targetComponent, command, ackResult, failureCode) {
            if (targetComponent !== control._compIdAutopilot || failureCode === control._failureDuplicate) {
                return      // someone else's command, or a rejected duplicate (the original is still pending)
            }
            if (command === control._mavCmdDoSetServo && control._servoBusy) {
                control._servoDone()
            } else if (command === control._mavCmdDoGripper && control._gripperPending !== "") {
                if (ackResult === 0) {      // MAV_RESULT_ACCEPTED
                    control.gripperState = control._gripperPending
                }
                control._gripperPending = ""
            }
        }
    }

    property real defaultX: 0
    property real defaultY: 0

    // ---- hook / winch outputs (set in Ctrl+F → 화물 버튼) ----
    readonly property int hookChannel:   globals.aeroPayloadHookServo
    readonly property int hookOpenPwm:   globals.aeroPayloadHookOpenPwm
    readonly property int hookClosePwm:  globals.aeroPayloadHookClosePwm
    readonly property int lineChannel:   globals.aeroPayloadLineServo
    readonly property int lineUpPwm:     globals.aeroPayloadLineUpPwm
    readonly property int lineStopPwm:   globals.aeroPayloadLineStopPwm
    readonly property int lineDownPwm:   globals.aeroPayloadLineDownPwm

    readonly property int _mavCmdDoSetServo:    183     // MAV_CMD_DO_SET_SERVO
    readonly property int _mavCmdDoGripper:     211     // MAV_CMD_DO_GRIPPER
    readonly property int _gripperRelease:      0       // GRIPPER_ACTION_RELEASE
    readonly property int _gripperGrab:         1       // GRIPPER_ACTION_GRAB
    readonly property int _compIdAutopilot:     1       // MAV_COMP_ID_AUTOPILOT1

    readonly property var _hookButtons: [
        { id: "hookOpen",  label: qsTr("후크 열림"), icon: "/res/AeroPayloadHookOpen.svg",  confirm: true },
        { id: "hookClose", label: qsTr("후크 닫힘"), icon: "/res/AeroPayloadHookClose.svg", confirm: false },
        { id: "lineUp",    label: qsTr("줄 올림"),   icon: "/res/AeroPayloadLineUp.svg",    confirm: false },
        { id: "lineStop",  label: qsTr("줄 멈춤"),   icon: "/res/AeroPayloadLineStop.svg",  confirm: false },
        { id: "lineDown",  label: qsTr("줄 내림"),   icon: "/res/AeroPayloadLineDown.svg",  confirm: false }
    ]
    readonly property var _gripperButtons: [
        { id: "grab",    label: qsTr("물건 잡기"), icon: "/res/AeroPayloadGripperGrab.svg",    confirm: false },
        { id: "release", label: qsTr("물건 투하"), icon: "/res/AeroPayloadGripperRelease.svg", confirm: true }
    ]

    // The vehicle's command queue rejects a second DO_SET_SERVO while one is waiting for its ACK, so
    // servo commands go one at a time. Requests made meanwhile wait, one per channel (the newest for
    // that channel wins, in the order the channels were first queued), so a winch stop can't be
    // replaced by a hook command.
    property bool   _servoBusy:     false
    property var    _servoQueue:    []          // [{ channel, pwm }], at most one per channel
    property var    _servoVehicle:  null

    function _sendServo(vehicle, channel, pwm) {
        if (_servoBusy) {
            var queue = _servoQueue.slice()
            var index = queue.findIndex(function(r) { return r.channel === channel })
            if (index >= 0) {
                queue[index] = { channel: channel, pwm: pwm }
            } else {
                queue.push({ channel: channel, pwm: pwm })
            }
            _servoQueue = queue
            return
        }
        _servoBusy = true
        _servoVehicle = vehicle
        servoWatchdog.restart()
        vehicle.sendCommand(_compIdAutopilot, _mavCmdDoSetServo, true, channel, pwm)
    }

    function _servoDone() {
        _servoBusy = false
        servoWatchdog.stop()
        var vehicle = QGroundControl.multiVehicleManager.activeVehicle
        if (_servoQueue.length === 0 || !vehicle || vehicle !== _servoVehicle) {
            _servoQueue = []
            return
        }
        var queue = _servoQueue.slice()
        var next = queue.shift()
        _servoQueue = queue
        _sendServo(vehicle, next.channel, next.pwm)
    }

    // The queue always reports a result (ACK, no response or failure); this only guards a lost signal
    Timer {
        id:         servoWatchdog
        interval:   15000
        onTriggered: control._servoDone()
    }

    function _send(id, vehicle) {
        if (!vehicle || vehicle !== QGroundControl.multiVehicleManager.activeVehicle) {
            return
        }
        switch (id) {
        case "hookOpen":  _sendServo(vehicle, hookChannel, hookOpenPwm); break
        case "hookClose": _sendServo(vehicle, hookChannel, hookClosePwm); break
        case "lineUp":    _sendServo(vehicle, lineChannel, lineUpPwm); break
        case "lineStop":  _sendServo(vehicle, lineChannel, lineStopPwm); break
        case "lineDown":  _sendServo(vehicle, lineChannel, lineDownPwm); break
        case "grab":
        case "release":
            if (_gripperPending !== "") {
                return              // one gripper command at a time
            }
            _gripperPending = id
            vehicle.sendCommand(_compIdAutopilot, _mavCmdDoGripper, true, 0, id === "grab" ? _gripperGrab : _gripperRelease)
            break
        default:
            return
        }
        _last = id
    }

    function _press(button) {
        // The command goes to the vehicle the button was pressed for; if the active vehicle changes
        // (or disconnects) while the confirmation is open, nothing is sent.
        var vehicle = QGroundControl.multiVehicleManager.activeVehicle
        if (!vehicle) {
            return
        }
        if (!button.confirm) {
            _send(button.id, vehicle)
            return
        }
        QGroundControl.showMessageDialog(control, button.label,
                                         button.id === "hookOpen" ? qsTr("후크를 엽니다. 화물이 분리될 수 있습니다. 진행할까요?")
                                                                  : qsTr("그리퍼를 열어 물건을 투하합니다. 진행할까요?"),
                                         Dialog.Cancel | Dialog.Ok,
                                         function() { control._send(button.id, vehicle) })
    }

    // ---- placement ----
    property bool _placed: false

    function _clamp() {
        if (!parent) {
            return
        }
        x = Math.max(0, Math.min(x, parent.width - width))
        y = Math.max(0, Math.min(y, parent.height - height))
    }

    function _place() {
        if (_placed || !parent || parent.width <= 0 || parent.height <= 0 || !visible) {
            return
        }
        _placed = true
        x = saved.posX >= 0 ? saved.posX : defaultX
        y = saved.posY >= 0 ? saved.posY : defaultY
        _clamp()
    }

    Component.onCompleted:  Qt.callLater(_place)
    onVisibleChanged:       Qt.callLater(_place)
    onWidthChanged:         if (_placed) { Qt.callLater(_clamp) }
    onHeightChanged:        if (_placed) { Qt.callLater(_clamp) }

    Connections {
        target:                     control.parent
        function onWidthChanged()   { control._placed ? control._clamp() : Qt.callLater(control._place) }
        function onHeightChanged()  { control._placed ? control._clamp() : Qt.callLater(control._place) }
    }

    Settings {
        id:         saved
        category:   "AeroPayloadBar"
        property real posX:     -1
        property real posY:     -1
        property bool vertical: false
    }

    GridLayout {
        id:             body
        columns:        saved.vertical ? 1 : Math.max(1, buttons.count)
        rowSpacing:     control._gap
        columnSpacing:  control._gap

        // Grip handle: drag to move, ↔ to switch horizontal / vertical
        Rectangle {
            Layout.columnSpan:      saved.vertical ? 1 : Math.max(1, buttons.count)
            Layout.fillWidth:       true
            Layout.preferredHeight: control._u * 1.4
            radius:                 control._u * 0.3
            color:                  Qt.rgba(0.05, 0.06, 0.07, 0.9)

            MouseArea {
                anchors.fill:   parent
                cursorShape:    pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                drag.target:    control
                drag.minimumX:  0
                drag.minimumY:  0
                drag.maximumX:  control.parent ? control.parent.width - control.width : 0
                drag.maximumY:  control.parent ? control.parent.height - control.height : 0
                drag.threshold: 0
                onReleased: {
                    saved.posX = control.x
                    saved.posY = control.y
                }
                onWheel: (wheel) => { wheel.accepted = true }
            }

            RowLayout {
                anchors.fill:           parent
                anchors.leftMargin:     control._u * 0.3
                anchors.rightMargin:    control._u * 0.2
                spacing:                control._u * 0.2

                QGCLabel {
                    Layout.fillWidth:   true
                    text: {
                        if (control.mode !== "gripper") {
                            return "⠿"
                        }
                        if (control._gripperPending !== "") {
                            return "⠿  " + qsTr("그리퍼: 전송 중…")
                        }
                        return "⠿  " + (control.gripperState === "grab" ? qsTr("그리퍼: 잡는 중") : qsTr("그리퍼: 투하 상태"))
                    }
                    color:              control.mode !== "gripper" || control._gripperPending !== "" ? "#9BA1A6"
                                        : (control.gripperState === "grab" ? "#3DDC84" : "#FF6B6B")
                    font.bold:          control.mode === "gripper"
                    elide:              Text.ElideRight
                }
                Rectangle {
                    Layout.preferredWidth:  control._u * 1.4
                    Layout.preferredHeight: control._u * 1.1
                    radius:                 control._u * 0.25
                    color:                  flipMouse.containsMouse ? "#2A2D31" : "transparent"

                    QGCLabel {
                        anchors.centerIn:   parent
                        text:               saved.vertical ? "↔" : "↕"
                        color:              "#ECEDEE"
                    }
                    MouseArea {
                        id:             flipMouse
                        anchors.fill:   parent
                        hoverEnabled:   true
                        onClicked: {
                            saved.vertical = !saved.vertical
                            Qt.callLater(control._clamp)
                        }
                    }
                }
            }
        }

        Repeater {
            id:     buttons
            model:  control.mode === "hook" ? control._hookButtons : (control.mode === "gripper" ? control._gripperButtons : [])

            Rectangle {
                required property var modelData

                Layout.preferredWidth:  control._button
                Layout.preferredHeight: control._button
                readonly property bool _gripperActive: control.mode === "gripper" && control.gripperState === modelData.id

                radius:                 control._u * 0.5
                color: {
                    if (pressArea.pressed) {
                        return "#2A2D31"
                    }
                    if (_gripperActive) {
                        return modelData.id === "grab" ? "#1F7A45" : "#A83232"
                    }
                    return Qt.rgba(0.11, 0.12, 0.14, 0.94)
                }
                border.color:           _gripperActive ? "#ECEDEE" : (control.mode !== "gripper" && control._last === modelData.id ? "#ECEDEE" : "#2A2D31")
                border.width:           _gripperActive || (control.mode !== "gripper" && control._last === modelData.id) ? 2 : 1
                opacity:                control.mode === "gripper" && !_gripperActive ? 0.75 : 1

                Image {
                    anchors.horizontalCenter:   parent.horizontalCenter
                    y:                          control._u * 0.35
                    width:                      control._button * 0.56
                    height:                     width
                    sourceSize.width:           width * 2
                    sourceSize.height:          height * 2
                    source:                     _gripperActive ? modelData.icon.replace(".svg", "Active.svg") : modelData.icon
                    fillMode:                   Image.PreserveAspectFit
                    smooth:                     true
                }
                QGCLabel {
                    anchors.horizontalCenter:   parent.horizontalCenter
                    anchors.bottom:             parent.bottom
                    anchors.bottomMargin:       control._u * 0.3
                    text:                       modelData.label
                    font.bold:                  true
                    color:                      "#ECEDEE"
                }
                MouseArea {
                    id:             pressArea
                    anchors.fill:   parent
                    onClicked:      control._press(modelData)
                    onWheel:        (wheel) => { wheel.accepted = true }
                }
            }
        }
    }
}
