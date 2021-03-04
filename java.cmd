:<<"::CMDLITERAL"
@ECHO OFF
GOTO :CMDSCRIPT
::CMDLITERAL

set -eux

VERSION=java-cmd-v1
COMPANY_DIR="Mikhail Filippov"
TARGET_DIR="${TEMPDIR:-/tmp}/$COMPANY_DIR"

warn () {
    echo "$*"
}

die () {
    echo
    echo "$*"
    echo
    exit 1
}

# OS specific support (must be 'true' or 'false').
cygwin=false
msys=false
darwin=false
nonstop=false
case "`uname`" in
  CYGWIN* )
    cygwin=true
    ;;
  Darwin* )
    darwin=true
    ;;
  MINGW* )
    msys=true
    ;;
  NONSTOP* )
    nonstop=true
    ;;
esac

if [ "$darwin" = "true" ]; then
    case $(uname -m) in
      x86_64)
        JVM_TEMP_FILE=$TARGET_DIR/jvm-macosx-x64.tar.gz
        JVM_URL=https://corretto.aws/downloads/resources/11.0.9.12.1/amazon-corretto-11.0.9.12.1-macosx-x64.tar.gz
        JVM_TARGET_DIR=$TARGET_DIR/amazon-corretto-11.0.9.12.1-macosx-x64-$VERSION
        ;;
      arm64)
        JVM_TEMP_FILE=$TARGET_DIR/jvm-macosx-arm64.tar.gz
        JVM_URL=https://cdn.azul.com/zulu/bin/zulu11.45.27-ca-jdk11.0.10-macosx_aarch64.tar.gz
        JVM_TARGET_DIR=$TARGET_DIR/zulu-11.0.10-macosx-arm64-$VERSION
        ;;
      *)
        echo "Unknown architecture $(uname -m)" >&2; exit 1
        ;;
    esac
else
    case $(uname -m) in
      x86_64)
        JVM_TEMP_FILE=$TARGET_DIR/jvm-linux-x64.tar.gz
        JVM_URL=https://corretto.aws/downloads/resources/11.0.9.12.1/amazon-corretto-11.0.9.12.1-linux-x64.tar.gz
        JVM_TARGET_DIR=$TARGET_DIR/amazon-corretto-11.0.9.12.1-linux-x64-$VERSION
        ;;
      aarch64)
        JVM_TEMP_FILE=$TARGET_DIR/jvm-linux-aarch64.tar.gz
        JVM_URL=https://corretto.aws/downloads/resources/11.0.9.12.1/amazon-corretto-11.0.9.12.1-linux-aarch64.tar.gz
        JVM_TARGET_DIR=$TARGET_DIR/amazon-corretto-11.0.9.12.1-linux-aarch64-$VERSION
        ;;
      *)
        echo "Unknown architecture $(uname -m)" >&2; exit 1
        ;;
    esac
fi

set -e

if [ -e "$JVM_TARGET_DIR/.flag" ] && [ -n "$(ls "$JVM_TARGET_DIR")" ] && [ "x$(cat "$JVM_TARGET_DIR/.flag")" = "x${JVM_URL}" ]; then
    # Everything is up-to-date in $JVM_TARGET_DIR, do nothing
    true
else
  warn "Downloading $JVM_URL to $JVM_TEMP_FILE"

  rm -f "$JVM_TEMP_FILE"
  mkdir -p "$TARGET_DIR"
  if command -v curl >/dev/null 2>&1; then
      if [ -t 1 ]; then CURL_PROGRESS="--progress-bar"; else CURL_PROGRESS="--silent --show-error"; fi
      curl $CURL_PROGRESS --output "${JVM_TEMP_FILE}" "$JVM_URL"
  elif command -v wget >/dev/null 2>&1; then
      if [ -t 1 ]; then WGET_PROGRESS=""; else WGET_PROGRESS="-nv"; fi
      wget $WGET_PROGRESS -O "${JVM_TEMP_FILE}" "$JVM_URL"
  else
      die "ERROR: Please install wget or curl"
  fi

  warn "Extracting $JVM_TEMP_FILE to $JVM_TARGET_DIR"
  rm -rf "$JVM_TARGET_DIR"
  mkdir -p "$JVM_TARGET_DIR"

  tar -x -f "$JVM_TEMP_FILE" -C "$JVM_TARGET_DIR"
  rm -f "$JVM_TEMP_FILE"

  echo "$JVM_URL" >"$JVM_TARGET_DIR/.flag"
