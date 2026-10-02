import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QtLocation
import QtPositioning
import QtQuick.Window
import QtQml.Models

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap

// AeroResearch custom layer: 후크(SERVO12) / 줄(SERVO13) 전용 버튼 패널
// Fly View 오른쪽 가운데에 항상 표시됨 (기체 연결 시)
Item {
    id: _root

    property var parentToolInsets               // These insets tell you what screen real estate is available for positioning the controls in your overlay
    property var totalToolInsets:   _toolInsets // These are the insets for your custom overlay additions
    property var mapControl

    // ---- 채널/PWM 설정 (필요 시 여기만 수정) ----
    readonly property int hookChannel:  12
    readonly property int hookOpenPwm:  1900   // 고 = 열림
    readonly property int hookClosePwm: 1100   // 저 = 닫힘

    readonly property int lineChannel:  13
    readonly property int lineUpPwm:    1900   // 고 = 올림
    readonly property int lineDownPwm:  1100   // 저 = 내림
    readonly property int lineStopPwm:  1500   // 중립 = 멈춤
    // ------------------------------------------

    readonly property int _mavCmdDoSetServo:   183  // MAV_CMD_DO_SET_SERVO
    readonly property int _compIdAutopilot:    1    // MAV_COMP_ID_AUTOPILOT1

    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property real   _margin:        ScreenTools.defaultFontPixelWidth
    property real   _buttonWidth:   ScreenTools.defaultFontPixelWidth * 9
    property string _hookState:     "-"
    property string _lineState:     "-"

    function _setServo(channel, pwm) {
        if (_activeVehicle) {
            _activeVehicle.sendCommand(_compIdAutopilot, _mavCmdDoSetServo, true, channel, pwm)
        }
    }

    QGCPalette { id: qgcPal }

    QGCToolInsets {
        id:                     _toolInsets
        leftEdgeTopInset:       parentToolInsets.leftEdgeTopInset
        leftEdgeCenterInset:    parentToolInsets.leftEdgeCenterInset
        leftEdgeBottomInset:    parentToolInsets.leftEdgeBottomInset
        rightEdgeTopInset:      parentToolInsets.rightEdgeTopInset
        rightEdgeCenterInset:   payloadPanel.visible ? parentToolInsets.rightEdgeCenterInset + payloadPanel.width + _margin : parentToolInsets.rightEdgeCenterInset
        rightEdgeBottomInset:   parentToolInsets.rightEdgeBottomInset
        topEdgeLeftInset:       parentToolInsets.topEdgeLeftInset
        topEdgeCenterInset:     parentToolInsets.topEdgeCenterInset
        topEdgeRightInset:      parentToolInsets.topEdgeRightInset
        bottomEdgeLeftInset:    parentToolInsets.bottomEdgeLeftInset
        bottomEdgeCenterInset:  parentToolInsets.bottomEdgeCenterInset
        bottomEdgeRightInset:   parentToolInsets.bottomEdgeRightInset
    }

    Rectangle {
        id:                     payloadPanel
        anchors.right:          parent.right
        anchors.rightMargin:    parentToolInsets.rightEdgeCenterInset
        anchors.verticalCenter: parent.verticalCenter
        width:                  panelColumn.width + _margin * 2
        height:                 panelColumn.height + _margin * 2
        radius:                 ScreenTools.defaultFontPixelWidth / 2
        color:                  Qt.rgba(qgcPal.window.r, qgcPal.window.g, qgcPal.window.b, 0.85)
        visible:                !!_activeVehicle

        ColumnLayout {
            id:                 panelColumn
            anchors.centerIn:   parent
            spacing:            _margin / 2

            // ----- 후크 -----
            QGCLabel {
                text:               qsTr("후크 (CH%1): %2").arg(hookChannel).arg(_hookState)
                font.bold:          true
            }
            QGCButton {
                text:                   qsTr("후크 열림")
                Layout.preferredWidth:  _buttonWidth
                // 화물 투하 방지를 위해 확인창 표시
                onClicked: QGroundControl.showMessageDialog(_root, qsTr("후크 열림"),
                                                            qsTr("후크를 엽니다. 화물이 분리될 수 있습니다. 진행할까요?"),
                                                            Dialog.Cancel | Dialog.Ok,
                                                            function() { _setServo(hookChannel, hookOpenPwm); _hookState = qsTr("열림") })
            }
            QGCButton {
                text:                   qsTr("후크 닫힘")
                Layout.preferredWidth:  _buttonWidth
                onClicked: { _setServo(hookChannel, hookClosePwm); _hookState = qsTr("닫힘") }
            }

            Item { Layout.preferredHeight: _margin / 2; Layout.preferredWidth: 1 }

            // ----- 줄 -----
            QGCLabel {
                text:               qsTr("줄 (CH%1): %2").arg(lineChannel).arg(_lineState)
                font.bold:          true
            }
            QGCButton {
                text:                   qsTr("줄 올림")
                Layout.preferredWidth:  _buttonWidth
                onClicked: { _setServo(lineChannel, lineUpPwm); _lineState = qsTr("올림") }
            }
            QGCButton {
                text:                   qsTr("줄 멈춤")
                Layout.preferredWidth:  _buttonWidth
                onClicked: { _setServo(lineChannel, lineStopPwm); _lineState = qsTr("멈춤") }
            }
            QGCButton {
                text:                   qsTr("줄 내림")
                Layout.preferredWidth:  _buttonWidth
                onClicked: { _setServo(lineChannel, lineDownPwm); _lineState = qsTr("내림") }
            }
        }
    }
}
