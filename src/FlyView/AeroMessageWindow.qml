import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// Vehicle message log as a movable, collapsible window (newest first).
// Each message is one row: time, severity dot, text (warnings/errors tinted).
AeroFloatingPanel {
    id:             control
    title:          qsTr("메시지")
    settingsKey:    "MessageWindow"
    panelWidth:     ScreenTools.defaultFontPixelWidth * 42
    visible:        !!_activeVehicle
    badgeText:      _alertCount > 0 ? qsTr("경고 %1").arg(_alertCount) : (messageModel.count > 0 ? messageModel.count.toString() : "")
    badgeColor:     _hasError ? "#FF4D4D" : (_alertCount > 0 ? "#F5C518" : "#9BA1A6")

    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property int    _alertCount:    0
    property bool   _hasError:      false

    readonly property int _maxRows: 300
    // <font style="<#E|I|N>">[hh:mm:ss.zzz COMP:n] Severity: text</font><br/>  (see StatusTextHandler.cc)
    readonly property string _rowPattern: "<font style=\"<#([EIN])>\">\\[(\\d\\d:\\d\\d:\\d\\d)[^\\]]*\\]\\s*[^:]*:\\s*([\\s\\S]*?)</font><br/>"

    QGCPalette { id: qgcPal }
    ListModel { id: messageModel }

    function _plain(html) {
        return html.replace(/<br\/?>/g, " ").replace(/<[^>]*>/g, "")
                   .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&amp;/g, "&")
    }

    function _parse(formatted) {
        var rows = []
        var re = new RegExp(_rowPattern, "g")
        var m
        while ((m = re.exec(formatted)) !== null) {
            rows.push({ level: m[1], time: m[2], text: _plain(m[3]) })
        }
        return rows
    }

    function _count(row) {
        if (row.level !== "N") {
            _alertCount++
        }
        if (row.level === "E") {
            _hasError = true
        }
    }

    function _reload() {
        messageModel.clear()
        _alertCount = 0
        _hasError = false
        if (!_activeVehicle) {
            return
        }
        var rows = _parse(_activeVehicle.formattedMessages)
        for (var i = 0; i < rows.length && i < _maxRows; i++) {
            messageModel.append(rows[i])
            _count(rows[i])
        }
    }

    on_ActiveVehicleChanged: _reload()
    Component.onCompleted: _reload()

    Connections {
        target: control._activeVehicle
        function onNewFormattedMessage(formattedMessage) {
            var rows = control._parse(formattedMessage)
            for (var i = 0; i < rows.length; i++) {
                messageModel.insert(0, rows[i])
                control._count(rows[i])
            }
            while (messageModel.count > control._maxRows) {
                messageModel.remove(messageModel.count - 1)
            }
        }
    }

    QGCListView {
        id:                     messageList
        Layout.fillWidth:       true
        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 13
        model:                  messageModel
        clip:                   true
        spacing:                2

        delegate: Rectangle {
            width:  messageList.width
            height: rowLayout.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.5
            radius: 3
            color:  model.level === "E" ? Qt.rgba(1, 0.30, 0.30, 0.10) : (model.level === "I" ? Qt.rgba(0.96, 0.77, 0.09, 0.08) : "transparent")

            RowLayout {
                id:                     rowLayout
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * 0.6
                anchors.rightMargin:    ScreenTools.defaultFontPixelWidth * 0.6
                spacing:                ScreenTools.defaultFontPixelWidth * 0.8

                QGCLabel {
                    Layout.alignment:   Qt.AlignTop
                    text:               model.time
                    color:              "#9BA1A6"
                    font.family:        ScreenTools.fixedFontFamily
                    font.pointSize:     ScreenTools.smallFontPointSize
                }
                Rectangle {
                    Layout.alignment:       Qt.AlignTop
                    Layout.topMargin:       ScreenTools.defaultFontPixelHeight * 0.35
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.4
                    Layout.preferredHeight: Layout.preferredWidth
                    radius:                 width / 2
                    color:                  model.level === "E" ? "#FF4D4D" : (model.level === "I" ? "#F5C518" : "#5A6066")
                }
                QGCLabel {
                    Layout.fillWidth:   true
                    text:               model.text
                    wrapMode:           Text.WordWrap
                    color:              model.level === "E" ? "#FFD6D6" : qgcPal.text
                }
            }
        }

        QGCLabel {
            anchors.centerIn:   parent
            visible:            messageModel.count === 0
            text:               qsTr("새 메시지가 없습니다")
            opacity:            0.6
        }
    }

    QGCButton {
        Layout.alignment:   Qt.AlignRight
        text:               qsTr("모두 지우기")
        heightFactor:       0.3
        enabled:            messageModel.count > 0
        onClicked: {
            if (control._activeVehicle) {
                control._activeVehicle.resetAllMessages()
            }
            messageModel.clear()
            control._alertCount = 0
            control._hasError = false
        }
    }
}
