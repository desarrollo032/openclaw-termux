#ifndef OPENCLAW_PTY_H
#define OPENCLAW_PTY_H

#include <jni.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Start a PTY session running the given shell.
 *
 * @param env       JNI environment
 * @param clazz     JNI class
 * @param shell     Path to the executable (e.g., /system/bin/sh)
 * @param args      Array of argument strings (java.lang.String[])
 * @param envVars   Array of environment strings "KEY=VALUE" (java.lang.String[])
 * @param cwd       Working directory (nullable)
 * @param rows      Terminal rows
 * @param cols      Terminal columns
 * @return          Session ID (positive int) on success, -1 on failure
 */
JNIEXPORT jint JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeStartPty(
    JNIEnv *env, jclass clazz,
    jstring shell,
    jobjectArray args,
    jobjectArray envVars,
    jstring cwd,
    jint rows,
    jint cols);

/**
 * Write data to a PTY session.
 *
 * @param env       JNI environment
 * @param clazz     JNI class
 * @param sessionId Session ID returned by nativeStartPty
 * @param data      Byte array of data to write
 * @return          true on success, false on failure
 */
JNIEXPORT jboolean JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeWritePty(
    JNIEnv *env, jclass clazz,
    jint sessionId,
    jbyteArray data);

/**
 * Resize a PTY session.
 *
 * @param env       JNI environment
 * @param clazz     JNI class
 * @param sessionId Session ID
 * @param rows      New row count
 * @param cols      New column count
 * @return          true on success, false on failure
 */
JNIEXPORT jboolean JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeResizePty(
    JNIEnv *env, jclass clazz,
    jint sessionId,
    jint rows,
    jint cols);

/**
 * Kill a PTY session (send SIGTERM, then SIGKILL if needed).
 *
 * @param env       JNI environment
 * @param clazz     JNI class
 * @param sessionId Session ID
 * @return          true on success, false on failure
 */
JNIEXPORT jboolean JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeKillPty(
    JNIEnv *env, jclass clazz,
    jint sessionId);

/**
 * Close a PTY session (cleanup all resources).
 *
 * @param env       JNI environment
 * @param clazz     JNI class
 * @param sessionId Session ID
 * @return          true on success, false on failure
 */
JNIEXPORT jboolean JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeClosePty(
    JNIEnv *env, jclass clazz,
    jint sessionId);

/**
 * Read available data from a PTY session (non-blocking).
 *
 * @param env       JNI environment
 * @param clazz     JNI class
 * @param sessionId Session ID
 * @return          Byte array of available data, or NULL if nothing available / session dead
 */
JNIEXPORT jbyteArray JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeReadPty(
    JNIEnv *env, jclass clazz,
    jint sessionId);

/**
 * Get the exit code of a finished session.
 *
 * @param env       JNI environment
 * @param clazz     JNI class
 * @param sessionId Session ID
 * @return          Exit code if process has exited, -1 if still running, -2 if error
 */
JNIEXPORT jint JNICALL
Java_com_nxg_openclawproot_OpenClawPtyBridge_nativeGetExitCode(
    JNIEnv *env, jclass clazz,
    jint sessionId);

#ifdef __cplusplus
}
#endif

#endif // OPENCLAW_PTY_H
