import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

// Bottom-right instrument panel: attitude indicator plus large altitude / speed /
// distance-to-home / heading / climb rate / flight time readouts.
Rectangle {
    id:             control
    implicitWidth:  mainRow.implicitWidth + _pad * 2
    implicitHeight: mainRow.implicitHeight + _pad * 2
    radius:         ScreenTools.defaultFontPixelWidth * 0.75
    color:          Qt.rgba(0.055, 0.059, 0.067, 0.94)
    border.color:   "#2A2D31"
    border.width:   1

    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    readonly property real _pad:    ScreenTools.defaultFontPixelWidth * 1.5

    function _value(fact, decimals) {
        if (!fact || isNaN(fact.rawValue)) {
            return "—"
        }
        return fact.value.toFixed(decimals)
    }

    component Readout: ColumnLayout {
        property string label
        property string value
        property string units
        spacing: 0

        QGCLabel {
            text:           parent.label
            color:          "#9BA1A6"
            font.pointSize: ScreenTools.smallFontPointSize
        }
        RowLayout {
            spacing: ScreenTools.defaultFontPixelWidth * 0.4
            QGCLabel {
                Layout.alignment:   Qt.AlignBaseline
                text:               value
                font.family:        ScreenTools.fixedFontFamily
                font.pointSize:     ScreenTools.largeFontPointSize
                font.bold:          true
            }
            QGCLabel {
                Layout.alignment:   Qt.AlignBaseline
                text:               units
                color:              "#9BA1A6"
                font.pointSize:     ScreenTools.smallFontPointSize
            }
        }
    }

    RowLayout {
        id:         mainRow
        x:          control._pad
        y:          control._pad
        spacing:    control._pad

        QGCAttitudeWidget {
            Layout.alignment:   Qt.AlignVCenter
            size:               ScreenTools.defaultFontPixelHeight * 6.5
            vehicle:            control._activeVehicle
        }

        GridLayout {
            columns:        2
            rowSpacing:     ScreenTools.defaultFontPixelHeight * 0.4
            columnSpacing:  ScreenTools.defaultFontPixelWidth * 2.5

            Readout {
                Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 11
                label:  qsTr("고도")
                value:  control._activeVehicle ? control._value(control._activeVehicle.altitudeRelative, 1) : "—"
                units:  control._activeVehicle ? control._activeVehicle.altitudeRelative.units : "m"
            }
            Readout {
                Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 11
                label:  qsTr("속도")
                value:  control._activeVehicle ? control._value(control._activeVehicle.groundSpeed, 1) : "—"
                units:  control._activeVehicle ? control._activeVehicle.groundSpeed.units : "m/s"
            }
            Readout {
                label:  qsTr("홈 거리")
                value:  control._activeVehicle ? control._value(control._activeVehicle.distanceToHome, 0) : "—"
                units:  control._activeVehicle ? control._activeVehicle.distanceToHome.units : "m"
            }
            Readout {
                label:  qsTr("방위")
                value:  control._activeVehicle && !isNaN(control._activeVehicle.heading.rawValue) ?
                            ("00" + Math.round(control._activeVehicle.heading.rawValue) % 360).slice(-3) + "°" : "—"
                units:  ""
            }
            Readout {
                label:  qsTr("상승 속도")
                value:  control._activeVehicle ? control._value(control._activeVehicle.climbRate, 1) : "—"
                units:  control._activeVehicle ? control._activeVehicle.climbRate.units : "m/s"
            }
            Readout {
                label:  qsTr("비행 시간")
                value:  control._activeVehicle ? control._activeVehicle.flightTime.valueString : "—"
                units:  ""
            }
        }
    }
}
