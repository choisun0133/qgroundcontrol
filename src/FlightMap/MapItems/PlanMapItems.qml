import QtQuick
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap
import QGroundControl.PlanView

// Adds visual items associated with the Flight Plan to the map.
// Currently only used by Fly View even though it's called PlanMapItems!
Item {
    id: _root

    property var    map                     ///< Map control to show items on
    property bool   largeMapView            ///< true: map takes up entire view, false: map is in small window
    property var    planMasterController    ///< Reference to PlanMasterController for vehicle
    property var    vehicle                 ///< Vehicle associated with these items

    property var    _map:                       map
    property var    _vehicle:                   vehicle
    property var    _missionController:         planMasterController.missionController
    property var    _geoFenceController:        planMasterController.geoFenceController
    property var    _rallyPointController:      planMasterController.rallyPointController
    property var    _guidedController:          globals.guidedControllerFlyView
    property var    _missionLineViewComponent

    property string fmode: vehicle.flightMode

    // Add the mission item visuals to the map
    Repeater {
        model: largeMapView ? _missionController.visualItems : 0

        delegate: MissionItemMapVisual {
            map:        _map
            vehicle:    _vehicle
            onClicked:  _guidedController.confirmAction(_guidedController.actionSetWaypoint, Math.max(object.sequenceNumber, 1))
        }
    }

    // Hovering a waypoint shows its latitude / longitude / altitude (does not block clicks)
    Repeater {
        model: largeMapView ? _missionController.visualItems : 0

        delegate: Item {
            property var _missionItem:  object
            property var _hoverItem:    null

            Component.onCompleted: {
                if (_missionItem.specifiesCoordinate && !_missionItem.homePosition) {
                    _hoverItem = waypointHoverComponent.createObject(_map, { missionItem: _missionItem })
                    _map.addMapItem(_hoverItem)
                }
            }
            Component.onDestruction: {
                if (_hoverItem) {
                    _map.removeMapItem(_hoverItem)
                    _hoverItem.destroy()
                }
            }
        }
    }

    Component {
        id: waypointHoverComponent

        MapQuickItem {
            id:             hoverMapItem
            coordinate:     missionItem.coordinate
            anchorPoint.x:  hoverTarget.width / 2
            anchorPoint.y:  hoverTarget.height / 2
            z:              QGroundControl.zOrderTopMost

            property var missionItem

            sourceItem: Item {
                id:     hoverTarget
                width:  ScreenTools.defaultFontPixelHeight * 1.6
                height: width

                HoverHandler { id: waypointHover }

                Rectangle {
                    x:              parent.width + ScreenTools.defaultFontPixelWidth * 0.5
                    y:              (parent.height - height) / 2
                    width:          infoColumn.width + ScreenTools.defaultFontPixelWidth * 2
                    height:         infoColumn.height + ScreenTools.defaultFontPixelHeight * 0.6
                    radius:         ScreenTools.defaultFontPixelHeight * 0.3
                    color:          "#E60E0F11"
                    border.color:   QGroundControl.globalPalette.brandingBlue
                    visible:        waypointHover.hovered

                    Column {
                        id:                 infoColumn
                        anchors.centerIn:   parent
                        spacing:            0

                        QGCLabel {
                            text:       (hoverMapItem.missionItem.isTakeoffItem ? qsTr("이륙") : qsTr("WP %1").arg(hoverMapItem.missionItem.sequenceNumber))
                                        + "  " + hoverMapItem.missionItem.commandName
                            color:      Qt.lighter(QGroundControl.globalPalette.brandingBlue, 1.25)
                            font.bold:  true
                        }
                        QGCLabel {
                            text:           qsTr("위도  %1").arg(hoverMapItem.missionItem.coordinate.latitude.toFixed(7))
                            font.family:    ScreenTools.fixedFontFamily
                        }
                        QGCLabel {
                            text:           qsTr("경도  %1").arg(hoverMapItem.missionItem.coordinate.longitude.toFixed(7))
                            font.family:    ScreenTools.fixedFontFamily
                        }
                        QGCLabel {
                            visible:        hoverMapItem.missionItem.isSimpleItem && !!hoverMapItem.missionItem.altitude
                            text:           visible ? qsTr("고도  %1 %2").arg(hoverMapItem.missionItem.altitude.valueString).arg(hoverMapItem.missionItem.altitude.units) : ""
                            font.family:    ScreenTools.fixedFontFamily
                        }
                        QGCLabel {
                            visible:        !isNaN(hoverMapItem.missionItem.amslEntryAlt)
                            text:           qsTr("해발  %1 m").arg(hoverMapItem.missionItem.amslEntryAlt.toFixed(1))
                            color:          "#9BA1A6"
                            font.family:    ScreenTools.fixedFontFamily
                            font.pointSize: ScreenTools.smallFontPointSize
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        _missionLineViewComponent = missionLineViewComponent.createObject(map)
        if (_missionLineViewComponent.status === Component.Error)
            console.log(_missionLineViewComponent.errorString())
        map.addMapItemGroup(_missionLineViewComponent)
    }

    Component.onDestruction: {
        if (_missionLineViewComponent) {
            // Must remove MapItemGroup before destruction, otherwise we crash on quit
            map.removeMapItemGroup(_missionLineViewComponent)
            _missionLineViewComponent.destroy()
        }
    }

    Component {
        id: missionLineViewComponent

        MapItemGroup {
            MissionLineView {
                model: _missionController.simpleFlightPathSegments
            }

            MapItemView {
                model: _missionController.directionArrows

                delegate: MapLineArrow {
                    fromCoord:      object ? object.coordinate1 : undefined
                    toCoord:        object ? object.coordinate2 : undefined
                    arrowPosition:  3
                    z:              QGroundControl.zOrderWaypointLines + 1
                }
            }
        }
    }
}
