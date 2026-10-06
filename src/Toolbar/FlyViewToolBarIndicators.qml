import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Toolbar

Item {
    objectName:    "flyViewToolBarIndicators"
    implicitWidth: mainLayout.width + _widthMargin

    property var  _activeVehicle:           QGroundControl.multiVehicleManager.activeVehicle
    property real _toolIndicatorMargins:    ScreenTools.defaultFontPixelHeight * 0.66
    property real _widthMargin:             _toolIndicatorMargins * 2

    Row {
        id:                 mainLayout
        anchors.margins:    _toolIndicatorMargins
        anchors.left:       parent.left
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        spacing:            ScreenTools.defaultFontPixelWidth * 1.75

        AeroLinkIndicator {
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
        }

        Repeater {
            id:     appRepeater
            model:  QGroundControl.corePlugin.toolBarIndicators
            Loader {
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                source:             modelData
                visible:            item.showIndicator
            }
        }

        Repeater {
            id:     toolIndicatorsRepeater
            model:  _activeVehicle ? _activeVehicle.toolIndicators : []

            Loader {
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                source:             modelData
                visible:            item.showIndicator
            }
        }

        // AeroResearch: armed state at the far right of the toolbar
        Item {
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width:          armedLabel.contentWidth + ScreenTools.defaultFontPixelWidth * 2
            visible:        !!_activeVehicle

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width:                  1
                height:                 parent.height * 0.8
                color:                  "#2A2D31"
            }
            QGCLabel {
                id:                     armedLabel
                anchors.right:          parent.right
                anchors.verticalCenter: parent.verticalCenter
                text:                   _activeVehicle && _activeVehicle.armed ? qsTr("시동 걸림") : qsTr("시동 꺼짐")
                color:                  _activeVehicle && _activeVehicle.armed ? "#FF4D4D" : "#9BA1A6"
                font.bold:              _activeVehicle && _activeVehicle.armed
            }
        }
    }
}
