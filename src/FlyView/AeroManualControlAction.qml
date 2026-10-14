import QGroundControl
import QGroundControl.Controls

// Tool strip button for keyboard manual control (AeroKeyboardControl). Enabled while a supported
// multirotor is flying; pressing it during a mission switches to GUIDED, which holds position first.
ToolStripAction {
    property var  _vehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool _active:      globals.aeroKeyboardControlActive

    text:           _active ? qsTr("수동 해제") : qsTr("수동 조종")
    iconSource:     "/res/AeroManualControl.svg"
    visible:        !!_vehicle && _vehicle.guidedModeBodyVelocitySupported()
    enabled:        _active || (!!_vehicle && _vehicle.flying)
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
