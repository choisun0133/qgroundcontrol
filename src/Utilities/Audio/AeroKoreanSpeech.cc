#include "AeroKoreanSpeech.h"

#include <QtCore/QHash>
#include <QtCore/QRegularExpression>

namespace {

struct Clip {
    const char *id;
    const char *sentence;   // UTF-8
};

// Recording script order. Clip ids are file names in the voice pack (<id>.wav).
const Clip kClips[] = {
    // Arming
    { "armed",                  "시동 걸림" },
    { "disarmed",               "시동 꺼짐" },
    { "prearm_failed",          "시동 전 점검 실패" },
    { "arm_failed",             "시동 점검 실패" },
    // Flight modes
    { "mode_stabilize",         "안정 모드" },
    { "mode_althold",           "고도 유지 모드" },
    { "mode_loiter",            "로이터 모드" },
    { "mode_poshold",           "위치 유지 모드" },
    { "mode_brake",             "정지 모드" },
    { "mode_hold",              "정지 비행 모드" },
    { "mode_auto",              "자동 비행 모드" },
    { "mode_mission",           "미션 모드" },
    { "mode_guided",            "가이드 모드" },
    { "mode_rtl",               "귀환 모드" },
    { "mode_smartrtl",          "스마트 귀환 모드" },
    { "mode_land",              "착륙 모드" },
    { "mode_takeoff",           "이륙 모드" },
    { "mode_circle",            "선회 모드" },
    { "mode_manual",            "수동 모드" },
    { "mode_acro",              "아크로 모드" },
    { "mode_position",          "위치 모드" },
    { "mode_altitude",          "고도 모드" },
    { "mode_offboard",          "오프보드 모드" },
    { "mode_precland",          "정밀 착륙 모드" },
    { "mode_follow",            "따라가기 모드" },
    { "mode_qloiter",           "큐 로이터 모드" },
    { "mode_qhover",            "큐 호버 모드" },
    { "mode_qland",             "큐 착륙 모드" },
    { "mode_qrtl",              "큐 귀환 모드" },
    { "mode_cruise",            "크루즈 모드" },
    { "mode_fbwa",              "에프비더블유에이 모드" },
    // Warnings
    { "warning",                "경고" },
    { "battery_low",            "배터리 부족" },
    { "battery_critical",       "배터리 위험" },
    { "battery_emergency",      "배터리 비상" },
    { "battery_failed",         "배터리 고장" },
    { "battery_unhealthy",      "배터리 이상" },
    { "comm_lost",              "통신 끊김" },
    { "comm_regained",          "통신 복구" },
    { "comm_primary_lost",      "주 통신 끊김" },
    { "comm_secondary_lost",    "보조 통신 끊김" },
    { "comm_switch_secondary",  "보조 통신으로 전환" },
    { "comm_switch_primary",    "주 통신 링크 변경" },
    { "fence_breached",         "지오펜스 이탈" },
    { "fence_alt_min",          "최저 고도 지오펜스 이탈" },
    { "fence_alt_max",          "최고 고도 지오펜스 이탈" },
    { "fence_boundary",         "경계 지오펜스 이탈" },
    { "rc_failsafe",            "조종기 신호 끊김" },
    { "gcs_failsafe",           "지상국 통신 끊김" },
    { "ekf_warning",            "이 케이 에프 이상" },
    { "gps_glitch",             "지피에스 오류" },
    { "vibration",              "진동 과다" },
    { "crash",                  "추락 감지" },
    { "takeoff_complete",       "이륙 완료" },
    { "land_complete",          "착륙 완료" },
    { "mission_complete",       "미션 완료" },
    // Downward lidar (AeroInstrumentPanel)
    { "ground_5m",              "지면 5미터" },
    { "ground_2m",              "지면 2미터" },
    { "ground_1m",              "지면 1미터" },
    // Test
    { "test",                   "음성 안내 테스트입니다" },
};

QString sentenceFor(const QString &clipId)
{
    for (const Clip &c : kClips) {
        if (clipId == QLatin1String(c.id)) {
            return QString::fromUtf8(c.sentence);
        }
    }
    return QString();
}

AeroKoreanSpeech::Phrase clip(const char *id)
{
    const QString clipId = QString::fromLatin1(id);
    return { sentenceFor(clipId), clipId };
}

// Flight mode name (lower case, as announced by the firmware plugins) -> clip id
const QHash<QString, QString> &modeClips()
{
    static const QHash<QString, QString> map = {
        { QStringLiteral("stabilize"),          QStringLiteral("mode_stabilize") },
        { QStringLiteral("stabilized"),         QStringLiteral("mode_stabilize") },
        { QStringLiteral("alt hold"),           QStringLiteral("mode_althold") },
        { QStringLiteral("althold"),            QStringLiteral("mode_althold") },
        { QStringLiteral("altitude hold"),      QStringLiteral("mode_althold") },
        { QStringLiteral("loiter"),             QStringLiteral("mode_loiter") },
        { QStringLiteral("poshold"),            QStringLiteral("mode_poshold") },
        { QStringLiteral("position hold"),      QStringLiteral("mode_poshold") },
        { QStringLiteral("brake"),              QStringLiteral("mode_brake") },
        { QStringLiteral("hold"),               QStringLiteral("mode_hold") },
        { QStringLiteral("auto"),               QStringLiteral("mode_auto") },
        { QStringLiteral("mission"),            QStringLiteral("mode_mission") },
        { QStringLiteral("guided"),             QStringLiteral("mode_guided") },
        { QStringLiteral("rtl"),                QStringLiteral("mode_rtl") },
        { QStringLiteral("return"),             QStringLiteral("mode_rtl") },
        { QStringLiteral("return to launch"),   QStringLiteral("mode_rtl") },
        { QStringLiteral("smart rtl"),          QStringLiteral("mode_smartrtl") },
        { QStringLiteral("smartrtl"),           QStringLiteral("mode_smartrtl") },
        { QStringLiteral("land"),               QStringLiteral("mode_land") },
        { QStringLiteral("takeoff"),            QStringLiteral("mode_takeoff") },
        { QStringLiteral("circle"),             QStringLiteral("mode_circle") },
        { QStringLiteral("manual"),             QStringLiteral("mode_manual") },
        { QStringLiteral("acro"),               QStringLiteral("mode_acro") },
        { QStringLiteral("position"),           QStringLiteral("mode_position") },
        { QStringLiteral("altitude"),           QStringLiteral("mode_altitude") },
        { QStringLiteral("offboard"),           QStringLiteral("mode_offboard") },
        { QStringLiteral("precision land"),     QStringLiteral("mode_precland") },
        { QStringLiteral("follow"),             QStringLiteral("mode_follow") },
        { QStringLiteral("follow me"),          QStringLiteral("mode_follow") },
        { QStringLiteral("qloiter"),            QStringLiteral("mode_qloiter") },
        { QStringLiteral("qhover"),             QStringLiteral("mode_qhover") },
        { QStringLiteral("qland"),              QStringLiteral("mode_qland") },
        { QStringLiteral("qrtl"),               QStringLiteral("mode_qrtl") },
        { QStringLiteral("cruise"),             QStringLiteral("mode_cruise") },
        { QStringLiteral("fbwa"),               QStringLiteral("mode_fbwa") },
    };
    return map;
}

AeroKoreanSpeech::Phrase translateBody(const QString &body)
{
    using AeroKoreanSpeech::Phrase;
    const QString t = body.trimmed().toLower();
    if (t.isEmpty()) {
        return {};
    }

    // Exact phrases (English source or QGC's Korean translation)
    if (t == QLatin1String("armed") || t == QStringLiteral("시동됨")) return clip("armed");
    if (t == QLatin1String("disarmed") || t == QStringLiteral("시동 꺼짐")) return clip("disarmed");
    if (t == QLatin1String("warning") || t == QStringLiteral("경고")) return clip("warning");

    // "<mode> flight mode" / "<mode> 비행모드"
    static const QRegularExpression modeRe(QStringLiteral("^(.+?)\\s*(flight mode|비행\\s*모드)$"));
    const QRegularExpressionMatch modeMatch = modeRe.match(t);
    if (modeMatch.hasMatch()) {
        const QString mode = modeMatch.captured(1).trimmed();
        const auto it = modeClips().constFind(mode);
        if (it != modeClips().constEnd()) {
            return { sentenceFor(it.value()), it.value() };
        }
        return { mode + QStringLiteral(" 모드"), QString() };
    }

    // Battery: "battery 1 level low", "battery level is critical", "battery failed" ...
    if (t.startsWith(QLatin1String("battery"))) {
        if (t.contains(QLatin1String("emergency"))) return clip("battery_emergency");
        if (t.contains(QLatin1String("critical"))) return clip("battery_critical");
        if (t.contains(QLatin1String("failed"))) return clip("battery_failed");
        if (t.contains(QLatin1String("unhealthy"))) return clip("battery_unhealthy");
        if (t.contains(QLatin1String("low"))) return clip("battery_low");
    }

    // Links
    if (t.startsWith(QLatin1String("communication lost on primary"))) return clip("comm_primary_lost");
    if (t.startsWith(QLatin1String("communication lost on secondary"))) return clip("comm_secondary_lost");
    if (t.startsWith(QLatin1String("communication lost")) || t.startsWith(QStringLiteral("통신이 끊겼습니다"))) return clip("comm_lost");
    if (t.startsWith(QLatin1String("communication regained"))) return clip("comm_regained");
    if (t.startsWith(QLatin1String("switching communication to secondary"))) return clip("comm_switch_secondary");
    if (t.startsWith(QLatin1String("switching communication to new primary"))) return clip("comm_switch_primary");

    // Fence: "<type> fence breached"
    if (t.endsWith(QLatin1String("fence breached")) || t.endsWith(QStringLiteral("펜스 이탈"))) {
        if (t.startsWith(QLatin1String("minimum altitude"))) return clip("fence_alt_min");
        if (t.startsWith(QLatin1String("maximum altitude"))) return clip("fence_alt_max");
        if (t.startsWith(QLatin1String("boundary"))) return clip("fence_boundary");
        return clip("fence_breached");
    }

    // Common flight controller status texts (ArduPilot / PX4). The full text stays in the message
    // window; the voice only says what kind of problem it is.
    if (t.startsWith(QLatin1String("prearm")) || t.startsWith(QLatin1String("preflight fail"))) return clip("prearm_failed");
    if (t.startsWith(QLatin1String("arm:")) || t.startsWith(QLatin1String("arming denied")) || t.startsWith(QLatin1String("arming failed"))) return clip("arm_failed");
    if (t.contains(QLatin1String("crash"))) return clip("crash");
    if (t.contains(QLatin1String("radio failsafe")) || t.contains(QLatin1String("rc failsafe")) || t.contains(QLatin1String("manual control lost"))) return clip("rc_failsafe");
    if (t.contains(QLatin1String("gcs failsafe")) || t.contains(QLatin1String("data link lost"))) return clip("gcs_failsafe");
    if (t.contains(QLatin1String("ekf variance")) || t.contains(QLatin1String("ekf failsafe")) || t.contains(QLatin1String("ekf primary changed"))) return clip("ekf_warning");
    if (t.contains(QLatin1String("gps glitch"))) return clip("gps_glitch");
    if (t.contains(QLatin1String("vibration"))) return clip("vibration");
    if (t.contains(QLatin1String("battery")) && (t.contains(QLatin1String("low")) || t.contains(QLatin1String("failsafe")))) return clip("battery_low");
    if (t.contains(QLatin1String("takeoff complete")) || t.contains(QLatin1String("takeoff detected"))) return clip("takeoff_complete");
    if (t.contains(QLatin1String("land complete")) || t.contains(QLatin1String("landing detected")) || t == QLatin1String("landed")) return clip("land_complete");
    if (t.contains(QLatin1String("mission complete")) || t.contains(QLatin1String("mission finished"))) return clip("mission_complete");

    return {};
}

} // namespace

AeroKoreanSpeech::Phrase AeroKoreanSpeech::translate(const QString &text)
{
    // Multi-vehicle prefix from Vehicle::_vehicleIdSpeech(): "vehicle 2 " (or translated "기체 2 ")
    static const QRegularExpression vehicleRe(QStringLiteral("^\\s*(?:vehicle|기체)\\s+(\\d+)\\s*(.*)$"),
                                              QRegularExpression::CaseInsensitiveOption);
    const QRegularExpressionMatch m = vehicleRe.match(text);
    if (m.hasMatch()) {
        const Phrase body = translateBody(m.captured(2));
        if (body.text.isEmpty()) {
            return {};
        }
        return { QStringLiteral("기체 %1 %2").arg(m.captured(1), body.text), QString() };
    }
    return translateBody(text);
}

QStringList AeroKoreanSpeech::allClips()
{
    QStringList list;
    for (const Clip &c : kClips) {
        list.append(QString::fromLatin1(c.id) + QLatin1Char('|') + QString::fromUtf8(c.sentence));
    }
    return list;
}
