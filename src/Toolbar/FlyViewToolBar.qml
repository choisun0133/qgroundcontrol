import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

Item {
    required property var guidedValueSlider

    id:     control
    width:  parent.width
    height: ScreenTools.toolbarHeight

    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool   _communicationLost: _activeVehicle ? _activeVehicle.vehicleLinkManager.communicationLost : false
    property color  _mainStatusBGColor: qgcPal.brandingPurple
    property real   _leftRightMargin:   ScreenTools.defaultFontPixelWidth * 0.75
    property var    _guidedController:  globals.guidedControllerFlyView

    function dropMainStatusIndicatorTool() {
        mainStatusIndicator.dropMainStatusIndicator();
    }

    QGCPalette { id: qgcPal }

    QGCFlickable {
        anchors.fill:       parent
        contentWidth:       toolBarLayout.width
        flickableDirection: Flickable.HorizontalFlick

        Row {
            id:         toolBarLayout
            height:     parent.height
            spacing:    0

            Item {
                id:     leftPanel
                width:  leftPanelLayout.implicitWidth
                height: parent.height

                // Gradient background behind Q button and main status indicator
                Rectangle {
                    id:         gradientBackground
                    height:     parent.height
                    width:      mainStatusLayout.width
                    color:      qgcPal.brandingPurple   // AeroResearch: flat black, status shown as a pill instead
                }

                // Standard toolbar background to the right of the gradient
                Rectangle {
                    anchors.left:   gradientBackground.right
                    anchors.right:  parent.right
                    height:         parent.height
                    color:          qgcPal.windowTransparent
                }

                RowLayout {
                    id:         leftPanelLayout
                    height:     parent.height
                    spacing:    ScreenTools.defaultFontPixelWidth * 2

                    RowLayout {
                        id:         mainStatusLayout
                        height:     parent.height
                        spacing:    0

                        QGCToolBarButton {
                            id:                 qgcButton
                            objectName:         "toolbar_qgcLogo"
                            Layout.fillHeight:  true
                            icon.source:        "/res/QGCLogoFull.svg"
                            logo:               true
                            onClicked:          mainWindow.showToolSelectDialog()
                        }

                        // AeroResearch wordmark + "GROUND CONTROL" next to the logo button
                        Item {
                            Layout.fillHeight:      true
                            Layout.preferredWidth:  wordmarkColumn.width + ScreenTools.defaultFontPixelWidth * 2
                            visible:                !ScreenTools.isMobile

                            MouseArea {
                                anchors.fill:   parent
                                cursorShape:    Qt.PointingHandCursor
                                onClicked:      mainWindow.showToolSelectDialog()
                            }

                            Column {
                                id:                     wordmarkColumn
                                anchors.verticalCenter: parent.verticalCenter
                                spacing:                ScreenTools.defaultFontPixelHeight * 0.25

                                Image {
                                    id:                 aeroWordmark
                                    height:             ScreenTools.defaultFontPixelHeight * 0.65
                                    width:              height * 13.7
                                    source:             "/res/AeroWordmark.svg"
                                    sourceSize.height:  height * 2
                                    fillMode:           Image.PreserveAspectFit
                                }
                                QGCLabel {
                                    text:               "GROUND CONTROL"
                                    color:              qgcPal.brandingBlue
                                    font.pointSize:     ScreenTools.smallFontPointSize
                                    font.bold:          true
                                    font.letterSpacing: ScreenTools.defaultFontPixelWidth * 0.3
                                }
                            }
                        }

                        Rectangle {
                            Layout.alignment:       Qt.AlignVCenter
                            Layout.preferredWidth:  1
                            Layout.preferredHeight: parent.height * 0.55
                            Layout.rightMargin:     ScreenTools.defaultFontPixelWidth
                            color:                  "#2A2D31"
                        }

                        // Always-visible 비행 / 임무 계획 switch
                        AeroViewSwitch {
                            Layout.alignment:       Qt.AlignVCenter
                            Layout.rightMargin:     ScreenTools.defaultFontPixelWidth * 1.5
                            current:                "fly"
                        }

                        MainStatusIndicator {
                            id:                 mainStatusIndicator
                            objectName:         "toolbar_mainStatusIndicator"
                            Layout.fillHeight:  true
                        }
                    }

                    QGCButton {
                        id:         disconnectButton
                        text:       qsTr("Disconnect")
                        onClicked:  _activeVehicle.closeVehicle()
                        visible:    _activeVehicle && _communicationLost
                    }

                    FlightModeIndicator {
                        objectName:         "toolbar_flightModeIndicator"
                        Layout.fillHeight:  true
                        visible:            _activeVehicle
                    }
                }
            }
            Item {
                id:     centerPanel
                // center panel takes up all remaining space in toolbar between left and right panels
                width:  Math.max(guidedActionConfirm.visible ? guidedActionConfirm.width : 0, control.width - (leftPanel.width + rightPanel.width))
                height: parent.height

                Rectangle {
                    anchors.fill:   parent
                    color:          qgcPal.windowTransparent
                }

                GuidedActionConfirm {
                    id:                         guidedActionConfirm
                    height:                     parent.height
                    anchors.horizontalCenter:   parent.horizontalCenter
                    guidedController:           control._guidedController
                    guidedValueSlider:          control.guidedValueSlider
                    messageDisplay:             guidedActionMessageDisplay
                }
            }

            Item {
                id:     rightPanel
                width:  flyViewIndicators.width
                height: parent.height

                Rectangle {
                    anchors.fill:   parent
                    color:          qgcPal.windowTransparent
                }

                FlyViewToolBarIndicators {
                    id:     flyViewIndicators
                    height: parent.height
                }
            }
        }
    }

    // The guided action message display is outside of the GuidedActionConfirm control so that it doesn't end up as
    // part of the Flickable
    Rectangle {
        id:                         guidedActionMessageDisplay
        anchors.top:                control.bottom
        anchors.topMargin:          _margins
        x:                          control.mapFromItem(guidedActionConfirm.parent, guidedActionConfirm.x, 0).x + (guidedActionConfirm.width - guidedActionMessageDisplay.width) / 2
        width:                      messageLabel.contentWidth + (_margins * 2)
        height:                     messageLabel.contentHeight + (_margins * 2)
        color:                      qgcPal.windowTransparent
        radius:                     ScreenTools.defaultBorderRadius
        visible:                    false   // AeroResearch: the confirm card shows the message itself

        QGCLabel {
            id:         messageLabel
            x:          _margins
            y:          _margins
            width:      ScreenTools.defaultFontPixelWidth * 30
            wrapMode:   Text.WordWrap
            text:       guidedActionConfirm.message
        }

        PropertyAnimation {
            id:         messageOpacityAnimation
            target:     guidedActionMessageDisplay
            property:   "opacity"
            from:       1
            to:         0
            duration:   500
        }

        Timer {
            id:             messageFadeTimer
            interval:       4000
            onTriggered:    messageOpacityAnimation.start()
        }
    }

    // AeroResearch accent line along the bottom edge of the toolbar
    Rectangle {
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        height:         Math.max(2, ScreenTools.defaultFontPixelHeight * 0.12)
        color:          qgcPal.brandingBlue
    }

    ParameterDownloadProgress {
        anchors.fill: parent
    }
}
