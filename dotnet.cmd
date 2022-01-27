:<<"::CMDLITERAL"
@ECHO OFF
GOTO :CMDSCRIPT
::CMDLITERAL

set -eu

SCRIPT_VERSION=dotnet-cmd-v2
COMPANY_DIR="Mikhail Filippov"
TARGET_DIR="${TEMPDIR:-$HOME/.local/share}/$COMPANY_DIR/dotnet-cmd"
KEEP_ROSETTA2=false

warn () {
    echo "$*"
}

die () {
    echo
    echo "$*"
    echo
    exit 1
}

retry_on_error () {
  local n="$1"
  shift

  for i in $(seq 2 "$n"); do
    "$@" 2>&1 && return || echo "WARNING: Command '$1' returned non-zero exit status $?, try again"
  done
  "$@"
}

is_linux_musl () {
  (ldd --version 2>&1 || true) | grep -q musl
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

DOTNET_TEMP_FILE=$TARGET_DIR/dotnet-sdk-temp.tar.gz
if [ "$darwin" = "true" ]; then
  DOTNET_ARCH=$(uname -m)
  if ! $KEEP_ROSETTA2 && [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || true)" = "1" ]; then
    DOTNET_ARCH=arm64
  fi
  case $DOTNET_ARCH in
    x86_64)
      DOTNET_URL=https://cache-redirector.jetbrains.com/download.visualstudio.microsoft.com/download/pr/4a39aac8-74b7-4366-81cd-4fcce0bd8354/02a581437c26bd88f5afc6ccc81d9637/dotnet-sdk-6.0.101-osx-x64.tar.gz
      DOTNET_TARGET_DIR=$TARGET_DIR/dotnet-sdk-6.0.101-osx-x64-$SCRIPT_VERSION
      ;;
    arm64)
      DOTNET_URL=https://cache-redirector.jetbrains.com/download.visualstudio.microsoft.com/download/pr/c1351f4c-d2e7-4066-a153-b6130f677bcc/161b0c331a5da2e080c7ad3a5ae2b185/dotnet-sdk-6.0.101-osx-arm64.tar.gz
      DOTNET_TARGET_DIR=$TARGET_DIR/dotnet-sdk-6.0.101-osx-arm64-$SCRIPT_VERSION
      ;;
    *)
      echo "Unknown architecture $(uname -m)" >&2; exit 1
      ;;
  esac
else
  case $(uname -m) in
    x86_64)
      if is_linux_musl; then
        DOTNET_URL=https://cache-redirector.jetbrains.com/download.visualstudio.microsoft.com/download/pr/bd94779d-c7c4-47fd-b80a-0088caa0afc6/40f115bbf4c068359e7a066fe0b03dbc/dotnet-sdk-6.0.101-linux-musl-x64.tar.gz
        DOTNET_TARGET_DIR=$TARGET_DIR/dotnet-sdk-6.0.101-linux-musl-x64-$SCRIPT_VERSION
      else
        DOTNET_URL=https://cache-redirector.jetbrains.com/download.visualstudio.microsoft.com/download/pr/ede8a287-3d61-4988-a356-32ff9129079e/bdb47b6b510ed0c4f0b132f7f4ad9d5a/dotnet-sdk-6.0.101-linux-x64.tar.gz
        DOTNET_TARGET_DIR=$TARGET_DIR/dotnet-sdk-6.0.101-linux-x64-$SCRIPT_VERSION
      fi
      ;;
    aarch64)
      if is_linux_musl; then
        DOTNET_URL=https://cache-redirector.jetbrains.com/download.visualstudio.microsoft.com/download/pr/ca800552-c6bb-4f1d-9d0c-f76f37edc8cb/f2c281c7f66347866086a3b0cf2b338e/dotnet-sdk-6.0.101-linux-musl-arm64.tar.gz
        DOTNET_TARGET_DIR=$TARGET_DIR/dotnet-sdk-6.0.101-linux-musl-arm64-$SCRIPT_VERSION
      else
        DOTNET_URL=https://cache-redirector.jetbrains.com/download.visualstudio.microsoft.com/download/pr/d43345e2-f0d7-4866-b56e-419071f30ebe/68debcece0276e9b25a65ec5798cf07b/dotnet-sdk-6.0.101-linux-arm64.tar.gz
        DOTNET_TARGET_DIR=$TARGET_DIR/dotnet-sdk-6.0.101-linux-arm64-$SCRIPT_VERSION
      fi
      ;;
    armv7l | armv8l)
      if is_linux_musl; then
        DOTNET_URL=https://cache-redirector.jetbrains.com/download.visualstudio.microsoft.com/download/pr/3a7ae99d-a36b-43c3-bd8e-14df916c7b56/b8e0802880ca73c19f56ac8ce5b95c1e/dotnet-sdk-6.0.101-linux-musl-arm.tar.gz
        DOTNET_TARGET_DIR=$TARGET_DIR/dotnet-sdk-6.0.101-linux-musl-arm-$SCRIPT_VERSION
      else
        DOTNET_URL=https://cache-redirector.jetbrains.com/download.visualstudio.microsoft.com/download/pr/72888385-910d-4ef3-bae2-c08c28e42af0/59be90572fdcc10766f1baf5ac39529a/dotnet-sdk-6.0.101-linux-arm.tar.gz
        DOTNET_TARGET_DIR=$TARGET_DIR/dotnet-sdk-6.0.101-linux-arm-$SCRIPT_VERSION
      fi
      ;;
    *)
      echo "Unknown architecture $(uname -m)" >&2; exit 1
      ;;
  esac
