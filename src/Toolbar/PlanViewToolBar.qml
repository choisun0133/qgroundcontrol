import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.PlanView

Rectangle {
    id: _root
    width: parent.width
    height: ScreenTools.toolbarHeight
    color: qgcPal.brandingPurple

    property var planMasterController
    property bool showRallyPointsHelp: false

    signal toolbarButtonClicked()

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property real _controllerProgressPct: planMasterController.missionController.progressPct

    // AeroResearch mission summary shown in the toolbar
    property var  _missionController: planMasterController.missionController
    property real _distance:    _missionController.missionPlannedDistance
    property real _maxDistance: _missionController.missionMaxTelemetry
    property real _timeSec:     _missionController.missionTime
    property int  _waypoints:   Math.max(0, _missionController.visualItems ? _missionController.visualItems.count - 1 : 0)

    function _distanceText(meters) {
        if (isNaN(meters) || meters <= 0) {
            return "—"
        }
        return QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(meters).toFixed(0) + " " +
               QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString
    }

    function _timeText(seconds) {
        if (isNaN(seconds) || seconds <= 0) {
            return "—"
        }
        var m = Math.floor(seconds / 60)
        var sec = Math.floor(seconds % 60)
        return (m < 10 ? "0" : "") + m + ":" + (sec < 10 ? "0" : "") + sec
    }

    component Stat: Column {
        property string label
        property string value
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        spacing: 0
        QGCLabel { text: label; color: "#9BA1A6"; font.pointSize: ScreenTools.smallFontPointSize }
        QGCLabel { text: value; font.family: ScreenTools.fixedFontFamily; font.pointSize: ScreenTools.mediumFontPointSize; font.bold: true }
    }

    QGCPalette { id: qgcPal }

    /// Bottom single pixel divider
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: "black"
        visible: qgcPal.globalTheme === QGCPalette.Light
    }

    QGCToolBarButton {
        id: qgcButton
        objectName: "toolbar_qgcLogo"
        height: parent.height
        icon.source: "/res/QGCLogoFull.svg"
        logo: true
        onClicked: mainWindow.showToolSelectDialog()
    }

    // AeroResearch lockup: wordmark + "MISSION PLAN"
    Column {
        id: planLockup
        anchors.left: qgcButton.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: ScreenTools.defaultFontPixelHeight * 0.25
        visible: !ScreenTools.isMobile
        width: visible ? implicitWidth : 0

        Image {
            height: ScreenTools.defaultFontPixelHeight * 0.65
            width: height * 13.7
            source: "/res/AeroWordmark.svg"
            sourceSize.height: height * 2
            fillMode: Image.PreserveAspectFit
        }
        QGCLabel {
            text: "MISSION PLAN"
            color: qgcPal.brandingBlue
            font.pointSize: ScreenTools.smallFontPointSize
            font.bold: true
            font.letterSpacing: ScreenTools.defaultFontPixelWidth * 0.3
        }
    }

    QGCFlickable {
        id: toolsFlickable
        anchors.bottomMargin: 1
        anchors.left: planLockup.right
        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 2
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: flyViewButton.left
        anchors.rightMargin: ScreenTools.defaultFontPixelWidth
        contentWidth: planRow.width
        flickableDirection: Flickable.HorizontalFlick

        Row {
            id: planRow
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            spacing: ScreenTools.defaultFontPixelWidth * 2.5

            Rectangle { width: 1; height: parent.height * 0.55; anchors.verticalCenter: parent.verticalCenter; color: "#2A2D31" }
            Stat { label: qsTr("총 거리");   value: _root._distanceText(_root._distance) }
            Stat { label: qsTr("예상 시간"); value: _root._timeText(_root._timeSec) }
            Stat { label: qsTr("최대 거리"); value: _root._distanceText(_root._maxDistance) }
            Stat { label: qsTr("미션 항목"); value: _root._waypoints.toString() }
            Rectangle { width: 1; height: parent.height * 0.55; anchors.verticalCenter: parent.verticalCenter; color: "#2A2D31" }

            PlanToolBarIndicators {
                id: toolIndicators
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                planMasterController: _root.planMasterController
                showRallyPointsHelp: _root.showRallyPointsHelp
                onToolbarButtonClicked: _root.toolbarButtonClicked()
            }
        }
    }

    // Back to the flight view
    QGCButton {
        id: flyViewButton
        anchors.right: parent.right
        anchors.rightMargin: ScreenTools.defaultFontPixelWidth
        anchors.verticalCenter: parent.verticalCenter
        text: qsTr("비행 화면")
        iconSource: "/qmlimages/PaperPlane.svg"
        onClicked: {
            if (mainWindow.allowViewSwitch()) {
                mainWindow.showFlyView()
            }
        }
    }

    // AeroResearch accent line along the bottom edge
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(2, ScreenTools.defaultFontPixelHeight * 0.12)
        color: qgcPal.brandingBlue
    }

    // Small mission download progress bar
    Rectangle {
        id: progressBar
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        height: 4
        width: _controllerProgressPct * parent.width
        color: qgcPal.colorGreen
        visible: false

        onVisibleChanged: {
            if (visible) {
                largeProgressBar._userHide = false
            }
        }
    }

    // Large mission download progress bar
    Rectangle {
        id: largeProgressBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height
        color: qgcPal.window
        visible: _showLargeProgress

        property bool _userHide: false
        property bool _showLargeProgress: progressBar.visible && !_userHide && qgcPal.globalTheme === QGCPalette.Light

        Connections {
            target: QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) { largeProgressBar._userHide = false }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: _controllerProgressPct * parent.width
            color: qgcPal.colorGreen
        }

        QGCLabel {
            anchors.centerIn: parent
            text: qsTr("Syncing Mission")
            font.pointSize: ScreenTools.largeFontPointSize
            visible: _controllerProgressPct !== 1
        }

        QGCLabel {
            anchors.centerIn: parent
            text: qsTr("Done")
            font.pointSize: ScreenTools.largeFontPointSize
            visible: _controllerProgressPct === 1
        }

        QGCLabel {
            anchors.margins: _margin
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: qsTr("Click anywhere to hide")

            property real _margin: ScreenTools.defaultFontPixelWidth / 2
        }

        MouseArea {
            anchors.fill: parent
            onClicked: largeProgressBar._userHide = true
        }
    }

    // Progress bar
    Connections {
        target: planMasterController.missionController

        function onProgressPctChanged(progressPct) {
            if (progressPct === 1) {
                if (_root.visible) {
                    resetProgressTimer.start()
                } else {
                    progressBar.visible = false
                }
            } else if (progressPct > 0) {
                progressBar.visible = true
            }
        }
    }

    Timer {
        id: resetProgressTimer
        interval: 3000
        onTriggered: progressBar.visible = false
    }
}
