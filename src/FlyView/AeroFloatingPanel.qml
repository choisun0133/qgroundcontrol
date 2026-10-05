import QtCore
import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// Floating panel used by the AeroResearch Fly View widgets.
// - drag the title bar to move it, press "-" to collapse it to a small pill
// - position and collapsed state are saved per panel (settingsKey)
Item {
    id: control

    property string title
    property string settingsKey
    property string badgeText:      ""
    property color  badgeColor:     qgcPal.colorRed
    property real   panelWidth:     ScreenTools.defaultFontPixelWidth * 40
    property real   defaultX:       0
    property real   defaultY:       0
    property bool   collapsed:      false
    property real   minY:           0

    default property alias content: contentColumn.data

    readonly property real _margin: ScreenTools.defaultFontPixelWidth

    width:  collapsed ? pill.width : panelWidth
    height: collapsed ? pill.height : panel.height

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    Settings {
        id:         saved
        category:   "AeroPanel_" + control.settingsKey

        property real posX:         -1
        property real posY:         -1
        property bool collapsed:    false
    }

    function _clamp() {
        if (!parent) {
            return
        }
        x = Math.max(0, Math.min(x, parent.width - width))
        y = Math.max(minY, Math.min(y, parent.height - height))
    }

    function _save() {
        saved.posX = x
        saved.posY = y
        saved.collapsed = collapsed
    }

    // Defer placement until the parent has its real size
    Component.onCompleted: Qt.callLater(function() {
        control.collapsed = saved.collapsed
        control.x = saved.posX >= 0 ? saved.posX : control.defaultX
        control.y = saved.posY >= 0 ? saved.posY : control.defaultY
        control._clamp()
    })

    onCollapsedChanged: Qt.callLater(function() { control._clamp(); control._save() })

    Connections {
        target:                 control.parent
        function onWidthChanged()  { control._clamp() }
        function onHeightChanged() { control._clamp() }
    }

    // ---- Expanded panel ----
    Rectangle {
        id:             panel
        width:          control.panelWidth
        height:         layout.height + control._margin * 2
        visible:        !control.collapsed
        radius:         ScreenTools.defaultFontPixelWidth * 0.75
        color:          Qt.rgba(qgcPal.window.r, qgcPal.window.g, qgcPal.window.b, 0.92)
        border.color:   qgcPal.groupBorder
        border.width:   1

        ColumnLayout {
            id:         layout
            x:          control._margin
            y:          control._margin
            width:      parent.width - control._margin * 2
            spacing:    control._margin

            // Title bar: drag handle + collapse button
            Item {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8

                MouseArea {
                    anchors.fill:   parent
                    cursorShape:    pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target:    control
                    drag.minimumX:  0
                    drag.minimumY:  control.minY
                    drag.maximumX:  control.parent ? control.parent.width - control.width : 0
                    drag.maximumY:  control.parent ? control.parent.height - control.height : 0
                    drag.threshold: 0
                    onReleased:     control._save()
                }

                RowLayout {
                    anchors.fill:   parent
                    spacing:        control._margin

                    QGCLabel {
                        text:       "≡"
                        opacity:    0.6
                    }
                    QGCLabel {
                        text:       control.title
                        font.bold:  true
                    }
                    Rectangle {
                        visible:                control.badgeText !== ""
                        Layout.preferredHeight: badgeLabel.height + 4
                        Layout.preferredWidth:  Math.max(Layout.preferredHeight, badgeLabel.width + control._margin)
                        radius:                 Layout.preferredHeight / 2
                        color:                  Qt.rgba(control.badgeColor.r, control.badgeColor.g, control.badgeColor.b, 0.2)

                        QGCLabel {
                            id:                 badgeLabel
                            anchors.centerIn:   parent
                            text:               control.badgeText
                            color:              control.badgeColor
                            font.bold:          true
                            font.pointSize:     ScreenTools.smallFontPointSize
                        }
                    }
                    Item { Layout.fillWidth: true }
                    QGCButton {
                        text:           "−"
                        heightFactor:   0.3
                        onClicked:      control.collapsed = true
                    }
                }
            }

            ColumnLayout {
                id:                 contentColumn
                Layout.fillWidth:   true
                spacing:            control._margin
            }
        }
    }

    // ---- Collapsed pill ----
    QGCButton {
        id:             pill
        visible:        control.collapsed
        text:           control.title + (control.badgeText !== "" ? "  " + control.badgeText : "") + "  ▴"
        heightFactor:   0.6
        onClicked:      control.collapsed = false
    }
}
