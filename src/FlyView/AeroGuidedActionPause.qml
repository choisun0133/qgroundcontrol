import QGroundControl
import QGroundControl.Controls

// AeroResearch: one-click pause. Pausing only stops the vehicle where it is, so it skips the
// slide-to-confirm and the altitude slider of the stock Pause action (altitude changes stay
// available through the guided "Change Altitude" action).
ToolStripAction {
    property var _guidedController: globals.guidedControllerFlyView
    property var _vehicle:          QGroundControl.multiVehicleManager.activeVehicle

    text:       _guidedController.pauseTitle
    iconSource: "/res/pause-mission.svg"
    visible:    true
    enabled:    _guidedController.showPause

    onTriggered: {
        _guidedController.closeAll()
        if (_vehicle && _guidedController.showPause) {
            _vehicle.pauseVehicle()
        }
    }
}
