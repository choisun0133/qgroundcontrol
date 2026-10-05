import QGroundControl
import QGroundControl.FlyView

// Start Mission on the tool strip. Like Takeoff it is only enabled once the vehicle is
// armed (showStartMission requires it), so it never arms the vehicle by itself.
GuidedToolStripAction {
    text:       qsTr("미션 시작")
    iconSource: "/res/AeroStartMission.svg"
    visible:    _guidedController.showStartMission || (!!QGroundControl.multiVehicleManager.activeVehicle && !_guidedController._vehicleFlying)
    enabled:    _guidedController.showStartMission
    actionID:   _guidedController.actionStartMission
}
