#include "AeroUpdater.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtCore/QStandardPaths>
#include <QtCore/QUrl>
#include <QtGui/QDesktopServices>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QNetworkRequest>

#ifndef QGC_AERO_VERSION
#define QGC_AERO_VERSION "0.0.0"
#endif

namespace {
constexpr int kTransferTimeoutMs = 60 * 1000;   // no data for this long: give up
}

AeroUpdater::AeroUpdater(QObject *parent)
    : QObject(parent)
    , _network(new QNetworkAccessManager(this))
{
}

AeroUpdater *AeroUpdater::instance()
{
    static AeroUpdater *updater = new AeroUpdater(QCoreApplication::instance());
    return updater;
}

QString AeroUpdater::currentVersion()
{
    return QStringLiteral(QGC_AERO_VERSION);
}

bool AeroUpdater::canInstall()
{
#ifdef Q_OS_WIN
    return true;
#else
    return false;
#endif
}

int AeroUpdater::compareVersions(const QString &a, const QString &b)
{
    const QStringList pa = a.trimmed().split(QLatin1Char('.'));
    const QStringList pb = b.trimmed().split(QLatin1Char('.'));
    const qsizetype n = qMax(pa.size(), pb.size());
    for (qsizetype i = 0; i < n; ++i) {
        const int va = i < pa.size() ? pa.at(i).toInt() : 0;
        const int vb = i < pb.size() ? pb.at(i).toInt() : 0;
        if (va != vb) {
            return va < vb ? -1 : 1;
        }
    }
    return 0;
}

void AeroUpdater::downloadAndInstall(const QString &url, const QString &sha256)
{
    if (_reply) {
        return;
    }
    const QUrl source(url);
    if (!source.isValid() || source.scheme() != QStringLiteral("https") || source.host() != QStringLiteral("github.com")) {
        emit failed(tr("업데이트 주소가 올바르지 않습니다"));
        return;
    }
    const QString expected = sha256.trimmed().toLower();
    if (expected.size() != 64) {
        emit failed(tr("업데이트 정보에 파일 확인값이 없습니다"));
        return;
    }

    const QString dir = QStandardPaths::writableLocation(QStandardPaths::TempLocation) + QStringLiteral("/AeroGCS-update");
    if (!QDir().mkpath(dir)) {
        emit failed(tr("임시 폴더를 만들 수 없습니다"));
        return;
    }
    _file.setFileName(dir + QLatin1Char('/') + QFileInfo(source.path()).fileName());
    if (!_file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        emit failed(tr("설치 파일을 저장할 수 없습니다"));
        return;
    }

    _hash.reset();
    _expectedSha = expected;
    _progress = 0;
    emit progressChanged();

    QNetworkRequest request(source);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(kTransferTimeoutMs);
    _reply = _network->get(request);
    emit busyChanged();

    connect(_reply, &QNetworkReply::readyRead, this, [this]() {
        const QByteArray chunk = _reply->readAll();
        _hash.addData(chunk);
        _file.write(chunk);
    });
    connect(_reply, &QNetworkReply::downloadProgress, this, [this](qint64 received, qint64 total) {
        _progress = total > 0 ? static_cast<qreal>(received) / static_cast<qreal>(total) : -1;
        emit progressChanged();
    });
    connect(_reply, &QNetworkReply::finished, this, &AeroUpdater::_finished);
}

void AeroUpdater::cancel()
{
    if (_reply) {
        _reply->abort();    // finished() follows with OperationCanceledError
    }
}

void AeroUpdater::_fail(const QString &message)
{
    _file.close();
    _file.remove();
    emit failed(message);
}

void AeroUpdater::_finished()
{
    QNetworkReply *reply = _reply;
    _reply = nullptr;
    reply->deleteLater();
    emit busyChanged();

    if (reply->error() == QNetworkReply::OperationCanceledError) {
        _fail(tr("업데이트를 취소했습니다"));
        return;
    }
    if (reply->error() != QNetworkReply::NoError) {
        _fail(tr("다운로드 실패: %1").arg(reply->errorString()));
        return;
    }
    const QByteArray rest = reply->readAll();
    _hash.addData(rest);
    _file.write(rest);
    _file.close();

    if (QString::fromLatin1(_hash.result().toHex()) != _expectedSha) {
        _file.remove();
        emit failed(tr("받은 파일이 손상되었거나 다른 파일입니다. 다시 시도하세요"));
        return;
    }

    // ShellExecute (via openUrl) shows the UAC prompt the installer needs
    if (!QDesktopServices::openUrl(QUrl::fromLocalFile(_file.fileName()))) {
        emit failed(tr("설치 프로그램을 실행할 수 없습니다: %1").arg(QDir::toNativeSeparators(_file.fileName())));
        return;
    }
    emit installerStarted();
}
