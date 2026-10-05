import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// Shows which link(s) the active vehicle is using: RF (telemetry radio), LTE (TCP/UDP server),
// USB (direct). The primary link gets an accent border; a lost link is shown in red.
Item {
    id:             control
    implicitWidth:  linkRow.width
    visible:        !!_activeVehicle && _links.length > 0

    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var    _vlm:           _activeVehicle ? _activeVehicle.vehicleLinkManager : null
    property var    _names:         _vlm ? _vlm.linkNames : []
    property var    _statuses:      _vlm ? _vlm.linkStatuses : []
    property string _primary:       _vlm ? _vlm.primaryLinkName : ""
    property var    _configs:       QGroundControl.linkManager.linkConfigurations
    property var    _links:         _buildLinks(_names, _statuses, _primary)

    QGCPalette { id: qgcPal }

    function _typeLabel(name) {
        for (var i = 0; i < _configs.count; i++) {
            var cfg = _configs.get(i)
            if (cfg.name !== name) {
                continue
            }
            if (cfg.linkType === LinkConfiguration.TypeTcp) {
                return "LTE"
            }
            if (cfg.linkType === LinkConfiguration.TypeUdp) {
                // The built-in UDP auto-connect link is usually Wi-Fi/SITL, not the LTE server
                return cfg.dynamic ? "UDP" : "LTE"
            }
            if (cfg.linkType === LinkConfiguration.TypeBluetooth) {
                return "BT"
            }
            if (cfg.linkType === LinkConfiguration.TypeSerial) {
                return cfg.usbDirect ? "USB" : "RF"
            }
            return name
        }
        return name
    }

    function _buildLinks(names, statuses, primary) {
        var list = []
        for (var i = 0; i < names.length; i++) {
            list.push({ label: _typeLabel(names[i]), lost: statuses[i] !== "", primary: names[i] === primary && names.length > 1 })
        }
        return list
    }

    Row {
        id:                     linkRow
        anchors.verticalCenter: parent.verticalCenter
        spacing:                ScreenTools.defaultFontPixelWidth * 0.5

        Repeater {
            model: control._links

            Rectangle {
                width:          pillLabel.width + ScreenTools.defaultFontPixelWidth * 1.6
                height:         ScreenTools.defaultFontPixelHeight * 1.5
                radius:         ScreenTools.defaultFontPixelWidth * 0.5
                color:          modelData.primary ? Qt.rgba(qgcPal.brandingBlue.r, qgcPal.brandingBlue.g, qgcPal.brandingBlue.b, 0.15) : "transparent"
                border.width:   1
                border.color:   modelData.lost ? qgcPal.colorRed : (modelData.primary ? qgcPal.brandingBlue : qgcPal.buttonBorder)

                QGCLabel {
                    id:                 pillLabel
                    anchors.centerIn:   parent
                    text:               modelData.lost ? modelData.label + " " + qsTr("끊김") : modelData.label
                    color:              modelData.lost ? qgcPal.colorRed : qgcPal.text
                    font.bold:          true
                }
            }
        }
    }
}
