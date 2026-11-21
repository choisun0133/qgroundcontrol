import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controls

// AeroResearch: natural-language mission draft ("AI 임무").
// GPT returns waypoints as north/east offsets from a reference point (or absolute lat/lon);
// the draft is listed for review and only added to the plan when the user presses "미션에 추가".
Popup {
    id:             control
    parent:         Overlay.overlay
    x:              Math.round((parent.width - width) / 2)
    y:              Math.round((parent.height - height) / 6)
    width:          Math.min(_u * 30, parent.width - _u * 2)
    padding:        _u * 0.8
    modal:          true
    focus:          true
    closePolicy:    Popup.CloseOnEscape

    // Set by PlanView
    property var    vehicleCoordinate
    property var    homeCoordinate
    property var    mapCenterCoordinate
    property int    existingItemCount:  0
    property real   defaultAltitude:    50
    property string vehicleType:        ""

    // Emitted with [{ type: "waypoint"|"land"|"rtl", coordinate, altitude }], addTakeoff, takeoffAltitude
    signal applyRequested(var items, bool addTakeoff, real takeoffAltitude)

    readonly property real _u:              ScreenTools.defaultFontPixelHeight
    readonly property real _legalMaxAlt:    150
    property var    _plan:                  null
    property var    _items:                 []
    property string _status:                ""
    property bool   _overLimitAccepted:     false
    property var    _requestRefs:           null    // reference points copied when the request was sent
    readonly property bool _overLimit:      _maxAltitude() > _legalMaxAlt

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    function openDialog() {
        _requestRefs = null
        _plan = null
        _items = []
        _status = ""
        _overLimitAccepted = false
        open()
        requestField.forceActiveFocus()
    }

    function _coordText(c) {
        return c && c.isValid ? c.latitude.toFixed(7) + ", " + c.longitude.toFixed(7) : "없음"
    }

    readonly property var _schema: ({
        type: "object",
        additionalProperties: false,
        required: ["summary", "reference", "add_takeoff", "takeoff_alt_m", "items", "warnings"],
        properties: {
            summary:        { type: "string" },
            reference:      { type: "string", enum: ["vehicle", "home", "map_center", "absolute"] },
            add_takeoff:    { type: "boolean" },
            takeoff_alt_m:  { type: ["number", "null"] },
            warnings:       { type: "array", items: { type: "string" } },
            items: {
                type: "array",
                items: {
                    type: "object",
                    additionalProperties: false,
                    required: ["type", "north_m", "east_m", "lat", "lon", "alt_m"],
                    properties: {
                        type:    { type: "string", enum: ["waypoint", "land", "rtl"] },
                        north_m: { type: ["number", "null"] },
                        east_m:  { type: ["number", "null"] },
                        lat:     { type: ["number", "null"] },
                        lon:     { type: ["number", "null"] },
                        alt_m:   { type: ["number", "null"] }
                    }
                }
            }
        }
    })

    function generate(request) {
        request = request.trim()
        if (request === "") {
            return
        }
        _status = qsTr("임무 초안을 만드는 중…")
        // Keep the reference points of this request: the vehicle may move (or the link drop)
        // before the answer arrives, and the offsets must be applied to the same points.
        var refs = {
            vehicle:    vehicleCoordinate && vehicleCoordinate.isValid ? QtPositioning.coordinate(vehicleCoordinate.latitude, vehicleCoordinate.longitude) : null,
            home:       homeCoordinate && homeCoordinate.isValid ? QtPositioning.coordinate(homeCoordinate.latitude, homeCoordinate.longitude) : null,
            mapCenter:  QtPositioning.coordinate(mapCenterCoordinate.latitude, mapCenterCoordinate.longitude)
        }
        _requestRefs = refs
        _plan = null
        _items = []
        _overLimitAccepted = false

        var instructions = aeroAI.baseInstructions
            + "\n\n너는 지금 임무(웨이포인트) 초안을 만든다. 규칙:\n"
            + "- 좌표는 기준점(reference)에서 북쪽(north_m)·동쪽(east_m) 미터 오프셋으로 쓴다. 남쪽·서쪽은 음수. 오프셋은 항목마다 기준점에서 잰 값이다(누적 아님).\n"
            + "- 사용자가 위경도를 직접 주면 reference를 absolute로 하고 lat/lon을 쓴다. 그 외에는 lat/lon은 null.\n"
            + "- 기준점 기본값: 기체 위치가 있으면 vehicle, 없으면 home, 둘 다 없으면 map_center.\n"
            + "- alt_m은 이륙 지점 기준 상대고도(m). 사용자가 말하지 않으면 기본 고도를 쓴다. land·rtl 항목의 alt_m은 null.\n"
            + "- 격자(지그재그) 비행은 요청한 영역과 간격으로 웨이포인트를 직접 나열한다. 항목은 최대 60개.\n"
            + "- 끝에 귀환을 원하면 rtl, 특정 지점 착륙이면 그 좌표로 land를 쓴다.\n"
            + "- 150m 초과 고도, 애매한 요청, 위험해 보이는 부분은 warnings에 한국어로 적는다.\n"
            + "- summary는 한국어 한두 문장.\n\n"
            + "[기체 종류] " + vehicleType + "\n"
            + "[기체 위치] " + _coordText(refs.vehicle) + "\n"
            + "[홈 위치] " + _coordText(refs.home) + "\n"
            + "[지도 중심] " + _coordText(refs.mapCenter) + "\n"
            + "[기본 고도] " + defaultAltitude + " m\n"
            + "[현재 미션 항목 수] " + existingItemCount + " (0이면 새 미션)"

        aeroAI.ask(request, { instructions: instructions, schema: _schema, schemaName: "mission_draft", maxOutputTokens: 4000 },
                   function(ok, plan, error) {
            if (control._requestRefs !== refs) {
                return      // a newer request replaced this one
            }
            if (!ok) {
                control._status = error
                return
            }
            control._build(plan, refs)
        })
    }

    function _referenceCoordinate(name, refs) {
        if (name === "vehicle" && refs.vehicle) {
            return refs.vehicle
        }
        if ((name === "vehicle" || name === "home") && refs.home) {
            return refs.home
        }
        return refs.mapCenter
    }

    function _build(plan, refs) {
        var ref = _referenceCoordinate(plan.reference, refs)
        var items = []
        var src = plan.items || []
        for (var i = 0; i < src.length && i < 60; i++) {
            var it = src[i]
            if (it.type === "rtl") {
                items.push({ type: "rtl", coordinate: null, altitude: NaN })
                continue
            }
            var coord
            if (plan.reference === "absolute" && it.lat !== null && it.lon !== null) {
                coord = QtPositioning.coordinate(it.lat, it.lon)
            } else {
                var north = it.north_m || 0
                var east = it.east_m || 0
                var dist = Math.sqrt(north * north + east * east)
                var azimuth = Math.atan2(east, north) * 180 / Math.PI
                coord = dist > 0 ? ref.atDistanceAndAzimuth(dist, azimuth) : QtPositioning.coordinate(ref.latitude, ref.longitude)
            }
            if (!coord || !coord.isValid) {
                continue
            }
            var alt = it.alt_m !== null && it.alt_m !== undefined ? it.alt_m : defaultAltitude
            items.push({ type: it.type, coordinate: coord, altitude: alt })
        }
        // An omitted takeoff altitude becomes the default mission altitude, the value the
        // takeoff item would get anyway, so it is shown and checked against the 150 m limit.
        if (plan.add_takeoff && (plan.takeoff_alt_m === null || plan.takeoff_alt_m === undefined)) {
            plan.takeoff_alt_m = defaultAltitude
        }
        _plan = plan
        _items = items
        _status = items.length > 0 ? "" : qsTr("만들어진 항목이 없습니다. 요청을 더 구체적으로 적어 주세요.")
    }

    function _maxAltitude() {
        var m = 0
        for (var i = 0; i < _items.length; i++) {
            if (!isNaN(_items[i].altitude)) {
                m = Math.max(m, _items[i].altitude)
            }
        }
        if (_plan && _plan.add_takeoff && _plan.takeoff_alt_m !== null) {
            m = Math.max(m, _plan.takeoff_alt_m)
        }
        return m
    }

    function _typeText(type) {
        return type === "land" ? qsTr("착륙") : (type === "rtl" ? qsTr("귀환(RTL)") : qsTr("웨이포인트"))
    }

    background: Rectangle {
        color:          "#0E0F11"
        border.color:   "#2A2D31"
        radius:         control._u * 0.5
    }

    contentItem: ColumnLayout {
        spacing: control._u * 0.5

        RowLayout {
            Layout.fillWidth: true
            QGCLabel { Layout.fillWidth: true; text: qsTr("AI 임무 작성"); font.bold: true }
            QGCButton { text: "✕"; heightFactor: 0.3; onClicked: control.close() }
        }

        QGCLabel {
            Layout.fillWidth:   true
            text:               qsTr("예) 기체 위치에서 북쪽 200m, 가로 100m 세로 60m 구역을 고도 60m, 간격 20m로 지그재그 촬영하고 귀환\n예) 홈에서 동쪽 300m 지점까지 고도 80m로 갔다가 그 자리에서 착륙")
            color:              "#9BA1A6"
            font.pointSize:     ScreenTools.smallFontPointSize
            wrapMode:           Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            QGCTextField {
                id:                 requestField
                Layout.fillWidth:   true
                placeholderText:    aeroAI.configured ? qsTr("원하는 임무를 말로 적고 Enter") : qsTr("Ctrl+F → AI 비서 → 설정에서 API 키를 입력하세요")
                enabled:            aeroAI.configured && !aeroAI.busy
                onAccepted:         control.generate(text)
            }
            QGCButton {
                text:       qsTr("만들기")
                enabled:    aeroAI.configured && !aeroAI.busy
                onClicked:  control.generate(requestField.text)
            }
        }

        QGCLabel {
            Layout.fillWidth:   true
            visible:            control._status !== ""
            text:               control._status
            color:              "#FFC861"
            wrapMode:           Text.WordWrap
        }

        // ---- Draft preview ----
        QGCLabel {
            Layout.fillWidth:   true
            visible:            !!control._plan
            text:               control._plan ? control._plan.summary : ""
            wrapMode:           Text.WordWrap
        }

        Repeater {
            model: control._plan ? control._plan.warnings : []
            QGCLabel {
                Layout.fillWidth:   true
                text:               "⚠ " + modelData
                color:              "#FFB020"
                font.pointSize:     ScreenTools.smallFontPointSize
                wrapMode:           Text.WordWrap
            }
        }

        ListView {
            id:                     draftList
            Layout.fillWidth:       true
            Layout.preferredHeight: Math.min(contentHeight, control._u * 12)
            visible:                control._items.length > 0
            model:                  control._items
            clip:                   true
            ScrollBar.vertical:     ScrollBar { }

            header: Item {
                width:  draftList.width
                height: takeoffLabel.visible ? takeoffLabel.implicitHeight + control._u * 0.2 : 0
                QGCLabel {
                    id:             takeoffLabel
                    visible:        !!control._plan && control._plan.add_takeoff
                    text:           qsTr("0. 이륙 (기체 위치) %1").arg(control._plan && control._plan.takeoff_alt_m !== null ? control._plan.takeoff_alt_m + " m" : "")
                    font.family:    ScreenTools.fixedFontFamily
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }
            delegate: QGCLabel {
                width:          draftList.width
                text:           (index + 1) + ". " + control._typeText(modelData.type)
                                + (modelData.coordinate ? "  " + modelData.coordinate.latitude.toFixed(6) + ", " + modelData.coordinate.longitude.toFixed(6) : "")
                                + (!isNaN(modelData.altitude) && modelData.type === "waypoint" ? "  " + modelData.altitude + " m" : "")
                color:          modelData.altitude > control._legalMaxAlt ? "#FF8A8A" : qgcPal.text
                font.family:    ScreenTools.fixedFontFamily
                font.pointSize: ScreenTools.smallFontPointSize
            }
        }

        QGCCheckBox {
            visible:    control._overLimit
            text:       qsTr("150m 초과 고도가 있습니다. 승인을 받은 비행임을 확인합니다")
            checked:    control._overLimitAccepted
            onClicked:  control._overLimitAccepted = checked
        }

        RowLayout {
            Layout.fillWidth:   true
            visible:            control._items.length > 0
            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("추가한 뒤 지도에서 위치를 꼭 확인하세요.")
                color:              "#6E757B"
                font.pointSize:     ScreenTools.smallFontPointSize
                wrapMode:           Text.WordWrap
            }
            QGCButton {
                text:       qsTr("다시 만들기")
                enabled:    aeroAI.configured && !aeroAI.busy
                onClicked:  control.generate(requestField.text)
            }
            QGCButton {
                text:       qsTr("미션에 추가")
                primary:    true
                enabled:    !control._overLimit || control._overLimitAccepted
                onClicked: {
                    var takeoffAlt = control._plan.takeoff_alt_m !== null ? control._plan.takeoff_alt_m : NaN
                    control.applyRequested(control._items, control._plan.add_takeoff, takeoffAlt)
                    control.close()
                }
            }
        }
    }
}
