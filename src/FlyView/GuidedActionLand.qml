import QGroundControl
import QGroundControl.FlyView

GuidedToolStripAction {
    text:       _guidedController.landTitle
    message:    _guidedController.landMessage
    iconSource: "/res/land.svg"
    visible:    true
    enabled:    _guidedController.showLand
    actionID:   _guidedController.actionLand
}
