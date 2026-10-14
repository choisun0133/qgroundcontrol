import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// AeroResearch quick tools (Mission Planner style Ctrl+F): FC reboot and window toggles.
Popup {
    id:             control
    parent:         Overlay.overlay
    x:              Math.round((parent.width - width) / 2)
    y:              Math.round((parent.height - height) / 3)
    width:          _u * 22
    padding:        _u * 0.8
    modal:          true
    focus:          true
    closePolicy:    Popup.CloseOnEscape | Popup.CloseOnPressOutside

    readonly property real _u:          ScreenTools.defaultFontPixelHeight
    property var  _vehicle:             QGroundControl.multiVehicleManager.activeVehicle
    property bool _armed:               _vehicle ? _vehicle.armed : false
    property bool _confirmReboot:       false

    function toggle() {
        if (opened) {
            close()
        } else {
            _confirmReboot = false
            open()
        }
    }

    onClosed: _confirmReboot = false

    background: Rectangle {
        color:          "#0E0F11"
        border.color:   "#2A2D31"
        radius:         control._u * 0.5
    }

    contentItem: ColumnLayout {
        spacing: control._u * 0.5

        RowLayout {
            Layout.fillWidth: true
            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("빠른 도구")
                font.bold:          true
            }
            QGCLabel {
                text:           Qt.platform.os === "osx" ? "⌘F" : "Ctrl+F"
                color:          "#6E757B"
                font.pointSize: ScreenTools.smallFontPointSize
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#2A2D31" }

        // ---- FC reboot ----
        Rectangle {
            Layout.fillWidth:       true
            Layout.preferredHeight: rebootColumn.implicitHeight + control._u * 0.8
            radius:                 control._u * 0.35
            color:                  control._confirmReboot ? Qt.rgba(1, 0.3, 0.3, 0.12) : "#15181B"
            border.color:           control._confirmReboot ? "#FF4D4D" : "#2A2D31"

            ColumnLayout {
                id:                 rebootColumn
                anchors.left:       parent.left
                anchors.right:      parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins:    control._u * 0.5
                spacing:            control._u * 0.3

                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        Layout.fillWidth:   true
                        spacing:            0
                        QGCLabel { text: qsTr("FC 재부팅"); font.bold: true }
                        QGCLabel {
                            Layout.fillWidth:   true
                            text:               !control._vehicle ? qsTr("기체 연결 안 됨")
                                              : (control._armed ? qsTr("시동 중에는 재부팅할 수 없습니다") : qsTr("비행 컨트롤러를 다시 시작합니다"))
                            color:              control._armed ? "#FFB020" : "#9BA1A6"
                            font.pointSize:     ScreenTools.smallFontPointSize
                            wrapMode:           Text.WordWrap
                        }
                    }
                    QGCButton {
                        visible:    !control._confirmReboot
                        enabled:    !!control._vehicle && !control._armed
                        text:       qsTr("재부팅")
                        onClicked:  control._confirmReboot = true
                    }
                }

                RowLayout {
                    Layout.fillWidth:   true
                    visible:            control._confirmReboot
                    QGCLabel {
                        Layout.fillWidth:   true
                        text:               qsTr("정말 재부팅할까요? 잠시 연결이 끊깁니다.")
                        color:              "#FF8A8A"
                        font.pointSize:     ScreenTools.smallFontPointSize
                        wrapMode:           Text.WordWrap
                    }
                    QGCButton {
                        text:       qsTr("취소")
                        onClicked:  control._confirmReboot = false
                    }
                    QGCButton {
                        text:       qsTr("재부팅 실행")
                        enabled:    !!control._vehicle && !control._armed
                        onClicked: {
                            if (control._vehicle && !control._armed) {
                                control._vehicle.rebootVehicle()
                            }
                            control.close()
                        }
                    }
                }
            }
        }

        // ---- Window toggles ----
        Repeater {
            model: [
                { label: qsTr("근접 센서 창"),  sub: qsTr("방향별 장애물 거리"),        key: "proximity" },
                { label: qsTr("진동 · EKF 창"), sub: qsTr("진동 · EKF 상태 · 플래그"),  key: "health" },
                { label: qsTr("키보드 조종"),   sub: qsTr("비행 중 · W/S/A/D + 방향키 (모드2)"), key: "keyboard" }
            ]

            Rectangle {
                id:                     toggleItem
                Layout.fillWidth:       true
                Layout.preferredHeight: toggleRow.implicitHeight + control._u * 0.6
                radius:                 control._u * 0.35
                color:                  toggleMouse.containsMouse ? "#1C1F23" : "#15181B"
                border.color:           "#2A2D31"

                property bool _on: modelData.key === "proximity" ? globals.aeroProximityPanelVisible
                                 : (modelData.key === "keyboard" ? globals.aeroKeyboardControlActive : globals.aeroHealthPanelVisible)

                RowLayout {
                    id:                 toggleRow
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins:    control._u * 0.5

                    ColumnLayout {
                        Layout.fillWidth:   true
                        spacing:            0
                        QGCLabel { text: modelData.label; font.bold: true }
                        QGCLabel { text: modelData.sub; color: "#9BA1A6"; font.pointSize: ScreenTools.smallFontPointSize }
                    }
                    // on/off pill
                    Rectangle {
                        Layout.preferredWidth:  control._u * 3.2
                        Layout.preferredHeight: control._u * 1.4
                        radius:                 height / 2
                        color:                  toggleItem._on ? "#FF7A1A" : "#2A2D31"
                        QGCLabel {
                            anchors.centerIn:   parent
                            text:               toggleItem._on ? "ON" : "OFF"
                            color:              toggleItem._on ? "#0E0F11" : "#9BA1A6"
                            font.bold:          true
                            font.pointSize:     ScreenTools.smallFontPointSize
                        }
                    }
                }

                MouseArea {
                    id:             toggleMouse
                    anchors.fill:   parent
                    hoverEnabled:   true
                    cursorShape:    Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.key === "proximity") {
                            globals.aeroProximityPanelVisible = !globals.aeroProximityPanelVisible
                        } else if (modelData.key === "keyboard") {
                            globals.aeroKeyboardControlActive = !globals.aeroKeyboardControlActive
                            control.close()     // give keyboard focus back to the fly view
                        } else {
                            globals.aeroHealthPanelVisible = !globals.aeroHealthPanelVisible
                        }
                    }
                }
            }
        }

        // ---- Video diagnostics ----
        Rectangle {
            Layout.fillWidth:       true
            Layout.preferredHeight: diagRow.implicitHeight + control._u * 0.6
            radius:                 control._u * 0.35
            color:                  "#15181B"
            border.color:           "#2A2D31"

            RowLayout {
                id:                     diagRow
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins:        control._u * 0.5

                ColumnLayout {
                    Layout.fillWidth:   true
                    spacing:            0
                    QGCLabel { text: qsTr("영상 진단 로그"); font.bold: true }
                    QGCLabel {
                        Layout.fillWidth:   true
                        text:               QGroundControl.videoManager.diagnosticsRunning ? qsTr("기록 중… 60초 뒤 바탕화면에 저장")
                                                                                          : qsTr("영상을 다시 연결하며 60초 동안 기록")
                        color:              "#9BA1A6"
                        font.pointSize:     ScreenTools.smallFontPointSize
                        wrapMode:           Text.WordWrap
                    }
                }
                QGCButton {
                    text:       qsTr("기록 시작")
                    enabled:    !QGroundControl.videoManager.diagnosticsRunning
                    onClicked:  QGroundControl.videoManager.startVideoDiagnostics()
                }
            }
        }

        QGCLabel {
            Layout.fillWidth:   true
            text:               qsTr("Esc 또는 바깥을 누르면 닫힙니다")
            color:              "#6E757B"
            font.pointSize:     ScreenTools.smallFontPointSize
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
