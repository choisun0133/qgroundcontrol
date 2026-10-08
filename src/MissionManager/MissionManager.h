#pragma once

#include <QtCore/QElapsedTimer>
#include <QtQmlIntegration/QtQmlIntegration>

#include "PlanManager.h"

class Vehicle;

class MissionManager : public PlanManager
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("")

    /// true: the vehicle reports a different mission item count than the last mission this GCS synced
    /// (for example another GCS uploaded a new mission)
    Q_PROPERTY(bool vehicleMissionOutOfSync READ vehicleMissionOutOfSync NOTIFY vehicleMissionOutOfSyncChanged)
    /// Mission item count (excluding home) last reported by the vehicle in MISSION_CURRENT, -1 if unknown
    Q_PROPERTY(int vehicleMissionCount READ vehicleMissionCount NOTIFY vehicleMissionOutOfSyncChanged)

public:
    MissionManager(Vehicle* vehicle);
    ~MissionManager();

    /// Current mission item as reported by MISSION_CURRENT
    int currentIndex(void) const { return _currentMissionIndex; }

    /// Last current mission item reported while in Mission flight mode
    int lastCurrentIndex(void) const { return _lastCurrentIndex; }

    /// Writes the specified set mission items to the vehicle as an ArduPilot guided mode mission item.
    ///     @param gotoCoord Coordinate to move to
    ///     @param altChangeOnly true: only altitude change, false: lat/lon/alt change
    void writeArduPilotGuidedMissionItem(const QGeoCoordinate& gotoCoord, bool altChangeOnly);

    /// Generates a new mission which starts from the specified index. It will include all the CMD_DO items
    /// from mission start to resumeIndex in the generate mission.
    void generateResumeMission(int resumeIndex);

    bool vehicleMissionOutOfSync() const { return _vehicleMissionOutOfSync; }

    int vehicleMissionCount() const { return _vehicleMissionCount; }

    /// Hides the out-of-sync notice until the vehicle mission count changes again
    Q_INVOKABLE void dismissVehicleMissionChange();

signals:
    void vehicleMissionOutOfSyncChanged();

private slots:
    void _mavlinkMessageReceived(const mavlink_message_t& message);

private:
    void _handleHighLatency(const mavlink_message_t& message);
    void _handleHighLatency2(const mavlink_message_t& message);
    void _handleMissionCurrent(const mavlink_message_t& message);
    void _updateMissionIndex(int index);
    void _handleHeartbeat(const mavlink_message_t& message);

    void _checkVehicleMissionCount(int vehicleCount);
    void _resetVehicleMissionTracking();
    int _syncedMissionCount() const;

    int _cachedLastCurrentIndex;

    bool _vehicleMissionCountTrusted = false;  ///< Vehicle has reported a count matching our synced mission
    bool _vehicleMissionOutOfSync = false;
    int _vehicleMissionCount = -1;
    int _dismissedMissionCount = -1;
    int _pendingMismatchCount = -1;
    QElapsedTimer _mismatchTimer;

    static constexpr qint64 _mismatchSettleMs =
        2000;  ///< Ignore counts that change while another GCS is still uploading
};
