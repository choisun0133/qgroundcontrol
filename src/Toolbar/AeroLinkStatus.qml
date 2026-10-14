import QtQuick

import QGroundControl

// AeroResearch: status of the five things a pilot watches - RF telemetry, RC transmitter, LTE, GPS
// and battery - reduced to ok / weak / lost / off with display text and details. Shared by the
// toolbar group (AeroStatusGroup) and the alert banner (AeroStatusAlert).
QtObject {
    id: root

    readonly property color colorOk:    "#3DDC84"
    readonly property color colorWeak:  "#FFB020"
    readonly property color colorLost:  "#FF6B6B"
    readonly property color colorOff:   "#9BA1A6"

    property var    vehicle:        QGroundControl.multiVehicleManager.activeVehicle
    property var    _vlm:           vehicle ? vehicle.vehicleLinkManager : null
    property var    _names:         _vlm ? _vlm.linkNames : []
    property var    _statuses:      _vlm ? _vlm.linkStatuses : []
    property string _primary:       _vlm ? _vlm.primaryLinkName : ""
    property bool   commLost:       _vlm ? _vlm.communicationLost : false
    property var    _configs:       QGroundControl.linkManager.linkConfigurations

    readonly property int _rcReceiverBit: 65536    // MAV_SYS_STATUS_SENSOR_RC_RECEIVER

    function stateColor(st) {
        return st === "ok" ? colorOk : (st === "weak" ? colorWeak : (st === "lost" ? colorLost : colorOff))
    }

    function _linkKind(name) {
        for (var i = 0; i < _configs.count; i++) {
            var cfg = _configs.get(i)
            if (cfg.name !== name) {
                continue
            }
            if (cfg.linkType === LinkConfiguration.TypeTcp) {
                return "LTE"
            }
            if (cfg.linkType === LinkConfiguration.TypeUdp) {
                return cfg.dynamic ? "UDP" : "LTE"
            }
            if (cfg.linkType === LinkConfiguration.TypeSerial) {
                return cfg.usbDirect ? "USB" : "RF"
            }
            return ""
        }
        return ""
    }

    function _linkState(kind, names, statuses, primary) {
        var found = false
        var alive = false
        var isPrimary = false
        for (var i = 0; i < names.length; i++) {
            if (_linkKind(names[i]) !== kind) {
                continue
            }
            found = true
            if (statuses[i] === "") {
                alive = true
            }
            if (names[i] === primary && names.length > 1) {
                isPrimary = true
            }
        }
        return { found: found, lost: found && !alive, primary: isPrimary }
    }

    function _dbmPercent(dbm) {
        if (dbm === 0 || isNaN(dbm)) {
            return -1
        }
        return Math.max(0, Math.min(100, Math.round((dbm + 110) * 100 / 70)))
    }

    function _item(key, name, st, text, pct, primary, details, note) {
        return { key: key, name: name, state: st, text: text, pct: pct, primary: primary,
                 color: stateColor(st), details: details, note: note }
    }

    function _detail(k, v, st) {
        return { k: k, v: v, color: st ? stateColor(st) : "#ECEDEE" }
    }

    // ---- RF telemetry -------------------------------------------------------------------------
    property var    _rf:        _linkState("RF", _names, _statuses, _primary)
    property real   _lrssi:     vehicle ? vehicle.radioStatus.lrssi.rawValue : 0
    property real   _rrssi:     vehicle ? vehicle.radioStatus.rrssi.rawValue : 0
    property real   _rxErrors:  vehicle ? vehicle.radioStatus.rxErrors.rawValue : 0

    property var telemetry: {
        var note = qsTr("RF 텔레메트리 모뎀의 신호 세기입니다 (기체가 RADIO_STATUS를 보낼 때 표시).")
        if (!vehicle || !_rf.found) {
            return _item("tel", qsTr("텔레메트리"), "off", qsTr("사용 안 함"), -1, false, [], note)
        }
        if (_rf.lost) {
            return _item("tel", qsTr("텔레메트리"), "lost", qsTr("끊김"), 0, _rf.primary,
                         [_detail(qsTr("상태"), qsTr("수신 없음"), "lost")], note)
        }
        var lp = _dbmPercent(_lrssi)
        var rp = _dbmPercent(_rrssi)
        var p = (lp < 0) ? rp : ((rp < 0) ? lp : Math.min(lp, rp))
        var st = (p >= 0 && p < 40) ? "weak" : "ok"
        return _item("tel", qsTr("텔레메트리"), st, st === "weak" ? qsTr("약함") : qsTr("정상"), p < 0 ? 100 : p, _rf.primary, [
            _detail(qsTr("신호 (GCS / 기체)"), lp < 0 ? "—" : (lp + "% / " + (rp < 0 ? "—" : rp + "%")), st === "weak" ? "weak" : ""),
            _detail(qsTr("RSSI (dBm)"), _lrssi === 0 ? "—" : (_lrssi + " / " + _rrssi)),
            _detail(qsTr("수신 오류"), String(_rxErrors)),
            _detail(qsTr("명령 경로"), _rf.primary ? qsTr("주 링크") : qsTr("보조"))
        ], note)
    }

    // ---- RC transmitter -----------------------------------------------------------------------
    property int    _rcRssi:    vehicle ? vehicle.rcRSSI.rawValue : 255
    property int    _present:   vehicle ? vehicle.sensorsPresentBits : 0
    property int    _health:    vehicle ? vehicle.sensorsHealthBits : 0

    property var rc: {
        var note = qsTr("FC 수신기 기준입니다. 신호가 끊기면 FC의 RC 페일세이프 설정에 따라 동작합니다 (기체 설정 → 안전).")
        if (!vehicle || commLost) {
            return _item("rc", qsTr("RC 조종기"), "off", qsTr("알 수 없음"), -1, false, [], note)
        }
        var rcPresent = (_present & _rcReceiverBit) !== 0
        var rcHealthy = (_health & _rcReceiverBit) !== 0
        var p = (_rcRssi >= 0 && _rcRssi <= 100) ? _rcRssi : -1
        // FC has never seen an RC receiver signal (no transmitter): not "normal"
        if (!rcPresent) {
            return _item("rc", qsTr("RC 조종기"), "off", qsTr("미연결"), 0, false, [
                _detail(qsTr("신호 (RSSI)"), "—"),
                _detail(qsTr("상태"), qsTr("FC가 조종기 신호를 받은 적 없음"))
            ], note)
        }
        if (!rcHealthy || p === 0) {
            return _item("rc", qsTr("RC 조종기"), "lost", qsTr("끊김"), 0, false, [
                _detail(qsTr("신호 (RSSI)"), "—", "lost"),
                _detail(qsTr("페일세이프"), qsTr("동작 중"), "lost")
            ], note)
        }
        var st = (p >= 0 && p < 40) ? "weak" : "ok"
        return _item("rc", qsTr("RC 조종기"), st, st === "weak" ? qsTr("약함") : qsTr("정상"), p < 0 ? 100 : p, false, [
            _detail(qsTr("신호 (RSSI)"), p < 0 ? "—" : p + "%", st === "weak" ? "weak" : ""),
            _detail(qsTr("페일세이프"), qsTr("대기"))
        ], note)
    }

    // ---- LTE ----------------------------------------------------------------------------------
    property var    _lte:       _linkState("LTE", _names, _statuses, _primary)
    property real   _loss:      vehicle ? vehicle.mavlinkLossPercent : 0

    property var lte: {
        var note = qsTr("LTE(서버 경유) 링크입니다. 텔레메트리와 함께 연결하면 한쪽이 끊겨도 다른 쪽으로 관제가 이어집니다.")
        if (!vehicle || !_lte.found) {
            return _item("lte", "LTE", "off", qsTr("사용 안 함"), -1, false, [], note)
        }
        if (_lte.lost) {
            return _item("lte", "LTE", "lost", qsTr("끊김"), 0, _lte.primary,
                         [_detail(qsTr("상태"), qsTr("수신 없음"), "lost")], note)
        }
        var usingIt = _lte.primary || !_rf.found
        var st = (usingIt && _loss > 5) ? "weak" : "ok"
        return _item("lte", "LTE", st, st === "weak" ? qsTr("약함") : qsTr("정상"), st === "weak" ? 35 : 100, _lte.primary, [
            _detail(qsTr("패킷 손실"), usingIt ? _loss.toFixed(1) + "%" : "—", st === "weak" ? "weak" : ""),
            _detail(qsTr("명령 경로"), _lte.primary ? qsTr("주 링크") : (usingIt ? qsTr("단독") : qsTr("보조")))
        ], note)
    }

    // ---- GPS ----------------------------------------------------------------------------------
    property int    _gpsLock:   vehicle ? vehicle.gps.lock.rawValue : 0
    property int    _gpsCount:  vehicle ? vehicle.gps.count.rawValue : 0
    property real   _gpsHdop:   vehicle ? vehicle.gps.hdop.rawValue : NaN

    function _lockText(lock) {
        switch (lock) {
        case 2: return qsTr("2D 고정")
        case 3: return qsTr("3D 고정")
        case 4: return "DGPS"
        case 5: return "RTK Float"
        case 6: return "RTK Fix"
        case 7: return qsTr("고정 위치")
        default: return qsTr("고정 없음")
        }
    }

    property var gps: {
        var note = qsTr("위성 10개 미만이거나 HDOP 1.5를 넘으면 노란색, 위치 고정이 없으면 빨간색입니다.")
        if (!vehicle || commLost) {
            return _item("gps", "GPS", "off", qsTr("알 수 없음"), -1, false, [], note)
        }
        var hdopText = isNaN(_gpsHdop) ? "—" : _gpsHdop.toFixed(1)
        var st = _gpsLock < 2 ? "lost" : ((_gpsLock === 2 || _gpsCount < 10 || (!isNaN(_gpsHdop) && _gpsHdop > 1.5)) ? "weak" : "ok")
        return _item("gps", "GPS", st, _lockText(_gpsLock) + " · " + _gpsCount + qsTr("개"), Math.min(100, _gpsCount * 5), false, [
            _detail(qsTr("고정 상태"), _lockText(_gpsLock), st === "lost" ? "lost" : ""),
            _detail(qsTr("위성 수"), _gpsCount + qsTr("개"), _gpsCount < 10 ? "weak" : ""),
            _detail("HDOP", hdopText, (!isNaN(_gpsHdop) && _gpsHdop > 1.5) ? "weak" : ""),
            _detail(qsTr("RTK 보정"), _gpsLock >= 5 && _gpsLock <= 6 ? qsTr("수신 중") : qsTr("없음"))
        ], note)
    }

    // ---- Battery ------------------------------------------------------------------------------
    property var    _battery:   vehicle && vehicle.batteries.count > 0 ? vehicle.batteries.get(0) : null
    property real   _batPct:    _battery ? _battery.percentRemaining.rawValue : NaN
    property real   _batVolt:   _battery ? _battery.voltage.rawValue : NaN
    property string _batTime:   _battery ? _battery.timeRemainingStr.valueString : ""
    // User-set pack voltage range (battery details popup). Both set -> % from voltage.
    property real   batMaxVolt: (typeof globals !== "undefined" && globals) ? globals.aeroBatteryMaxVolt : 0
    property real   batMinVolt: (typeof globals !== "undefined" && globals) ? globals.aeroBatteryMinVolt : 0
    readonly property bool batVoltRangeSet: batMaxVolt > 0 && batMinVolt > 0 && batMaxVolt > batMinVolt
    property real   _batVoltPct: (batVoltRangeSet && !isNaN(_batVolt) && _batVolt > 0)
                                 ? Math.max(0, Math.min(100, (_batVolt - batMinVolt) / (batMaxVolt - batMinVolt) * 100))
                                 : NaN

    property var battery: {
        var note = qsTr("30% 이하면 노란색, 15% 이하면 빨간색입니다. 실제 복귀 시점은 FC의 배터리 페일세이프 설정을 따릅니다.")
        if (!vehicle || commLost || !_battery) {
            return _item("bat", qsTr("배터리"), "off", qsTr("알 수 없음"), -1, false, [], note)
        }
        var fcHasPct = !isNaN(_batPct) && _batPct >= 0
        var useVolt = !isNaN(_batVoltPct)
        var pct = useVolt ? _batVoltPct : (fcHasPct ? _batPct : NaN)
        var hasPct = !isNaN(pct)
        var voltText = isNaN(_batVolt) ? "—" : _batVolt.toFixed(1) + "V"
        var st = !hasPct ? "ok" : (pct <= 15 ? "lost" : (pct <= 30 ? "weak" : "ok"))
        var chipText = hasPct ? (Math.round(pct) + "% · " + voltText) : voltText
        return _item("bat", qsTr("배터리"), st, chipText, hasPct ? pct : 100, false, [
            _detail(useVolt ? qsTr("잔량 (전압 기준)") : qsTr("잔량 (FC)"), hasPct ? Math.round(pct) + "%" : "—", st === "ok" ? "" : st),
            _detail(qsTr("전압"), voltText),
            _detail(qsTr("FC 잔량"), fcHasPct ? Math.round(_batPct) + "%" : "—"),
            _detail(qsTr("남은 비행"), _batTime === "" ? "—" : _batTime)
        ], note)
    }


    // ---- Vibration (VIBRATION) ----------------------------------------------------------------
    property var    _vib:       vehicle ? vehicle.vibration : null
    property real   _vibX:      _vib ? _vib.xAxis.rawValue : NaN
    property real   _vibY:      _vib ? _vib.yAxis.rawValue : NaN
    property real   _vibZ:      _vib ? _vib.zAxis.rawValue : NaN
    property int    _clip1:     _vib ? _vib.clipCount1.rawValue : 0
    property int    _clip2:     _vib ? _vib.clipCount2.rawValue : 0
    property int    _clip3:     _vib ? _vib.clipCount3.rawValue : 0

    function _vibState(v) {
        return isNaN(v) ? "off" : (v >= 60 ? "lost" : (v >= 30 ? "weak" : "ok"))
    }
    function _worst(states) {
        if (states.indexOf("lost") >= 0) { return "lost" }
        if (states.indexOf("weak") >= 0) { return "weak" }
        if (states.indexOf("ok") >= 0) { return "ok" }
        return "off"
    }
    function _stateWord(st) {
        return st === "ok" ? qsTr("정상") : (st === "weak" ? qsTr("주의") : (st === "lost" ? qsTr("위험") : "—"))
    }

    property var vibration: {
        var axes = [[ "X", _vibX ], [ "Y", _vibY ], [ "Z", _vibZ ]].map(function(a) {
            var st = _vibState(a[1])
            return { n: a[0], v: isNaN(a[1]) ? "—" : a[1].toFixed(1), frac: isNaN(a[1]) ? 0 : Math.min(1, a[1] / 90), state: st, color: stateColor(st) }
        })
        var clipStates = (_clip1 + _clip2 + _clip3) > 0 ? ["weak"] : []
        var st = (!vehicle || commLost) ? "off" : _worst(axes.map(function(a) { return a.state }).concat(clipStates))
        return { state: st, word: _stateWord(st), color: stateColor(st), axes: axes,
                 clips: [_clip1, _clip2, _clip3].map(function(c, i) { return { n: qsTr("가속도계 %1").arg(i + 1), v: String(c), color: c > 0 ? colorWeak : "#ECEDEE" } }) }
    }

    // ---- EKF (ArduPilot EKF_STATUS_REPORT) ----------------------------------------------------
    property var    _ekfGroup:  vehicle ? vehicle.ekfStatus : null
    property real   _ekfVel:    _ekfGroup ? _ekfGroup.velocityVariance.rawValue : NaN
    property real   _ekfPosH:   _ekfGroup ? _ekfGroup.posHorizVariance.rawValue : NaN
    property real   _ekfPosV:   _ekfGroup ? _ekfGroup.posVertVariance.rawValue : NaN
    property real   _ekfMag:    _ekfGroup ? _ekfGroup.compassVariance.rawValue : NaN
    property real   _ekfTerr:   _ekfGroup ? _ekfGroup.terrainAltVariance.rawValue : NaN
    property int    _ekfFlags:  _ekfGroup ? _ekfGroup.flags.rawValue : 0
    property bool   _ekfSeen:   !isNaN(_ekfVel)

    function _ekfVarState(v) {
        return isNaN(v) ? "off" : (v >= 0.8 ? "lost" : (v >= 0.5 ? "weak" : "ok"))
    }

    // [bit, label, setIsBad, counts toward the summary when wrong]
    readonly property var _ekfFlagDefs: [
        [1,     qsTr("자세"),            false, true],
        [2,     qsTr("수평 속도"),       false, true],
        [4,     qsTr("수직 속도"),       false, true],
        [8,     qsTr("수평 상대 위치"),  false, false],
        [16,    qsTr("수평 절대 위치"),  false, true],
        [32,    qsTr("수직 절대 위치"),  false, true],
        [64,    qsTr("지면 고도"),       false, false],
        [256,   qsTr("예측 수평 상대"),  false, false],
        [512,   qsTr("예측 수평 절대"),  false, false],
        [128,   qsTr("고정 위치 모드"),  true,  true],
        [32768, qsTr("GPS 글리치"),      true,  true],
        [1024,  qsTr("미초기화"),        true,  true]
    ]

    property var ekfFlags: _ekfFlagDefs.map(function(d) {
        var set = (_ekfFlags & d[0]) !== 0
        var wrong = _ekfSeen && (d[2] ? set : !set)
        var important = d[3]
        return { n: d[1], mark: !_ekfSeen ? "" : (wrong ? "!" : (d[2] ? "" : "✓")), bad: wrong && important,
                 box: !_ekfSeen ? "#33383D" : (wrong ? (important ? colorWeak : "#5A6066") : (d[2] ? "#33383D" : colorOk)),
                 color: wrong && important ? "#FFC861" : (d[2] || !set ? "#9BA1A6" : "#ECEDEE") }
    })
    property int ekfFlagProblems: ekfFlags.filter(function(f) { return f.bad }).length

    property var ekf: {
        var rows = [[ qsTr("속도"), _ekfVel ], [ qsTr("수평 위치"), _ekfPosH ], [ qsTr("수직 위치"), _ekfPosV ],
                    [ qsTr("나침반"), _ekfMag ], [ qsTr("지형"), _ekfTerr ]].map(function(r) {
            var st = _ekfVarState(r[1])
            return { n: r[0], v: isNaN(r[1]) ? "—" : r[1].toFixed(2), frac: isNaN(r[1]) ? 0 : Math.min(1, r[1]), state: st, color: stateColor(st) }
        })
        var st = (!vehicle || commLost || !_ekfSeen) ? "off"
                 : _worst(rows.slice(0, 4).map(function(r) { return r.state }).concat(ekfFlagProblems > 0 ? ["weak"] : []))
        return { state: st, word: _ekfSeen ? _stateWord(st) : qsTr("수신 없음"), color: stateColor(st), rows: rows }
    }

    // ---- Sensors (SYS_STATUS) -----------------------------------------------------------------
    property int    _enabled:   vehicle ? vehicle.sensorsEnabledBits : 0

    readonly property var _sensorDefs: [
        [1,         qsTr("자이로")],    [2,         qsTr("가속도계")],
        [4,         qsTr("나침반")],    [8,         qsTr("기압계")],
        [32,        "GPS"],             [2097152,   "AHRS"],
        [65536,     qsTr("RC 수신기")], [32768,     qsTr("모터 출력")],
        [33554432,  qsTr("배터리")],    [16777216,  qsTr("로깅")],
        [256,       qsTr("거리 센서")], [64,        qsTr("광류 센서")],
        [1048576,   qsTr("지오펜스")],  [268435456, qsTr("사전 점검")]
    ]

    property var sensors: _sensorDefs.map(function(d) {
        var present = (_present & d[0]) !== 0
        var enabled = (_enabled & d[0]) !== 0
        var healthy = (_health & d[0]) !== 0
        var st = !vehicle || commLost || !present ? "none" : (!enabled ? "disabled" : (healthy ? "ok" : "bad"))
        return { n: d[1], state: st,
                 s: st === "ok" ? qsTr("정상") : (st === "bad" ? qsTr("이상") : (st === "disabled" ? qsTr("꺼짐") : qsTr("없음"))),
                 dot: st === "ok" ? colorOk : (st === "bad" ? "#FF4D4D" : "#5A6066"),
                 color: st === "ok" ? "#7BEAB0" : (st === "bad" ? "#FF8A8A" : "#9BA1A6") }
    })
    property int sensorProblems: sensors.filter(function(z) { return z.state === "bad" }).length

    property var health: {
        var st = _worst([vibration.state, ekf.state])
        return { state: st, color: stateColor(st), vibWord: vibration.word, vibColor: vibration.color,
                 ekfWord: ekf.word, ekfColor: ekf.color, detailProblems: ekfFlagProblems + sensorProblems }
    }

    property var items: [telemetry, rc, lte, gps, battery]

    // ---- Highest-priority alert ---------------------------------------------------------------
    property var alert: {
        if (!vehicle) {
            return null
        }
        if (commLost) {
            return { key: "comm", level: "lost", title: qsTr("모든 통신 끊김"),
                     sub: qsTr("기체는 GCS 페일세이프 설정에 따라 동작합니다 · 지도에 마지막 위치를 표시 중") }
        }
        if (rc.state === "lost") {
            return { key: "rc", level: "lost", title: qsTr("RC 조종기 신호 끊김"),
                     sub: qsTr("FC의 RC 페일세이프 설정에 따라 기체가 동작합니다 · 텔레메트리/LTE로 관제는 계속됩니다") }
        }
        if (battery.state === "lost") {
            return { key: "batLost", level: "lost", title: qsTr("배터리 위험 · %1").arg(battery.text),
                     sub: qsTr("배터리 페일세이프가 동작할 수 있습니다 · 바로 복귀하거나 착륙하세요") }
        }
        if (vibration.state === "lost") {
            return { key: "vibLost", level: "lost", title: qsTr("진동 위험 · X %1 / Y %2 / Z %3 m/s²").arg(vibration.axes[0].v).arg(vibration.axes[1].v).arg(vibration.axes[2].v),
                     sub: qsTr("고도·위치 유지가 불안정할 수 있습니다 · 착륙 후 프롭 밸런스와 방진 마운트를 점검하세요") }
        }
        if (ekf.state === "lost") {
            return { key: "ekfLost", level: "lost", title: qsTr("EKF 위험 · 위치/자세 추정 불안정"),
                     sub: qsTr("자동 비행을 멈추고 수동(AltHold/Loiter) 대기 · 진동·EKF 창에서 원인 확인") }
        }
        if (telemetry.state === "lost" && lte.state !== "lost" && lte.state !== "off") {
            return { key: "telLost", level: "weak", title: qsTr("텔레메트리 끊김 → LTE로 계속 관제"),
                     sub: qsTr("텔레메트리가 돌아오면 다시 사용합니다") }
        }
        if (lte.state === "lost" && telemetry.state !== "lost" && telemetry.state !== "off") {
            return { key: "lteLost", level: "weak", title: qsTr("LTE 끊김 → 텔레메트리로 계속 관제"),
                     sub: qsTr("LTE가 돌아오면 다시 사용합니다 · 영상이 끊길 수 있습니다") }
        }
        if (battery.state === "weak") {
            return { key: "batWeak", level: "weak", title: qsTr("배터리 부족 · %1").arg(battery.text),
                     sub: qsTr("남은 비행 %1 · 복귀를 준비하세요").arg(_batTime === "" ? "—" : _batTime) }
        }
        if (ekf.state === "weak") {
            return { key: "ekfWeak", level: "weak", title: qsTr("EKF 주의"),
                     sub: qsTr("자동 비행 전 나침반 보정과 주변 자기 간섭, GPS 상태를 확인하세요") }
        }
        if (vibration.state === "weak") {
            return { key: "vibWeak", level: "weak", title: qsTr("진동 주의 · 최대 %1 m/s²").arg(Math.max(_vibX || 0, _vibY || 0, _vibZ || 0).toFixed(0)),
                     sub: qsTr("비행은 가능하지만 진동이 큽니다 · 비행 후 점검을 권장합니다") }
        }
        if (gps.state === "lost" || gps.state === "weak") {
            return { key: "gps", level: "weak", title: qsTr("GPS 약함 · 위성 %1개, HDOP %2").arg(_gpsCount).arg(isNaN(_gpsHdop) ? "—" : _gpsHdop.toFixed(1)),
                     sub: qsTr("위치 정확도가 낮습니다 · 이륙·자동 비행 전 위성이 늘어날 때까지 기다리세요") }
        }
        return null
    }
}
