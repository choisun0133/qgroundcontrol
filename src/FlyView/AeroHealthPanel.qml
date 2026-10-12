import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Toolbar

// AeroResearch: vibration (Vibe) and EKF window. Opens from the toolbar "진동 · EKF" chip.
// "상세" widens it to show the EKF flags and the SYS_STATUS sensor list.
AeroFloatingPanel {
    id:             control
    title:          qsTr("진동 · EKF")
    settingsKey:    "HealthWindow"
    panelWidth:     _u * (_details ? 46 : 23)
    badgeText:      status.health.detailProblems > 0 ? qsTr("이상 %1").arg(status.health.detailProblems) : ""
    badgeColor:     "#FFB020"

    readonly property real _u: ScreenTools.defaultFontPixelHeight
    property bool _details: false

    signal closeRequested()

    visible: globals.aeroHealthPanelVisible
    onCloseRequested: globals.aeroHealthPanelVisible = false

    AeroLinkStatus { id: status }

    // Header actions
    RowLayout {
        Layout.fillWidth:   true
        spacing:            control._u * 0.4

        QGCLabel {
            Layout.fillWidth:   true
            text:               status.health.detailProblems > 0 ? qsTr("플래그·센서 이상 %1개").arg(status.health.detailProblems) : ""
            color:              "#FFC861"
            font.pointSize:     ScreenTools.smallFontPointSize
            font.bold:          true
        }
        QGCButton {
            text:           control._details ? qsTr("상세 닫기 ◂") : qsTr("상세 ▸")
            heightFactor:   0.3
            onClicked:      control._details = !control._details
        }
        QGCButton {
            text:           "✕"
            heightFactor:   0.3
            onClicked:      control.closeRequested()
        }
    }

    GridLayout {
        Layout.fillWidth:   true
        columns:            control._details ? 2 : 1
        columnSpacing:      control._u * 1.2
        rowSpacing:         control._u * 0.6

        // ---- Left: Vibe + EKF ----
        ColumnLayout {
            Layout.fillWidth:       true
            Layout.alignment:       Qt.AlignTop
            Layout.preferredWidth:  control._u * 21
            spacing:                control._u * 0.45

            RowLayout {
                Layout.fillWidth: true
                Rectangle { width: control._u * 0.5; height: width; radius: width / 2; color: status.vibration.color }
                QGCLabel { text: qsTr("진동 (Vibe)"); font.bold: true }
                QGCLabel { text: status.vibration.word; color: status.vibration.color; font.bold: true }
                Item { Layout.fillWidth: true }
                QGCLabel { text: "m/s² · 30 / 60"; color: "#9BA1A6"; font.pointSize: ScreenTools.smallFontPointSize }
            }
            Repeater {
                model: status.vibration.axes
                delegate: barRow
            }
            RowLayout {
                Layout.fillWidth:   true
                spacing:            control._u * 0.3
                Repeater {
                    model: status.vibration.clips
                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: clipCol.implicitHeight + control._u * 0.4
                        radius:                 control._u * 0.25
                        color:                  "#15181B"
                        border.color:           "#2A2D31"
                        Column {
                            id:                     clipCol
                            anchors.verticalCenter: parent.verticalCenter
                            x:                      control._u * 0.35
                            QGCLabel { text: modelData.n + " " + qsTr("클리핑"); color: "#9BA1A6"; font.pointSize: ScreenTools.smallFontPointSize }
                            QGCLabel { text: modelData.v; color: modelData.color; font.bold: true; font.family: ScreenTools.fixedFontFamily }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#2A2D31"; Layout.topMargin: control._u * 0.3 }

            RowLayout {
                Layout.fillWidth: true
                Rectangle { width: control._u * 0.5; height: width; radius: width / 2; color: status.ekf.color }
                QGCLabel { text: qsTr("EKF 상태"); font.bold: true }
                QGCLabel { text: status.ekf.word; color: status.ekf.color; font.bold: true }
                Item { Layout.fillWidth: true }
                QGCLabel { text: qsTr("분산값 · 0.5 / 0.8"); color: "#9BA1A6"; font.pointSize: ScreenTools.smallFontPointSize }
            }
            Repeater {
                model: status.ekf.rows
                delegate: barRow
            }
        }

        // ---- Right: flags + sensors (details) ----
        ColumnLayout {
            visible:                control._details
            Layout.fillWidth:       true
            Layout.alignment:       Qt.AlignTop
            Layout.preferredWidth:  control._u * 21
            spacing:                control._u * 0.35

            RowLayout {
                Layout.fillWidth: true
                QGCLabel { text: qsTr("플래그 (EKF)"); font.bold: true }
                Item { Layout.fillWidth: true }
                QGCLabel {
                    text:           status.ekfFlagProblems > 0 ? qsTr("이상 %1개").arg(status.ekfFlagProblems) : qsTr("모두 정상")
                    color:          status.ekfFlagProblems > 0 ? "#FFC861" : "#7BEAB0"
                    font.bold:      true
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }
            GridLayout {
                Layout.fillWidth:   true
                columns:            2
                columnSpacing:      control._u * 0.6
                rowSpacing:         control._u * 0.15
                Repeater {
                    model: status.ekfFlags
                    RowLayout {
                        Layout.fillWidth:   true
                        spacing:            control._u * 0.35
                        Rectangle {
                            Layout.preferredWidth:  control._u * 0.7
                            Layout.preferredHeight: Layout.preferredWidth
                            radius:                 2
                            color:                  modelData.box
                            QGCLabel {
                                anchors.centerIn:   parent
                                text:               modelData.mark
                                color:              "#0E0F11"
                                font.bold:          true
                                font.pointSize:     ScreenTools.smallFontPointSize
                            }
                        }
                        QGCLabel { Layout.fillWidth: true; text: modelData.n; color: modelData.color; font.pointSize: ScreenTools.smallFontPointSize }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#2A2D31"; Layout.topMargin: control._u * 0.3 }

            RowLayout {
                Layout.fillWidth: true
                QGCLabel { text: qsTr("센서"); font.bold: true }
                Item { Layout.fillWidth: true }
                QGCLabel {
                    text:           status.sensorProblems > 0 ? qsTr("이상 %1개").arg(status.sensorProblems) : qsTr("모두 정상")
                    color:          status.sensorProblems > 0 ? "#FF8A8A" : "#7BEAB0"
                    font.bold:      true
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }
            GridLayout {
                Layout.fillWidth:   true
                columns:            2
                columnSpacing:      control._u * 0.8
                rowSpacing:         control._u * 0.15
                Repeater {
                    model: status.sensors
                    RowLayout {
                        Layout.fillWidth:   true
                        spacing:            control._u * 0.35
                        Rectangle { width: control._u * 0.35; height: width; radius: width / 2; color: modelData.dot }
                        QGCLabel { Layout.fillWidth: true; text: modelData.n; color: "#C9CDD1"; font.pointSize: ScreenTools.smallFontPointSize }
                        QGCLabel { text: modelData.s; color: modelData.color; font.bold: true; font.pointSize: ScreenTools.smallFontPointSize }
                    }
                }
            }
        }
    }

    // One labelled bar: name, track with 2 threshold ticks, value
    Component {
        id: barRow

        RowLayout {
            Layout.fillWidth:   true
            spacing:            control._u * 0.4

            property bool _isVibe: modelData.n.length === 1

            QGCLabel {
                Layout.preferredWidth:  _isVibe ? control._u * 0.9 : control._u * 3.6
                text:                   modelData.n
                color:                  "#C9CDD1"
                font.family:            _isVibe ? ScreenTools.fixedFontFamily : ScreenTools.normalFontFamily
            }
            Rectangle {
                id:                     track
                Layout.fillWidth:       true
                Layout.preferredHeight: control._u * 0.55
                radius:                 3
                color:                  "#1C1F23"

                Rectangle {
                    width:  track.width * modelData.frac
                    height: parent.height
                    radius: 3
                    color:  modelData.color
                }
                Rectangle { x: track.width * (_isVibe ? 1 / 3 : 0.5) - 1; width: 2; height: parent.height; color: Qt.rgba(1, 0.69, 0.125, 0.7) }
                Rectangle { x: track.width * (_isVibe ? 2 / 3 : 0.8) - 1; width: 2; height: parent.height; color: Qt.rgba(1, 0.3, 0.3, 0.7) }
            }
            QGCLabel {
                Layout.preferredWidth:  control._u * 2.4
                horizontalAlignment:    Text.AlignRight
                text:                   modelData.v
                color:                  modelData.color
                font.bold:              true
                font.family:            ScreenTools.fixedFontFamily
            }
        }
    }
}
