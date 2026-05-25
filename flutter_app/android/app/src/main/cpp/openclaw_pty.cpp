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
    // Open master PTY
    int masterFd = posix_openpt(O_RDWR | O_NOCTTY);
    if (masterFd < 0) {
        LOGE("posix_openpt failed: %s", strerror(errno));
        return -1;
    }

    // Grant access
    if (grantpt(masterFd) != 0) {
        LOGE("grantpt failed: %s", strerror(errno));
        close(masterFd);
        return -1;
    }

    // Unlock
    if (unlockpt(masterFd) != 0) {
        LOGE("unlockpt failed: %s", strerror(errno));
        close(masterFd);
        return -1;
    }

    // Get slave name
    char slaveName[256];
    if (ptsname_r(masterFd, slaveName, sizeof(slaveName)) != 0) {
        LOGE("ptsname_r failed: %s", strerror(errno));
        close(masterFd);
        return -1;
    }

    // Fork
    pid_t pid = fork();
    if (pid < 0) {
        LOGE("fork failed: %s", strerror(errno));
        close(masterFd);
        return -1;
    }

    if (pid == 0) {
        // ── Child process ──
        // Create new session
        setsid();

        // Open slave
        int slaveFd = open(slaveName, O_RDWR);
        if (slaveFd < 0) {
            LOGE("child: open slave failed: %s", strerror(errno));
            _exit(1);
        }

        // Set controlling terminal
        if (ioctl(slaveFd, TIOCSCTTY, 0) != 0) {
            LOGE("child: TIOCSCTTY failed: %s", strerror(errno));
        }

        // Configure terminal size
        struct winsize ws;
        ws.ws_row = (unsigned short) rows;
        ws.ws_col = (unsigned short) cols;
        ws.ws_xpixel = 0;
        ws.ws_ypixel = 0;
        ioctl(slaveFd, TIOCSWINSZ, &ws);

        // Dup2 stdin/stdout/stderr to slave
        dup2(slaveFd, STDIN_FILENO);
        dup2(slaveFd, STDOUT_FILENO);
        dup2(slaveFd, STDERR_FILENO);

        // Close extra fds
        if (slaveFd > 2) close(slaveFd);
        close(masterFd);

        // Change directory if provided
        if (!cwd.empty()) {
            chdir(cwd.c_str());
        }

        // Build argv: [shell, ...args]
        std::vector<std::string> argv;
        argv.push_back(shell);
        argv.insert(argv.end(), args.begin(), args.end());

        char **cargv = stringVectorToCArray(argv);
        char **cenv = stringVectorToCArray(envVars);

        // Exec
        execve(shell.c_str(), cargv, cenv);

        // If execve fails
        LOGE("execve failed for %s: %s", shell.c_str(), strerror(errno));
        freeCArray(cargv);
        freeCArray(cenv);
        _exit(127);
    }

    // ── Parent process ──
    // Close slave fd in parent
    // (slaveName was opened by child, we just track master)

    // Set master to non-blocking for reads
    int flags = fcntl(masterFd, F_GETFL, 0);
    fcntl(masterFd, F_SETFL, flags | O_NONBLOCK);

    // Allocate session ID
    std::lock_guard<std::mutex> lock(sSessionsMutex);
    int sessionId = sNextSessionId++;
    sSessions[sessionId] = {sessionId, masterFd, pid, true, -1};

    LOGI("PTY session %d started: pid=%d, shell=%s, %dx%d",
         sessionId, pid, shell.c_str(), cols, rows);

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
    if (it->second.masterFd >= 0) {
        close(it->second.masterFd);
    }
    sSessions.erase(it);
    return true;
}

static bool checkChildStatus(PtySession *session) {
    if (!session->alive) return false;
    int status;
    pid_t result = waitpid(session->childPid, &status, WNOHANG);
    if (result == session->childPid) {
        session->alive = false;
        if (WIFEXITED(status)) {
            session->exitCode = WEXITSTATUS(status);
        } else if (WIFSIGNALED(status)) {
            session->exitCode = 128 + WTERMSIG(status);
        } else {
            session->exitCode = -1;
        }
        LOGI("PTY session %d exited with code %d", session->sessionId, session->exitCode);
        return true;
    } else if (result < 0 && errno == ECHILD) {
        // Process has already been reaped (e.g., by kill)
        session->alive = false;
        session->exitCode = -1;
        return true;
    }
    return false;
}

// ──────────────────────────────────────────────
// JNI implementations
// ──────────────────────────────────────────────

