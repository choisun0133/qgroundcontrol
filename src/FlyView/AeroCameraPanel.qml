import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// MAVLink camera + gimbal control: photo/video, zoom, EO/IR, gimbal tilt/pan.
// Uses the MAVLink camera protocol (cameraManager) and gimbal manager (gimbalController).
AeroFloatingPanel {
    id:             control
    title:          qsTr("카메라")
    settingsKey:    "CameraPanel"
    panelWidth:     ScreenTools.defaultFontPixelWidth * 34
    visible:        !!_activeVehicle
    badgeText:      _recording ? "● REC " + _camera.recordTimeStr : ""

    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property var    _cameraManager:     _activeVehicle ? _activeVehicle.cameraManager : null
    property var    _camera:            _cameraManager ? _cameraManager.currentCameraInstance : null
    property var    _gimbalController:  _activeVehicle ? _activeVehicle.gimbalController : null
    property var    _gimbal:            _gimbalController ? _gimbalController.activeGimbal : null

    property bool   _hasCamera:     !!_camera
    property bool   _videoMode:     _hasCamera && _camera.cameraMode === MavlinkCameraControlInterface.CAM_MODE_VIDEO
    property bool   _recording:     _hasCamera && _camera.captureVideoState === MavlinkCameraControlInterface.CaptureVideoStateCapturing
    property bool   _hasThermal:    _hasCamera && !!_camera.thermalStreamInstance
    property real   _pitch:         _gimbal && !isNaN(_gimbal.absolutePitch.rawValue) ? _gimbal.absolutePitch.rawValue : 0
    property real   _yaw:           _gimbal && !isNaN(_gimbal.bodyYaw.rawValue) ? _gimbal.bodyYaw.rawValue : 0

    readonly property real _pitchStep:  10
    readonly property real _yawStep:    15
    readonly property color _accent:    qgcPal.brandingBlue
    readonly property real  _btn:       ScreenTools.defaultFontPixelHeight * 2.4

    QGCPalette { id: qgcPal }

    property int _sensor: 0     // 0 EO, 1 IR, 2 EO+IR (picture-in-picture)

    readonly property int _autopilotCompId:     1       // MAV_COMP_ID_AUTOPILOT1
    readonly property int _cmdSetCameraSource:  534     // MAV_CMD_SET_CAMERA_SOURCE
    readonly property int _sourceRgb:           1       // CAMERA_SOURCE_RGB
    readonly property int _sourceIr:            2       // CAMERA_SOURCE_IR

    function _setSensor(sensor) {
        _sensor = sensor
        if (_activeVehicle) {
            var primary = sensor === 1 ? _sourceIr : _sourceRgb
            var secondary = sensor === 2 ? _sourceIr : 0
            // param1 0 = all cameras on the autopilot
            _activeVehicle.sendCommand(_autopilotCompId, _cmdSetCameraSource, true, 0, primary, secondary)
        }
        if (_hasThermal) {
            _camera.thermalMode = sensor === 1 ? MavlinkCameraControlInterface.THERMAL_FULL :
                                  (sensor === 2 ? MavlinkCameraControlInterface.THERMAL_PIP : MavlinkCameraControlInterface.THERMAL_OFF)
        }
    }

    function _sendGimbal(pitch, yaw) {
        if (!_gimbalController) {
            return
        }
        pitch = Math.max(-90, Math.min(30, pitch))
        yaw = Math.max(-180, Math.min(180, yaw))
        _gimbalController.sendPitchBodyYaw(pitch, yaw)
    }

    component SegButton: QGCButton {
        property bool selected: false
        Layout.fillWidth:       true
        Layout.preferredWidth:  1
        heightFactor:           0.4
        fontWeight:             Font.Bold
        backgroundColor:        selected ? control._accent : qgcPal.button
        textColor:              selected ? "#0E0F11" : qgcPal.buttonText
    }

    component PadButton: QGCButton {
        Layout.preferredWidth:  control._btn
        Layout.preferredHeight: control._btn
        heightFactor:           0.2
        pointSize:              ScreenTools.mediumFontPointSize
        enabled:                !!control._gimbalController
    }

    QGCLabel {
        Layout.fillWidth:   true
        visible:            !control._hasCamera
        wrapMode:           Text.WordWrap
        text:               qsTr("MAVLink 카메라 정보가 없어 촬영 버튼은 숨겨집니다. 센서 전환과 짐벌 조작은 사용할 수 있어요.")
        opacity:            0.7
    }

    // Photo / video mode
    RowLayout {
        Layout.fillWidth:   true
        visible:            control._hasCamera
        spacing:            2

        SegButton {
            text:       qsTr("사진")
            selected:   !control._videoMode
            enabled:    !control._recording
            onClicked:  control._camera.setCameraModePhoto()
        }
        SegButton {
            text:       qsTr("영상")
            selected:   control._videoMode
            onClicked:  control._camera.setCameraModeVideo()
        }
    }

    // EO / IR / EO+IR - always shown. Sends MAV_CMD_SET_CAMERA_SOURCE to the autopilot
    // (ArduPilot 4.5+: SIYI, Topotek, Viewpro... gimbals) and, when QGC also receives a
    // separate thermal stream, switches the local thermal view to match.
    RowLayout {
        Layout.fillWidth:   true
        spacing:            2

        QGCLabel { text: qsTr("센서"); opacity: 0.7 }
        SegButton {
            text:       "EO"
            selected:   control._sensor === 0
            onClicked:  control._setSensor(0)
        }
        SegButton {
            text:       "IR"
            selected:   control._sensor === 1
            onClicked:  control._setSensor(1)
        }
        SegButton {
            text:       "EO+IR"
            selected:   control._sensor === 2
            onClicked:  control._setSensor(2)
        }
    }

    RowLayout {
        Layout.fillWidth:   true
        spacing:            control._margin * 1.5

        // Shutter
        ColumnLayout {
            Layout.fillWidth:   true
            visible:            control._hasCamera
            spacing:            control._margin * 0.5

            Rectangle {
                Layout.alignment:       Qt.AlignHCenter
                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 3.8
                Layout.preferredHeight: Layout.preferredWidth
                radius:                 width / 2
                color:                  qgcPal.windowShadeDark
                border.color:           qgcPal.text
                border.width:           3

                Rectangle {
                    anchors.centerIn:   parent
                    width:              control._recording ? parent.width * 0.36 : parent.width * 0.7
                    height:             width
                    radius:             control._recording ? 4 : width / 2
                    color:              control._videoMode ? qgcPal.colorRed : qgcPal.text
                }

                MouseArea {
                    anchors.fill:   parent
                    onClicked: {
                        if (control._videoMode) {
                            control._camera.toggleVideoRecording()
                        } else {
                            control._camera.takePhoto()
                        }
                    }
                }
            }
            QGCLabel {
                Layout.alignment:   Qt.AlignHCenter
                text:               control._videoMode ? (control._recording ? qsTr("녹화 중지") : qsTr("녹화 시작")) : qsTr("사진 촬영")
                font.bold:          true
            }
        }

        // Gimbal pad
        ColumnLayout {
            spacing: control._margin * 0.5

            GridLayout {
                Layout.alignment:   Qt.AlignHCenter
                columns:            3
                rowSpacing:         4
                columnSpacing:      4

                Item { width: 1; height: 1 }
                PadButton { text: "▲"; onClicked: control._sendGimbal(control._pitch + control._pitchStep, control._yaw) }
                Item { width: 1; height: 1 }
                PadButton { text: "◀"; onClicked: control._sendGimbal(control._pitch, control._yaw - control._yawStep) }
                PadButton {
                    text:           qsTr("정면")
                    pointSize:      ScreenTools.smallFontPointSize
                    onClicked:      control._gimbalController.centerGimbal()
                }
                PadButton { text: "▶"; onClicked: control._sendGimbal(control._pitch, control._yaw + control._yawStep) }
                Item { width: 1; height: 1 }
                PadButton { text: "▼"; onClicked: control._sendGimbal(control._pitch - control._pitchStep, control._yaw) }
                Item { width: 1; height: 1 }
            }
            QGCLabel {
                Layout.alignment:   Qt.AlignHCenter
                text:               control._gimbal ? qsTr("상하 %1° · 좌우 %2°").arg(control._pitch.toFixed(0)).arg(control._yaw.toFixed(0)) : qsTr("짐벌 없음")
                opacity:            0.7
            }
        }
    }

    // Zoom
    RowLayout {
        Layout.fillWidth:   true
        visible:            control._hasCamera && control._camera.hasZoom
        spacing:            control._margin

        QGCLabel { text: qsTr("줌"); opacity: 0.7 }
        QGCButton {
            text:                   "−"
            Layout.preferredWidth:  control._btn
            onClicked:              control._camera.stepZoom(-1)
        }
        QGCLabel {
            Layout.fillWidth:       true
            horizontalAlignment:    Text.AlignHCenter
            text:                   control._cameraManager && control._cameraManager.currentZoomLevel > 0 ? control._cameraManager.currentZoomLevel + "x" : "—"
            font.bold:              true
        }
        QGCButton {
            text:                   "+"
            Layout.preferredWidth:  control._btn
            onClicked:              control._camera.stepZoom(1)
        }
    }
}
