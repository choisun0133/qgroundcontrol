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
        if (rcPresent && !rcHealthy) {
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
        return _item("gps", "GPS", st, _lockText(_gpsLock), Math.min(100, _gpsCount * 5), false, [
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

    property var battery: {
        var note = qsTr("30% 이하면 노란색, 15% 이하면 빨간색입니다. 실제 복귀 시점은 FC의 배터리 페일세이프 설정을 따릅니다.")
        if (!vehicle || commLost || !_battery) {
            return _item("bat", qsTr("배터리"), "off", qsTr("알 수 없음"), -1, false, [], note)
        }
        var hasPct = !isNaN(_batPct) && _batPct >= 0
        var voltText = isNaN(_batVolt) ? "—" : _batVolt.toFixed(1) + "V"
        var st = !hasPct ? "ok" : (_batPct <= 15 ? "lost" : (_batPct <= 30 ? "weak" : "ok"))
        return _item("bat", qsTr("배터리"), st, hasPct ? Math.round(_batPct) + "%" : voltText, hasPct ? _batPct : 100, false, [
            _detail(qsTr("잔량"), hasPct ? Math.round(_batPct) + "%" : "—", st === "ok" ? "" : st),
            _detail(qsTr("전압"), voltText),
            _detail(qsTr("남은 비행"), _batTime === "" ? "—" : _batTime)
        ], note)
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
        if (gps.state === "lost" || gps.state === "weak") {
            return { key: "gps", level: "weak", title: qsTr("GPS 약함 · 위성 %1개, HDOP %2").arg(_gpsCount).arg(isNaN(_gpsHdop) ? "—" : _gpsHdop.toFixed(1)),
                     sub: qsTr("위치 정확도가 낮습니다 · 이륙·자동 비행 전 위성이 늘어날 때까지 기다리세요") }
        }
        return null
    }
}
