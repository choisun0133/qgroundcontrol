import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// Always-visible view switch in the top toolbar: 비행 / 임무 계획.
// Vehicle setup, analyze and app settings live in the logo menu.
Rectangle {
    id:             control
    implicitWidth:  row.implicitWidth + _pad * 2
    implicitHeight: row.implicitHeight + _pad * 2
    radius:         ScreenTools.defaultFontPixelWidth * 0.8
    color:          "#15181B"
    border.color:   "#2A2D31"
    border.width:   1

    property string current: "fly"     // "fly" or "plan"

    readonly property real  _pad:       ScreenTools.defaultFontPixelWidth * 0.35
    readonly property color _accent:    QGroundControl.globalPalette.brandingBlue

    function _go(view) {
        if (view === current || !mainWindow.allowViewSwitch()) {
            return
        }
        if (view === "fly") {
            mainWindow.showFlyView()
        } else {
            mainWindow.showPlanView()
        }
    }

    Row {
        id:     row
        x:      control._pad
        y:      control._pad
        spacing: control._pad

        Repeater {
            model: [
                { key: "fly",  label: qsTr("비행"),      icon: "/qmlimages/PaperPlane.svg" },
                { key: "plan", label: qsTr("임무 계획"), icon: "/qmlimages/Plan.svg" }
            ]

            Rectangle {
                readonly property bool selected: control.current === modelData.key
                width:  Math.max(ScreenTools.defaultFontPixelWidth * 7, itemColumn.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.6)
                height: ScreenTools.toolbarHeight * 0.78
                radius: ScreenTools.defaultFontPixelWidth * 0.6
                color:  selected ? control._accent : (itemMouse.containsMouse ? "#22262B" : "transparent")

                Column {
                    id:                 itemColumn
                    anchors.centerIn:   parent
                    spacing:            1
                    QGCColoredImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width:              ScreenTools.defaultFontPixelHeight * 1.1
                        height:             width
                        source:             modelData.icon
                        sourceSize.height:  height
                        color:              parent.parent.selected ? "#0E0F11" : "#C9CDD1"
                    }
                    QGCLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text:           modelData.label
                        font.pointSize: ScreenTools.smallFontPointSize
                        font.bold:      parent.parent.selected
                        color:          parent.parent.selected ? "#0E0F11" : "#C9CDD1"
                    }
                }

                MouseArea {
                    id:             itemMouse
                    anchors.fill:   parent
                    hoverEnabled:   true
                    cursorShape:    Qt.PointingHandCursor
                    onClicked:      control._go(modelData.key)
                }
            }
        }
    }
}
