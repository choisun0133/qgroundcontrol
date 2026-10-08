#include "Platform.h"
#include "qgc_version.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QProcessEnvironment>
#include <QtQuick/QQuickWindow>
#include <QtQuick/QSGRendererInterface>

#include <cstdio>

#include "QGCCommandLineParser.h"

#if !defined(Q_OS_IOS) && !defined(Q_OS_ANDROID)
    #include "RunGuard.h"
    #include "SignalHandler.h"
#endif

#if (defined(Q_OS_LINUX) || defined(Q_OS_FREEBSD)) && !defined(Q_OS_ANDROID)
    #include <unistd.h>
    #include <sys/types.h>
    #include <sys/wait.h>
#endif

#if defined(Q_OS_MACOS)
    #include <CoreFoundation/CoreFoundation.h>
#elif defined(Q_OS_WIN)
    #include <qt_windows.h>
    #include <iostream>
    #include <iterator>  // std::size
    #include <cwchar>    // swprintf
    #if defined(_MSC_VER)
        #include <crtdbg.h>
        #include <stdlib.h>
    #endif
#endif

namespace {

#if (defined(Q_OS_LINUX) || defined(Q_OS_FREEBSD)) && !defined(Q_OS_ANDROID)
static void showLinuxErrorDialog(const QByteArray& msg)
{
    // Try to show a GUI dialog — important for AppImage users where stderr is invisible.
    // Fork a child and attempt dialog tools in order of preference; no shell is invoked.
    const pid_t pid = fork();
    if (pid == 0) {
        const QByteArray zenityText = QByteArrayLiteral("--text=") + msg;
        execlp("zenity", "zenity", "--error", "--title=Error", zenityText.constData(), nullptr);
        execlp("kdialog", "kdialog", "--error", msg.constData(), nullptr);
        execlp("xmessage", "xmessage", "-center", msg.constData(), nullptr);
        _exit(1);
    } else if (pid > 0) {
        int status = 0;
        (void) waitpid(pid, &status, 0);
    }
    // Always write to stderr as well
    fprintf(stderr, "Error: %s\n", msg.constData());
}
#endif // Q_OS_LINUX

#if defined(Q_OS_MACOS)
void disableAppNapViaInfoDict()
{
    CFBundleRef bundle = CFBundleGetMainBundle();
    if (!bundle) {
        return;
    }
    CFMutableDictionaryRef infoDict = const_cast<CFMutableDictionaryRef>(CFBundleGetInfoDictionary(bundle));
    if (infoDict) {
        CFDictionarySetValue(infoDict, CFSTR("NSAppSleepDisabled"), kCFBooleanTrue);
    }
}
#endif // Q_OS_MACOS

#if defined(Q_OS_WIN)

#if defined(_MSC_VER)

#if defined(_DEBUG)
int __cdecl WindowsCrtReportHook(int reportType, char* message, int* returnValue)
{
    if (message) {
        std::cerr << message << std::endl;
    }
    if (reportType == _CRT_ASSERT) {
        if (returnValue) {
            *returnValue = 0;
        }
        return 1; // handled
    }
    return 0; // let CRT continue
}
#endif // _DEBUG

void __cdecl WindowsPurecallHandler()
{
    (void) OutputDebugStringW(L"QGC: _purecall\n");
}

void WindowsInvalidParameterHandler([[maybe_unused]] const wchar_t* expression,
                                    [[maybe_unused]] const wchar_t* function,
                                    [[maybe_unused]] const wchar_t* file,
                                    [[maybe_unused]] unsigned int line,
                                    [[maybe_unused]] uintptr_t pReserved)
{

}
#endif // _MSC_VER

LPTOP_LEVEL_EXCEPTION_FILTER g_prevUef = nullptr;

// AeroResearch: crash report (%LOCALAPPDATA%\AeroResearch\last_crash.txt) listing the faulting module and
// the call chain as module+offset, shown to the user on the next launch. Path is resolved at startup so the
// filter itself only uses Win32 calls that are safe after a fault.
wchar_t g_crashReportPath[MAX_PATH] = {};

void initCrashReportPath()
{
    wchar_t dir[MAX_PATH] = {};
    const DWORD n = GetEnvironmentVariableW(L"LOCALAPPDATA", dir, MAX_PATH);
    if ((n == 0) || (n >= MAX_PATH - 40)) {
        return;
    }
    (void) wcscat_s(dir, L"\\AeroResearch");
    (void) CreateDirectoryW(dir, nullptr);
    (void) wcscpy_s(g_crashReportPath, dir);
    (void) wcscat_s(g_crashReportPath, L"\\last_crash.txt");
}

void crashReportWrite(HANDLE file, const wchar_t* text)
{
    char utf8[1024] = {};
    const int len = WideCharToMultiByte(CP_UTF8, 0, text, -1, utf8, static_cast<int>(sizeof(utf8)), nullptr, nullptr);
    if (len > 1) {
        DWORD written = 0;
        (void) WriteFile(file, utf8, static_cast<DWORD>(len - 1), &written, nullptr);
    }
}

void crashReportFrame(HANDLE file, const wchar_t* label, const void* address)
{
    HMODULE module = nullptr;
    wchar_t modulePath[MAX_PATH] = L"?";
    if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                           static_cast<LPCWSTR>(address), &module) && module) {
        (void) GetModuleFileNameW(module, modulePath, MAX_PATH);
    }
    const wchar_t* moduleName = wcsrchr(modulePath, L'\\');
    moduleName = moduleName ? moduleName + 1 : modulePath;
    const unsigned long long offset = module
        ? static_cast<unsigned long long>(static_cast<const char*>(address) - reinterpret_cast<const char*>(module))
        : reinterpret_cast<unsigned long long>(address);
    wchar_t line[512] = {};
    (void) _snwprintf_s(line, _TRUNCATE, L"%ls %ls+0x%llx\r\n", label, moduleName, offset);
    crashReportWrite(file, line);
}

