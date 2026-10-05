import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// Vehicle message log as a movable, collapsible window (newest first).
AeroFloatingPanel {
    id:             control
    title:          qsTr("메시지")
    settingsKey:    "MessageWindow"
    panelWidth:     ScreenTools.defaultFontPixelWidth * 46
    visible:        !!_activeVehicle
    badgeText:      _activeVehicle && _activeVehicle.messageCount > 0 ? _activeVehicle.messageCount.toString() : ""
    badgeColor:     _activeVehicle && _activeVehicle.messageTypeError ? qgcPal.colorRed : (_activeVehicle && _activeVehicle.messageTypeWarning ? qgcPal.colorOrange : qgcPal.text)

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    QGCPalette { id: qgcPal }

    function _format(message) {
        var font = "font: " + (ScreenTools.defaultFontPointSize.toFixed(0) - 1) + "pt monospace;"
        message = message.replace(new RegExp("<#E>", "g"), "color: " + qgcPal.colorRed + "; " + font)
        message = message.replace(new RegExp("<#I>", "g"), "color: " + qgcPal.colorOrange + "; " + font)
        message = message.replace(new RegExp("<#N>", "g"), "color: " + qgcPal.text + "; " + font)
        return message
    }

    function _reload() {
        messageText.text = _activeVehicle ? _format(_activeVehicle.formattedMessages) : ""
    }

    on_ActiveVehicleChanged: _reload()

    Connections {
        target: control._activeVehicle
        function onNewFormattedMessage(formattedMessage) { messageText.insert(0, control._format(formattedMessage)) }
    }

    QGCFlickable {
        Layout.fillWidth:       true
        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 12
        contentWidth:           width
        contentHeight:          messageText.height
        clip:                   true

        TextEdit {
            id:                 messageText
            width:              parent.width
            readOnly:           true
            selectByMouse:      true
            textFormat:         TextEdit.RichText
            wrapMode:           TextEdit.Wrap
            color:              qgcPal.text
            font.pointSize:     ScreenTools.defaultFontPointSize
            Component.onCompleted: control._reload()
        }

        QGCLabel {
            anchors.centerIn:   parent
            visible:            messageText.length === 0
            text:               qsTr("새 메시지가 없습니다")
            opacity:            0.6
        }
    }

    QGCButton {
        Layout.alignment:   Qt.AlignRight
        text:               qsTr("모두 지우기")
        heightFactor:       0.3
        onClicked: {
            if (control._activeVehicle) {
                control._activeVehicle.resetAllMessages()
            }
            messageText.text = ""
        }
    }
}
