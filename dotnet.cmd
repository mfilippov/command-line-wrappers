:<<"::CMDLITERAL"
@ECHO OFF
GOTO :CMDSCRIPT
::CMDLITERAL

VERSION=dotnet-cmd-v1
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
    DOTNET_TEMP_FILE=$TARGET_DIR/dotnet-sdk-5.0.100-osx-x64.tar.gz
    DOTNET_URL=https://download.visualstudio.microsoft.com/download/pr/0871336f-9a83-4ce4-80ca-625d03003369/2eb78456e0b106e9515dc03898d3867a/dotnet-sdk-5.0.100-osx-x64.tar.gz
    DOTNET_TARGET_DIR=$TARGET_DIR/dotnet-sdk-5.0.100-osx-x64-$VERSION
else
    DOTNET_TEMP_FILE=$TARGET_DIR/dotnet-sdk-5.0.100-linux-x64.tar.gz
    DOTNET_URL=https://download.visualstudio.microsoft.com/download/pr/820db713-c9a5-466e-b72a-16f2f5ed00e2/628aa2a75f6aa270e77f4a83b3742fb8/dotnet-sdk-5.0.100-linux-x64.tar.gz
    DOTNET_TARGET_DIR=$TARGET_DIR/dotnet-sdk-5.0.100-linux-x64-$VERSION
fi

set -e

if [ -e "$DOTNET_TARGET_DIR/.flag" ] && [ -n "$(ls "$DOTNET_TARGET_DIR")" ] && [ "x$(cat "$DOTNET_TARGET_DIR/.flag")" = "x${DOTNET_URL}" ]; then
    # Everything is up-to-date in $DOTNET_TARGET_DIR, do nothing
    true
else
  warn "Downloading $DOTNET_URL to $DOTNET_TEMP_FILE"

  rm -f "$DOTNET_TEMP_FILE"
  mkdir -p "$TARGET_DIR"
  if command -v curl >/dev/null 2>&1; then
      if [ -t 1 ]; then CURL_PROGRESS="--progress-bar"; else CURL_PROGRESS="--silent --show-error"; fi
      curl $CURL_PROGRESS --output "${DOTNET_TEMP_FILE}" "$DOTNET_URL"
  elif command -v wget >/dev/null 2>&1; then
      if [ -t 1 ]; then WGET_PROGRESS=""; else WGET_PROGRESS="-nv"; fi
      wget $WGET_PROGRESS -O "${DOTNET_TEMP_FILE}" "$DOTNET_URL"
  else
      die "ERROR: Please install wget or curl"
  fi

  warn "Extracting $DOTNET_TEMP_FILE to $DOTNET_TARGET_DIR"
  rm -rf "$DOTNET_TARGET_DIR"
  mkdir -p "$DOTNET_TARGET_DIR"

  tar -x -f "$DOTNET_TEMP_FILE" -C "$DOTNET_TARGET_DIR"
  rm -f "$DOTNET_TEMP_FILE"

  echo "$DOTNET_URL" >"$DOTNET_TARGET_DIR/.flag"
fi

if [ '!' -e "$DOTNET_TARGET_DIR/dotnet" ]; then
  die "Unable to find dotnet under $DOTNET_TARGET_DIR"
fi

exec "$DOTNET_TARGET_DIR/dotnet" "$@"

:CMDSCRIPT

setlocal
set VERSION=dotnet-cmd-v1
set COMPANY_NAME=Mikhail Filippov
set TARGET_DIR=%LOCALAPPDATA%\Temp\%COMPANY_NAME%\
set DOTNET_TARGET_DIR=%TARGET_DIR%dotnet-sdk-5.0.100-win-x64-%VERSION%\
set DOTNET_TEMP_FILE=dotnet-sdk-5.0.100-win-x64.zip
set DOTNET_URL=https://download.visualstudio.microsoft.com/download/pr/7b78bdaa-d0ac-41c4-9fdc-5820d7dc79b6/cea499dd314ba6394ccea51a2a2dcda9/dotnet-sdk-5.0.100-win-x64.zip


set POWERSHELL=%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe

if not exist "%DOTNET_TARGET_DIR%" MD "%DOTNET_TARGET_DIR%"

if not exist "%DOTNET_TARGET_DIR%.flag" goto downloadAndExtractDotNet

set /p CURRENT_FLAG=<"%DOTNET_TARGET_DIR%.flag"
if "%CURRENT_FLAG%" == "%DOTNET_URL%" goto continueWithDotNet

:downloadAndExtractDotNet

cd /d "%TARGET_DIR%"
if errorlevel 1 goto fail

echo Downloading %DOTNET_URL% to %TARGET_DIR%%DOTNET_TEMP_FILE%
if exist "%DOTNET_TEMP_FILE%" DEL /F "%DOTNET_TEMP_FILE%"
"%POWERSHELL%" -nologo -noprofile -Command "Set-StrictMode -Version 3.0; $ErrorActionPreference = \"Stop\"; (New-Object Net.WebClient).DownloadFile('%DOTNET_URL%', '%DOTNET_TEMP_FILE%')"
if errorlevel 1 goto fail

rmdir /S /Q "%DOTNET_TARGET_DIR%"
if errorlevel 1 goto fail

mkdir "%DOTNET_TARGET_DIR%"
if errorlevel 1 goto fail

cd /d %DOTNET_TARGET_DIR%"
if errorlevel 1 goto fail

echo Extracting %TARGET_DIR%%DOTNET_TEMP_FILE% to %DOTNET_TARGET_DIR%
"%POWERSHELL%" -nologo -noprofile -command "Set-StrictMode -Version 3.0; $ErrorActionPreference = \"Stop\"; Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::ExtractToDirectory('..\\%DOTNET_TEMP_FILE%', '.');"
if errorlevel 1 goto fail

del /F "..\%DOTNET_TEMP_FILE%"
if errorlevel 1 goto fail

echo %DOTNET_URL%>"%DOTNET_TARGET_DIR%.flag"
if errorlevel 1 goto fail

:continueWithDotNet

if not exist "%DOTNET_TARGET_DIR%\dotnet.exe" (
  echo Unable to find dotnet.exe under %DOTNET_TARGET_DIR%
  goto fail
)

call "%DOTNET_TARGET_DIR%\dotnet.exe" %*
exit /B %ERRORLEVEL%
endlocal

:fail
echo "FAIL"
exit /b 1