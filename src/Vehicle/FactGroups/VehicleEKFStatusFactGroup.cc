#include "VehicleEKFStatusFactGroup.h"
#include "Vehicle.h"

VehicleEKFStatusFactGroup::VehicleEKFStatusFactGroup(QObject *parent)
    : FactGroup(1000, QStringLiteral(":/json/Vehicle/EKFStatusFact.json"), parent)
{
    _addFact(&_velocityVarianceFact);
    _addFact(&_posHorizVarianceFact);
    _addFact(&_posVertVarianceFact);
    _addFact(&_compassVarianceFact);
    _addFact(&_terrainAltVarianceFact);
    _addFact(&_airspeedVarianceFact);
    _addFact(&_flagsFact);

    _velocityVarianceFact.setRawValue(qQNaN());
    _posHorizVarianceFact.setRawValue(qQNaN());
    _posVertVarianceFact.setRawValue(qQNaN());
    _compassVarianceFact.setRawValue(qQNaN());
    _terrainAltVarianceFact.setRawValue(qQNaN());
    _airspeedVarianceFact.setRawValue(qQNaN());
}

void VehicleEKFStatusFactGroup::handleMessage(Vehicle *vehicle, const mavlink_message_t &message)
{
    Q_UNUSED(vehicle);

    if (message.msgid != MAVLINK_MSG_ID_EKF_STATUS_REPORT) {
        return;
    }

    mavlink_ekf_status_report_t report{};
    mavlink_msg_ekf_status_report_decode(&message, &report);

    velocityVariance()->setRawValue(report.velocity_variance);
    posHorizVariance()->setRawValue(report.pos_horiz_variance);
    posVertVariance()->setRawValue(report.pos_vert_variance);
    compassVariance()->setRawValue(report.compass_variance);
    terrainAltVariance()->setRawValue(report.terrain_alt_variance);
    airspeedVariance()->setRawValue(report.airspeed_variance);
    flags()->setRawValue(report.flags);

    _setTelemetryAvailable(true);
}
