import QtQml.Models

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Viewer3D

ToolStripActionList {
    id: _root

    signal displayPreFlightChecklist

    model: [
        Viewer3DShowAction { },
        PreFlightCheckListShowAction { onTriggered: displayPreFlightChecklist() },
        AeroGuidedActionArm { },
        GuidedActionTakeoff { },
        AeroGuidedActionStartMission { },
        GuidedActionPause { },
        GuidedActionRTL { },
        GuidedActionLand { },
        FlyViewAdditionalActionsButton { },
        FlyViewGripperButton { }
    ]
}