fi

if grep -q -x "$DOTNET_URL" "$DOTNET_TARGET_DIR/.flag" 2>/dev/null; then
  # Everything is up-to-date in $DOTNET_TARGET_DIR, do nothing
  true
else
while true; do  # Note(k15tfu): for goto
  mkdir -p "$TARGET_DIR"

  LOCK_FILE="$TARGET_DIR/.dotnet-cmd-lock.pid"
  TMP_LOCK_FILE="$TARGET_DIR/.tmp.$$.pid"
  echo $$ >"$TMP_LOCK_FILE"

  while ! ln "$TMP_LOCK_FILE" "$LOCK_FILE" 2>/dev/null; do
    LOCK_OWNER=$(cat "$LOCK_FILE" 2>/dev/null || true)
    while [ -n "$LOCK_OWNER" ] && ps -p $LOCK_OWNER >/dev/null; do
      warn "Waiting for the process $LOCK_OWNER to finish bootstrap dotnet.cmd"
      sleep 1
      LOCK_OWNER=$(cat "$LOCK_FILE" 2>/dev/null || true)

      # Hurry up, bootstrap is ready..
      if grep -q -x "$DOTNET_URL" "$DOTNET_TARGET_DIR/.flag" 2>/dev/null; then
        break 3  # Note(k15tfu): goto out of the outer if-else block.
      fi
    done

    if [ -n "$LOCK_OWNER" ] && grep -q -x $LOCK_OWNER "$LOCK_FILE" 2>/dev/null; then
      die "ERROR: The lock file $LOCK_FILE still exists on disk after the owner process $LOCK_OWNER exited"
    fi
  done

  trap "rm -f \"$LOCK_FILE\"" EXIT
  rm "$TMP_LOCK_FILE"

  if ! grep -q -x "$DOTNET_URL" "$DOTNET_TARGET_DIR/.flag" 2>/dev/null; then
    warn "Downloading $DOTNET_URL to $DOTNET_TEMP_FILE"

    rm -f "$DOTNET_TEMP_FILE"
    if command -v curl >/dev/null 2>&1; then
      if [ -t 1 ]; then CURL_PROGRESS="--progress-bar"; else CURL_PROGRESS="--silent --show-error"; fi
      retry_on_error 5 curl -L $CURL_PROGRESS --output "${DOTNET_TEMP_FILE}" "$DOTNET_URL"
    elif command -v wget >/dev/null 2>&1; then
      if [ -t 1 ]; then WGET_PROGRESS=""; else WGET_PROGRESS="-nv"; fi
      retry_on_error 5 wget $WGET_PROGRESS -O "${DOTNET_TEMP_FILE}" "$DOTNET_URL"
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

  rm "$LOCK_FILE"
  break
