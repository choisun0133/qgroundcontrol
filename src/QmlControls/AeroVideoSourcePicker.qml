import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// AeroResearch: pick a saved video source (MainWindow `aeroVideo`) and edit the list.
ColumnLayout {
    id:         control
    spacing:    _u * 0.3

    readonly property real _u: ScreenTools.defaultFontPixelHeight
    property string _error: ""

    // "rtsp://user:pass@host/..." -> "rtsp://***@host/..."
    function _masked(url) {
        return String(url).replace(/^([a-z][a-z0-9+.-]*:\/\/)[^@\/]*@/i, "$1***@")
    }

    Connections {
        target:         aeroVideo
        function onApplyFailed(reason) { control._error = reason }
    }

    RowLayout {
        Layout.fillWidth:   true
        spacing:            control._u * 0.3

        QGCComboBox {
            id:                 sourceCombo
            Layout.fillWidth:   true
            enabled:            aeroVideo.entries.length > 0
            model:              aeroVideo.entries.length > 0 ? aeroVideo.entries.map(function(e) { return e.name }) : [ qsTr("저장된 영상 없음") ]
            currentIndex:       aeroVideo.entries.length > 0 ? aeroVideo.indexOfName(aeroVideo.selected) : 0
            displayText:        currentIndex < 0 ? qsTr("선택 안 됨") : currentText
            onActivated: (index) => {
                control._error = ""
                if (!aeroVideo.apply(aeroVideo.entries[index].name)) {
                    // Activation already moved currentIndex (and broke its binding): show the
                    // entry that is actually playing again
                    currentIndex = Qt.binding(function() {
                        return aeroVideo.entries.length > 0 ? aeroVideo.indexOfName(aeroVideo.selected) : 0
                    })
                }
            }
        }
        QGCButton {
            text:       qsTr("편집")
            onClicked:  editor.openEditor()
        }
    }

    QGCLabel {
        Layout.fillWidth:   true
        visible:            text !== ""
        text:               control._error !== "" ? control._error : control._masked(QGroundControl.settingsManager.videoSettings.rtspUrl.rawValue)
        color:              control._error !== "" ? "#FF6B6B" : "#9BA1A6"
        font.pointSize:     ScreenTools.smallFontPointSize
        elide:              Text.ElideMiddle
    }

    Popup {
        id:             editor
        parent:         Overlay.overlay
        x:              Math.round((parent.width - width) / 2)
        y:              Math.round((parent.height - height) / 4)
        width:          Math.min(parent.width - control._u * 2, control._u * 34)
        padding:        control._u * 0.8
        modal:          true
        focus:          true
        closePolicy:    Popup.CloseOnEscape

        property var _links: [ qsTr("(자동 전환 안 함)") ]

        function openEditor() {
            baseField.text = aeroVideo.baseUrl
            rows.clear()
            for (var i = 0; i < aeroVideo.entries.length; i++) {
                var e = aeroVideo.entries[i]
                rows.append({ name: e.name, value: e.value, link: e.link || "", wasSelected: e.name === aeroVideo.selected })
            }
            if (rows.count === 0) {
                rows.append({ name: "", value: "", link: "", wasSelected: false })
            }
            var names = [ qsTr("(자동 전환 안 함)") ]
            var configs = QGroundControl.linkManager.linkConfigurations
            for (var c = 0; c < configs.count; c++) {
                var cfg = configs.get(c)
                if (cfg && !cfg.dynamic && cfg.name !== "") {
                    names.push(cfg.name)
                }
            }
            _links = names
            open()
        }

        function save() {
            var list = []
            for (var i = 0; i < rows.count; i++) {
                var r = rows.get(i)
                list.push({ name: r.name, value: r.value, link: r.link, wasSelected: r.wasSelected })
            }
            aeroVideo.baseUrl = aeroVideo.clean(baseField.text)
            aeroVideo.setEntries(list)
            control._error = ""
            if (aeroVideo.selected !== "") {
                aeroVideo.apply(aeroVideo.selected)     // the selected entry may have been edited
            }
            close()
        }

        ListModel { id: rows }

        background: Rectangle {
            color:          "#0E0F11"
            border.color:   "#2A2D31"
            radius:         control._u * 0.5
        }

        contentItem: ColumnLayout {
            spacing: control._u * 0.4

            QGCLabel { text: qsTr("영상 주소 목록"); font.bold: true }

            QGCLabel { text: qsTr("기본 주소 (디바이스 키 앞부분)") }
            QGCTextField {
                id:                 baseField
                Layout.fillWidth:   true
                echoMode:           activeFocus ? TextInput.Normal : TextInput.Password
                placeholderText:    "rtsp://아이디:비번@서버:8554/경로?DeviceKey="
            }
            QGCLabel {
                Layout.fillWidth:   true
                wrapMode:           Text.WordWrap
                color:              "#9BA1A6"
                font.pointSize:     ScreenTools.smallFontPointSize
                text:               qsTr("각 줄의 값에 디바이스 키만 넣으면 기본 주소 뒤에 붙고, rtsp:// 로 시작하는 전체 주소를 넣으면 그 주소를 그대로 씁니다. "
                                         + "연결을 고르면 그 연결로 기체가 접속할 때 이 영상으로 자동 전환됩니다.")
            }

            RowLayout {
                Layout.fillWidth:   true
                spacing:            control._u * 0.3
                QGCLabel { Layout.preferredWidth: control._u * 7; text: qsTr("이름");                 font.pointSize: ScreenTools.smallFontPointSize; color: "#9BA1A6" }
                QGCLabel { Layout.fillWidth: true;                text: qsTr("디바이스 키 또는 전체 주소"); font.pointSize: ScreenTools.smallFontPointSize; color: "#9BA1A6" }
                QGCLabel { Layout.preferredWidth: control._u * 8; text: qsTr("연결 시 자동");          font.pointSize: ScreenTools.smallFontPointSize; color: "#9BA1A6" }
                Item     { Layout.preferredWidth: control._u * 2 }
            }

            Repeater {
                model: rows

                RowLayout {
                    required property int    index
                    required property string name
                    required property string value
                    required property string link

                    Layout.fillWidth:   true
                    spacing:            control._u * 0.3

                    QGCTextField {
                        Layout.preferredWidth:  control._u * 7
                        text:                   name
                        placeholderText:        qsTr("예: AR-01")
                        onTextChanged:          rows.setProperty(index, "name", text)
                    }
                    QGCTextField {
                        Layout.fillWidth:   true
                        text:               value
                        placeholderText:    qsTr("키 또는 rtsp://…")
                        echoMode:           activeFocus || !aeroVideo.isFullUrl(text) ? TextInput.Normal : TextInput.Password
                        onTextChanged:      rows.setProperty(index, "value", aeroVideo.clean(text))
                    }
                    QGCComboBox {
                        Layout.preferredWidth:  control._u * 8
                        model:                  editor._links
                        currentIndex:           Math.max(0, editor._links.indexOf(link))
                        onActivated: (i) => { rows.setProperty(index, "link", i === 0 ? "" : editor._links[i]) }
                    }
                    QGCButton {
                        Layout.preferredWidth:  control._u * 2
                        text:                   "✕"
                        onClicked:              rows.remove(index)
                    }
                }
            }

            QGCButton {
                text:       qsTr("+ 영상 추가")
                onClicked:  rows.append({ name: "", value: "", link: "", wasSelected: false })
            }

            RowLayout {
                Layout.fillWidth:   true
                spacing:            control._u * 0.4
                Item { Layout.fillWidth: true }
                QGCButton {
                    text:       qsTr("취소")
                    onClicked:  editor.close()
                }
                QGCButton {
                    text:       qsTr("저장")
                    onClicked:  editor.save()
                }
            }
        }
    }
}
