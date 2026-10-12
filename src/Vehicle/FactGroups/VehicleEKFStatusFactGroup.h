#pragma once

#include "FactGroup.h"

/// ArduPilot EKF health from MAVLINK_MSG_ID_EKF_STATUS_REPORT: normalised innovation variances
/// (0 = perfect, 1 = at the rejection limit) and the EKF_STATUS_FLAGS bitmask.
class VehicleEKFStatusFactGroup : public FactGroup
{
    Q_OBJECT
    Q_PROPERTY(Fact *velocityVariance   READ velocityVariance   CONSTANT)
    Q_PROPERTY(Fact *posHorizVariance   READ posHorizVariance   CONSTANT)
    Q_PROPERTY(Fact *posVertVariance    READ posVertVariance    CONSTANT)
    Q_PROPERTY(Fact *compassVariance    READ compassVariance    CONSTANT)
    Q_PROPERTY(Fact *terrainAltVariance READ terrainAltVariance CONSTANT)
    Q_PROPERTY(Fact *airspeedVariance   READ airspeedVariance   CONSTANT)
    Q_PROPERTY(Fact *flags              READ flags              CONSTANT)

public:
    explicit VehicleEKFStatusFactGroup(QObject *parent = nullptr);

    Fact *velocityVariance() { return &_velocityVarianceFact; }
    Fact *posHorizVariance() { return &_posHorizVarianceFact; }
    Fact *posVertVariance() { return &_posVertVarianceFact; }
    Fact *compassVariance() { return &_compassVarianceFact; }
    Fact *terrainAltVariance() { return &_terrainAltVarianceFact; }
    Fact *airspeedVariance() { return &_airspeedVarianceFact; }
    Fact *flags() { return &_flagsFact; }

    // Overrides from FactGroup
    void handleMessage(Vehicle *vehicle, const mavlink_message_t &message) final;

private:
    Fact _velocityVarianceFact = Fact(0, QStringLiteral("velocityVariance"), FactMetaData::valueTypeDouble);
    Fact _posHorizVarianceFact = Fact(0, QStringLiteral("posHorizVariance"), FactMetaData::valueTypeDouble);
    Fact _posVertVarianceFact = Fact(0, QStringLiteral("posVertVariance"), FactMetaData::valueTypeDouble);
    Fact _compassVarianceFact = Fact(0, QStringLiteral("compassVariance"), FactMetaData::valueTypeDouble);
    Fact _terrainAltVarianceFact = Fact(0, QStringLiteral("terrainAltVariance"), FactMetaData::valueTypeDouble);
    Fact _airspeedVarianceFact = Fact(0, QStringLiteral("airspeedVariance"), FactMetaData::valueTypeDouble);
    Fact _flagsFact = Fact(0, QStringLiteral("flags"), FactMetaData::valueTypeUint32);
};
