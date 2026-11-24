import QtCore
import QtQuick

import QGroundControl

// AeroResearch: AI client shared by the AI windows. Providers:
//  - openai: OpenAI Responses API (paid)
//  - aero:   AeroResearch shared AI (aero-ai-relay on the office server). The password is asked
//            once per run and never saved.
//  - claude: Anthropic Claude Messages API (paid)
//  - gemini: Google Gemini through its OpenAI-compatible Chat Completions endpoint (free tier)
//  - custom: any endpoint; ".../responses" is sent in Responses format, anything else as Chat
//            Completions (Ollama, LM Studio, an in-house relay)
// One instance lives in MainWindow as `aeroAI`.
//  - ask(): sends a request and calls back with the answer text (or parsed JSON when a schema is given)
//  - vehicleSnapshot() / recentMessages(): flight context in plain text for the prompts
// The endpoint can be changed to an in-house relay (e.g. the NAS), so the API key does not have
// to be stored on every GCS PC; with an empty key no Authorization header is sent.
QtObject {
    id: control

    // ---- Settings (saved per PC) ----
    property alias provider:        saved.provider          // "aero" | "openai" | "claude" | "gemini" | "custom"
    property alias aeroEndpoint:    saved.aeroEndpoint
    property string aeroPassword:   ""                      // shared AI password: this run only, never saved
    property alias apiKey:          saved.apiKey            // OpenAI
    property alias model:           saved.model
    property alias endpoint:        saved.endpoint
    property alias claudeKey:       saved.claudeKey
    property alias claudeModel:     saved.claudeModel
    property alias geminiKey:       saved.geminiKey
    property alias geminiModel:     saved.geminiModel
    property alias customKey:       saved.customKey
    property alias customModel:     saved.customModel
    property alias customEndpoint:  saved.customEndpoint
    property alias autoSummary:     saved.autoSummary       // write a flight summary after disarm
    property alias autoExplain:     saved.autoExplain       // explain error (E) messages automatically

    readonly property string defaultEndpoint:   "https://api.openai.com/v1/responses"
    readonly property string defaultModel:      "gpt-6-astra"
    readonly property string defaultAeroEndpoint: "http://192.168.0.239:8090/v1/chat/completions"
    readonly property bool   aeroAvailable:     QGroundControl.aeroBrand === "aero"
    readonly property bool   needsPassword:     provider === "aero" && aeroPassword === ""
    readonly property string claudeEndpoint:    "https://api.anthropic.com/v1/messages"
    readonly property string defaultClaudeModel: "claude-sonnet-5-5"
    readonly property string geminiEndpoint:    "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
    readonly property string defaultGeminiModel: "gemini-flash-latest"

    readonly property string activeKey:      provider === "aero" ? aeroPassword : provider === "claude" ? claudeKey : (provider === "gemini" ? geminiKey : (provider === "custom" ? customKey : apiKey))
    readonly property string activeEndpoint: provider === "aero" ? (aeroEndpoint !== "" ? aeroEndpoint : defaultAeroEndpoint) : provider === "claude" ? claudeEndpoint : (provider === "gemini" ? geminiEndpoint : (provider === "custom" ? customEndpoint : endpoint))
    readonly property string activeModel:    provider === "aero" ? "server" : provider === "claude" ? (claudeModel !== "" ? claudeModel : defaultClaudeModel)
                                             : provider === "gemini" ? (geminiModel !== "" ? geminiModel : defaultGeminiModel)
                                             : (provider === "custom" ? customModel : (model !== "" ? model : defaultModel))
    readonly property bool   claudeFormat:   provider === "claude"
    readonly property bool   chatFormat:     provider === "aero" || provider === "gemini" || (provider === "custom" && !/\/responses\/?$/.test(customEndpoint))
    readonly property bool   configured:     activeEndpoint !== "" && activeModel !== ""
                                             && (activeKey !== "" || provider === "aero" || provider === "custom" || (provider === "openai" && endpoint !== defaultEndpoint))
    readonly property bool   busy:              _pending.length > 0
    property var             _pending:          []
    readonly property int    _timeoutMs:        90000

    // Asks the AI window to explain a vehicle message (connected in AeroAIPanel)
    signal explainRequested(string messageText)

    property Settings _saved: Settings {
        id:         saved
        category:   "AeroAI"
        property string provider:       "openai"
        property string aeroEndpoint:   ""
        property string apiKey:         ""
        property string claudeKey:      ""
        property string claudeModel:    ""
        property string geminiKey:      ""
        property string geminiModel:    ""
        property string customKey:      ""
        property string customModel:    ""
        property string customEndpoint: ""
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
        if (needsPassword) {
            done(false, null, qsTr("AI 비서 창에서 공용 AI 비밀번호를 입력하세요"))
            return
        }
        if (!configured) {
            done(false, null, qsTr("AI 설정에서 API 키를 입력하세요"))
            return
        }

        var instructions = options.instructions !== undefined ? options.instructions : baseInstructions
        // The reply is parsed in the format the request was sent in
        options._chat = chatFormat
        options._claude = claudeFormat
        options._aero = provider === "aero"
        var body = options._claude ? _claudeBody(input, instructions, options)
                 : (options._chat ? _chatBody(input, instructions, options) : _responsesBody(input, instructions, options))

        var xhr = new XMLHttpRequest()
        var entry = { xhr: xhr, started: Date.now(), done: done, finished: false }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || entry.finished) {
                return
            }
            control._finish(entry)
            control._handleReply(xhr, options, done)
        }
        xhr.open("POST", activeEndpoint)
        xhr.setRequestHeader("Content-Type", "application/json")
        if (options._claude) {
            xhr.setRequestHeader("x-api-key", activeKey)
            xhr.setRequestHeader("anthropic-version", "2023-06-01")
        } else if (activeKey !== "") {
            xhr.setRequestHeader("Authorization", "Bearer " + activeKey)
        }
        var list = _pending.slice()
        list.push(entry)
        _pending = list
        _timeoutTimer.start()
        xhr.send(JSON.stringify(body))
    }

    function _responsesBody(input, instructions, options) {
        var body = { model: activeModel, instructions: instructions, input: input, store: false }
        if (options.maxOutputTokens) {
            body.max_output_tokens = options.maxOutputTokens
        }
        if (options.schema) {
            body.text = { format: { type: "json_schema", name: options.schemaName || "result", schema: options.schema, strict: true } }
        }
        return body
    }

    // Chat Completions. No max_tokens: Gemini's thinking tokens count against it and a small limit
    // returns an empty answer. Structured output is requested in the prompt, which every
    // compatible server understands, and the JSON is cut out of the reply.
    function _chatBody(input, instructions, options) {
        var system = instructions
        if (options.schema) {
            system += "\n\n응답은 아래 JSON 스키마를 따르는 JSON 객체 하나만 출력한다. 설명 문장이나 ``` 코드 블록 없이 JSON만 쓴다.\n"
                      + JSON.stringify(options.schema)
        }
        var messages = [ { role: "system", content: system } ]
        if (Array.isArray(input)) {
            for (var i = 0; i < input.length; i++) {
                messages.push({ role: input[i].role, content: String(input[i].content) })
            }
        } else {
            messages.push({ role: "user", content: String(input) })
        }
        return { model: activeModel, messages: messages }
    }

    // Claude Messages API: system is a top-level field and max_tokens is required. Structured output
    // goes through the prompt, as for Chat Completions.
    function _claudeBody(input, instructions, options) {
        var body = _chatBody(input, instructions, options)
        var system = body.messages.shift().content
        return { model: activeModel, max_tokens: Math.max(options.maxOutputTokens || 0, 4096), system: system, messages: body.messages }
    }

    function _extractJson(text) {
        var t = text.replace(/^```(?:json)?\s*/i, "").replace(/\s*```\s*$/, "")
        var start = t.indexOf("{")
        var end = t.lastIndexOf("}")
        return start >= 0 && end > start ? t.substring(start, end + 1) : t
    }

    // JSON schema subset used by the AI windows: type (single or list), enum, properties,
    // required, additionalProperties:false, items. Numbers must be finite.
    function _matchesSchema(value, schema) {
        if (!schema) {
            return true
        }
        var types = schema.type === undefined ? [] : (Array.isArray(schema.type) ? schema.type : [schema.type])
        if (types.length > 0) {
            var typeOk = false
            for (var t = 0; t < types.length && !typeOk; t++) {
                switch (types[t]) {
                case "null":    typeOk = value === null; break
                case "boolean": typeOk = typeof value === "boolean"; break
                case "string":  typeOk = typeof value === "string"; break
                case "number":  typeOk = typeof value === "number" && isFinite(value); break
                case "integer": typeOk = typeof value === "number" && isFinite(value) && Math.floor(value) === value; break
                case "array":   typeOk = Array.isArray(value); break
                case "object":  typeOk = value !== null && typeof value === "object" && !Array.isArray(value); break
                }
            }
            if (!typeOk) {
                return false
            }
        }
        if (schema.enum && schema.enum.indexOf(value) < 0) {
            return false
        }
        if (Array.isArray(value) && schema.items) {
            for (var i = 0; i < value.length; i++) {
                if (!_matchesSchema(value[i], schema.items)) {
                    return false
                }
            }
        }
        if (value !== null && typeof value === "object" && !Array.isArray(value)) {
            var props = schema.properties || {}
            var required = schema.required || []
            for (var r = 0; r < required.length; r++) {
                if (!(required[r] in value)) {
                    return false
                }
            }
            for (var key in value) {
                if (props[key] !== undefined) {
                    if (!_matchesSchema(value[key], props[key])) {
                        return false
                    }
                } else if (schema.additionalProperties === false) {
                    return false
                }
            }
        }
        return true
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
            var err = Array.isArray(data) ? data[0] : data     // Gemini can wrap the error in an array
            var msg = err && err.error && err.error.message ? err.error.message : ""
            if (xhr.status === 0) {
                done(false, null, qsTr("서버에 연결할 수 없습니다 (인터넷·주소 확인)"))
            } else if ((xhr.status === 401 || xhr.status === 403) && options._aero) {
                aeroPassword = ""       // ask again
                done(false, null, qsTr("공용 AI 비밀번호가 올바르지 않습니다"))
            } else if (xhr.status === 401 || xhr.status === 403) {
                done(false, null, qsTr("API 키가 올바르지 않습니다 (%1) %2").arg(xhr.status).arg(msg))
            } else if (xhr.status === 429) {
                done(false, null, qsTr("사용 한도 초과 또는 요청이 너무 많습니다 (429) %1").arg(msg))
            } else {
                done(false, null, qsTr("오류 %1: %2").arg(xhr.status).arg(msg))
            }
            return
        }
        var text = options._claude ? _claudeText(data) : (options._chat ? _chatText(data) : _outputText(data))
        if (text === "") {
            done(false, null, qsTr("응답이 비어 있습니다"))
            return
        }
        if (options.schema) {
            try {
                var parsed = JSON.parse(options._chat || options._claude ? _extractJson(text) : text)
                // Only the OpenAI Responses format enforces the schema on the server; the
                // prompt-only formats are checked here so a "200m" altitude can't slip through.
                if ((options._chat || options._claude) && !_matchesSchema(parsed, options.schema)) {
                    done(false, null, qsTr("응답 형식이 맞지 않습니다. 다시 시도하세요"))
                    return
                }
                done(true, parsed, "")
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

    // Chat Completions: choices[0].message.content (string, or an array of {type:"text", text})
    function _chatText(data) {
        if (!data || !data.choices || data.choices.length === 0 || !data.choices[0].message) {
            return ""
        }
        var content = data.choices[0].message.content
        if (typeof content === "string") {
            return content.trim()
        }
        var parts = []
        for (var i = 0; content && i < content.length; i++) {
            if (content[i].text) {
                parts.push(content[i].text)
            }
        }
        return parts.join("\n").trim()
    }

    // Claude Messages API: content[] -> {type:"text", text}
    function _claudeText(data) {
        var parts = []
        var content = data && data.content ? data.content : []
        for (var i = 0; i < content.length; i++) {
            if (content[i].type === "text" && content[i].text) {
                parts.push(content[i].text)
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
