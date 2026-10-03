import QtCore
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
// - 상단 제목줄을 끌어서 위치 이동, 오른쪽 아래 모서리를 끌어서 크기 조절
// - 제목줄 더블클릭 또는 ↺ 버튼으로 기본 위치/크기 복원
// - 위치와 크기는 QGC를 다시 켜도 유지됨
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
    readonly property real _minScale:     0.6
    readonly property real _maxScale:     2.5
    property real   _panelScale:    Math.min(Math.max(panelSettings.panelScale, _minScale), _maxScale)
    property real   _buttonWidth:   ScreenTools.defaultFontPixelWidth * 20 * _panelScale    // 장갑 착용 고려 대형 버튼
    property real   _buttonFont:    ScreenTools.largeFontPointSize * _panelScale
    property real   _buttonHeight:  1.0                                     // QGCButton heightFactor (기본 0.5)

    readonly property color _colorOpen:   "#C62828"   // 후크 열림 = 빨강
    readonly property color _colorClose:  "#2E7D32"   // 후크 닫힘 = 초록
    readonly property color _colorText:   "#FFFFFF"
    property string _hookState:     "-"
    property string _lineState:     "-"

    function _setServo(channel, pwm) {
        if (_activeVehicle) {
            _activeVehicle.sendCommand(_compIdAutopilot, _mavCmdDoSetServo, true, channel, pwm)
        }
    }

    QGCPalette { id: qgcPal }

    // 패널 위치/크기 저장 (QGC 재실행 후에도 유지)
    Settings {
        id:         panelSettings
        category:   "AeroResearchPayloadPanel"

        property real posX:         -1
        property real posY:         -1
        property real panelScale:   1.0
    }

    function _defaultPanelPosition() {
        payloadPanel.x = _root.width - payloadPanel.width - parentToolInsets.rightEdgeCenterInset
        payloadPanel.y = (_root.height - payloadPanel.height) / 2
    }

    // 창 크기가 바뀌어도 패널이 화면 밖으로 나가지 않게 보정
    function _clampPanel() {
        payloadPanel.x = Math.max(0, Math.min(payloadPanel.x, _root.width - payloadPanel.width))
        payloadPanel.y = Math.max(0, Math.min(payloadPanel.y, _root.height - payloadPanel.height))
    }

    function _savePanel() {
        panelSettings.posX = payloadPanel.x
        panelSettings.posY = payloadPanel.y
        panelSettings.panelScale = _panelScale
    }

    function _resetPanel() {
        panelSettings.panelScale = 1.0
        Qt.callLater(function() { _defaultPanelPosition(); _clampPanel(); _savePanel() })
    }

    onWidthChanged:  if (payloadPanel._positioned) _clampPanel()
    onHeightChanged: if (payloadPanel._positioned) _clampPanel()

    QGCToolInsets {
        id:                     _toolInsets
        leftEdgeTopInset:       parentToolInsets.leftEdgeTopInset
        leftEdgeCenterInset:    parentToolInsets.leftEdgeCenterInset
        leftEdgeBottomInset:    parentToolInsets.leftEdgeBottomInset
        rightEdgeTopInset:      parentToolInsets.rightEdgeTopInset
        rightEdgeCenterInset:   parentToolInsets.rightEdgeCenterInset
        rightEdgeBottomInset:   parentToolInsets.rightEdgeBottomInset
        topEdgeLeftInset:       parentToolInsets.topEdgeLeftInset
        topEdgeCenterInset:     parentToolInsets.topEdgeCenterInset
        topEdgeRightInset:      parentToolInsets.topEdgeRightInset
        bottomEdgeLeftInset:    parentToolInsets.bottomEdgeLeftInset
        bottomEdgeCenterInset:  parentToolInsets.bottomEdgeCenterInset
        bottomEdgeRightInset:   parentToolInsets.bottomEdgeRightInset
    }

    Rectangle {
        id:             payloadPanel
        width:          panelColumn.width + _margin * 2
        height:         panelColumn.height + _margin + resizeGrip.height   // 크기 조절 손잡이 공간 확보
        radius:         ScreenTools.defaultFontPixelWidth / 2
        color:          Qt.rgba(qgcPal.window.r, qgcPal.window.g, qgcPal.window.b, 0.85)
        border.color:   qgcPal.text
        border.width:   1
        visible:        !!_activeVehicle

        property bool _positioned: false

        function _initPosition() {
            if (!visible || _positioned) {
                return
            }
            Qt.callLater(function() {
                if (panelSettings.posX < 0 || panelSettings.posY < 0) {
                    _defaultPanelPosition()
                } else {
                    payloadPanel.x = panelSettings.posX
                    payloadPanel.y = panelSettings.posY
                }
                _clampPanel()
                payloadPanel._positioned = true
            })
        }

        onVisibleChanged:       _initPosition()
        Component.onCompleted:  _initPosition()

        ColumnLayout {
            id:         panelColumn
            x:          _margin
            y:          _margin
            spacing:    _margin / 2

            // ----- 제목줄: 끌어서 이동 -----
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: titleRow.height + _margin
                radius:                 ScreenTools.defaultFontPixelWidth / 2
                color:                  dragArea.pressed ? qgcPal.buttonHighlight : qgcPal.button

                RowLayout {
                    id:                     titleRow
                    anchors.left:           parent.left
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin:     _margin / 2
                    anchors.rightMargin:    _margin / 2

                    QGCLabel {
                        text:               "⠿ " + qsTr("화물 제어")
                        font.bold:          true
                        font.pointSize:     _buttonFont
                        Layout.fillWidth:   true
                    }
                    QGCLabel {
                        id:                 resetLabel
                        text:               "↺"
                        font.pointSize:     _buttonFont
                    }
                }

                MouseArea {
                    id:                 dragArea
                    anchors.fill:       parent
                    cursorShape:        pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target:        payloadPanel
                    drag.axis:          Drag.XAndYAxis
                    drag.minimumX:      0
                    drag.minimumY:      0
                    drag.maximumX:      _root.width - payloadPanel.width
                    drag.maximumY:      _root.height - payloadPanel.height
                    drag.threshold:     0
                    onReleased:         _savePanel()
                    onDoubleClicked:    _resetPanel()
                    onClicked: (mouse) => {
                        // ↺ 영역을 누르면 기본 위치/크기로 복원
                        var p = mapToItem(resetLabel, mouse.x, mouse.y)
                        if (p.x >= 0 && p.x <= resetLabel.width && p.y >= 0 && p.y <= resetLabel.height) {
                            _resetPanel()
                        }
                    }
                }
            }

            // ----- 후크 -----
            QGCLabel {
                text:               qsTr("후크 (CH%1): %2").arg(hookChannel).arg(_hookState)
                font.bold:          true
                font.pointSize:     _buttonFont
            }
            QGCButton {
                text:                   qsTr("후크 열림")
                iconSource:             "/res/GripperRelease.svg"
                pointSize:              _buttonFont
                heightFactor:           _buttonHeight
                backgroundColor:        _colorOpen
                textColor:              _colorText
                Layout.preferredWidth:  _buttonWidth
                // 화물 투하 방지를 위해 확인창 표시
                onClicked: QGroundControl.showMessageDialog(_root, qsTr("후크 열림"),
                                                            qsTr("후크를 엽니다. 화물이 분리될 수 있습니다. 진행할까요?"),
                                                            Dialog.Cancel | Dialog.Ok,
                                                            function() { _setServo(hookChannel, hookOpenPwm); _hookState = qsTr("열림") })
            }
            QGCButton {
                text:                   qsTr("후크 닫힘")
                iconSource:             "/res/GripperGrab.svg"
                pointSize:              _buttonFont
                heightFactor:           _buttonHeight
                backgroundColor:        _colorClose
                textColor:              _colorText
                Layout.preferredWidth:  _buttonWidth
                onClicked: { _setServo(hookChannel, hookClosePwm); _hookState = qsTr("닫힘") }
            }

            Item { Layout.preferredHeight: _margin; Layout.preferredWidth: 1 }

            // ----- 줄 -----
            QGCLabel {
                text:               qsTr("줄 (CH%1): %2").arg(lineChannel).arg(_lineState)
                font.bold:          true
                font.pointSize:     _buttonFont
            }
            QGCButton {
                text:                   qsTr("줄 올림")
                iconSource:             "/res/PayloadUp.svg"
                pointSize:              _buttonFont
                heightFactor:           _buttonHeight
                Layout.preferredWidth:  _buttonWidth
                onClicked: { _setServo(lineChannel, lineUpPwm); _lineState = qsTr("올림") }
            }
            QGCButton {
                text:                   qsTr("줄 멈춤")
                iconSource:             "/res/PayloadStop.svg"
                pointSize:              _buttonFont
                heightFactor:           _buttonHeight
                Layout.preferredWidth:  _buttonWidth
                onClicked: { _setServo(lineChannel, lineStopPwm); _lineState = qsTr("멈춤") }
            }
            QGCButton {
                text:                   qsTr("줄 내림")
                iconSource:             "/res/PayloadDown.svg"
                pointSize:              _buttonFont
                heightFactor:           _buttonHeight
                Layout.preferredWidth:  _buttonWidth
                onClicked: { _setServo(lineChannel, lineDownPwm); _lineState = qsTr("내림") }
            }
        }

        // ----- 오른쪽 아래 모서리: 끌어서 크기 조절 -----
        Item {
            id:             resizeGrip
            anchors.right:  parent.right
            anchors.bottom: parent.bottom
            width:          ScreenTools.defaultFontPixelWidth * 3
            height:         width

            Canvas {
                anchors.fill:   parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = qgcPal.text
                    ctx.lineWidth = 2
                    for (var i = 1; i <= 3; i++) {
                        var o = width * i / 4
                        ctx.beginPath()
                        ctx.moveTo(width - 2, o)
                        ctx.lineTo(o, height - 2)
                        ctx.stroke()
                    }
                }
            }

            MouseArea {
                anchors.fill:   parent
                cursorShape:    Qt.SizeFDiagCursor

                property point  _startPos
                property real   _startScale
                property real   _startWidth

                onPressed: (mouse) => {
                    _startPos = mapToItem(_root, mouse.x, mouse.y)
                    _startScale = _panelScale
                    _startWidth = payloadPanel.width
                }
                onPositionChanged: (mouse) => {
                    if (!pressed || _startWidth <= 0) {
                        return
                    }
                    var p = mapToItem(_root, mouse.x, mouse.y)
                    var delta = Math.max(p.x - _startPos.x, p.y - _startPos.y)
                    var newScale = _startScale * (_startWidth + delta) / _startWidth
                    panelSettings.panelScale = Math.min(Math.max(newScale, _minScale), _maxScale)
                }
                onReleased: {
                    _clampPanel()
                    _savePanel()
                }
            }
        }
    }
}
