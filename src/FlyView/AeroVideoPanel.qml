import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// Video window placeholder shown while no video stream is configured or received.
// Once a stream exists the stock (movable) PiP video window takes over.
AeroFloatingPanel {
    id:             control
    title:          qsTr("영상")
    settingsKey:    "VideoPanel"
    panelWidth:     ScreenTools.defaultFontPixelWidth * 36
    visible:        !!QGroundControl.multiVehicleManager.activeVehicle && !QGroundControl.videoManager.hasVideo
    badgeText:      qsTr("신호 없음")
    badgeColor:     "#9BA1A6"

    Rectangle {
        Layout.fillWidth:       true
        Layout.preferredHeight: width * 9 / 16
        radius:                 ScreenTools.defaultFontPixelWidth * 0.5
        color:                  "#050607"
        border.color:           "#2A2D31"
        border.width:           1

        ColumnLayout {
            anchors.centerIn:   parent
            width:              parent.width * 0.85
            spacing:            ScreenTools.defaultFontPixelHeight * 0.5

            QGCLabel {
                Layout.alignment:   Qt.AlignHCenter
                text:               qsTr("영상 신호 없음")
                font.pointSize:     ScreenTools.mediumFontPointSize
                font.bold:          true
                color:              "#9BA1A6"
            }
            QGCLabel {
                Layout.fillWidth:       true
                horizontalAlignment:    Text.AlignHCenter
                wrapMode:               Text.WordWrap
                text:                   qsTr("카메라 영상 주소(RTSP/UDP)를 설정하면 여기에 표시됩니다.")
                color:                  "#5A6066"
                font.pointSize:         ScreenTools.smallFontPointSize
            }
            QGCButton {
                Layout.alignment:   Qt.AlignHCenter
                text:               qsTr("영상 설정")
                onClicked:          mainWindow.showSettingsTool("Video")
            }
        }
    }
}
