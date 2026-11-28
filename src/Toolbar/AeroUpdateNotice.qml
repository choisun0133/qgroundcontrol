import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// AeroResearch: in-app update.
//  - A few seconds after start, reads releases/latest/download/update-<brand>-<edition>.json from
//    GitHub; when it names a newer version, a banner offers to download and install it (Windows) or
//    opens the release page (other platforms). Never while a vehicle is connected.
//  - On the first start of a new version, shows that version's release notes once.
Item {
    id:             control
    anchors.fill:   parent
    z:              10000

    readonly property var    _updater:      QGroundControl.aeroUpdater
    readonly property string _current:      _updater.currentVersion
    readonly property string _manifestUrl:  "https://github.com/choisun0133/qgroundcontrol/releases/latest/download/update-"
                                            + QGroundControl.aeroBrand + "-" + (QGroundControl.aeroUserEdition ? "user" : "dev") + ".json"
    readonly property bool   _vehicleConnected: !!QGroundControl.multiVehicleManager.activeVehicle
    readonly property real   _u:            ScreenTools.defaultFontPixelHeight

    property var    _manifest:      null        // newer release offered
    property bool   _showUpdate:    false
    property string _error:         ""
    property string _notesVersion:  ""          // "what's new" popup
    property string _notesText:     ""

    Settings {
        id:         saved
        category:   "AeroUpdate"
        property string lastSeenVersion:    ""
        property string pendingVersion:     ""      // version being installed, with its notes
        property string pendingNotes:       ""
    }

    function _fetchManifest(callback) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return
            }
            var data = null
            if (xhr.status === 200) {
                try {
                    data = JSON.parse(xhr.responseText)
                } catch (e) {
                    data = null
                }
            }
            callback(data && data.version ? data : null)
        }
        xhr.open("GET", _manifestUrl)
        xhr.send()
    }

    // What's new: notes saved before installing, or the latest manifest when it is this version
    function _showWhatsNew() {
        if (saved.lastSeenVersion === _current) {
            return
        }
        var firstRun = saved.lastSeenVersion === ""
        saved.lastSeenVersion = _current
        if (saved.pendingVersion === _current && saved.pendingNotes !== "") {
            _notesVersion = _current
            _notesText = saved.pendingNotes
            saved.pendingVersion = ""
            saved.pendingNotes = ""
            return
        }
        if (firstRun) {
            return      // fresh install: nothing to compare with
        }
        _fetchManifest(function(m) {
            if (m && _updater.compareVersions(m.version, _current) === 0 && m.notes) {
                _notesVersion = _current
                _notesText = m.notes
            }
        })
    }

    function _checkForUpdate() {
        _fetchManifest(function(m) {
            if (m && _updater.compareVersions(m.version, _current) > 0) {
                _manifest = m
                _showUpdate = true
            }
        })
    }

    function _install() {
        if (!_manifest || _vehicleConnected) {
            return
        }
        _error = ""
        if (!_updater.canInstall) {
            Qt.openUrlExternally(_manifest.page ? _manifest.page : "https://github.com/choisun0133/qgroundcontrol/releases/latest")
            return
        }
        saved.pendingVersion = _manifest.version
        saved.pendingNotes = _manifest.notes || ""
        _updater.downloadAndInstall(_manifest.url, _manifest.sha256)
    }

    // A vehicle connecting during the download stops it, and the updater refuses to start the
    // installer while one is connected
    Binding {
        target:     control._updater
        property:   "installBlocked"
        value:      control._vehicleConnected
    }
    on_VehicleConnectedChanged: {
        if (_vehicleConnected && _updater.busy) {
            _updater.cancel()
        }
    }

    Connections {
        target: control._updater
        function onFailed(message) {
            control._error = message
            saved.pendingVersion = ""
            saved.pendingNotes = ""
        }
        function onInstallerStarted() {
            // The installer replaces the running program: close so it can
            Qt.quit()
        }
    }

    Timer {
        running:        true
        interval:       4000
        onTriggered: {
            control._showWhatsNew()
            control._checkForUpdate()
        }
    }

    // ---- update banner ----
    Rectangle {
        id:                         banner
        visible:                    control._showUpdate
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                parent.top
        anchors.topMargin:          control._u * 4.5
        width:                      Math.min(parent.width - control._u * 2, control._u * 30)
        height:                     bannerColumn.implicitHeight + control._u * 1.2
        radius:                     control._u * 0.5
        color:                      "#0E0F11"
        border.color:               "#4A9EFF"

        MouseArea {
            anchors.fill:       parent
            acceptedButtons:    Qt.AllButtons
            onWheel:            (wheel) => { wheel.accepted = true }
        }

        ColumnLayout {
            id:                 bannerColumn
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.top:        parent.top
            anchors.margins:    control._u * 0.6
            spacing:            control._u * 0.35

            QGCLabel {
                Layout.fillWidth:   true
                text:               control._manifest ? qsTr("새 버전 %1이 있습니다 (지금 %2)").arg(control._manifest.version).arg(control._current) : ""
                font.bold:          true
                wrapMode:           Text.WordWrap
            }
            QGCFlickable {
                Layout.fillWidth:       true
                Layout.preferredHeight: Math.min(notesLabel.implicitHeight, control._u * 7)
                contentHeight:          notesLabel.implicitHeight
                clip:                   true
                visible:                notesLabel.text !== ""

                QGCLabel {
                    id:             notesLabel
                    width:          parent.width
                    text:           control._manifest && control._manifest.notes ? control._manifest.notes.replace(/\*\*/g, "") : ""
                    wrapMode:       Text.WordWrap
                    color:          "#C9CDD1"
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }
            QGCLabel {
                Layout.fillWidth:   true
                visible:            control._vehicleConnected
                text:               qsTr("기체 연결을 끊은 뒤 업데이트할 수 있습니다")
                color:              "#F5C518"
                wrapMode:           Text.WordWrap
            }
            QGCLabel {
                Layout.fillWidth:   true
                visible:            control._error !== ""
                text:               control._error
                color:              "#FF6B6B"
                wrapMode:           Text.WordWrap
            }
            ProgressBar {
                Layout.fillWidth:   true
                visible:            control._updater.busy
                indeterminate:      control._updater.progress < 0
                value:              Math.max(0, control._updater.progress)
            }
            RowLayout {
                Layout.fillWidth:   true
                spacing:            control._u * 0.4
                Item { Layout.fillWidth: true }
                QGCButton {
                    text:       control._updater.busy ? qsTr("취소") : qsTr("나중에")
                    onClicked: {
                        if (control._updater.busy) {
                            control._updater.cancel()
                        } else {
                            control._showUpdate = false
                        }
                    }
                }
                QGCButton {
                    text:       control._updater.canInstall ? qsTr("업데이트") : qsTr("다운로드 페이지")
                    enabled:    !control._updater.busy && !control._vehicleConnected
                    onClicked:  control._install()
                }
            }
        }
    }

    // ---- what's new (first start of a new version) ----
    Rectangle {
        anchors.fill:   parent
        visible:        control._notesVersion !== ""
        color:          Qt.rgba(0, 0, 0, 0.55)

        MouseArea {
            anchors.fill:       parent
            acceptedButtons:    Qt.AllButtons
            onWheel:            (wheel) => { wheel.accepted = true }
        }

        Rectangle {
            anchors.centerIn:   parent
            width:              Math.min(parent.width - control._u * 2, control._u * 32)
            height:             Math.min(parent.height - control._u * 2, whatsNewColumn.implicitHeight + control._u * 1.6)
            radius:             control._u * 0.6
            color:              "#0E0F11"
            border.color:       "#2A2D31"

            ColumnLayout {
                id:                 whatsNewColumn
                anchors.fill:       parent
                anchors.margins:    control._u * 0.8
                spacing:            control._u * 0.5

                QGCLabel {
                    text:           qsTr("%1 버전으로 업데이트되었습니다").arg(control._notesVersion)
                    font.bold:      true
                    font.pointSize: ScreenTools.mediumFontPointSize
                }
                QGCFlickable {
                    Layout.fillWidth:       true
                    Layout.fillHeight:      true
                    Layout.preferredHeight: Math.min(whatsNewLabel.implicitHeight, control._u * 18)
                    contentHeight:          whatsNewLabel.implicitHeight
                    clip:                   true

                    QGCLabel {
                        id:         whatsNewLabel
                        width:      parent.width
                        text:       control._notesText.replace(/\*\*/g, "")
                        wrapMode:   Text.WordWrap
                    }
                }
                QGCButton {
                    Layout.alignment:   Qt.AlignRight
                    text:               qsTr("확인")
                    onClicked:          control._notesVersion = ""
                }
            }
        }
    }
}
