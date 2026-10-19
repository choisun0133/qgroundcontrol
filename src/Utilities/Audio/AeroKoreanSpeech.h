#pragma once

#include <QtCore/QString>
#include <QtCore/QStringList>

/// AeroResearch: Korean spoken announcements.
///
/// Turns the English (or partly translated) announcement text QGC produces - flight mode changes,
/// arming, battery, link and fence warnings, common flight controller status texts - into short
/// Korean phrases. Each phrase that can be pre-recorded also carries a clip id: if the voice pack
/// has <clip id>.wav, that recording is played instead of the TTS voice.
namespace AeroKoreanSpeech
{
    struct Phrase {
        QString text;       ///< Korean sentence to speak (empty: no translation, speak the original)
        QString clipId;     ///< Voice pack clip for this sentence (empty: TTS only)
    };

    /// Translates one announcement. Multi-vehicle prefixes ("vehicle 2 ...") become "기체 2 ..."
    /// and then have no clip (the recording cannot include the vehicle number).
    Phrase translate(const QString &text);

    /// Every clip id with its sentence, in recording-script order ("id|sentence" entries).
    QStringList allClips();
}
