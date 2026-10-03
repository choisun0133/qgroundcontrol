import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// Used as the base class control for nboth VehicleGPSIndicator and RTKGPSIndicator

Item {
    id:             control
    width:          gpsIndicatorRow.width
    anchors.top:    parent.top
    anchors.bottom: parent.bottom

    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool   _rtkConnected:  QGroundControl.gpsRtk.connected.value
    property int    _gpsLock:       _activeVehicle ? _activeVehicle.gps.lock.rawValue : 0

    // GPS_FIX_TYPE -> short status text shown next to the satellite count
    function _fixText(lock) {
        switch (lock) {
        case 2:  return qsTr("2D")
        case 3:  return qsTr("GPS")
        case 4:  return qsTr("DGPS")
        case 5:  return qsTr("RTK Float")
        case 6:  return qsTr("RTK Fix")
        case 7:  return qsTr("Static")
        default: return qsTr("No Fix")
        }
    }

    function _fixColor(lock) {
        switch (lock) {
        case 2:  return qgcPal.colorOrange
        case 3:
        case 4:  return qgcPal.text
        case 5:  return qgcPal.colorYellow
        case 6:
        case 7:  return qgcPal.colorGreen
        default: return qgcPal.colorRed
        }
    }

    QGCPalette { id: qgcPal }

    Row {
        id:             gpsIndicatorRow
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        spacing:        ScreenTools.defaultFontPixelWidth / 2

        Row {
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            spacing:        -ScreenTools.defaultFontPixelWidth / 2

            QGCLabel {
                id:                     gpsLabel
                rotation:               90
                text:                   qsTr("RTK")
                color:                  qgcPal.text
                anchors.verticalCenter: parent.verticalCenter
                visible:                _rtkConnected
            }

            QGCColoredImage {
                id:                 gpsIcon
                width:              height
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                source:             "/qmlimages/Gps.svg"
                fillMode:           Image.PreserveAspectFit
                sourceSize.height:  height
                opacity:            (_activeVehicle && _activeVehicle.gps.count.value >= 0) ? 1 : 0.5
                color:              qgcPal.text
            }
        }

        Column {
            id:                     gpsValuesColumn
            anchors.verticalCenter: parent.verticalCenter
            visible:                _activeVehicle && !isNaN(_activeVehicle.gps.hdop.value)
            spacing:                0

            QGCLabel {
                anchors.horizontalCenter:   hdopValue.horizontalCenter
                color:              qgcPal.text
                text:               _activeVehicle ? _activeVehicle.gps.count.valueString : ""
            }

            QGCLabel {
                id:     hdopValue
                color:  qgcPal.text
                text:   _activeVehicle ? _activeVehicle.gps.hdop.value.toFixed(1) : ""
            }
        }

        // Fix type: No Fix / GPS / DGPS / RTK Float / RTK Fix
        QGCLabel {
            id:                     gpsFixLabel
            anchors.verticalCenter: parent.verticalCenter
            visible:                !!_activeVehicle
            text:                   _fixText(_gpsLock)
            color:                  _fixColor(_gpsLock)
            font.bold:              true
            font.pointSize:         ScreenTools.mediumFontPointSize
        }
    }

    MouseArea {
        anchors.fill:   parent
        onClicked:      mainWindow.showIndicatorDrawer(gpsIndicatorPage, control)
    }

    Component {
        id: gpsIndicatorPage

        GPSIndicatorPage { }
    }
}