void writeCrashReport(EXCEPTION_POINTERS* ep)
{
    if (g_crashReportPath[0] == L'\0') {
        return;
    }
    const HANDLE file = CreateFileW(g_crashReportPath, GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) {
        return;
    }
    const DWORD code = (ep && ep->ExceptionRecord) ? ep->ExceptionRecord->ExceptionCode : 0;
    wchar_t line[256] = {};
    (void) _snwprintf_s(line, _TRUNCATE, L"AeroResearch GCS %hs crash 0x%08lX thread %lu\r\n",
                        QGC_APP_VERSION_STR, static_cast<unsigned long>(code), GetCurrentThreadId());
    crashReportWrite(file, line);
    if (ep && ep->ExceptionRecord) {
        crashReportFrame(file, L"at", ep->ExceptionRecord->ExceptionAddress);
    }
    void* frames[48] = {};
    const USHORT count = RtlCaptureStackBackTrace(0, static_cast<DWORD>(std::size(frames)), frames, nullptr);
    for (USHORT i = 0; i < count; i++) {
        crashReportFrame(file, L" ", frames[i]);
    }
    (void) FlushFileBuffers(file);
    (void) CloseHandle(file);
}

LONG WINAPI WindowsUnhandledExceptionFilter(EXCEPTION_POINTERS* ep)
{
    const DWORD code = (ep && ep->ExceptionRecord) ? ep->ExceptionRecord->ExceptionCode : 0;
    wchar_t buf[128] = {};
#if defined(_MSC_VER)
    (void) _snwprintf_s(buf, _TRUNCATE, L"QGC: unhandled SEH 0x%08lX\n", static_cast<unsigned long>(code));
#else
    (void) swprintf(buf, static_cast<int>(std::size(buf)), L"QGC: unhandled SEH 0x%08lX\n", static_cast<unsigned long>(code));
#endif
    (void) OutputDebugStringW(buf);

#if defined(_MSC_VER)
    writeCrashReport(ep);
#endif

    const HANDLE h = GetStdHandle(STD_ERROR_HANDLE);
    if (h && (h != INVALID_HANDLE_VALUE)) {
        DWORD ignored = 0;
        const char narrow[] = "QGC: unhandled SEH\n";
        (void) WriteFile(h, narrow, (DWORD)sizeof(narrow) - 1, &ignored, nullptr);
    }

    return EXCEPTION_EXECUTE_HANDLER;
}

