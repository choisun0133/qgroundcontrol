import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// AeroResearch logo menu: vehicle status, vehicle setup / analyze / app settings / links,
// version and exit. 비행 / 임무 계획 are always in the toolbar's view switch instead.
ToolIndicatorPage {
    id: root

    contentComponent: Component {
        ColumnLayout {
            id:         menuLayout
            width:      ScreenTools.defaultFontPixelWidth * 34
            spacing:    ScreenTools.defaultFontPixelHeight * 0.3

            property var    _vehicle:   QGroundControl.multiVehicleManager.activeVehicle
            readonly property real _u:  ScreenTools.defaultFontPixelHeight

            function _open(fn) {
                if (mainWindow.allowViewSwitch()) {
                    mainWindow.closeIndicatorDrawer()
                    fn()
                }
            }

            // Vehicle status
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: statusRow.implicitHeight + menuLayout._u * 0.9
                radius:                 menuLayout._u * 0.4
                color:                  "#15181B"
                border.color:           "#2A2D31"

                RowLayout {
                    id:                     statusRow
                    anchors.left:           parent.left
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins:        menuLayout._u * 0.6
                    spacing:                menuLayout._u * 0.5

                    Rectangle {
                        Layout.preferredWidth:  menuLayout._u * 0.5
                        Layout.preferredHeight: Layout.preferredWidth
                        radius:                 width / 2
                        color:                  menuLayout._vehicle ? (menuLayout._vehicle.vehicleLinkManager.communicationLost ? "#FF4D4D" : "#3DDC84") : "#5A6066"
                    }
                    ColumnLayout {
                        Layout.fillWidth:   true
                        spacing:            0
                        QGCLabel {
                            text:       menuLayout._vehicle ? qsTr("기체 연결됨") : qsTr("기체 연결 안 됨")
                            font.bold:  true
                        }
                        QGCLabel {
                            visible:        !!menuLayout._vehicle
                            text:           menuLayout._vehicle ? (menuLayout._vehicle.vehicleLinkManager.primaryLinkName + " · " + menuLayout._vehicle.flightMode) : ""
                            color:          "#9BA1A6"
                            font.pointSize: ScreenTools.smallFontPointSize
                        }
                    }
                }
            }

            QGCLabel {
                Layout.topMargin:   menuLayout._u * 0.3
                text:               qsTr("메뉴")
                color:              "#6E757B"
                font.pointSize:     ScreenTools.smallFontPointSize
                font.bold:          true
            }

            Repeater {
                model: [
                    { label: qsTr("기체 설정"), sub: qsTr("센서 보정 · 비행 모드 · 안전 · 파라미터"), icon: "/res/GearWithPaperPlane.svg", action: "setup" },
                    { label: qsTr("분석 도구"), sub: qsTr("비행 로그 · 지오태그 · MAVLink 점검"),     icon: "/qmlimages/Analyze.svg",      action: "analyze" },
                    { label: qsTr("앱 설정"),   sub: qsTr("화면 · 지도 · 영상 · 단위 · 언어"),       icon: "/qmlimages/Gears.svg",        action: "settings" },
                    { label: qsTr("연결 관리"), sub: qsTr("USB · RF · LTE 연결 추가 · 해제"),        icon: "/qmlimages/Connect.svg",      action: "links" }
                ]

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: menuLayout._u * 3
                    radius:                 menuLayout._u * 0.4
                    color:                  itemMouse.containsMouse ? "#1C1F23" : "transparent"

                    RowLayout {
                        anchors.fill:       parent
                        anchors.leftMargin: menuLayout._u * 0.5
                        anchors.rightMargin: menuLayout._u * 0.5
                        spacing:            menuLayout._u * 0.6

                        Rectangle {
                            Layout.preferredWidth:  menuLayout._u * 2
                            Layout.preferredHeight: Layout.preferredWidth
                            radius:                 menuLayout._u * 0.4
                            color:                  "#1C1F23"
                            QGCColoredImage {
                                anchors.centerIn:   parent
                                width:              parent.width * 0.55
                                height:             width
                                source:             modelData.icon
                                sourceSize.height:  height
                                color:              "#ECEDEE"
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth:   true
                            spacing:            0
                            QGCLabel { text: modelData.label; font.bold: true }
                            QGCLabel { text: modelData.sub; color: "#9BA1A6"; font.pointSize: ScreenTools.smallFontPointSize }
                        }
                        QGCLabel { text: "›"; color: "#5A6066"; font.pointSize: ScreenTools.largeFontPointSize }
                    }

                    MouseArea {
                        id:             itemMouse
                        anchors.fill:   parent
                        hoverEnabled:   true
                        cursorShape:    Qt.PointingHandCursor
                        onClicked: {
                            switch (modelData.action) {
                            case "setup":    menuLayout._open(mainWindow.showVehicleConfig); break
                            case "analyze":  menuLayout._open(mainWindow.showAnalyzeTool); break
                            case "settings": menuLayout._open(function() { mainWindow.showSettingsTool() }); break
                            case "links":    menuLayout._open(function() { mainWindow.showSettingsTool("Comm Links") }); break
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth:       true
                Layout.topMargin:       menuLayout._u * 0.3
                Layout.preferredHeight: 1
                color:                  "#2A2D31"
            }

            RowLayout {
                Layout.fillWidth:   true
                spacing:            menuLayout._u * 0.5

                ColumnLayout {
                    Layout.fillWidth:   true
                    spacing:            0
                    QGCLabel {
                        text:           QGroundControl.appName
                        font.bold:      true
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                    QGCLabel {
                        Layout.fillWidth:   true
                        text:               QGroundControl.qgcVersion
                        color:              "#9BA1A6"
                        font.family:        ScreenTools.fixedFontFamily
                        font.pointSize:     ScreenTools.smallFontPointSize
                        elide:              Text.ElideRight
                    }
                }
                QGCButton {
                    text:           qsTr("프로그램 종료")
                    textColor:      "#FF6B6B"
                    onClicked: {
                        if (mainWindow.allowViewSwitch()) {
                            mainWindow.closeIndicatorDrawer()
                            // Goes through the window close handler (unsaved plan / params / link checks)
                            mainWindow.close()
                        }
                    }
                }
            }
        }
    }
}
