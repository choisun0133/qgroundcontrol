import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// AeroResearch: GPT window (Ctrl+F → "AI 비서"). Uses the shared `aeroAI` client from MainWindow.
//  - 비서:      questions about the current flight; vehicle state and recent messages are sent along
//  - 비행 요약:  flight report from the messages, written automatically after disarm (setting)
//  - 설정:      API key / model / endpoint, auto summary, auto explanation of error messages
// Message rows in the message window have an "AI" button that asks for an explanation here.
AeroFloatingPanel {
    id:             control
    title:          qsTr("AI 비서")
    settingsKey:    "AIWindow"
    panelWidth:     _u * 27
    badgeText:      aeroAI.busy ? qsTr("응답 중…") : (_summaryUnread ? qsTr("요약 완료") : "")
    badgeColor:     aeroAI.busy ? "#9BA1A6" : "#3DD68C"
    visible:        globals.aeroAIPanelVisible

    readonly property real _u:          ScreenTools.defaultFontPixelHeight
    property string _tab:               aeroAI.configured ? "chat" : "settings"
    property var    _vehicle:           QGroundControl.multiVehicleManager.activeVehicle
    property bool   _wasArmed:          false
    property double _armedAt:           0
    property string _summaryText:       ""
    property string _summaryStatus:     ""
    property bool   _summaryUnread:     false
    property double _lastAutoExplain:   0
    property string _lastExplained:     ""

    readonly property int _historyTurns: 10

    QGCPalette { id: qgcPal; colorGroupEnabled: true }
    ListModel { id: chatModel }       // { role: "user"|"assistant"|"error", text }

    onCollapsedChanged: if (!collapsed && _tab === "summary") { _summaryUnread = false }
    on_TabChanged:      if (_tab === "summary") { _summaryUnread = false }

    // ---------------------------------------------------------------- chat
    function _contextInstructions() {
        return aeroAI.baseInstructions
                + "\n\n[현재 비행 데이터]\n" + aeroAI.vehicleSnapshot()
                + "\n\n[최근 기체 메시지 (오래된 것 → 최신)]\n" + (aeroAI.recentMessages(40) || "없음")
    }

    function send(question) {
        question = question.trim()
        if (question === "") {
            return
        }
        chatModel.append({ role: "user", text: question })
        _scrollToEnd()

        var history = []
        var first = Math.max(0, chatModel.count - _historyTurns * 2)
        for (var i = first; i < chatModel.count; i++) {
            var row = chatModel.get(i)
            if (row.role === "user" || row.role === "assistant") {
                history.push({ role: row.role, content: row.text })
            }
        }
        aeroAI.ask(history, { instructions: _contextInstructions() }, function(ok, answer, error) {
            chatModel.append({ role: ok ? "assistant" : "error", text: ok ? answer : error })
            control._scrollToEnd()
        })
    }

    function explain(messageText) {
        globals.aeroAIPanelVisible = true
        collapsed = false
        _tab = "chat"
        send(qsTr("이 기체 메시지가 무슨 뜻인지, 원인과 지금 해야 할 조치를 알려줘: \"%1\"").arg(messageText))
    }

    function _scrollToEnd() {
        Qt.callLater(function() { chatList.positionViewAtEnd() })
    }

    // ---------------------------------------------------------------- summary
    function makeSummary(auto) {
        _summaryStatus = qsTr("요약을 만드는 중…")
        var duration = _armedAt > 0 && !_wasArmed ? Math.round((Date.now() - _armedAt) / 1000) : 0
        var prompt = "아래 데이터로 비행 결과 보고서를 작성해줘. 형식:\n"
                + "1) 비행 개요 (시간, 최대 고도·거리 등 알 수 있는 것)\n"
                + "2) 주요 이벤트 (시간순, 모드 변경·시동·경고)\n"
                + "3) 이상 및 경고 (없으면 '특이사항 없음')\n"
                + "4) 다음 비행 전 점검 권고\n"
                + "표나 마크다운 기호 없이 짧은 문장과 번호로만 쓴다.\n\n"
                + (duration > 0 ? "[시동 유지 시간] " + Math.floor(duration / 60) + "분 " + (duration % 60) + "초\n\n" : "")
                + "[마지막 비행 데이터]\n" + aeroAI.vehicleSnapshot()
                + "\n\n[기체 메시지 (오래된 것 → 최신)]\n" + (aeroAI.recentMessages(150) || "없음")
        aeroAI.ask(prompt, { maxOutputTokens: 1500 }, function(ok, answer, error) {
            if (ok) {
                control._summaryText = answer
                control._summaryStatus = qsTr("%1 작성").arg(new Date().toLocaleTimeString(Qt.locale("ko_KR"), "HH:mm"))
                control._summaryUnread = auto && control._tab !== "summary"
            } else {
                control._summaryStatus = error
            }
        })
    }

    on_VehicleChanged: {
        _wasArmed = _vehicle ? _vehicle.armed : false
        _armedAt = _wasArmed ? Date.now() : 0
    }

    Connections {
        target: control._vehicle

        function onArmedChanged(armed) {
            if (armed) {
                control._armedAt = Date.now()
                control._wasArmed = true
                return
            }
            var wasArmed = control._wasArmed
            control._wasArmed = false
            // Skip short arm/disarm checks on the ground
            if (wasArmed && aeroAI.autoSummary && aeroAI.configured && Date.now() - control._armedAt > 20000) {
                control.makeSummary(true)
            }
        }

        // Automatic explanation of error (E) messages, at most one every 30 s and no repeats
        function onNewFormattedMessage(formattedMessage) {
            if (!aeroAI.autoExplain || !aeroAI.configured || formattedMessage.indexOf("<#E>") < 0) {
                return
            }
            // <font style="<#E>">[hh:mm:ss.zzz COMP:n] Severity: text</font><br/>
            var m = /<font style="<#E>">\[[^\]]*\]\s*[^:]*:\s*([\s\S]*?)<\/font>/.exec(formattedMessage)
            if (!m) {
                return
            }
            var text = m[1].replace(/<br\/?>/g, " ").replace(/<[^>]*>/g, "")
                           .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&amp;/g, "&").trim()
            if (text === control._lastExplained || Date.now() - control._lastAutoExplain < 30000) {
                return
            }
            control._lastExplained = text
            control._lastAutoExplain = Date.now()
            control.explain(text)
        }
    }

    Connections {
        target: aeroAI
        function onExplainRequested(messageText) { control.explain(messageText) }
    }

    // ---------------------------------------------------------------- UI
    RowLayout {
        Layout.fillWidth:   true
        spacing:            control._u * 0.3

        Repeater {
            model: [
                { key: "chat",     label: qsTr("비서") },
                { key: "summary",  label: qsTr("비행 요약") },
                { key: "settings", label: qsTr("설정") }
            ]
            QGCButton {
                text:           modelData.label + (modelData.key === "summary" && control._summaryUnread ? " •" : "")
                heightFactor:   0.3
                checkable:      true
                checked:        control._tab === modelData.key
                onClicked:      control._tab = modelData.key
            }
        }
        Item { Layout.fillWidth: true }
        QGCButton {
            text:           "✕"
            heightFactor:   0.3
            onClicked:      globals.aeroAIPanelVisible = false
        }
    }

    // ---- 비서 ----
    ColumnLayout {
        Layout.fillWidth:   true
        visible:            control._tab === "chat"
        spacing:            control._u * 0.4

        ListView {
            id:                     chatList
            Layout.fillWidth:       true
            Layout.preferredHeight: control._u * 15
            model:                  chatModel
            clip:                   true
            spacing:                control._u * 0.35
            boundsBehavior:         Flickable.StopAtBounds
            ScrollBar.vertical:     ScrollBar { }

            delegate: Rectangle {
                width:  chatList.width - control._u * 0.6
                height: bubbleText.implicitHeight + control._u * 0.6
                radius: control._u * 0.3
                color:  model.role === "user" ? Qt.rgba(1, 1, 1, 0.06)
                      : (model.role === "error" ? Qt.rgba(1, 0.3, 0.3, 0.12) : Qt.rgba(0.24, 0.84, 0.55, 0.08))
                border.color: model.role === "assistant" ? Qt.rgba(0.24, 0.84, 0.55, 0.35) : "transparent"

                TextEdit {
                    id:                 bubbleText
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins:    control._u * 0.4
                    text:               (model.role === "user" ? "▶ " : "") + model.text
                    wrapMode:           TextEdit.Wrap
                    readOnly:           true
                    selectByMouse:      true
                    color:              model.role === "error" ? "#FF8A8A" : qgcPal.text
                    selectionColor:     qgcPal.buttonHighlight
                    font.pointSize:     ScreenTools.defaultFontPointSize
                    font.family:        ScreenTools.normalFontFamily
                }
            }

            QGCLabel {
                anchors.centerIn:       parent
                width:                  parent.width * 0.85
                visible:                chatModel.count === 0
                horizontalAlignment:    Text.AlignHCenter
                wrapMode:               Text.WordWrap
                opacity:                0.6
                text:                   qsTr("현재 비행 상태와 메시지를 함께 보내 질문합니다.\n예) 지금 배터리로 몇 분 더 날 수 있어?\n예) EKF 경고가 왜 떠?")
            }
        }

        // Quick questions
        Flow {
            Layout.fillWidth:   true
            spacing:            control._u * 0.3
            Repeater {
                model: [ qsTr("지금 상태 점검해줘"), qsTr("이륙해도 될까?"), qsTr("최근 경고 정리해줘") ]
                QGCButton {
                    text:           modelData
                    heightFactor:   0.25
                    enabled:        aeroAI.configured
                    onClicked:      control.send(modelData)
                }
            }
        }

        RowLayout {
            Layout.fillWidth:   true
            spacing:            control._u * 0.3

            QGCTextField {
                id:                 questionField
                Layout.fillWidth:   true
                placeholderText:    aeroAI.configured ? qsTr("질문 입력 후 Enter") : qsTr("설정에서 API 키를 먼저 입력하세요")
                enabled:            aeroAI.configured
                onAccepted: {
                    control.send(text)
                    text = ""
                }
            }
            QGCButton {
                text:       aeroAI.busy ? qsTr("취소") : qsTr("보내기")
                enabled:    aeroAI.configured
                onClicked: {
                    if (aeroAI.busy) {
                        aeroAI.cancelAll()
                    } else {
                        control.send(questionField.text)
                        questionField.text = ""
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("AI 답변은 참고용입니다. 최종 판단은 조종자가 합니다.")
                color:              "#6E757B"
                font.pointSize:     ScreenTools.smallFontPointSize
                wrapMode:           Text.WordWrap
            }
            QGCButton {
                text:           qsTr("대화 지우기")
                heightFactor:   0.25
                enabled:        chatModel.count > 0
                onClicked:      chatModel.clear()
            }
        }
    }

    // ---- 비행 요약 ----
    ColumnLayout {
        Layout.fillWidth:   true
        visible:            control._tab === "summary"
        spacing:            control._u * 0.4

        ScrollView {
            Layout.fillWidth:       true
            Layout.preferredHeight: control._u * 17
            clip:                   true

            TextArea {
                text:               control._summaryText
                placeholderText:    qsTr("비행이 끝나면(시동 끔) 자동으로 요약합니다.\n지금 바로 만들려면 아래 '요약 만들기'를 누르세요.")
                readOnly:           true
                selectByMouse:      true
                wrapMode:           TextEdit.Wrap
                color:              qgcPal.text
                placeholderTextColor: "#6E757B"
                font.pointSize:     ScreenTools.defaultFontPointSize
                background:         Rectangle { color: Qt.rgba(1, 1, 1, 0.04); radius: control._u * 0.3 }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            QGCLabel {
                Layout.fillWidth:   true
                text:               control._summaryStatus
                color:              "#9BA1A6"
                font.pointSize:     ScreenTools.smallFontPointSize
                wrapMode:           Text.WordWrap
            }
            QGCButton {
                text:       qsTr("복사")
                enabled:    control._summaryText !== ""
                onClicked: {
                    QGroundControl.copyToClipboard(control._summaryText)
                    control._summaryStatus = qsTr("클립보드에 복사했습니다")
                }
            }
            QGCButton {
                text:       qsTr("요약 만들기")
                enabled:    aeroAI.configured && !aeroAI.busy && !!control._vehicle
                onClicked:  control.makeSummary(false)
            }
        }
    }

    // ---- 설정 ----
    GridLayout {
        Layout.fillWidth:   true
        visible:            control._tab === "settings"
        columns:            2
        columnSpacing:      control._u * 0.5
        rowSpacing:         control._u * 0.4

        QGCLabel { text: qsTr("API 키") }
        QGCTextField {
            Layout.fillWidth:   true
            text:               aeroAI.apiKey
            echoMode:           TextInput.Password
            placeholderText:    "sk-..."
            onEditingFinished:  aeroAI.apiKey = text.trim()
        }

        QGCLabel { text: qsTr("모델") }
        QGCTextField {
            Layout.fillWidth:   true
            text:               aeroAI.model
            placeholderText:    aeroAI.defaultModel
            onEditingFinished:  aeroAI.model = text.trim() !== "" ? text.trim() : aeroAI.defaultModel
        }

        QGCLabel { text: qsTr("주소") }
        QGCTextField {
            Layout.fillWidth:   true
            text:               aeroAI.endpoint
            placeholderText:    aeroAI.defaultEndpoint
            onEditingFinished:  aeroAI.endpoint = text.trim() !== "" ? text.trim() : aeroAI.defaultEndpoint
        }

        QGCCheckBox {
            Layout.columnSpan:  2
            text:               qsTr("비행이 끝나면 요약 자동 작성")
            checked:            aeroAI.autoSummary
            onClicked:          aeroAI.autoSummary = checked
        }
        QGCCheckBox {
            Layout.columnSpan:  2
            text:               qsTr("오류 메시지 자동 해설 (30초에 1번까지)")
            checked:            aeroAI.autoExplain
            onClicked:          aeroAI.autoExplain = checked
        }

        QGCLabel {
            id:                 testResult
            Layout.fillWidth:   true
            text:               ""
            color:              "#9BA1A6"
            font.pointSize:     ScreenTools.smallFontPointSize
            wrapMode:           Text.WordWrap
        }
        QGCButton {
            text:       qsTr("연결 테스트")
            enabled:    aeroAI.configured && !aeroAI.busy
            onClicked: {
                testResult.text = qsTr("확인 중…")
                aeroAI.ask("연결 테스트다. '연결 정상'이라고만 답해.", { maxOutputTokens: 50 }, function(ok, answer, error) {
                    testResult.color = ok ? "#3DD68C" : "#FF8A8A"
                    testResult.text = ok ? qsTr("정상: %1").arg(answer) : error
                })
            }
        }

        QGCLabel {
            Layout.columnSpan:  2
            Layout.fillWidth:   true
            text:               qsTr("API 키는 이 PC에만 저장됩니다. 여러 PC에 배포할 때는 주소를 사내 중계 서버(NAS)로 바꾸고 키는 비워 두면 됩니다.")
            color:              "#6E757B"
            font.pointSize:     ScreenTools.smallFontPointSize
            wrapMode:           Text.WordWrap
        }
    }
}
