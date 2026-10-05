import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// AeroResearch start screen: shown over the Fly View until a vehicle connects.
// Lets the operator pick USB / RF telemetry / LTE server, connect, or reuse a saved link.
Rectangle {
    id:     control
    color:  qgcPal.windowShadeDark

    // Set by the "start without connection" button; reset when a vehicle disconnects.
    property bool   dismissed:      false
    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var    _linkManager:   QGroundControl.linkManager
    property var    _linkConfigs:   _linkManager.linkConfigurations
    property int    _mode:          ScreenTools.isSerialAvailable ? 1 : 2   // 0 USB, 1 RF, 2 LTE
    property bool   _connecting:    false
    property string _errorText:     ""

    readonly property color _accent:        qgcPal.brandingBlue
    readonly property color _waitColor:     "#F5C518"
    readonly property color _okColor:       qgcPal.colorGreen
    readonly property real  _cardWidth:     Math.min(width - ScreenTools.defaultFontPixelWidth * 4, ScreenTools.defaultFontPixelWidth * 62)
    readonly property real  _margin:        ScreenTools.defaultFontPixelWidth * 2
    readonly property var   _baudRates:     [ "57600", "115200", "921600" ]

    visible: !_activeVehicle && !dismissed

    on_ActiveVehicleChanged: {
        if (_activeVehicle) {
            _connecting = false
            _errorText = ""
        } else {
            dismissed = false
        }
    }

    // Swallow input so the map underneath does not react while the screen is up
    MouseArea {
        anchors.fill:       parent
        acceptedButtons:    Qt.AllButtons
        onWheel:            (wheel) => { wheel.accepted = true }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    function _findConfig(name) {
        for (var i = 0; i < _linkConfigs.count; i++) {
            var cfg = _linkConfigs.get(i)
            if (cfg.name === name) {
                return cfg
            }
        }
        return null
    }

    function _connectConfig(cfg) {
        if (!cfg) {
            return
        }
        _errorText = ""
        _connecting = true
        connectTimeout.restart()
        if (!cfg.link) {
            _linkManager.createConnectedLink(cfg)
        }
    }

    function _connect() {
        _errorText = ""
        if (_mode === 0) {
            // USB direct: auto-connect handles it as soon as the board is plugged in
            _connecting = true
            connectTimeout.restart()
            return
        }

        var name = nameField.text.trim()
        if (name === "") {
            name = _mode === 1 ? qsTr("RF %1").arg(rfPortCombo.currentText) : qsTr("LTE %1").arg(hostField.text.trim())
        }

        var existing = _findConfig(name)
        if (existing) {
            _connectConfig(existing)
            return
        }

        var cfg
        if (_mode === 1) {
            if (_linkManager.serialPorts.length === 0) {
                _errorText = qsTr("연결된 텔레메트리 포트가 없습니다. 무선 모뎀을 USB에 꽂아 주세요.")
                return
            }
            cfg = _linkManager.createConfiguration(LinkConfiguration.TypeSerial, name)
            cfg.portName = _linkManager.serialPorts[Math.max(0, rfPortCombo.currentIndex)]
            cfg.baud = parseInt(rfBaudCombo.currentText)
        } else {
            var host = hostField.text.trim()
            var port = parseInt(portField.text)
            if (host === "" || isNaN(port)) {
                _errorText = qsTr("서버 주소와 포트를 입력해 주세요.")
                return
            }
            if (protocolCombo.currentIndex === 0) {
                cfg = _linkManager.createConfiguration(LinkConfiguration.TypeTcp, name)
                cfg.host = host
                cfg.port = port
            } else {
                cfg = _linkManager.createConfiguration(LinkConfiguration.TypeUdp, name)
                cfg.addHost(host, port)
            }
        }
        cfg.dynamic = false
        cfg.autoConnect = autoConnectCheck.checked
        _linkManager.endCreateConfiguration(cfg)
        _connectConfig(_findConfig(name))
    }

    Timer {
        id:         connectTimeout
        interval:   15000
        onTriggered: {
            if (!control._activeVehicle) {
                control._connecting = false
                control._errorText = qsTr("기체 응답이 없습니다. 전원, 안테나, 주소/포트를 확인해 주세요.")
            }
        }
    }

    // Blueprint-style drone line art
    // Rasterised once at window size (cheaper than a curve-rendered full-screen vector)
    Image {
        anchors.fill:       parent
        source:             "/res/AeroDroneLineArt.svg"
        sourceSize.width:   width
        sourceSize.height:  height
        fillMode:           Image.PreserveAspectFit
        asynchronous:       true
        cache:              false
        opacity:            0.9
    }

    // Top accent line
    Rectangle {
        anchors.left:   parent.left
        anchors.right:  parent.right
        height:         Math.max(3, ScreenTools.defaultFontPixelHeight * 0.2)
        color:          control._accent
    }

    QGCFlickable {
        anchors.fill:       parent
        contentWidth:       width
        contentHeight:      Math.max(height, column.height + control._margin * 2)
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id:                         column
            anchors.horizontalCenter:   parent.horizontalCenter
            y:                          Math.max(control._margin, (parent.height - height) / 2)
            width:                      control._cardWidth
            spacing:                    ScreenTools.defaultFontPixelHeight

            // ---- Logo ----
            // Dark disc keeps the mark readable over the line art
            Rectangle {
                Layout.alignment:       Qt.AlignHCenter
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 6.6
                Layout.preferredWidth:  Layout.preferredHeight
                radius:                 width / 2
                color:                  control.color

                QGCVectorImage {
                    anchors.centerIn:   parent
                    width:              ScreenTools.defaultFontPixelHeight * 6
                    height:             width
                    source:             "/res/QGCLogoFull.svg"
                }
            }
            Image {
                Layout.alignment:       Qt.AlignHCenter
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.1
                Layout.preferredWidth:  Layout.preferredHeight * 13.7
                source:                 "/res/AeroWordmark.svg"
                sourceSize.height:      Layout.preferredHeight * 2
                fillMode:               Image.PreserveAspectFit
            }
            QGCLabel {
                Layout.alignment:   Qt.AlignHCenter
                text:               "GROUND CONTROL"
                color:              control._accent
                font.bold:          true
                font.letterSpacing: ScreenTools.defaultFontPixelWidth * 0.6
            }

            // ---- Connection card ----
            Rectangle {
                Layout.fillWidth:       true
                Layout.topMargin:       ScreenTools.defaultFontPixelHeight
                Layout.preferredHeight: card.height + control._margin * 2
                radius:                 ScreenTools.defaultFontPixelWidth
                color:                  Qt.rgba(0.07, 0.08, 0.09, 0.55)
                border.color:           Qt.rgba(1, 1, 1, 0.14)
                border.width:           1

                ColumnLayout {
                    id:         card
                    x:          control._margin
                    y:          control._margin
                    width:      parent.width - control._margin * 2
                    spacing:    ScreenTools.defaultFontPixelHeight * 0.8

                    QGCLabel {
                        text:           qsTr("기체 연결")
                        font.pointSize: ScreenTools.mediumFontPointSize
                        font.bold:      true
                    }

                    // Status banner
                    Rectangle {
                        id:                     statusBanner
                        Layout.fillWidth:       true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.8
                        radius:                 ScreenTools.defaultFontPixelWidth * 0.75
                        color:                  Qt.rgba(statusColor.r, statusColor.g, statusColor.b, 0.15)
                        border.color:           statusColor
                        border.width:           1

                        property color statusColor: control._errorText !== "" ? qgcPal.colorRed : (control._connecting ? control._accent : control._waitColor)

                        RowLayout {
                            anchors.fill:           parent
                            anchors.leftMargin:     control._margin * 0.75
                            anchors.rightMargin:    control._margin * 0.75
                            spacing:                ScreenTools.defaultFontPixelWidth

                            Rectangle {
                                width:      ScreenTools.defaultFontPixelHeight * 0.7
                                height:     width
                                radius:     width / 2
                                color:      statusBanner.statusColor

                                SequentialAnimation on opacity {
                                    loops:      Animation.Infinite
                                    running:    control.visible
                                    NumberAnimation { to: 0.3; duration: 700 }
                                    NumberAnimation { to: 1.0; duration: 700 }
                                }
                            }
                            QGCLabel {
                                text:           control._errorText !== "" ? qsTr("연결 실패") : (control._connecting ? qsTr("연결 중…") : qsTr("연결 대기 중"))
                                color:          statusBanner.statusColor
                                font.pointSize: ScreenTools.largeFontPointSize
                                font.bold:      true
                            }
                            QGCLabel {
                                Layout.fillWidth:       true
                                horizontalAlignment:    Text.AlignRight
                                elide:                  Text.ElideRight
                                text:                   control._errorText !== "" ? control._errorText : (control._connecting ? qsTr("기체와 통신 확인 중") : qsTr("기체 신호를 기다리는 중"))
                            }
                        }
                    }

                    // Connection type selector
                    RowLayout {
                        Layout.fillWidth:   true
                        spacing:            2

                        Repeater {
                            model: [ qsTr("USB 자동"), qsTr("RF 텔레메트리"), qsTr("LTE 서버") ]

                            QGCButton {
                                Layout.fillWidth:       true
                                Layout.preferredWidth:  1
                                text:                   modelData
                                visible:            index !== 1 || ScreenTools.isSerialAvailable
                                heightFactor:       0.7
                                fontWeight:         Font.Bold
                                backgroundColor:    control._mode === index ? control._accent : Qt.rgba(0.11, 0.12, 0.14, 0.7)
                                textColor:          control._mode === index ? "#0E0F11" : qgcPal.buttonText
                                onClicked: {
                                    control._mode = index
                                    control._errorText = ""
                                }
                            }
                        }
                    }

                    // USB
                    QGCLabel {
                        Layout.fillWidth:   true
                        visible:            control._mode === 0
                        wrapMode:           Text.WordWrap
                        text:               qsTr("USB 케이블로 FC를 꽂으면 자동으로 연결됩니다. 별도 설정이 필요 없어요.")
                    }

                    // RF telemetry
                    GridLayout {
                        Layout.fillWidth:   true
                        visible:            control._mode === 1
                        columns:            2
                        columnSpacing:      ScreenTools.defaultFontPixelWidth
                        rowSpacing:         ScreenTools.defaultFontPixelHeight * 0.3

                        QGCLabel { text: qsTr("포트") }
                        QGCLabel { text: qsTr("통신 속도 (baud)") }
                        QGCComboBox {
                            id:                 rfPortCombo
                            Layout.fillWidth:   true
                            model:              control._linkManager.serialPortStrings.length > 0 ? control._linkManager.serialPortStrings : [ qsTr("포트 없음") ]
                        }
                        QGCComboBox {
                            id:                     rfBaudCombo
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 16
                            model:                  control._baudRates
                            currentIndex:           0
                        }
                    }

                    // LTE server
                    GridLayout {
                        Layout.fillWidth:   true
                        visible:            control._mode === 2
                        columns:            3
                        columnSpacing:      ScreenTools.defaultFontPixelWidth
                        rowSpacing:         ScreenTools.defaultFontPixelHeight * 0.3

                        QGCLabel { text: qsTr("서버 주소"); Layout.columnSpan: 2 }
                        QGCLabel { text: qsTr("포트") }
                        QGCTextField {
                            id:                 hostField
                            Layout.fillWidth:   true
                            Layout.columnSpan:  2
                            placeholderText:    qsTr("서버 IP 또는 도메인")
                        }
                        QGCTextField {
                            id:                     portField
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 12
                            text:                   "5760"
                            inputMethodHints:       Qt.ImhDigitsOnly
                        }
                        QGCLabel { text: qsTr("프로토콜") }
                        QGCLabel { text: qsTr("연결 이름"); Layout.columnSpan: 2 }
                        QGCComboBox {
                            id:                     protocolCombo
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 12
                            model:                  [ "TCP", "UDP" ]
                        }
                        QGCTextField {
                            id:                 nameField
                            Layout.fillWidth:   true
                            Layout.columnSpan:  2
                            placeholderText:    qsTr("예: AR-01 LTE")
                        }
                    }

                    QGCCheckBox {
                        id:         autoConnectCheck
                        visible:    control._mode !== 0
                        text:       qsTr("다음 실행 때 이 설정으로 자동 연결")
                        checked:    true
                    }

                    RowLayout {
                        Layout.fillWidth:   true
                        spacing:            ScreenTools.defaultFontPixelWidth

                        QGCButton {
                            Layout.fillWidth:   true
                            text:               control._connecting ? qsTr("연결 중…") : qsTr("연결")
                            enabled:            !control._connecting
                            heightFactor:       0.9
                            pointSize:          ScreenTools.mediumFontPointSize
                            fontWeight:         Font.Bold
                            backgroundColor:    control._accent
                            textColor:          "#0E0F11"
                            onClicked:          control._connect()
                        }
                        QGCButton {
                            text:           qsTr("연결 없이 시작")
                            heightFactor:   0.9
                            onClicked:      control.dismissed = true
                        }
                    }

                    // Saved connections
                    QGCLabel {
                        text:       qsTr("저장된 연결")
                        visible:    savedFlow.visibleChildren.length > 1
                        opacity:    0.7
                    }
                    Flow {
                        id:                 savedFlow
                        Layout.fillWidth:   true
                        spacing:            ScreenTools.defaultFontPixelWidth

                        Repeater {
                            model: control._linkConfigs

                            QGCButton {
                                text:       object.name + (object.link ? qsTr(" (연결됨)") : "")
                                visible:    !object.dynamic
                                enabled:    !control._connecting
                                onClicked:  control._connectConfig(object)
                            }
                        }
                    }
                }
            }
        }
    }

    // Footer
    RowLayout {
        anchors.left:           parent.left
        anchors.right:          parent.right
        anchors.bottom:         parent.bottom
        anchors.margins:        control._margin
        visible:                !ScreenTools.isMobile

        QGCLabel { text: "© AeroResearch Co., Ltd."; opacity: 0.6 }
        Item { Layout.fillWidth: true }
        QGCLabel { text: QGroundControl.qgcVersion; opacity: 0.6 }
    }
}