void setWindowsErrorModes(bool quietWindowsAsserts)
{
    (void) SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX | SEM_NOOPENFILEERRORBOX);
#if defined(_MSC_VER)
    initCrashReportPath();
#endif
    g_prevUef = SetUnhandledExceptionFilter(WindowsUnhandledExceptionFilter);

#if defined(_MSC_VER)
    (void) _set_invalid_parameter_handler(WindowsInvalidParameterHandler);
    (void) _set_purecall_handler(WindowsPurecallHandler);

    if (quietWindowsAsserts) {
        (void) _CrtSetReportMode(_CRT_ASSERT, _CRTDBG_MODE_DEBUG);
        (void) _CrtSetReportMode(_CRT_ERROR,  _CRTDBG_MODE_DEBUG);
        (void) _CrtSetReportMode(_CRT_WARN,   _CRTDBG_MODE_DEBUG);
        (void) _CrtSetReportHook2(_CRT_RPTHOOK_INSTALL, WindowsCrtReportHook);
        (void) _set_abort_behavior(0, _WRITE_ABORT_MSG | _CALL_REPORTFAULT);
        (void) _set_error_mode(_OUT_TO_STDERR);
    }
#else
    Q_UNUSED(quietWindowsAsserts);
#endif
}
#endif // Q_OS_WIN

} // namespace

std::optional<int> Platform::initialize(int argc, char* argv[],
                                         const QGCCommandLineParser::CommandLineParseResult& args)
{
#if (defined(Q_OS_LINUX) || defined(Q_OS_FREEBSD)) && !defined(Q_OS_ANDROID)
    if (isRunningAsRoot()) {
        return showRootError(argc, argv);
    }
#endif

#if !defined(Q_OS_ANDROID) && !defined(Q_OS_IOS)
    const bool allowMultiple = args.allowMultiple || args.runningUnitTests || args.listTests;
    if (!checkSingleInstance(allowMultiple)) {
        return showMultipleInstanceError(argc, argv);
    }
#else
    Q_UNUSED(argc);
    Q_UNUSED(argv);
#endif

#ifdef Q_OS_UNIX
#ifndef Q_OS_ANDROID
    // On Android, skip these — either env var triggers shouldLogToStderr(),
    // which bypasses Qt's __android_log_print path to logcat.
    if (!qEnvironmentVariableIsSet("QT_ASSUME_STDERR_HAS_CONSOLE")) {
        (void) qputenv("QT_ASSUME_STDERR_HAS_CONSOLE", "1");
    }
    if (!qEnvironmentVariableIsSet("QT_FORCE_STDERR_LOGGING")) {
        (void) qputenv("QT_FORCE_STDERR_LOGGING", "1");
    }
#endif
#endif

#ifdef Q_OS_WIN
    if (!qEnvironmentVariableIsSet("QT_WIN_DEBUG_CONSOLE")) {
        (void) qputenv("QT_WIN_DEBUG_CONSOLE", "attach");
    }
    if (qEnvironmentVariable("QSG_RHI_BACKEND").compare(QLatin1String("d3d12"), Qt::CaseInsensitive) == 0) {
        // Qt 6.10 does not reliably select D3D12 from QSG_RHI_BACKEND on Windows. Make the test/diagnostic override
        // explicit before the scene graph is initialized; the default path remains Qt's D3D11 backend.
        QQuickWindow::setGraphicsApi(QSGRendererInterface::Direct3D12);
    }
    setWindowsErrorModes(args.quietWindowsAsserts);
#endif

#ifdef Q_OS_MACOS
    disableAppNapViaInfoDict();
#endif

#ifdef QGC_UNITTEST_BUILD
    if ((args.runningUnitTests || args.listTests) && !args.onscreen) {
        if (!qEnvironmentVariableIsSet("QT_QPA_PLATFORM")) {
            (void) qputenv("QT_QPA_PLATFORM", "offscreen");
        }
    }
#endif

    // --- Qt attributes ---
    if (args.useSwRast) {
        // RHI defaults to D3D11/Metal on Win/macOS; AA_UseSoftwareOpenGL only bites once the scene graph is on GL.
        QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);
        QCoreApplication::setAttribute(Qt::AA_UseSoftwareOpenGL);
    }
