import QGroundControl
import QGroundControl.Controls

// Tool strip button for keyboard manual control (AeroKeyboardControl). Shown only while a supported
// multirotor is flying and paused (pause flight mode), and while manual control is on (to end it).
ToolStripAction {
    property var  _vehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool _active:      globals.aeroKeyboardControlActive

    text:           _active ? qsTr("수동 해제") : qsTr("수동 조종")
    iconSource:     "/res/AeroManualControl.svg"
    property bool _paused:      !!_vehicle && _vehicle.flying && _vehicle.flightMode === _vehicle.pauseFlightMode

    visible:        _active || (_paused && _vehicle.guidedModeBodyVelocitySupported())
    enabled:        visible
    nonExclusive:   true

    onTriggered: {
        if (_active) {
            globals.aeroKeyboardControlActive = false
            if (_vehicle && _vehicle.guidedMode && _vehicle.flying) {
                _vehicle.pauseVehicle()     // keep hovering where manual control ended
            }
        } else {
            globals.aeroKeyboardControlActive = true
        }
    }
}
