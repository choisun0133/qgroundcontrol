import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// AeroResearch: guided action confirmation shown as a card next to the left tool strip.
// Keeps the confirmDialog API used by GuidedActionsController (show/reset/confirmCancelled,
// title/message/action/actionData/hideTrigger/mapIndicator/option*), but the action only
// runs after the confirm button has been held until its progress bar fills.
Item {
    id:         control
    width:      0
    visible:    false

    property var    guidedController
    property var    guidedValueSlider
    property var    messageDisplay
    property string title
    property string message
    property int    action
    property var    actionData
    property bool   hideTrigger:        false
    property var    mapIndicator
    property alias  optionText:         optionCheckBox.text
    property alias  optionChecked:      optionCheckBox.checked

    property bool _emergencyAction: action === guidedController.actionEmergencyStop

    // Takeoff altitude is picked inside the card instead of the right-edge slider
    property bool _takeoffPicker:   false
    property real _pickerValue:     0
    property real _pickerMin:       0
    property real _pickerMax:       120

    readonly property var    _activeVehicle:    QGroundControl.multiVehicleManager.activeVehicle
    readonly property color  _accent:           QGroundControl.globalPalette.brandingBlue
    readonly property color  _red:              "#FF4D4D"
    readonly property color  _yellow:           "#F5C518"
    readonly property color  _green:            "#3DDC84"
    readonly property real   _u:                ScreenTools.defaultFontPixelHeight

    readonly property color _tone: {
        var g = guidedController
        if (action === g.actionLand || action === g.actionDisarm || action === g.actionMVDisarm || _emergencyAction) {
            return _red
        }
        if (action === g.actionPause || action === g.actionMVPause || action === g.actionRTL) {
            return _yellow
        }
        return _accent
    }

    readonly property string _subtitle: {
        var g = guidedController
        switch (action) {
        case g.actionArm:           return qsTr("모터가 회전을 시작합니다")
        case g.actionForceArm:      return qsTr("점검을 무시하고 강제로 시동합니다")
        case g.actionDisarm:        return qsTr("모터를 정지합니다")
        case g.actionEmergencyStop: return qsTr("비행 중 모터를 즉시 정지합니다 · 기체가 추락합니다")
        case g.actionTakeoff:       return qsTr("설정한 고도까지 상승 후 정지 비행")
        case g.actionStartMission:  return qsTr("업로드된 미션을 처음부터 수행")
        case g.actionContinueMission:
        case g.actionResumeMission: return qsTr("중단된 지점부터 미션을 이어서 수행")
        case g.actionPause:         return qsTr("현재 위치에서 정지 비행 (호버링)")
        case g.actionRTL:           return qsTr("복귀 고도로 상승 후 이륙 지점에 착륙")
        case g.actionLand:          return qsTr("현재 위치에서 수직으로 착륙")
        case g.actionGoto:          return qsTr("지도에서 선택한 위치로 이동")
        case g.actionChangeAlt:     return qsTr("현재 위치에서 고도 변경")
        case g.actionOrbit:         return qsTr("선택한 지점을 중심으로 선회")
        default:                    return ""
        }
    }

    readonly property string _iconSource: {
        var g = guidedController
        switch (action) {
        case g.actionArm:
        case g.actionForceArm:
        case g.actionDisarm:
        case g.actionEmergencyStop: return "/res/AeroPower.svg"
        case g.actionTakeoff:       return "/res/takeoff.svg"
        case g.actionStartMission:
        case g.actionContinueMission:
        case g.actionResumeMission: return "/res/AeroStartMission.svg"
        case g.actionPause:         return "/res/pause-mission.svg"
        case g.actionRTL:           return "/res/rtl.svg"
        case g.actionLand:          return "/res/land.svg"
        default:                    return ""
        }
    }

    // Short pre-flight checks shown in the card
    readonly property var _checks: {
        var list = []
        var v = _activeVehicle
        if (!v) {
            return list
        }
        var g = guidedController
        if (action === g.actionArm || action === g.actionTakeoff || action === g.actionStartMission) {
            var lock = v.gps ? v.gps.lock.rawValue : 0
            var count = v.gps ? v.gps.count.rawValue : 0
            var lockText = lock >= 6 ? "RTK Fix" : (lock === 5 ? "RTK Float" : (lock >= 3 ? "GPS 3D" : qsTr("위치 없음")))
            list.push({ text: qsTr("GPS %1 · 위성 %2개").arg(lockText).arg(count), color: lock >= 3 ? _green : _red })
            if (v.batteries && v.batteries.count > 0) {
                var pct = v.batteries.get(0).percentRemaining.rawValue
                if (!isNaN(pct)) {
                    list.push({ text: qsTr("배터리 %1%").arg(Math.round(pct)), color: pct > 40 ? _green : (pct > 20 ? _yellow : _red) })
                }
            }
        }
        if (action === g.actionTakeoff || action === g.actionStartMission) {
            list.push({ text: v.armed ? qsTr("시동 걸림") : qsTr("시동 꺼짐 · 먼저 시동을 거세요"), color: v.armed ? _green : _red })
        }
        if (action === g.actionLand || action === g.actionArm) {
            list.push({ text: action === g.actionArm ? qsTr("프로펠러 주변에 사람이 없는지 확인") : qsTr("하강 지점 아래 사람·장애물 확인"), color: _yellow })
        }
        return list
    }

    Component.onCompleted: guidedController.confirmDialog = this

    onHideTriggerChanged: {
        if (hideTrigger) {
            confirmCancelled()
        }
    }

    function show(immediate) {
        if (immediate) {
            _reallyShow()
        } else {
            // Delay a little so other state changes settle first and only the final state shows
            visibleTimer.restart()
        }
    }

    function reset() {
        visible = false
        guidedValueSlider.visible = false
        hideTrigger = false
        visibleTimer.stop()
        _takeoffPicker = false
        if (messageDisplay) {
            messageDisplay.opacity = 1.0
        }
    }

    // Cancel the pending action and notify its map indicator (see GuidedActionsController.confirmAction)
    function confirmCancelled(incomingIndicator) {
        reset()
        if (mapIndicator && mapIndicator !== incomingIndicator) {
            mapIndicator.actionCancelled()
        }
        mapIndicator = undefined
    }

    function _reallyShow() {
        // Takeoff: take over the right-edge altitude slider with the in-card picker
        if (action === guidedController.actionTakeoff && guidedValueSlider.visible) {
            _pickerMin = guidedValueSlider._sliderMinVal
            _pickerMax = guidedValueSlider._sliderMaxVal
            _pickerValue = Math.max(_pickerMin, Math.min(_pickerMax, 20))
            _takeoffPicker = true
            guidedValueSlider.visible = false
        }
        visible = true
    }

    function _setPicker(v) {
        _pickerValue = Math.max(_pickerMin, Math.min(_pickerMax, v))
    }

    function _execute() {
        var sliderOutputValue = 0
        if (_takeoffPicker) {
            sliderOutputValue = _pickerValue
        } else if (guidedValueSlider.visible) {
            sliderOutputValue = guidedValueSlider.getOutputValue()
        }
        var act = action
        var data = actionData
        var opt = optionChecked
        var indicator = mapIndicator
        visible = false
        guidedValueSlider.visible = false
        _takeoffPicker = false
        hideTrigger = false
        let success = guidedController.executeAction(act, data, sliderOutputValue, opt)
        if (indicator) {
            if (success) {
                indicator.actionConfirmed()
            } else {
                indicator.actionCancelled()
            }
            mapIndicator = undefined
        }
        if (success) {
            doneToast.show(title)
        }
    }

    Timer {
        id:             visibleTimer
        interval:       1000
        repeat:         false
        onTriggered:    _reallyShow()
    }

    QGCPalette { id: qgcPal }

    // ---------------- Card ----------------
    Popup {
        id:             card
        parent:         Overlay.overlay
        visible:        control.visible
        modal:          false
        focus:          false
        closePolicy:    Popup.NoAutoClose
        x:              control._u * 6.2
        y:              ScreenTools.toolbarHeight + control._u * 0.8
        width:          control._u * 21
        padding:        control._u * 0.9

        background: Rectangle {
            color:          "#0E0F11"
            radius:         control._u * 0.5
            border.color:   "#2A2D31"
            border.width:   1
            Rectangle {
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.top:    parent.top
                height:         3
                radius:         1.5
                color:          control._tone
            }
        }

        contentItem: ColumnLayout {
            spacing: control._u * 0.7

            RowLayout {
                Layout.fillWidth:   true
                spacing:            control._u * 0.6

                Rectangle {
                    Layout.preferredWidth:  control._u * 2.3
                    Layout.preferredHeight: Layout.preferredWidth
                    radius:                 control._u * 0.5
                    color:                  Qt.rgba(control._tone.r, control._tone.g, control._tone.b, 0.15)
                    visible:                control._iconSource !== ""
                    QGCColoredImage {
                        anchors.centerIn:   parent
                        width:              parent.width * 0.55
                        height:             width
                        source:             control._iconSource
                        color:              control._tone
                        sourceSize.height:  height
                    }
                }
                ColumnLayout {
                    Layout.fillWidth:   true
                    spacing:            0
                    QGCLabel {
                        text:           control.title
                        font.pointSize: ScreenTools.mediumFontPointSize
                        font.bold:      true
                    }
                    QGCLabel {
                        Layout.fillWidth:   true
                        text:               control._subtitle
                        color:              "#9BA1A6"
                        font.pointSize:     ScreenTools.smallFontPointSize
                        wrapMode:           Text.WordWrap
                        visible:            text !== ""
                    }
                }
                QGCButton {
                    text:           "✕"
                    heightFactor:   0.3
                    onClicked:      control.confirmCancelled()
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                text:               control.message
                wrapMode:           Text.WordWrap
                color:              "#C9CDD1"
                visible:            text !== ""
            }

            // Takeoff altitude picker
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: pickerColumn.implicitHeight + control._u
                visible:                control._takeoffPicker
                color:                  "#15181B"
                border.color:           "#2A2D31"
                radius:                 control._u * 0.4

                ColumnLayout {
                    id:         pickerColumn
                    x:          control._u * 0.5
                    y:          control._u * 0.5
                    width:      parent.width - control._u
                    spacing:    control._u * 0.4

                    QGCLabel {
                        text:           qsTr("이륙 고도 (이륙 지점 기준)")
                        color:          "#9BA1A6"
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        QGCButton {
                            text:                   "−"
                            Layout.preferredWidth:  control._u * 2.4
                            onClicked:              control._setPicker(control._pickerValue - 5)
                        }
                        QGCLabel {
                            Layout.fillWidth:       true
                            horizontalAlignment:    Text.AlignHCenter
                            text:                   control._pickerValue.toFixed(0) + " " + QGroundControl.unitsConversion.appSettingsVerticalDistanceUnitsString
                            font.family:            ScreenTools.fixedFontFamily
                            font.pointSize:         ScreenTools.largeFontPointSize
                            font.bold:              true
                        }
                        QGCButton {
                            text:                   "+"
                            Layout.preferredWidth:  control._u * 2.4
                            onClicked:              control._setPicker(control._pickerValue + 5)
                        }
                    }
                    RowLayout {
                        Layout.fillWidth:   true
                        spacing:            control._u * 0.3
                        Repeater {
                            model: [10, 20, 30, 50]
                            QGCButton {
                                Layout.fillWidth:   true
                                Layout.preferredWidth: 1
                                text:               modelData
                                heightFactor:       0.3
                                checkable:          false
                                backgroundColor:    control._pickerValue === modelData ? Qt.rgba(control._accent.r, control._accent.g, control._accent.b, 0.25) : qgcPal.button
                                enabled:            modelData >= control._pickerMin && modelData <= control._pickerMax
                                onClicked:          control._setPicker(modelData)
                            }
                        }
                    }
                }
            }

            // Checks
            Repeater {
                model: control._checks
                RowLayout {
                    spacing: control._u * 0.4
                    Rectangle {
                        Layout.preferredWidth:  control._u * 0.4
                        Layout.preferredHeight: Layout.preferredWidth
                        radius:                 width / 2
                        color:                  modelData.color
                    }
                    QGCLabel {
                        text:           modelData.text
                        color:          "#C9CDD1"
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                }
            }

            QGCCheckBox {
                id:         optionCheckBox
                visible:    text !== ""
            }

            // Hold-to-confirm: the bar fills while held, the action runs when it is full
            DelayButton {
                id:                     holdButton
                Layout.fillWidth:       true
                Layout.preferredHeight: control._u * 2.6
                delay:                  1500
                text:                   qsTr("누르고 있으면 %1").arg(control.title)

                onActivated: control._execute()

                background: Rectangle {
                    radius:         control._u * 0.4
                    color:          Qt.rgba(control._tone.r, control._tone.g, control._tone.b, 0.14)
                    border.color:   control._tone
                    border.width:   1
                    clip:           true
                    Rectangle {
                        width:  parent.width * holdButton.progress
                        height: parent.height
                        radius: parent.radius
                        color:  control._tone
                    }
                }
                contentItem: QGCLabel {
                    text:                   holdButton.text
                    horizontalAlignment:    Text.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                    font.bold:              true
                    color:                  holdButton.progress > 0.55 ? (Qt.colorEqual(control._tone, control._red) ? "#FFFFFF" : "#0E0F11") : qgcPal.text
                }
            }

            QGCLabel {
                Layout.fillWidth:       true
                horizontalAlignment:    Text.AlignHCenter
                text:                   holdButton.pressed ? qsTr("계속 누르고 있으세요 · 손을 떼면 취소됩니다") : qsTr("버튼을 누르고 있으면 바가 차오르고, 끝까지 차면 실행됩니다")
                color:                  "#6E757B"
                font.pointSize:         ScreenTools.smallFontPointSize
                wrapMode:               Text.WordWrap
            }
        }
    }

    // ---------------- Done toast ----------------
    Popup {
        id:             doneToast
        parent:         Overlay.overlay
        modal:          false
        focus:          false
        closePolicy:    Popup.NoAutoClose
        x:              (parent.width - width) / 2
        y:              ScreenTools.toolbarHeight + control._u * 0.8
        padding:        control._u * 0.6

        property string text

        function show(actionTitle) {
            text = qsTr("%1 명령을 보냈습니다").arg(actionTitle)
            open()
            toastTimer.restart()
        }

        background: Rectangle {
            radius:         height / 2
            color:          Qt.rgba(0.24, 0.86, 0.52, 0.16)
            border.color:   control._green
        }
        contentItem: QGCLabel {
            text:       "✓  " + doneToast.text
            color:      control._green
            font.bold:  true
        }

        Timer {
            id:             toastTimer
            interval:       2500
            onTriggered:    doneToast.close()
        }
    }
}
