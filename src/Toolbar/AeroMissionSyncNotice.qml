import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// Shown below the toolbar when the vehicle reports a mission that differs from the one this GCS last
// synced (for example another GCS uploaded a new mission). Lets the operator download it or ignore it.
Rectangle {
    id:         control
    width:      contentRow.implicitWidth + _u * 1.6
    height:     contentRow.implicitHeight + _u * 1.0
    radius:     _u * 0.5
    color:      "#15181B"
    border.color: "#FF7A00"
    border.width: 1
    visible:    _missionManager ? _missionManager.vehicleMissionOutOfSync : false

    /// Called when the operator chooses to download; the host owns the plan controller
    signal downloadRequested()

    readonly property real _u:              ScreenTools.defaultFontPixelHeight
    property var    _activeVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property var    _missionManager:        _activeVehicle ? _activeVehicle.missionManager : null

    RowLayout {
        id:                 contentRow
        anchors.centerIn:   parent
        spacing:            control._u * 0.8

        Rectangle {
            Layout.preferredWidth:  control._u * 0.6
            Layout.preferredHeight: Layout.preferredWidth
            radius:                 width / 2
            color:                  "#FF7A00"
        }

        ColumnLayout {
            spacing: 0
            QGCLabel {
                text:       qsTr("기체 미션이 변경되었습니다")
                font.bold:  true
            }
            QGCLabel {
                text:           control._missionManager
                                ? qsTr("다른 관제에서 올린 미션으로 보입니다 · 기체 미션 %1개 항목").arg(control._missionManager.vehicleMissionCount)
                                : ""
                color:          "#9BA1A6"
                font.pointSize: ScreenTools.smallFontPointSize
            }
        }

        QGCButton {
            text:       qsTr("미션 다운로드")
            primary:    true
            onClicked:  control.downloadRequested()
        }

        QGCButton {
            text:       qsTr("무시")
            onClicked: {
                if (control._missionManager) {
                    control._missionManager.dismissVehicleMissionChange()
                }
            }
        }
    }
}
