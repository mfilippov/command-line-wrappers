:<<"::CMDLITERAL"
@ECHO OFF
GOTO :CMDSCRIPT
::CMDLITERAL

set -eu

UV_VERSION=0.13.1
UV_BIN=uvx
SCRIPT_VERSION=v1
COMPANY_DIR="Mikhail Filippov"
TARGET_DIR="${TEMPDIR:-$HOME/.local/share}/$COMPANY_DIR/uv-cmd"
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

# Links from here: https://github.com/astral-sh/uv/releases
case $(uname) in
Darwin)
  UNAME_ARCH=$(uname -m)
  if ! $KEEP_ROSETTA2 && [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || true)" = "1" ]; then
    UNAME_ARCH=arm64
  fi
  case $UNAME_ARCH in
  arm64)  UV_TARGET=aarch64-apple-darwin;;
  x86_64) UV_TARGET=x86_64-apple-darwin;;
  *) echo "Unknown architecture $UNAME_ARCH" >&2; exit 1;;
  esac;;
Linux)
  UNAME_ARCH=$(linux$(getconf LONG_BIT) uname -m)
  case $UNAME_ARCH in
  x86_64)        is_linux_musl && UV_TARGET=x86_64-unknown-linux-musl    || UV_TARGET=x86_64-unknown-linux-gnu;;
  aarch64)       is_linux_musl && UV_TARGET=aarch64-unknown-linux-musl   || UV_TARGET=aarch64-unknown-linux-gnu;;
  armv7l)        is_linux_musl && UV_TARGET=armv7-unknown-linux-musleabihf || UV_TARGET=armv7-unknown-linux-gnueabihf;;
  i386 | i686)   is_linux_musl && UV_TARGET=i686-unknown-linux-musl      || UV_TARGET=i686-unknown-linux-gnu;;
  riscv64)       is_linux_musl && UV_TARGET=riscv64gc-unknown-linux-musl || UV_TARGET=riscv64gc-unknown-linux-gnu;;
  ppc64le)       UV_TARGET=powerpc64le-unknown-linux-gnu;;
  s390x)         UV_TARGET=s390x-unknown-linux-gnu;;
  *) echo "Unknown architecture $UNAME_ARCH" >&2; exit 1;;
  esac;;
*) echo "Unknown platform: $(uname)" >&2; exit 1;;
esac

UV_URL=https://github.com/astral-sh/uv/releases/download/$UV_VERSION/uv-$UV_TARGET.tar.gz
UV_TARGET_DIR=$TARGET_DIR/uv-$UV_VERSION-$UV_TARGET-$SCRIPT_VERSION
UV_TEMP_FILE=$TARGET_DIR/temp-$SCRIPT_VERSION.tar.gz

if grep -q -x "$UV_URL" "$UV_TARGET_DIR/.flag" 2>/dev/null; then
  # Everything is up-to-date in $UV_TARGET_DIR, do nothing
  true
else
while true; do  # Note(k15tfu): for goto
  mkdir -p "$TARGET_DIR"

  LOCK_FILE="$TARGET_DIR/.uv-cmd-lock.pid"
  TMP_LOCK_FILE="$TARGET_DIR/.tmp.$$.pid"
  echo $$ >"$TMP_LOCK_FILE"

  while ! ln "$TMP_LOCK_FILE" "$LOCK_FILE" 2>/dev/null; do
    LOCK_OWNER=$(cat "$LOCK_FILE" 2>/dev/null || true)
    while [ -n "$LOCK_OWNER" ] && ps -p $LOCK_OWNER >/dev/null; do
      warn "Waiting for the process $LOCK_OWNER to finish bootstrap uv.cmd"
      sleep 1
      LOCK_OWNER=$(cat "$LOCK_FILE" 2>/dev/null || true)

      # Hurry up, bootstrap is ready..
      if grep -q -x "$UV_URL" "$UV_TARGET_DIR/.flag" 2>/dev/null; then
        break 3  # Note(k15tfu): goto out of the outer if-else block.
      fi
    done

    if [ -n "$LOCK_OWNER" ] && grep -q -x $LOCK_OWNER "$LOCK_FILE" 2>/dev/null; then
      die "ERROR: The lock file $LOCK_FILE still exists on disk after the owner process $LOCK_OWNER exited"
    fi
  done

  trap "rm -f \"$LOCK_FILE\"" EXIT
  rm "$TMP_LOCK_FILE"

  if ! grep -q -x "$UV_URL" "$UV_TARGET_DIR/.flag" 2>/dev/null; then
    warn "Downloading $UV_URL to $UV_TEMP_FILE"

    rm -f "$UV_TEMP_FILE"
    if command -v curl >/dev/null 2>&1; then
      if [ -t 1 ]; then CURL_PROGRESS="--progress-bar"; else CURL_PROGRESS="--silent --show-error"; fi
      retry_on_error 5 curl -L $CURL_PROGRESS --output "${UV_TEMP_FILE}" "$UV_URL"
    elif command -v wget >/dev/null 2>&1; then
      if [ -t 1 ]; then WGET_PROGRESS=""; else WGET_PROGRESS="-nv"; fi
      retry_on_error 5 wget $WGET_PROGRESS -O "${UV_TEMP_FILE}" "$UV_URL"
    else
      die "ERROR: Please install wget or curl"
    fi

    warn "Extracting $UV_TEMP_FILE to $UV_TARGET_DIR"
    rm -rf "$UV_TARGET_DIR"
    mkdir -p "$UV_TARGET_DIR"

    # The archive contains one folder: uv-$UV_TARGET/{uv,uvx}
    tar -x -f "$UV_TEMP_FILE" -C "$UV_TARGET_DIR"
    rm -f "$UV_TEMP_FILE"

    echo "$UV_URL" >"$UV_TARGET_DIR/.flag"
  fi

  rm "$LOCK_FILE"
  break