fi

JAVA_HOME=
for d in "$JVM_TARGET_DIR" "$JVM_TARGET_DIR"/* "$JVM_TARGET_DIR/Contents/Home" "$JVM_TARGET_DIR/"*/Contents/Home; do
  echo "$d"
  if [ -e "$d/bin/java" ]; then
    JAVA_HOME="$d"
  fi
done

if [ '!' -e "$JAVA_HOME/bin/java" ]; then
  die "Unable to find bin/java under $JVM_TARGET_DIR"
fi

JAVA_HOME=$JAVA_HOME exec "$JAVA_HOME/bin/java" "$@"

:CMDSCRIPT

setlocal
set VERSION=java-cmd-v1
set COMPANY_NAME=Mikhail Filippov
set TARGET_DIR=%LOCALAPPDATA%\Temp\%COMPANY_NAME%\
set JVM_TARGET_DIR=%TARGET_DIR%amazon-corretto-11.0.9.12.1-windows-x64-jdk-%VERSION%\
set JVM_TEMP_FILE=jvm-windows-x64.zip
set JVM_URL=https://corretto.aws/downloads/resources/11.0.9.12.1/amazon-corretto-11.0.9.12.1-windows-x64-jdk.zip

set POWERSHELL=%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe

if not exist "%JVM_TARGET_DIR%" MD "%JVM_TARGET_DIR%"

if not exist "%JVM_TARGET_DIR%.flag" goto downloadAndExtractJvm

set /p CURRENT_FLAG=<"%JVM_TARGET_DIR%.flag"
if "%CURRENT_FLAG%" == "%JVM_URL%" goto continueWithJvm

:downloadAndExtractJvm

cd /d "%TARGET_DIR%"
if errorlevel 1 goto fail

echo Downloading %JVM_URL% to %TARGET_DIR%%JVM_TEMP_FILE%
if exist "%JVM_TEMP_FILE%" DEL /F "%JVM_TEMP_FILE%"
"%POWERSHELL%" -nologo -noprofile -Command "Set-StrictMode -Version 3.0; $ErrorActionPreference = \"Stop\"; (New-Object Net.WebClient).DownloadFile('%JVM_URL%', '%JVM_TEMP_FILE%')"
if errorlevel 1 goto fail

rmdir /S /Q "%JVM_TARGET_DIR%"
if errorlevel 1 goto fail

mkdir "%JVM_TARGET_DIR%"
if errorlevel 1 goto fail

cd /d "%JVM_TARGET_DIR%"
if errorlevel 1 goto fail

echo Extracting %TARGET_DIR%%JVM_TEMP_FILE% to %JVM_TARGET_DIR%
"%POWERSHELL%" -nologo -noprofile -command "Set-StrictMode -Version 3.0; $ErrorActionPreference = \"Stop\"; Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::ExtractToDirectory('..\\%JVM_TEMP_FILE%', '.');"
if errorlevel 1 goto fail

del /F "..\%JVM_TEMP_FILE%"
if errorlevel 1 goto fail

echo %JVM_URL%>"%JVM_TARGET_DIR%.flag"
if errorlevel 1 goto fail

:continueWithJvm

set JAVA_HOME=
for /d %%d in ("%JVM_TARGET_DIR%"*) do if exist "%%d\bin\java.exe" set JAVA_HOME=%%d
if not exist "%JAVA_HOME%\bin\java.exe" (
  echo Unable to find java.exe under %JVM_TARGET_DIR%
  goto fail
)

:continueWithJavaHome

call "%JAVA_HOME%\bin\java.exe" %*
exit /B %ERRORLEVEL%
endlocal
