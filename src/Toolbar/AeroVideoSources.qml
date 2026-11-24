import QtCore
import QtQuick

import QGroundControl

// AeroResearch: saved video sources, so switching cameras doesn't mean retyping the RTSP URL.
// Each entry is either a device key, appended to the shared base URL (relay servers that pick the
// camera with "...?DeviceKey="), or a complete rtsp:// URL. An entry can be tied to a saved
// connection; when a vehicle comes in over that connection its video is selected automatically.
// Everything is stored on this PC only (the URLs carry camera passwords).
QtObject {
    id: control

    property alias baseUrl:     saved.baseUrl
    property alias selected:    saved.selected
    property var   entries:     []          // [{ name, value, link }]

    // The entry that is actually playing, read back from the video settings: stays right when the
    // URL is changed elsewhere (영상 설정 page) or a pick did not take. "" when none matches.
    readonly property string activeName: {
        var vs = QGroundControl.settingsManager.videoSettings
        if (vs.videoSource.rawValue !== vs.rtspVideoSource) {
            return ""
        }
        var current = clean(vs.rtspUrl.rawValue)
        var match = ""
        for (var i = 0; i < entries.length; i++) {
            if (urlFor(entries[i]) === current) {
                if (entries[i].name === selected) {
                    return selected
                }
                if (match === "") {
                    match = entries[i].name
                }
            }
        }
        return match
    }

    readonly property var _vehicle:     QGroundControl.multiVehicleManager.activeVehicle
    readonly property string _linkName: _vehicle && _vehicle.vehicleLinkManager ? _vehicle.vehicleLinkManager.primaryLinkName : ""

    signal applyFailed(string reason)

    function isFullUrl(value) {
        return /^[a-z][a-z0-9+.-]*:\/\//i.test(value)
    }

    function clean(text) {
        return String(text || "").replace(/[\r\n\t]/g, "").trim()
    }

    // Empty string when the entry can't make a URL (a key without a base URL)
    function urlFor(entry) {
        if (!entry) {
            return ""
        }
        var value = clean(entry.value)
        if (value === "") {
            return ""
        }
        if (isFullUrl(value)) {
            return value
        }
        var base = clean(baseUrl)
        return base === "" ? "" : base + value
    }

    function indexOfName(name) {
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].name === name) {
                return i
            }
        }
        return -1
    }

    // Replaces the whole list (from the editor). Blank rows are dropped, names made unique.
    // A row flagged `wasSelected` keeps the selection under its (possibly new) name.
    function setEntries(list) {
        var out = []
        var used = {}
        var newSelected = ""
        for (var i = 0; i < list.length; i++) {
            var name = clean(list[i].name)
            var value = clean(list[i].value)
            if (value === "") {
                continue
            }
            if (name === "") {
                name = qsTr("영상 %1").arg(out.length + 1)
            }
            var unique = name
            for (var n = 2; used[unique]; n++) {
                unique = name + " " + n
            }
            used[unique] = true
            out.push({ name: unique, value: value, link: clean(list[i].link) })
            if (list[i].wasSelected) {
                newSelected = unique
            }
        }
        entries = out
        saved.entriesJson = JSON.stringify(out)
        selected = newSelected !== "" ? newSelected : (indexOfName(selected) >= 0 ? selected : "")
    }

    function apply(name) {
        var index = indexOfName(name)
        if (index < 0) {
            return false
        }
        var url = urlFor(entries[index])
        if (url === "") {
            applyFailed(qsTr("기본 주소가 비어 있어 디바이스 키만으로는 주소를 만들 수 없습니다"))
            return false
        }
        if (!/^rtsps?:\/\//i.test(url)) {
            applyFailed(qsTr("rtsp:// 로 시작하는 주소만 쓸 수 있습니다"))
            return false
        }
        // A vehicle that announces its own stream (MAVLink VIDEO_STREAM_INFORMATION) overrides the
        // RTSP URL right away, so a pick would show one camera's name over another's video.
        if (QGroundControl.videoManager.autoStreamConfigured) {
            applyFailed(qsTr("기체가 영상 주소를 직접 보내고 있어 저장된 영상으로 바꿀 수 없습니다"))
            return false
        }
        var vs = QGroundControl.settingsManager.videoSettings
        if (vs.videoSource.rawValue !== vs.rtspVideoSource) {
            vs.videoSource.rawValue = vs.rtspVideoSource
        }
        if (vs.rtspUrl.rawValue !== url) {
            vs.rtspUrl.rawValue = url
        }
        if (vs.rtspUrl.rawValue !== url) {
            applyFailed(qsTr("영상 주소를 바꾸지 못했습니다"))
            return false
        }
        selected = name
        return true
    }

    function entryForLink(linkName) {
        if (linkName === "") {
            return ""
        }
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].link !== "" && entries[i].link === linkName) {
                return entries[i].name
            }
        }
        return ""
    }

    on_LinkNameChanged: {
        var name = entryForLink(_linkName)
        if (name !== "") {
            apply(name)
        }
    }

    // First run: a stored ".../...?DeviceKey=xxxx" URL becomes the base URL plus a first entry
    function _importCurrentUrl() {
        var current = clean(QGroundControl.settingsManager.videoSettings.rtspUrl.rawValue)
        if (current === "") {
            return
        }
        var match = /^(.*[?&]DeviceKey=)([^&]+)$/i.exec(current)
        if (match) {
            baseUrl = match[1]
            setEntries([ { name: qsTr("기체 1"), value: match[2], link: "" } ])
        } else {
            setEntries([ { name: qsTr("기체 1"), value: current, link: "" } ])
        }
        selected = entries.length > 0 ? entries[0].name : ""
    }

    Component.onCompleted: {
        try {
            var list = JSON.parse(saved.entriesJson)
            entries = Array.isArray(list) ? list : []
        } catch (e) {
            entries = []
        }
        if (entries.length === 0 && clean(baseUrl) === "" && !saved.imported) {
            saved.imported = true
            _importCurrentUrl()
        }
    }

    property Settings _saved: Settings {
        id:         saved
        category:   "AeroVideoSources"
        property string baseUrl:        ""
        property string entriesJson:    "[]"
        property string selected:       ""
        property bool   imported:       false
    }
}
