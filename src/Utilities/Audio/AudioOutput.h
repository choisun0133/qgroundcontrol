#pragma once

#include <chrono>

#include <QtCore/QHash>
#include <QtCore/QObject>
#include <QtCore/QSet>
#include <QtCore/QString>
#include <QtCore/QStringList>
#include <QtTextToSpeech/QVoice>

class QTextToSpeech;
class QMediaPlayer;
class QAudioOutput;
class Fact;
class AudioOutputTest;

/// \brief The AudioOutput class provides functionality for audio output using text-to-speech.
///
class AudioOutput : public QObject
{
    Q_OBJECT

    friend AudioOutputTest;

    // AeroResearch: voice selection and Korean announcements (Ctrl+F quick tools)
    Q_PROPERTY(QStringList  voiceNames      READ voiceNames                     NOTIFY voicesChanged)
    Q_PROPERTY(QString      voiceName       READ voiceName  WRITE setVoiceName  NOTIFY voiceNameChanged)
    Q_PROPERTY(double       rate            READ rate       WRITE setRate       NOTIFY rateChanged)
    Q_PROPERTY(bool         korean          READ korean                         NOTIFY voiceNameChanged)
    Q_PROPERTY(bool         voicePack       READ voicePack  WRITE setVoicePack  NOTIFY voicePackChanged)
    Q_PROPERTY(int          voicePackClips  READ voicePackClips                 NOTIFY voicePackChanged)
    Q_PROPERTY(QString      voicePackFolder READ voicePackFolder                CONSTANT)

public:
    /// Enumeration for text modification options.
    enum class TextMod {
        None = 0,
        Translate = 1 << 0,
    };
    Q_FLAG(TextMod)
    Q_DECLARE_FLAGS(TextMods, TextMod)

    /// Constructs an AudioOutput object.
    ///     @param parent The parent QObject.
    explicit AudioOutput(QObject *parent = nullptr);

    /// Destructor for the AudioOutput class.
    ~AudioOutput();

    /// Gets the singleton instance of AudioOutput.
    ///     @return The singleton instance.
    static AudioOutput *instance();

    /// Initialize the Singleton
    void init(Fact *volumeFact, Fact *mutedFact);

    /// Reads the specified text with optional text modifications.
    ///     @param text The text to be read.
    ///     @param textMods The text modifications to apply.
    void say(const QString &text, TextMods textMods = TextMod::None);

    /// Tests the audio output. Will stop current output before test
    void testAudioOutput();

    /// AeroResearch: installed voices ("name (language)"), Korean and English only
    QStringList voiceNames() const { return _voiceNames; }
    QString voiceName() const;
    void setVoiceName(const QString &name);
    /// Speech rate -1.0 (slow) .. 1.0 (fast)
    double rate() const { return _rate; }
    void setRate(double rate);
    /// True when the current voice speaks Korean: announcements are then translated to Korean
    bool korean() const;
    /// Use recorded clips (<voicePackFolder>/<clip>.wav, or the bundled :/voice/<clip>.wav) when available
    bool voicePack() const { return _voicePackEnabled; }
    void setVoicePack(bool enabled);
    int voicePackClips() const;
    QString voicePackFolder() const;
    /// Speaks a short Korean/English test sentence with the current settings
    Q_INVOKABLE void testVoice();
    /// Re-scans the voice pack folder (after copying recordings into it)
    Q_INVOKABLE void reloadVoicePack();
    /// Speaks one script clip (e.g. "ground_2m"): the recording if present, else the Korean
    /// sentence with a Korean voice, else englishFallback.
    Q_INVOKABLE void sayClip(const QString &clipId, const QString &englishFallback);

signals:
    void voicesChanged();
    void voiceNameChanged();
    void rateChanged();
    void voicePackChanged();

private:
    QTextToSpeech *_engine = nullptr;
    qsizetype _textQueueSize = 0;
    bool _initialized = false;
    bool _speakCapable = false;
    Fact *_volumeFact = nullptr;
    Fact *_mutedFact = nullptr;
    double _lastVolume = -1.0;

    // AeroResearch voice selection / voice pack
    QStringList _voiceNames;
    QList<QVoice> _voices;
    double _rate = 0.0;
    bool _voicePackEnabled = true;
    QMediaPlayer *_clipPlayer = nullptr;
    QAudioOutput *_clipAudio = nullptr;
    QStringList _clipQueue;
    void _collectVoices();
    void _applySavedVoice();
    QString _clipPath(const QString &clipId) const;
    void _playClip(const QString &path);
    void _playNextClip();

    /// Returns the current volume (0.0 - 100.0) from the settings Fact.
    double _volumeSetting() const;

    /// Returns the current muted state from the settings Fact.
    bool _mutedSetting() const;

    /// Sets the TTS engine volume from the current Fact value.
    void _setVolume();

    /// Applies engine-dependent settings (locale, cached capabilities) for the current engine.
    void _applyEngineSettings();

    /// Finalizes initialization once the engine is Ready: applies settings, wires Facts, sets volume.
    void _finishInit();

    static const QHash<QString, QString> _textHash;
    static const QSet<QString> _spelledAcronyms;

    static constexpr qsizetype kMaxTextQueueSize = 20;

    /// Grace period for async TTS backends (e.g. Android service binding) to reach Ready before warning.
    static constexpr std::chrono::seconds kEngineInitWarnTimeout{10};

    /// Fixes text messages for audio output.
    ///     @param string The text message to fix.
    ///     @return The fixed text message.
    static QString _fixTextMessageForAudio(const QString &string);

    /// Replaces predefined abbreviations with their corresponding full forms.
    ///     @param input The input string containing abbreviations.
    ///     @return A string with abbreviations replaced by their full forms.
    static QString _replaceAbbreviations(const QString &input);

    /// Returns the spoken form of an abbreviation token, or an empty string if none.
    /// _textHash ignores case; _spelledAcronyms matches all-caps only.
    static QString _spokenAbbreviation(const QString& token);

    /// Replaces negative signs with the word "negative".
    static QString _replaceNegativeSigns(const QString &input);

    /// Replaces decimal points with the word "point".
    static QString _replaceDecimalPoints(const QString &input);

    /// Replaces "m" (meters) with the word "meters" following numbers.
    static QString _replaceMeters(const QString &input);

    /// Converts millisecond values to a more readable format (seconds and minutes).
    static QString _convertMilliseconds(const QString &input);

    /// Extracts a millisecond value from the given string.
    ///     @param string The string to extract from.
    ///     @param match The extracted millisecond string.
    ///     @param number The extracted number.
    ///     @return True if extraction is successful, false otherwise.
    static bool _getMillisecondString(const QString &string, QString &match, int &number);

};
Q_DECLARE_OPERATORS_FOR_FLAGS(AudioOutput::TextMods)