done
fi

UV_HOME="$UV_TARGET_DIR/uv-$UV_TARGET"
if [ ! -x "$UV_HOME/$UV_BIN" ]; then
  die "Unable to find $UV_BIN under $UV_TARGET_DIR"
fi

exec "$UV_HOME/$UV_BIN" "$@"

:CMDSCRIPT

setlocal
set UV_VERSION=0.13.1
set UV_BIN=uvx.exe
set SCRIPT_VERSION=v1
set COMPANY_NAME=Mikhail Filippov
set TARGET_DIR=%LOCALAPPDATA%\%COMPANY_NAME%\uv-cmd\

for /f "tokens=3 delims= " %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "PROCESSOR_ARCHITECTURE"') do set ARCH=%%a

if "%ARCH%"=="ARM64" (set UV_TARGET=aarch64-pc-windows-msvc) else (
if "%ARCH%"=="AMD64" (set UV_TARGET=x86_64-pc-windows-msvc)  else (
if "%ARCH%"=="x86"   (set UV_TARGET=i686-pc-windows-msvc)    else (

echo Unknown Windows architecture
goto fail

)))

set UV_URL=https://github.com/astral-sh/uv/releases/download/%UV_VERSION%/uv-%UV_TARGET%.zip
set UV_TARGET_DIR=%TARGET_DIR%uv-%UV_VERSION%-%UV_TARGET%-%SCRIPT_VERSION%\
set UV_TEMP_FILE=%TARGET_DIR%temp-%SCRIPT_VERSION%.zip

set POWERSHELL=%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe

if not exist "%UV_TARGET_DIR%.flag" goto downloadAndExtractUv

set /p CURRENT_FLAG=<"%UV_TARGET_DIR%.flag"
if "%CURRENT_FLAG%" == "%UV_URL%" goto continueWithUv

:downloadAndExtractUv

set DOWNLOAD_AND_EXTRACT_UV_PS1= ^
Set-StrictMode -Version 3.0; ^
$ErrorActionPreference = 'Stop'; ^
 ^
$createdNew = $false; ^
$lock = New-Object System.Threading.Mutex($true, 'Global\uv-cmd-lock', [ref]$createdNew); ^
if (-not $createdNew) { ^
    Write-Host 'Waiting for the other process to finish bootstrap uv.cmd'; ^
    [void]$lock.WaitOne(); ^
} ^
 ^
try { ^
    if ((Get-Content '%UV_TARGET_DIR%.flag' -ErrorAction Ignore) -ne '%UV_URL%') { ^
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; ^
        Write-Host 'Downloading %UV_URL% to %UV_TEMP_FILE%'; ^
        [void](New-Item '%TARGET_DIR%' -ItemType Directory -Force); ^
        (New-Object Net.WebClient).DownloadFile('%UV_URL%', '%UV_TEMP_FILE%'); ^
 ^
        Write-Host 'Extracting %UV_TEMP_FILE% to %UV_TARGET_DIR%'; ^
        if (Test-Path '%UV_TARGET_DIR%') { ^
            Remove-Item '%UV_TARGET_DIR%' -Recurse; ^
        } ^
        Add-Type -A 'System.IO.Compression.FileSystem'; ^
        [IO.Compression.ZipFile]::ExtractToDirectory('%UV_TEMP_FILE%', '%UV_TARGET_DIR%'); ^
        Remove-Item '%UV_TEMP_FILE%'; ^
 ^
        Set-Content '%UV_TARGET_DIR%.flag' -Value '%UV_URL%'; ^
    } ^
} ^
finally { ^
    $lock.ReleaseMutex(); ^
}

"%POWERSHELL%" -nologo -noprofile -Command %DOWNLOAD_AND_EXTRACT_UV_PS1%
if errorlevel 1 goto fail

:continueWithUv

if not exist "%UV_TARGET_DIR%%UV_BIN%" (
  echo Unable to find %UV_BIN% under %UV_TARGET_DIR%
  goto fail
)

call "%UV_TARGET_DIR%%UV_BIN%" %*
exit /B %ERRORLEVEL%
endlocal

:fail
echo "FAIL"
exit /b 1
