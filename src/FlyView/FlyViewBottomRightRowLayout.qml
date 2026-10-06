import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

RowLayout {
    // AeroResearch: single instrument panel instead of the stock telemetry bar + compass
    AeroInstrumentPanel {
        Layout.alignment:   Qt.AlignBottom
        visible:            _showSingleVehicleUI
    }
}
