import QGroundControl
import QGroundControl.Controls

// Tool strip shortcut to the vehicle setup / app settings selector
ToolStripAction {
    text:       qsTr("설정")
    iconSource: "/qmlimages/Gears.svg"
    onTriggered: mainWindow.showToolSelectDialog()
}
