import QtCore
import QtQuick

import QGroundControl

// AeroResearch: GPT (OpenAI Responses API) client shared by the AI windows.
// One instance lives in MainWindow as `aeroAI`.
//  - ask(): sends a request and calls back with the answer text (or parsed JSON when a schema is given)
//  - vehicleSnapshot() / recentMessages(): flight context in plain text for the prompts
// The endpoint can be changed to an in-house relay (e.g. the NAS), so the API key does not have
// to be stored on every GCS PC; with an empty key no Authorization header is sent.
QtObject {
    id: control

    // ---- Settings (saved per PC) ----
    property alias apiKey:          saved.apiKey
    property alias model:           saved.model
    property alias endpoint:        saved.endpoint
    property alias autoSummary:     saved.autoSummary       // write a flight summary after disarm
    property alias autoExplain:     saved.autoExplain       // explain error (E) messages automatically

    readonly property string defaultEndpoint:   "https://api.openai.com/v1/responses"
    readonly property string defaultModel:      "gpt-6-astra"
    readonly property bool   configured:        endpoint !== "" && (apiKey !== "" || endpoint !== defaultEndpoint)
    readonly property bool   busy:              _pending.length > 0
    property var             _pending:          []
    readonly property int    _timeoutMs:        90000

    // Asks the AI window to explain a vehicle message (connected in AeroAIPanel)
    signal explainRequested(string messageText)

    property Settings _saved: Settings {
        id:         saved
        category:   "AeroAI"
        property string apiKey:         ""
        property string model:          "gpt-6-astra"
        property string endpoint:       "https://api.openai.com/v1/responses"
        property bool   autoSummary:    true
        property bool   autoExplain:    false
    }

    readonly property string baseInstructions:
        "너는 주식회사 에어로리서치의 드론 지상통제(GCS) 보조 AI다. 항상 한국어로, 짧고 실무적으로 답한다. "
        + "기체는 주로 ArduPilot(멀티콥터)이며 일부 PX4 VTOL이 있다. "
        + "주어진 비행 데이터와 메시지에 근거해서만 판단하고, 데이터에 없는 내용은 추측이라고 밝힌다. "
        + "안전이 걸린 판단(즉시 착륙, RTL 등)은 분명하게 먼저 말한다. 최종 판단은 조종자가 한다는 전제로 조언한다. "
        + "한국 항공안전법상 일반 비행 고도 상한은 150m이며 비행금지·제한구역은 별도 승인이 필요하다."

    // ---------------------------------------------------------------- request
    // input:   string, or an array of {role, content} messages
    // options: { instructions, schema (JSON schema object), schemaName, maxOutputTokens }
    // done(ok, result, errorText): result is text, or the parsed object when a schema was given
    function ask(input, options, done) {
        options = options || {}
        if (!configured) {
            done(false, null, qsTr("AI 설정에서 API 키를 입력하세요"))
            return
        }

        var body = {
            model:          model !== "" ? model : defaultModel,
            instructions:   options.instructions !== undefined ? options.instructions : baseInstructions,
            input:          input,
            store:          false
        }
        if (options.maxOutputTokens) {
            body.max_output_tokens = options.maxOutputTokens
        }
        if (options.schema) {
            body.text = { format: { type: "json_schema", name: options.schemaName || "result", schema: options.schema, strict: true } }
        }

        var xhr = new XMLHttpRequest()
        var entry = { xhr: xhr, started: Date.now(), done: done, finished: false }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || entry.finished) {
                return
            }
            control._finish(entry)
            control._handleReply(xhr, options, done)
        }
        xhr.open("POST", endpoint)
        xhr.setRequestHeader("Content-Type", "application/json")
        if (apiKey !== "") {
            xhr.setRequestHeader("Authorization", "Bearer " + apiKey)
        }
        var list = _pending.slice()
        list.push(entry)
        _pending = list
        _timeoutTimer.start()
        xhr.send(JSON.stringify(body))
    }

    function _finish(entry) {
        entry.finished = true
        _pending = _pending.filter(function(e) { return e !== entry })
        if (_pending.length === 0) {
            _timeoutTimer.stop()
        }
    }

    function _handleReply(xhr, options, done) {
        var data = null
        try {
            data = JSON.parse(xhr.responseText)
        } catch (e) {
            data = null
        }
        if (xhr.status < 200 || xhr.status >= 300) {
            var msg = data && data.error && data.error.message ? data.error.message : ""
            if (xhr.status === 0) {
                done(false, null, qsTr("서버에 연결할 수 없습니다 (인터넷·주소 확인)"))
            } else if (xhr.status === 401) {
                done(false, null, qsTr("API 키가 올바르지 않습니다 (401)"))
            } else if (xhr.status === 429) {
                done(false, null, qsTr("사용 한도 초과 또는 요청이 너무 많습니다 (429) %1").arg(msg))
            } else {
                done(false, null, qsTr("오류 %1: %2").arg(xhr.status).arg(msg))
            }
            return
        }
        var text = _outputText(data)
        if (text === "") {
            done(false, null, qsTr("응답이 비어 있습니다"))
            return
        }
        if (options.schema) {
            try {
                done(true, JSON.parse(text), "")
            } catch (e2) {
                done(false, null, qsTr("응답 형식을 읽지 못했습니다"))
            }
            return
        }
        done(true, text, "")
    }

    // Responses API: output[] -> {type:"message", content:[{type:"output_text", text}]}
    function _outputText(data) {
        if (!data) {
            return ""
        }
        if (typeof data.output_text === "string") {
            return data.output_text
        }
        var parts = []
        var output = data.output || []
        for (var i = 0; i < output.length; i++) {
            var content = output[i].content || []
            for (var j = 0; j < content.length; j++) {
                if (content[j].type === "output_text" && content[j].text) {
                    parts.push(content[j].text)
                } else if (content[j].type === "refusal" && content[j].refusal) {
                    parts.push(content[j].refusal)
                }
            }
        }
        return parts.join("\n").trim()
    }

    function cancelAll() {
        var list = _pending
        _pending = []
        _timeoutTimer.stop()
        for (var i = 0; i < list.length; i++) {
            list[i].finished = true
            list[i].xhr.abort()
            list[i].done(false, null, qsTr("취소했습니다"))
        }
    }

    property Timer _timeoutTimer: Timer {
        interval:   1000
        repeat:     true
        onTriggered: {
            var now = Date.now()
            var list = control._pending.slice()
            for (var i = 0; i < list.length; i++) {
                if (now - list[i].started > control._timeoutMs) {
                    control._finish(list[i])
                    list[i].xhr.abort()
                    list[i].done(false, null, qsTr("응답 시간이 초과됐습니다"))
                }
            }
        }
    }

    // ---------------------------------------------------------------- flight context
    function _num(fact, digits) {
        if (!fact) {
            return "?"
        }
        var v = fact.rawValue
        if (v === undefined || v === null || isNaN(v)) {
            return "?"
        }
        return Number(v).toFixed(digits === undefined ? 1 : digits)
    }

    function _coord(c) {
        return c && c.isValid ? c.latitude.toFixed(7) + ", " + c.longitude.toFixed(7) : "?"
    }

    function vehicleSnapshot() {
        var v = QGroundControl.multiVehicleManager.activeVehicle
        if (!v) {
            return "기체 연결 안 됨"
        }
        var lines = []
        try {
            lines.push("시각: " + new Date().toLocaleString(Qt.locale("ko_KR")))
            lines.push("기체: " + v.firmwareTypeString + " / " + v.vehicleTypeString)
            lines.push("시동: " + (v.armed ? "켜짐" : "꺼짐") + ", 비행 중: " + (v.flying ? "예" : "아니오") + ", 모드: " + v.flightMode)
            lines.push("위치: " + _coord(v.coordinate) + ", 홈: " + _coord(v.homePosition))
            lines.push("상대고도 " + _num(v.altitudeRelative) + " m, 지상속도 " + _num(v.groundSpeed) + " m/s, 상승률 "
                       + _num(v.climbRate) + " m/s, 홈 거리 " + _num(v.distanceToHome, 0) + " m, 비행 거리 " + _num(v.flightDistance, 0) + " m")
            lines.push("자세: 롤 " + _num(v.roll) + "°, 피치 " + _num(v.pitch) + "°, 기수 " + _num(v.heading, 0) + "°")
            if (v.gps) {
                lines.push("GPS: 위성 " + _num(v.gps.count, 0) + "개, 고정 " + _num(v.gps.lock, 0) + " (3=3D, 5=RTK Float, 6=RTK Fixed), HDOP " + _num(v.gps.hdop, 2))
            }
            for (var i = 0; i < v.batteries.count; i++) {
                var b = v.batteries.get(i)
                lines.push("배터리" + (i + 1) + ": " + _num(b.voltage, 2) + " V, " + _num(b.percentRemaining, 0) + " %, 전류 " + _num(b.current, 1) + " A")
            }
            if (v.vibration) {
                lines.push("진동(m/s²): X " + _num(v.vibration.xAxis) + ", Y " + _num(v.vibration.yAxis) + ", Z " + _num(v.vibration.zAxis)
                           + ", 클리핑 " + _num(v.vibration.clipCount1, 0) + "/" + _num(v.vibration.clipCount2, 0) + "/" + _num(v.vibration.clipCount3, 0))
            }
            if (v.ekfStatus) {
                lines.push("EKF 분산: 속도 " + _num(v.ekfStatus.velocityVariance, 2) + ", 수평위치 " + _num(v.ekfStatus.posHorizVariance, 2)
                           + ", 수직위치 " + _num(v.ekfStatus.posVertVariance, 2) + ", 나침반 " + _num(v.ekfStatus.compassVariance, 2))
            }
            lines.push("RC RSSI: " + v.rcRSSI + ", MAVLink 손실: " + Number(v.mavlinkLossPercent).toFixed(1) + " %")
        } catch (e) {
            lines.push("(일부 값 읽기 실패: " + e + ")")
        }
        return lines.join("\n")
    }

    // Vehicle STATUSTEXT log, oldest first. StatusTextHandler format:
    // <font style="<#E|I|N>">[hh:mm:ss.zzz COMP:n] Severity: text</font><br/>
    function recentMessages(maxCount) {
        var v = QGroundControl.multiVehicleManager.activeVehicle
        if (!v) {
            return ""
        }
        var re = /<font style="<#([EIN])>">\[(\d\d:\d\d:\d\d)[^\]]*\]\s*[^:]*:\s*([\s\S]*?)<\/font><br\/>/g
        var rows = []
        var m
        var formatted = v.formattedMessages || ""
        while ((m = re.exec(formatted)) !== null) {
            var text = m[3].replace(/<br\/?>/g, " ").replace(/<[^>]*>/g, "")
                           .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&amp;/g, "&")
            rows.push(m[2] + " [" + (m[1] === "E" ? "오류" : (m[1] === "I" ? "경고" : "정보")) + "] " + text)
        }
        rows.reverse()      // formattedMessages is newest first
        var n = maxCount || 60
        return rows.slice(Math.max(0, rows.length - n)).join("\n")
    }
}
