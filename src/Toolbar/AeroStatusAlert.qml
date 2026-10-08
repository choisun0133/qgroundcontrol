import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// AeroResearch: banner under the toolbar for the most important link / GPS / battery problem.
// Closing it hides that alert until a different alert (or the same one again later) appears.
Rectangle {
    id:         control
    width:      Math.min(_u * 36, contentRow.implicitWidth + _u * 1.6)
    height:     contentRow.implicitHeight + _u * 1.0
    radius:     _u * 0.5
    visible:    !!_alert && _alert.key !== _dismissedKey
    color:      _lost ? "#2A1214" : "#2A2110"
    border.color: _lost ? "#FF4D4D" : "#FFB020"
    border.width: 2

    readonly property real _u: ScreenTools.defaultFontPixelHeight
    property var    _alert:         status.alert
    property bool   _lost:          !!_alert && _alert.level === "lost"
    property string _dismissedKey:  ""

    AeroLinkStatus { id: status }

    // Forget a dismissal once that alert clears, so it shows again next time it happens
    on_AlertChanged: {
        if (!_alert || _alert.key !== _dismissedKey) {
            _dismissedKey = ""
        }
    }

    RowLayout {
        id:                 contentRow
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: control._u * 0.8
        anchors.rightMargin: control._u * 0.4
        spacing:            control._u * 0.7

        QGCLabel {
            text:           "⚠"
            color:          control._lost ? "#FF8A8A" : "#FFC861"
            font.pointSize: ScreenTools.largeFontPointSize
        }
        ColumnLayout {
            Layout.fillWidth:   true
            spacing:            0
            QGCLabel {
                Layout.fillWidth:   true
                text:               control._alert ? control._alert.title : ""
                color:              control._lost ? "#FF8A8A" : "#FFC861"
                font.bold:          true
                elide:              Text.ElideRight
            }
            QGCLabel {
                Layout.fillWidth:   true
                text:               control._alert ? control._alert.sub : ""
                color:              "#D5D8DB"
                font.pointSize:     ScreenTools.smallFontPointSize
                wrapMode:           Text.WordWrap
            }
        }
        QGCButton {
            text:       "✕"
            onClicked:  control._dismissedKey = control._alert ? control._alert.key : ""
        }
    }
}
