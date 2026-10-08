import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// AeroResearch toolbar group: RF telemetry / RC transmitter / LTE / GPS / battery chips.
// Each chip shows its state colour, a short status and signal bars; clicking opens details.
Item {
    id:             control
    implicitWidth:  groupFrame.width
    visible:        !!status.vehicle

    readonly property real _u:  ScreenTools.defaultFontPixelHeight

    AeroLinkStatus { id: status }

    Rectangle {
        id:                     groupFrame
        anchors.verticalCenter: parent.verticalCenter
        width:                  chipRow.width + control._u * 0.4
        height:                 control._u * 2.5
        radius:                 control._u * 0.4
        color:                  "#15181B"
        border.color:           "#2A2D31"

        Row {
            id:                 chipRow
            anchors.centerIn:   parent
            spacing:            control._u * 0.25

            Repeater {
                model: status.items

                Rectangle {
                    id:             chip
                    width:          chipContent.width + control._u * 0.8
                    height:         control._u * 2.1
                    radius:         control._u * 0.3
                    color:          modelData.state === "lost" ? Qt.rgba(1, 0.3, 0.3, 0.16)
                                  : (modelData.state === "weak" ? Qt.rgba(1, 0.69, 0.125, 0.10)
                                  : (modelData.state === "ok" ? Qt.rgba(0.24, 0.86, 0.52, 0.08) : "transparent"))
                    border.width:   detailsPopup.opened && detailsPopup.itemKey === modelData.key ? 2 : 1
                    border.color:   detailsPopup.opened && detailsPopup.itemKey === modelData.key ? QGroundControl.globalPalette.brandingBlue
                                  : (modelData.state === "off" ? "transparent" : Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.55))

                    Row {
                        id:                     chipContent
                        anchors.centerIn:       parent
                        spacing:                control._u * 0.35

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing:                0
                            QGCLabel {
                                text:           modelData.name
                                color:          "#9BA1A6"
                                font.pointSize: ScreenTools.smallFontPointSize
                            }
                            QGCLabel {
                                text:       modelData.text
                                color:      modelData.color
                                font.bold:  true
                            }
                        }

                        // Signal bars
                        Row {
                            anchors.bottom:         parent.bottom
                            anchors.bottomMargin:   control._u * 0.2
                            spacing:                2
                            visible:                modelData.state !== "off"
                            Repeater {
                                model: 4
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width:          Math.max(3, control._u * 0.18)
                                    height:         control._u * (0.3 + index * 0.22)
                                    radius:         1
                                    color:          chip.chipData.state !== "lost" && chip.chipData.pct >= (index + 1) * 22 ? chip.chipData.color : "#33383D"
                                }
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible:                modelData.primary
                            width:                  primaryLabel.width + control._u * 0.4
                            height:                 primaryLabel.height + control._u * 0.1
                            radius:                 control._u * 0.15
                            color:                  Qt.rgba(1, 0.48, 0.1, 0.18)
                            QGCLabel {
                                id:                 primaryLabel
                                anchors.centerIn:   parent
                                text:               qsTr("주")
                                color:              "#FF9A4D"
                                font.pointSize:     ScreenTools.smallFontPointSize
                                font.bold:          true
                            }
                        }
                    }

                    property var chipData: modelData

                    MouseArea {
                        anchors.fill:   parent
                        cursorShape:    Qt.PointingHandCursor
                        onClicked: {
                            if (detailsPopup.opened && detailsPopup.itemKey === modelData.key) {
                                detailsPopup.close()
                                return
                            }
                            var p = chip.mapToItem(Overlay.overlay, 0, chip.height)
                            detailsPopup.itemKey = modelData.key
                            detailsPopup.x = Math.max(control._u * 0.5, Math.min(p.x, Overlay.overlay.width - detailsPopup.width - control._u * 0.5))
                            detailsPopup.y = p.y + control._u * 0.5
                            detailsPopup.open()
                        }
                    }
                }
            }
        }
    }

    Popup {
        id:             detailsPopup
        parent:         Overlay.overlay
        width:          control._u * 19
        padding:        control._u * 0.8
        closePolicy:    Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property string itemKey: ""
        property var    item: {
            var list = status.items
            for (var i = 0; i < list.length; i++) {
                if (list[i].key === itemKey) {
                    return list[i]
                }
            }
            return null
        }

        background: Rectangle {
            color:          "#0E0F11"
            border.color:   "#2A2D31"
            radius:         control._u * 0.5
        }

        contentItem: ColumnLayout {
            spacing: control._u * 0.6

            RowLayout {
                Layout.fillWidth:   true
                spacing:            control._u * 0.5
                Rectangle {
                    Layout.preferredWidth:  control._u * 0.55
                    Layout.preferredHeight: Layout.preferredWidth
                    radius:                 width / 2
                    color:                  detailsPopup.item ? detailsPopup.item.color : "#9BA1A6"
                }
                QGCLabel {
                    Layout.fillWidth:   true
                    text:               detailsPopup.item ? detailsPopup.item.name + " · " + detailsPopup.item.text : ""
                    font.bold:          true
                }
            }

            GridLayout {
                Layout.fillWidth:   true
                columns:            2
                columnSpacing:      control._u * 0.4
                rowSpacing:         control._u * 0.4
                visible:            !!detailsPopup.item && detailsPopup.item.details.length > 0

                Repeater {
                    model: detailsPopup.item ? detailsPopup.item.details : []
                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: detailCol.implicitHeight + control._u * 0.6
                        radius:                 control._u * 0.3
                        color:                  "#15181B"
                        border.color:           "#2A2D31"
                        Column {
                            id:                     detailCol
                            anchors.left:           parent.left
                            anchors.leftMargin:     control._u * 0.5
                            anchors.verticalCenter: parent.verticalCenter
                            QGCLabel { text: modelData.k; color: "#9BA1A6"; font.pointSize: ScreenTools.smallFontPointSize }
                            QGCLabel { text: modelData.v; color: modelData.color; font.bold: true; font.family: ScreenTools.fixedFontFamily }
                        }
                    }
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                text:               detailsPopup.item ? detailsPopup.item.note : ""
                color:              "#9BA1A6"
                wrapMode:           Text.WordWrap
                font.pointSize:     ScreenTools.smallFontPointSize
            }
        }
    }
}
