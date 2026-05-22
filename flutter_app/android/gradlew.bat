@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ###############################################################
rem
rem  Gradle startup script for Windows
rem  Compatible with:
rem   - Flutter 3.44+
rem   - Gradle 8.14
rem   - AGP 8.10.x
rem   - Kotlin 2.2.20
rem   - JDK 21
rem
rem ###############################################################

set DIRNAME=%~dp0

if "%DIRNAME%"=="" (
    set DIRNAME=.
)

set APP_BASE_NAME=%~n0
set APP_HOME=%DIRNAME%

rem Default JVM options
set DEFAULT_JVM_OPTS="-Xmx512m" "-Xms128m"

rem ###############################################################
rem Find Java
rem ###############################################################

if defined JAVA_HOME goto findJavaFromJavaHome

set JAVA_EXE=java.exe

%JAVA_EXE% -version >NUL 2>&1

if %ERRORLEVEL% EQU 0 goto execute

echo.
echo ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.
echo.
echo Please install JDK 21 and set JAVA_HOME correctly.
echo.

exit /b 1

:findJavaFromJavaHome

set JAVA_HOME=%JAVA_HOME:"=%

set JAVA_EXE=%JAVA_HOME%\bin\java.exe

if exist "%JAVA_EXE%" goto execute

echo.
echo ERROR: JAVA_HOME is set to an invalid directory:
echo.
echo %JAVA_HOME%
echo.
echo Please set JAVA_HOME to a valid JDK 21 installation.
echo.

exit /b 1

rem ###############################################################
rem Execute Gradle
rem ###############################################################

:execute

set CLASSPATH=%APP_HOME%\gradle\wrapper\gradle-wrapper.jar

if not exist "%CLASSPATH%" (
    echo.
    echo ERROR: Could not find gradle-wrapper.jar
    echo Expected path:
    echo %CLASSPATH%
    echo.
    exit /b 1
)

"%JAVA_EXE%" ^
    %DEFAULT_JVM_OPTS% ^
    %JAVA_OPTS% ^
    %GRADLE_OPTS% ^
    "-Dorg.gradle.appname=%APP_BASE_NAME%" ^
    -classpath "%CLASSPATH%" ^
    org.gradle.wrapper.GradleWrapperMain %*

set EXIT_CODE=%ERRORLEVEL%

if %EXIT_CODE% NEQ 0 (
    echo.
    echo Gradle execution failed with exit code %EXIT_CODE%.
    echo.
)

endlocal & exit /b %EXIT_CODE%