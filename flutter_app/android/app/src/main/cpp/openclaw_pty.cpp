#include "openclaw_pty.h"

#include <android/log.h>
#include <jni.h>

#include <cstring>
#include <cstdlib>
#include <cerrno>
#include <mutex>
#include <unordered_map>
#include <vector>
#include <string>

#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/ioctl.h>
#include <sys/epoll.h>
#include <termios.h>

#define LOG_TAG "OpenClawPty"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// ──────────────────────────────────────────────
// Session data
// ──────────────────────────────────────────────

struct PtySession {
    int sessionId;
    int masterFd;
    pid_t childPid;
    bool alive;
    int exitCode;
    int epollFd;
};

static std::mutex sSessionsMutex;
static std::unordered_map<int, PtySession> sSessions;
static int sNextSessionId = 1;

// ──────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────

static std::string jstringToString(JNIEnv *env, jstring js) {
    if (js == nullptr) return "";
    const char *chars = env->GetStringUTFChars(js, nullptr);
    std::string result(chars);
    env->ReleaseStringUTFChars(js, chars);
    return result;
}

static std::vector<std::string> jobjectArrayToStringVector(JNIEnv *env, jobjectArray array) {
    std::vector<std::string> result;
    if (array == nullptr) return result;
    jsize len = env->GetArrayLength(array);
    for (jsize i = 0; i < len; i++) {
        jstring js = (jstring) env->GetObjectArrayElement(array, i);
        if (js != nullptr) {
            result.push_back(jstringToString(env, js));
            env->DeleteLocalRef(js);
        }
    }
    return result;
}

static char **stringVectorToCArray(const std::vector<std::string> &vec) {
    char **arr = (char **) calloc(vec.size() + 1, sizeof(char *));
    for (size_t i = 0; i < vec.size(); i++) {
        arr[i] = strdup(vec[i].c_str());
    }
    arr[vec.size()] = nullptr;
    return arr;
}

static void freeCArray(char **arr) {
    if (arr == nullptr) return;
    for (size_t i = 0; arr[i] != nullptr; i++) {
        free(arr[i]);
    }
    free(arr);
}

// ──────────────────────────────────────────────
// Core PTY logic
// ──────────────────────────────────────────────

static int createPtySession(const std::string &shell,
                             const std::vector<std::string> &args,
                             const std::vector<std::string> &envVars,
                             const std::string &cwd,
                             int rows, int cols) {
    int masterFd = posix_openpt(O_RDWR | O_NOCTTY);
    if (masterFd < 0) {
        LOGE("posix_openpt failed: %s", strerror(errno));
        return -1;
    }

    if (grantpt(masterFd) != 0 || unlockpt(masterFd) != 0) {
        LOGE("grantpt/unlockpt failed");
        close(masterFd);
        return -1;
    }

    char slaveName[256];
    if (ptsname_r(masterFd, slaveName, sizeof(slaveName)) != 0) {
        LOGE("ptsname_r failed");
        close(masterFd);
        return -1;
    }

    pid_t pid = fork();
    if (pid < 0) {
        LOGE("fork failed");
        close(masterFd);
        return -1;
    }

    if (pid == 0) {
        setsid();
        int slaveFd = open(slaveName, O_RDWR);
        if (slaveFd < 0) _exit(1);

        ioctl(slaveFd, TIOCSCTTY, 0);
        struct winsize ws = {(unsigned short)rows, (unsigned short)cols, 0, 0};
        ioctl(slaveFd, TIOCSWINSZ, &ws);

        dup2(slaveFd, STDIN_FILENO);
        dup2(slaveFd, STDOUT_FILENO);
        dup2(slaveFd, STDERR_FILENO);

        if (slaveFd > 2) close(slaveFd);
        close(masterFd);

        if (!cwd.empty()) chdir(cwd.c_str());

        std::vector<std::string> argv;
        argv.push_back(shell);
        argv.insert(argv.end(), args.begin(), args.end());

        char **cargv = stringVectorToCArray(argv);
        char **cenv = stringVectorToCArray(envVars);
        execve(shell.c_str(), cargv, cenv);
        _exit(127);
    }

    // parent
    int flags = fcntl(masterFd, F_GETFL, 0);
    fcntl(masterFd, F_SETFL, flags | O_NONBLOCK);

    // Setup epoll for efficient wait
    int epollFd = epoll_create1(0);
    if (epollFd >= 0) {
        struct epoll_event ev;
        ev.events = EPOLLIN;
        ev.data.fd = masterFd;
        epoll_ctl(epollFd, EPOLL_CTL_ADD, masterFd, &ev);
    }

    std::lock_guard<std::mutex> lock(sSessionsMutex);
    int sessionId = sNextSessionId++;
    sSessions[sessionId] = {sessionId, masterFd, pid, true, -1, epollFd};

    LOGI("PTY session %d started (epoll=%d)", sessionId, epollFd);
    return sessionId;
}