#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID) && \
    (defined(QGC_HAS_GST_GLMEMORY_GPU_PATH) || defined(QGC_HAS_GST_DMABUF_GPU_PATH))
    // GL is the only working desktop-Linux GStreamer zero-copy backend (GLMemory and DMABuf/EGLImage both import into a
    // GL RHI; Vulkan import dormant); pin it unless the user set QSG_RHI_BACKEND. No QRhi::probe — needs GuiPrivate (not
    // linked here) and GL is always present on Linux.
    else if (!qEnvironmentVariableIsSet("QSG_RHI_BACKEND")) {
        QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);
    }
#endif

    // GStreamer's GL/DMABuf zero-copy paths both need QOpenGLContext::globalShareContext(), which this attribute enables.
#if defined(QGC_HAS_GST_GLMEMORY_GPU_PATH) || defined(QGC_HAS_GST_DMABUF_GPU_PATH)
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
#endif
    QCoreApplication::setAttribute(Qt::AA_CompressTabletEvents);

    return std::nullopt;
}

void Platform::setupPostApp()
{
#if !defined(Q_OS_IOS) && !defined(Q_OS_ANDROID)
    SignalHandler* signalHandler = new SignalHandler(QCoreApplication::instance());
    (void) signalHandler->setupSignalHandlers();
#endif
}

#if (defined(Q_OS_LINUX) || defined(Q_OS_FREEBSD)) && !defined(Q_OS_ANDROID)
bool Platform::isRunningAsRoot()
{
    return ::getuid() == 0;
}

int Platform::showRootError([[maybe_unused]] int argc, [[maybe_unused]] char *argv[])
{
    const QString message = QCoreApplication::translate("main",
        "You are running %1 as root. "
        "You should not do this since it will cause other issues with %1. "
        "%1 will now exit.").arg(QLatin1String(QGC_APP_NAME));
    showLinuxErrorDialog(message.toLocal8Bit());
    return -1;
}
#endif

#if !defined(Q_OS_ANDROID) && !defined(Q_OS_IOS)
int Platform::showMultipleInstanceError([[maybe_unused]] int argc, [[maybe_unused]] char *argv[])
{
    const QString message = QCoreApplication::translate("main",
        "A second instance of %1 is already running. "
        "Please close the other instance and try again.").arg(QLatin1String(QGC_APP_NAME));
#if defined(Q_OS_MACOS)
    // The native alert is GUI-only; also write to stderr so a CLI/headless launch sees the reason.
    fprintf(stderr, "Error: %s\n", message.toLocal8Bit().constData());
    CFStringRef cfMessage = CFStringCreateWithCString(nullptr, message.toUtf8().constData(), kCFStringEncodingUTF8);
    CFUserNotificationDisplayAlert(0, kCFUserNotificationStopAlertLevel,
                                   nullptr, nullptr, nullptr,
                                   CFSTR("Error"), cfMessage,
                                   nullptr, nullptr, nullptr, nullptr);
    CFRelease(cfMessage);
#elif defined(Q_OS_WIN)
    // MessageBoxW is GUI-only; also write to stderr so a CLI/headless launch sees the reason.
    fprintf(stderr, "Error: %s\n", message.toLocal8Bit().constData());
    MessageBoxW(nullptr, message.toStdWString().c_str(), L"Error", MB_OK | MB_ICONERROR);
#else
    showLinuxErrorDialog(message.toLocal8Bit());
#endif
    return -1;
}

bool Platform::checkSingleInstance(bool allowMultiple)
{
    if (allowMultiple) {
        return true;
    }

    static const QString runguardString = QStringLiteral("%1 RunGuardKey").arg(QLatin1String(QGC_APP_NAME));
    static RunGuard guard(runguardString);
    return guard.tryToRun();
}
#endif