done
fi

if [ ! -x "$DOTNET_TARGET_DIR/dotnet" ]; then
  die "Unable to find dotnet under $DOTNET_TARGET_DIR"
fi

exec "$DOTNET_TARGET_DIR/dotnet" "$@"

:CMDSCRIPT

setlocal
set SCRIPT_VERSION=v2
set COMPANY_NAME=Mikhail Filippov
set TARGET_DIR=%LOCALAPPDATA%\%COMPANY_NAME%\dotnet-cmd\
set DOTNET_TARGET_DIR=%TARGET_DIR%dotnet-sdk-6.0.101-win-x64-%SCRIPT_VERSION%\
set DOTNET_TEMP_FILE=%TARGET_DIR%dotnet-sdk-temp.zip
set DOTNET_URL=https://cache-redirector.jetbrains.com/download.visualstudio.microsoft.com/download/pr/8e55ce37-9740-41b7-a758-f731043060da/4b8bfd4aad9d322bf501ca9e473e35c5/dotnet-sdk-6.0.101-win-x64.zip

set POWERSHELL=%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe

if not exist "%DOTNET_TARGET_DIR%.flag" goto downloadAndExtractDotNet

set /p CURRENT_FLAG=<"%DOTNET_TARGET_DIR%.flag"
if "%CURRENT_FLAG%" == "%DOTNET_URL%" goto continueWithDotNet

:downloadAndExtractDotNet

set DOWNLOAD_AND_EXTRACT_DOTNET_PS1= ^
Set-StrictMode -Version 3.0; ^
$ErrorActionPreference = 'Stop'; ^
 ^
$createdNew = $false; ^
$lock = New-Object System.Threading.Mutex($true, 'Global\dotnet-cmd-lock', [ref]$createdNew); ^
if (-not $createdNew) { ^
    Write-Host 'Waiting for the other process to finish bootstrap dotnet.cmd'; ^
    [void]$lock.WaitOne(); ^
} ^
 ^
try { ^
    if ((Get-Content '%DOTNET_TARGET_DIR%.flag' -ErrorAction Ignore) -ne '%DOTNET_URL%') { ^
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; ^
        Write-Host 'Downloading %DOTNET_URL% to %DOTNET_TEMP_FILE%'; ^
        [void](New-Item '%TARGET_DIR%' -ItemType Directory -Force); ^
        (New-Object Net.WebClient).DownloadFile('%DOTNET_URL%', '%DOTNET_TEMP_FILE%'); ^
 ^
        Write-Host 'Extracting %DOTNET_TEMP_FILE% to %DOTNET_TARGET_DIR%'; ^
        if (Test-Path '%DOTNET_TARGET_DIR%') { ^
            Remove-Item '%DOTNET_TARGET_DIR%' -Recurse; ^
        } ^
        Add-Type -A 'System.IO.Compression.FileSystem'; ^
        [IO.Compression.ZipFile]::ExtractToDirectory('%DOTNET_TEMP_FILE%', '%DOTNET_TARGET_DIR%'); ^
        Remove-Item '%DOTNET_TEMP_FILE%'; ^
 ^
        Set-Content '%DOTNET_TARGET_DIR%.flag' -Value '%DOTNET_URL%'; ^
    } ^
} ^
finally { ^
    $lock.ReleaseMutex(); ^
}

"%POWERSHELL%" -nologo -noprofile -Command %DOWNLOAD_AND_EXTRACT_DOTNET_PS1%
if errorlevel 1 goto fail

:continueWithDotNet

if not exist "%DOTNET_TARGET_DIR%\dotnet.exe" (
  echo Unable to find dotnet.exe under %DOTNET_TARGET_DIR%
  goto fail
)

REM Prevent globally installed .NET Core from leaking into this runtime's lookup
SET DOTNET_MULTILEVEL_LOOKUP=0

call "%DOTNET_TARGET_DIR%\dotnet.exe" %*
exit /B %ERRORLEVEL%
endlocal

:fail
echo "FAIL"
exit /b 1