static PtySession *getSession(int sessionId) {
    std::lock_guard<std::mutex> lock(sSessionsMutex);
    auto it = sSessions.find(sessionId);
    if (it == sSessions.end()) return nullptr;
    return &it->second;
}

static bool removeSession(int sessionId) {
    std::lock_guard<std::mutex> lock(sSessionsMutex);
    auto it = sSessions.find(sessionId);
    if (it == sSessions.end()) return false;
    if (it->second.masterFd >= 0) close(it->second.masterFd);
    if (it->second.epollFd >= 0) close(it->second.epollFd);
    sSessions.erase(it);
    return true;
}

static bool checkChildStatus(PtySession *session) {
    if (!session->alive) return false;
    int status;
    pid_t result = waitpid(session->childPid, &status, WNOHANG);
    if (result == session->childPid) {
        session->alive = false;
        if (WIFEXITED(status)) session->exitCode = WEXITSTATUS(status);
        else if (WIFSIGNALED(status)) session->exitCode = 128 + WTERMSIG(status);
        else session->exitCode = -1;
        return true;
    } else if (result < 0 && errno == ECHILD) {
        session->alive = false;
        session->exitCode = -1;
        return true;
    }
    return false;
}

JNIEXPORT jint JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeStartPty(
    JNIEnv *env, jclass clazz, jstring shell, jobjectArray args, jobjectArray envVars, jstring cwd, jint rows, jint cols) {
    return createPtySession(jstringToString(env, shell), jobjectArrayToStringVector(env, args), jobjectArrayToStringVector(env, envVars), jstringToString(env, cwd), rows, cols);
}

JNIEXPORT jboolean JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeWritePty(
    JNIEnv *env, jclass clazz, jint sessionId, jbyteArray data) {
    PtySession *session = getSession(sessionId);
    if (session == nullptr || !session->alive) return JNI_FALSE;
    jsize len = env->GetArrayLength(data);
    jbyte *bytes = env->GetByteArrayElements(data, nullptr);
    ssize_t written = write(session->masterFd, bytes, (size_t) len);
    env->ReleaseByteArrayElements(data, bytes, JNI_ABORT);
    if (written < 0 && errno == EIO) session->alive = false;
    return (written >= 0) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeResizePty(
    JNIEnv *env, jclass clazz, jint sessionId, jint rows, jint cols) {
    PtySession *session = getSession(sessionId);
    if (session == nullptr) return JNI_FALSE;
    struct winsize ws = {(unsigned short)rows, (unsigned short)cols, 0, 0};
    return (ioctl(session->masterFd, TIOCSWINSZ, &ws) == 0) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeKillPty(
    JNIEnv *env, jclass clazz, jint sessionId) {
    PtySession *session = getSession(sessionId);
    if (session == nullptr) return JNI_FALSE;
    if (session->alive) {
        kill(session->childPid, SIGTERM);
        usleep(100000);
        if (waitpid(session->childPid, nullptr, WNOHANG) == 0) {
            kill(session->childPid, SIGKILL);
            waitpid(session->childPid, nullptr, 0);
        }
        session->alive = false;
    }
    return JNI_TRUE;
}

JNIEXPORT jboolean JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeClosePty(
    JNIEnv *env, jclass clazz, jint sessionId) {
    PtySession *session = getSession(sessionId);
    if (session == nullptr) return JNI_FALSE;
    if (session->alive) {
        kill(session->childPid, SIGKILL);
        waitpid(session->childPid, nullptr, WNOHANG);
    }
    removeSession(sessionId);
    return JNI_TRUE;
}

JNIEXPORT jbyteArray JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeReadPty(
    JNIEnv *env, jclass clazz, jint sessionId) {
    PtySession *session = getSession(sessionId);
    if (session == nullptr) return nullptr;
    checkChildStatus(session);
    if (!session->alive && session->masterFd < 0) return nullptr;

    // Quick epoll check — 1ms timeout for near-zero latency
    // The fd is O_NONBLOCK so read() returns EAGAIN immediately if no data.
    // epoll just avoids a wasted read() syscall when there's nothing.
    if (session->epollFd >= 0) {
        struct epoll_event events[1];
        int nfds = epoll_wait(session->epollFd, events, 1, 1);
        if (nfds <= 0) return nullptr;
    }

    char buffer[8192];
    ssize_t n = read(session->masterFd, buffer, sizeof(buffer));
    if (n <= 0) {
        if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) return nullptr;
        session->alive = false;
        checkChildStatus(session);
        return nullptr;
    }

    jbyteArray result = env->NewByteArray(n);
    if (result != nullptr) env->SetByteArrayRegion(result, 0, n, reinterpret_cast<jbyte *>(buffer));
    return result;
}

JNIEXPORT jint JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeGetExitCode(
    JNIEnv *env, jclass clazz, jint sessionId) {
    PtySession *session = getSession(sessionId);
    if (session == nullptr) return -2;
    checkChildStatus(session);
    return session->alive ? -1 : session->exitCode;
}
