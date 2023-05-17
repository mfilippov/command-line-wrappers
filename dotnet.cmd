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

case $(uname) in
Darwin)
  DOTNET_ARCH=$(uname -m)
  if ! $KEEP_ROSETTA2 && [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || true)" = "1" ]; then
    DOTNET_ARCH=arm64
  fi
  case $DOTNET_ARCH in
  arm64)
    DOTNET_HASH_URL=fc7ed56d-3afe-4aa6-81bb-b4b0f5df56b5/d199f43f7421c6677ba25544b442b6b7
    DOTNET_FILE_NAME=dotnet-sdk-7.0.302-osx-arm64
    ;;
  x86_64)
    DOTNET_HASH_URL=34ce4803-1444-48a2-9955-e2a9b9061b03/e18c978b55226240ca037cf8b1770064
    DOTNET_FILE_NAME=dotnet-sdk-7.0.302-osx-x64
    ;;
  *) echo "Unknown architecture $DOTNET_ARCH" >&2; exit 1;;
  esac;;
Linux)
  DOTNET_ARCH=$(linux$(getconf LONG_BIT) uname -m)
  case $DOTNET_ARCH in
  armv7l | armv8l)
    if is_linux_musl; then
      DOTNET_HASH_URL=cb66972b-75fe-4e91-8a06-ddaf1d7e882b/fd04b081250aa6b40fad8319c7224390
      DOTNET_FILE_NAME=dotnet-sdk-7.0.302-linux-musl-arm
    else
      DOTNET_HASH_URL=773e201f-00f3-4de2-beb7-698d9c72f4b7/4c1de128cb18198e1b9bf30902c665bc
      DOTNET_FILE_NAME=dotnet-sdk-7.0.302-linux-arm
    fi
    ;;
  aarch64)
    if is_linux_musl; then
      DOTNET_HASH_URL=4e8faf53-6f5e-452a-a993-fbb90ab25ad1/f64b041fd3bf3c0e9b2f3c6b0ed887e5
      DOTNET_FILE_NAME=dotnet-sdk-7.0.302-linux-musl-arm64
    else
      DOTNET_HASH_URL=142603ad-0df5-4aef-bdc2-87b6140c90ed/2cce467e6c954d01024942b8370aaf70
      DOTNET_FILE_NAME=dotnet-sdk-7.0.302-linux-arm64
    fi
    ;;
  x86_64)
    if is_linux_musl; then
      DOTNET_HASH_URL=6b06ee15-ac63-4b8a-9bae-49453e258687/536a27d0c3a990757590dfc9f7e617ba
      DOTNET_FILE_NAME=dotnet-sdk-7.0.302-linux-musl-x64
    else
      DOTNET_HASH_URL=351400ef-f2e6-4ee7-9d1b-4c246231a065/9f7826270fb36ada1bdb9e14bc8b5123
      DOTNET_FILE_NAME=dotnet-sdk-7.0.302-linux-x64
    fi
    ;;
  *) echo "Unknown architecture $DOTNET_ARCH" >&2; exit 1;;
  esac;;
*) echo "Unknown platform: $(uname)" >&2; exit 1;;
esac

DOTNET_URL=https://cache-redirector.jetbrains.com/download.visualstudio.microsoft.com/download/pr/$DOTNET_HASH_URL/$DOTNET_FILE_NAME.tar.gz
DOTNET_TARGET_DIR=$TARGET_DIR/$DOTNET_FILE_NAME-$SCRIPT_VERSION
DOTNET_TEMP_FILE=$TARGET_DIR/dotnet-sdk-temp.tar.gz

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

for /f "tokens=3 delims= " %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "PROCESSOR_ARCHITECTURE"') do set ARCH=%%a

if "%ARCH%"=="ARM64" (
    set DOTNET_HASH_URL=3a8c2602-3e5f-44ff-9a1a-4dcac7718051/4309ff475d8771e740baf514a66c7d38
    set DOTNET_FILE_NAME=dotnet-sdk-7.0.302-win-arm64
) else (

if "%ARCH%"=="AMD64" (
    set DOTNET_HASH_URL=c973fb82-ecba-4bcc-b1cc-443d817b9472/f4426b15af724f4baf31a50d204d1ca7
    set DOTNET_FILE_NAME=dotnet-sdk-7.0.302-win-x64
) else (

if "%ARCH%"=="x86" (
    set DOTNET_HASH_URL=823b3ed8-9078-41f5-8ba9-176aabb67866/6cff5b428cfe5b7535c827ebed8283a1
    set DOTNET_FILE_NAME=dotnet-sdk-7.0.302-win-x86
) else (

echo Unknown Windows architecture
goto fail

)))

set DOTNET_URL=https://cache-redirector.jetbrains.com/download.visualstudio.microsoft.com/download/pr/%DOTNET_HASH_URL%/%DOTNET_FILE_NAME%.zip
set DOTNET_TARGET_DIR=%TARGET_DIR%%DOTNET_FILE_NAME%-%SCRIPT_VERSION%\
set DOTNET_TEMP_FILE=%TARGET_DIR%dotnet-sdk-temp.zip

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