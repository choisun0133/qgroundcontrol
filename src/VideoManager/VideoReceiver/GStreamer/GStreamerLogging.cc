#include "GStreamerLogging.h"

#include <QtCore/QSettings>
#include <glib/gstdio.h>
#include <cstdio>
#include <QtCore/QString>
#include <algorithm>
#include <atomic>
#include <memory>

#include "AppSettings.h"
#include "GStreamer.h"
#include "GStreamerHelpers.h"
#include "QGCLoggingCategory.h"

QGC_LOGGING_CATEGORY(GStreamerLoggingLog, "Video.GStreamer.GStreamerLogging")
QGC_LOGGING_CATEGORY_ON(GStreamerAPILog, "Video.GStreamer.GStreamerAPI")
QGC_LOGGING_CATEGORY(GStreamerDecoderRanksLog, "Video.GStreamer.DecoderRanks")

namespace {

std::atomic_bool g_externalPluginLoaderFailed = false;

void glib_print_handler(const gchar* string)
{
    qCInfo(GStreamerLoggingLog) << string;
}

void glib_printerr_handler(const gchar* string)
{
    qCWarning(GStreamerLoggingLog) << string;
}

void glib_log_handler(const gchar* log_domain, GLogLevelFlags log_level, const gchar* message, gpointer user_data)
{
    Q_UNUSED(user_data);
    const QString domain = log_domain ? QString::fromUtf8(log_domain) : QStringLiteral("GLib");
    const QString msg = QString::fromUtf8(message);

    if (msg.contains(QStringLiteral("External plugin loader failed"), Qt::CaseInsensitive)) {
        g_externalPluginLoaderFailed.store(true);
    }

    if (msg.contains(QStringLiteral("pygobject initialization failed"), Qt::CaseInsensitive)) {
        qCDebug(GStreamerLoggingLog) << domain << msg;
        return;
    }

    switch (log_level & G_LOG_LEVEL_MASK) {
        case G_LOG_LEVEL_ERROR:
        case G_LOG_LEVEL_CRITICAL:
            qCCritical(GStreamerLoggingLog) << domain << msg;
            break;
        case G_LOG_LEVEL_WARNING:
            qCWarning(GStreamerLoggingLog) << domain << msg;
            break;
        case G_LOG_LEVEL_MESSAGE:
        case G_LOG_LEVEL_INFO:
            qCInfo(GStreamerLoggingLog) << domain << msg;
            break;
        case G_LOG_LEVEL_DEBUG:
        default:
            qCDebug(GStreamerLoggingLog) << domain << msg;
            break;
    }
}

}  // anonymous namespace

namespace GStreamer {

void resetExternalPluginLoaderFailure()
{
    g_externalPluginLoaderFailed.store(false);
}

bool didExternalPluginLoaderFail()
{
    return g_externalPluginLoaderFailed.load();
}

void redirectGLibLogging()
{
    g_set_print_handler(glib_print_handler);
    g_set_printerr_handler(glib_printerr_handler);
    g_log_set_default_handler(glib_log_handler, nullptr);
}

void qtGstLog(GstDebugCategory* category, GstDebugLevel level, const gchar* file, const gchar* function, gint line,
              GObject* object, GstDebugMessage* message, gpointer data)
{
    Q_UNUSED(data);

    if (level > gst_debug_category_get_threshold(category)) {
        return;
    }

    QMessageLogger log(file, line, function);

    struct GFree
    {
        void operator()(gchar* p) const { g_free(p); }
    };

    const std::unique_ptr<gchar, GFree> object_info(gst_info_strdup_printf("%" GST_PTR_FORMAT, object));

    switch (level) {
        case GST_LEVEL_ERROR:
            log.critical(GStreamerAPILog, "%s %s", object_info.get(), gst_debug_message_get(message));
            break;
        case GST_LEVEL_WARNING:
            log.warning(GStreamerAPILog, "%s %s", object_info.get(), gst_debug_message_get(message));
            break;
        case GST_LEVEL_FIXME:
        case GST_LEVEL_INFO:
            log.info(GStreamerAPILog, "%s %s", object_info.get(), gst_debug_message_get(message));
            break;
        case GST_LEVEL_DEBUG:
#ifdef QT_DEBUG
        // In release builds LOG/TRACE/MEMDUMP are intentionally dropped to reduce
        // noise. Only debug builds route these verbose levels through Qt logging.
        case GST_LEVEL_LOG:
        case GST_LEVEL_TRACE:
        case GST_LEVEL_MEMDUMP:
#endif
            log.debug(GStreamerAPILog, "%s %s", object_info.get(), gst_debug_message_get(message));
            break;
        default:
            break;
    }
}

void configureDebugLogging()
{
    gst_debug_remove_log_function(gst_debug_log_default);
    gst_debug_remove_log_function(GStreamer::qtGstLog);
    gst_debug_add_log_function(GStreamer::qtGstLog, nullptr, nullptr);

    if (!qEnvironmentVariableIsEmpty("GST_DEBUG")) {
        return;
    }

    QSettings settings;
    if (settings.contains(AppSettings::gstDebugLevelName)) {
        const int level =
            std::clamp(settings.value(AppSettings::gstDebugLevelName).toInt(), 0, static_cast<int>(GST_LEVEL_MEMDUMP));
        gst_debug_set_default_threshold(static_cast<GstDebugLevel>(level));
    }
}

void setDebugLevel(int level)
{
    if (!gst_is_initialized()) {
        return;
    }
    const int clamped = std::clamp(level, 0, static_cast<int>(GST_LEVEL_MEMDUMP));
    gst_debug_set_default_threshold(static_cast<GstDebugLevel>(clamped));
    qCDebug(GStreamerLoggingLog) << "GStreamer debug threshold set to" << clamped;
}

void logDecoderRanks()
{
    GList* factories = gst_element_factory_list_get_elements(
        static_cast<GstElementFactoryListType>(GST_ELEMENT_FACTORY_TYPE_DECODER | GST_ELEMENT_FACTORY_TYPE_MEDIA_VIDEO),
        GST_RANK_NONE);

    if (!factories) {
        qCDebug(GStreamerDecoderRanksLog) << "No video decoder factories found";
        return;
    }

    factories = g_list_sort(factories, [](gconstpointer lhs, gconstpointer rhs) -> gint {
        const guint lhsRank = gst_plugin_feature_get_rank(GST_PLUGIN_FEATURE(lhs));
        const guint rhsRank = gst_plugin_feature_get_rank(GST_PLUGIN_FEATURE(rhs));
        if (lhsRank != rhsRank) {
            return (lhsRank > rhsRank) ? -1 : 1;
        }
        return g_strcmp0(gst_plugin_feature_get_name(GST_PLUGIN_FEATURE(lhs)),
                         gst_plugin_feature_get_name(GST_PLUGIN_FEATURE(rhs)));
    });

    qCDebug(GStreamerDecoderRanksLog) << "Video decoder ranks:";
    for (GList* node = factories; node != nullptr; node = node->next) {
        GstElementFactory* factory = GST_ELEMENT_FACTORY(node->data);
        GstPluginFeature* feature = GST_PLUGIN_FEATURE(factory);
        const gchar* featureName = gst_plugin_feature_get_name(feature);
        const guint rank = gst_plugin_feature_get_rank(feature);
        const gchar* klass = gst_element_factory_get_klass(factory);
        const bool isHw = GStreamer::isHardwareDecoderFactory(factory);

        GstPlugin* plugin = gst_plugin_feature_get_plugin(feature);
        const gchar* pluginName = plugin ? gst_plugin_get_name(plugin) : "?";

        qCDebug(GStreamerDecoderRanksLog).noquote()
            << QStringLiteral("  [%1] %2/%3 rank=%4 (%5)")
                   .arg(isHw ? QStringLiteral("HW") : QStringLiteral("SW"), QString::fromUtf8(pluginName),
                        QString::fromUtf8(featureName))
                   .arg(rank)
                   .arg(QString::fromUtf8(klass));

        if (plugin) {
            gst_object_unref(plugin);
        }
    }

    gst_plugin_feature_list_free(factories);
}

}  // namespace GStreamer

