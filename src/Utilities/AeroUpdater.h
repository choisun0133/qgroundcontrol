#pragma once

#include <QtCore/QCryptographicHash>
#include <QtCore/QFile>
#include <QtCore/QObject>
#include <QtCore/QPointer>
#include <QtCore/QString>

class QNetworkAccessManager;
class QNetworkReply;

/// AeroResearch: downloads a new installer, checks its SHA-256 against the release manifest and
/// starts it. Checking for a new version and asking the user happen in QML (AeroUpdateNotice).
class AeroUpdater : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString  currentVersion  READ currentVersion CONSTANT)
    Q_PROPERTY(bool     canInstall      READ canInstall     CONSTANT)   ///< installer can be run from the app (Windows)
    Q_PROPERTY(bool     busy            READ busy           NOTIFY busyChanged)
    Q_PROPERTY(qreal    progress        READ progress       NOTIFY progressChanged)  ///< 0..1, -1 when size unknown
    /// Set by the UI while a vehicle is connected: the installer is never started then
    Q_PROPERTY(bool     installBlocked  READ installBlocked WRITE setInstallBlocked NOTIFY installBlockedChanged)

public:
    explicit AeroUpdater(QObject *parent = nullptr);
    static AeroUpdater *instance();

    static QString currentVersion();
    static bool canInstall();
    bool busy() const { return _reply != nullptr; }
    qreal progress() const { return _progress; }
    bool installBlocked() const { return _installBlocked; }
    void setInstallBlocked(bool blocked);

    /// -1 / 0 / 1 for a < b / a == b / a > b, comparing dotted numbers ("1.6.34" > "1.6.9")
    Q_INVOKABLE static int compareVersions(const QString &a, const QString &b);

    /// Downloads url (https on github.com only), verifies sha256 (hex) and opens the installer.
    Q_INVOKABLE void downloadAndInstall(const QString &url, const QString &sha256);
    Q_INVOKABLE void cancel();

signals:
    void busyChanged();
    void progressChanged();
    void installBlockedChanged();
    void failed(const QString &message);
    void installerStarted();

private:
    void _finished();
    void _fail(const QString &message);

    QNetworkAccessManager *_network = nullptr;
    QPointer<QNetworkReply> _reply;
    QFile _file;
    QCryptographicHash _hash{QCryptographicHash::Sha256};
    QString _expectedSha;
    qreal _progress = 0;
    bool _installBlocked = false;
    bool _writeFailed = false;
};
