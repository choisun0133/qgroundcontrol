import QGroundControl
import QGroundControl.FlyView

// Arm / disarm toggle for the Fly View tool strip. Arming here is the only way to
// start the motors; Takeoff is enabled only once the vehicle is armed.
GuidedToolStripAction {
    property var  _activeVehicle:   QGroundControl.multiVehicleManager.activeVehicle
    property bool _armed:           _activeVehicle ? _activeVehicle.armed : false

    text:       _armed ? qsTr("시동 끄기") : qsTr("시동")
    iconSource: "/res/AeroPower.svg"
    visible:    !!_activeVehicle
    enabled:    _armed ? _guidedController.showDisarm : _guidedController.showArm
    actionID:   _armed ? _guidedController.actionDisarm : _guidedController.actionArm
}
