import QGroundControl
import QGroundControl.FlyView

GuidedToolStripAction {
    text:       _guidedController.takeoffTitle
    iconSource: "/res/takeoff.svg"
    visible:    true
    enabled:    _guidedController.showTakeoff
    actionID:   _guidedController.actionTakeoff
}
