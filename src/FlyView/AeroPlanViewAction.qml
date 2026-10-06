import QGroundControl
import QGroundControl.Controls

// Tool strip shortcut to the mission planning view
ToolStripAction {
    text:       qsTr("임무 계획")
    iconSource: "/qmlimages/Plan.svg"
    onTriggered: mainWindow.showPlanView()
}