namespace {

FILE* s_diagFile = nullptr;
GMutex s_diagMutex;

void diagFileLog(GstDebugCategory* category, GstDebugLevel level, const gchar* file, const gchar* function, gint line,
                 GObject* object, GstDebugMessage* message, gpointer /*data*/)
{
    if (level > gst_debug_category_get_threshold(category)) {
        return;
    }
    g_mutex_lock(&s_diagMutex);
    if (s_diagFile) {
        gchar* obj = object ? gst_info_strdup_printf("%" GST_PTR_FORMAT, object) : g_strdup("");
        const GstClockTime t = gst_util_get_timestamp();
        fprintf(s_diagFile, "%" GST_TIME_FORMAT " %-7s %-20s %s:%d:%s: %s %s\n", GST_TIME_ARGS(t),
                gst_debug_level_get_name(level), gst_debug_category_get_name(category), file ? file : "", line,
                function ? function : "", obj, gst_debug_message_get(message));
        g_free(obj);
    }
    g_mutex_unlock(&s_diagMutex);
}

}  // namespace

void GStreamer::stopFileLog()
{
    gst_debug_remove_log_function(diagFileLog);
    gst_debug_set_threshold_from_string("*:1", TRUE);
    g_mutex_lock(&s_diagMutex);
    if (s_diagFile) {
        fprintf(s_diagFile, "===== end of AeroResearch video diagnostics =====\n");
        fclose(s_diagFile);
        s_diagFile = nullptr;
    }
    g_mutex_unlock(&s_diagMutex);
}

bool GStreamer::startFileLog(const char* path)
{
    if (!gst_is_initialized() || !path) {
        return false;
    }
    g_mutex_lock(&s_diagMutex);
    if (s_diagFile) {
        fclose(s_diagFile);
    }
    s_diagFile = g_fopen(path, "w");
    const bool ok = (s_diagFile != nullptr);
    if (ok) {
        fprintf(s_diagFile, "===== AeroResearch video diagnostics =====\n");
        fflush(s_diagFile);
    }
    g_mutex_unlock(&s_diagMutex);
    if (!ok) {
        return false;
    }

    gst_debug_remove_log_function(diagFileLog);
    gst_debug_add_log_function(diagFileLog, nullptr, nullptr);
    gst_debug_set_threshold_from_string(
        "*:3,rtspsrc:6,rtspconnection:5,rtspsrc2:5,rtpbin:4,rtpsession:4,rtpjitterbuffer:4,rtph265depay:6,"
        "rtph264depay:5,rtpbasedepayload:5,h265parse:5,h264parse:5,parsebin:5,decodebin3:5,"
        "videodecoder:4,avdec_h265:4,nvh265dec:4,d3d11h265dec:4,d3d12h265dec:4",
        TRUE);
    return true;
}