JNIEXPORT jint JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeStartPty(
    JNIEnv *env, jclass clazz,
    jstring shell,
    jobjectArray args,
    jobjectArray envVars,
    jstring cwd,
    jint rows,
    jint cols) {

    std::string shellStr = jstringToString(env, shell);
    std::vector<std::string> argsVec = jobjectArrayToStringVector(env, args);
    std::vector<std::string> envVec = jobjectArrayToStringVector(env, envVars);
    std::string cwdStr = jstringToString(env, cwd);

    return createPtySession(shellStr, argsVec, envVec, cwdStr, rows, cols);
}

JNIEXPORT jboolean JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeWritePty(
    JNIEnv *env, jclass clazz,
    jint sessionId,
    jbyteArray data) {

    PtySession *session = getSession(sessionId);
    if (session == nullptr || !session->alive) return JNI_FALSE;

    jsize len = env->GetArrayLength(data);
    jbyte *bytes = env->GetByteArrayElements(data, nullptr);

    ssize_t written = write(session->masterFd, bytes, (size_t) len);

    env->ReleaseByteArrayElements(data, bytes, JNI_ABORT);

    if (written < 0) {
        if (errno == EIO) {
            // Slave side closed
            session->alive = false;
        }
        return JNI_FALSE;
    }
    return JNI_TRUE;
}

JNIEXPORT jboolean JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeResizePty(
    JNIEnv *env, jclass clazz,
    jint sessionId,
    jint rows,
    jint cols) {

    PtySession *session = getSession(sessionId);
    if (session == nullptr) return JNI_FALSE;

    struct winsize ws;
    ws.ws_row = (unsigned short) rows;
    ws.ws_col = (unsigned short) cols;
    ws.ws_xpixel = 0;
    ws.ws_ypixel = 0;

    if (ioctl(session->masterFd, TIOCSWINSZ, &ws) != 0) {
        LOGE("resize failed: %s", strerror(errno));
        return JNI_FALSE;
    }
    return JNI_TRUE;
}

JNIEXPORT jboolean JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeKillPty(
    JNIEnv *env, jclass clazz,
    jint sessionId) {

    PtySession *session = getSession(sessionId);
    if (session == nullptr) return JNI_FALSE;

    if (!session->alive) return JNI_TRUE;

    // Send SIGTERM first
    kill(session->childPid, SIGTERM);

    // Wait a bit, then SIGKILL if still running
    usleep(100000); // 100ms
    int status;
    pid_t result = waitpid(session->childPid, &status, WNOHANG);
    if (result == 0) {
        // Still running, force kill
        kill(session->childPid, SIGKILL);
        usleep(50000);
        waitpid(session->childPid, &status, WNOHANG);
    }

    session->alive = false;
    if (WIFEXITED(status)) {
        session->exitCode = WEXITSTATUS(status);
    } else if (WIFSIGNALED(status)) {
        session->exitCode = 128 + WTERMSIG(status);
    }

    LOGI("PTY session %d killed", sessionId);
    return JNI_TRUE;
}

JNIEXPORT jboolean JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeClosePty(
    JNIEnv *env, jclass clazz,
    jint sessionId) {

    PtySession *session = getSession(sessionId);
    if (session == nullptr) return JNI_FALSE;

    // Kill if still alive
    if (session->alive) {
        kill(session->childPid, SIGKILL);
        waitpid(session->childPid, nullptr, WNOHANG);
    }

    // Close master fd
    if (session->masterFd >= 0) {
        close(session->masterFd);
    }

    removeSession(sessionId);
    LOGI("PTY session %d closed", sessionId);
    return JNI_TRUE;
}

JNIEXPORT jbyteArray JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeReadPty(
    JNIEnv *env, jclass clazz,
    jint sessionId) {

    PtySession *session = getSession(sessionId);
    if (session == nullptr) return nullptr;

    // Check if child has exited
    checkChildStatus(session);

    if (!session->alive && session->masterFd < 0) return nullptr;

    // Read available data (up to 4K)
    char buffer[4096];
    ssize_t n = read(session->masterFd, buffer, sizeof(buffer));

    if (n < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            // No data available
            return nullptr;
        }
        if (errno == EIO) {
            // Slave closed, process likely exited
            session->alive = false;
            checkChildStatus(session);
            return nullptr;
        }
        return nullptr;
    }

    if (n == 0) {
        // EOF
        session->alive = false;
        checkChildStatus(session);
        return nullptr;
    }

    jbyteArray result = env->NewByteArray(n);
    if (result != nullptr) {
        env->SetByteArrayRegion(result, 0, n, reinterpret_cast<jbyte *>(buffer));
    }
    return result;
}

JNIEXPORT jint JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeGetExitCode(
    JNIEnv *env, jclass clazz,
    jint sessionId) {

    PtySession *session = getSession(sessionId);
    if (session == nullptr) return -2;

    checkChildStatus(session);

    if (session->alive) return -1;
    return session->exitCode;
}
