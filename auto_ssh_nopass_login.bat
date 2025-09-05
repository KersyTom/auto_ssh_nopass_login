@echo off
setlocal enabledelayedexpansion

:: ===== Step 0: Get arguments =====
if "%~3"=="" (
    echo No arguments provided, please input manually:
    set /p SERVER_IP=Enter server IP: 
    set /p SERVER_USER=Enter username: 
    set /p SERVER_PASS=Enter password: 
) else (
    set SERVER_IP=%~1
    set SERVER_USER=%~2
    set SERVER_PASS=%~3
)

:: ===== Path settings =====
set KEY_DIR=%USERPROFILE%\ssh_keygen\%SERVER_IP%
set PRIV_KEY=%KEY_DIR%\id_rsa
set PUB_KEY=%KEY_DIR%\id_rsa.pub
set SSH_CONFIG=%USERPROFILE%\.ssh\config

echo ==== Step 1: Check local config ====

:: check ssh config
if exist "%SSH_CONFIG%" (
    findstr /C:"Host %SERVER_IP%" "%SSH_CONFIG%" >nul 2>&1
    if %errorlevel%==0 (
        echo Found Host %SERVER_IP% in %SSH_CONFIG%
    ) else (
        echo Host %SERVER_IP% not found in config
    )
) else (
    echo ssh config file not found, will create later.
)

:: check key existence
if exist "%PRIV_KEY%" (
    echo Private key already exists: %PRIV_KEY%
) else (
    echo Private key does not exist: %PRIV_KEY%
)

:: ===== Step 2: Test passwordless login =====
ssh -o BatchMode=yes -o ConnectTimeout=5 %SERVER_USER%@%SERVER_IP% "echo ok" 2>nul | findstr /C:"ok" >nul
if %errorlevel%==0 (
    echo Can login to %SERVER_IP% without password. Nothing to do.
    goto :EOF
) else (
    echo Cannot login to %SERVER_IP% without password. Will create keys...
)

:: ===== Step 3: Create local key pair =====
if not exist "%KEY_DIR%" mkdir "%KEY_DIR%"
if exist "%PRIV_KEY%" del /f /q "%PRIV_KEY%"
if exist "%PUB_KEY%" del /f /q "%PUB_KEY%"
ssh-keygen -t rsa -b 2048 -f "%PRIV_KEY%" -N "" -q

:: ===== Step 4: Create remote .ssh dir =====
ssh %SERVER_USER%@%SERVER_IP% "mkdir -p ~/.ssh && chmod 700 ~/.ssh"

:: ===== Step 5: Upload public key =====
scp "%PUB_KEY%" %SERVER_USER%@%SERVER_IP%:/tmp/id_rsa.pub

:: ===== Step 6: Append public key to authorized_keys =====
ssh %SERVER_USER%@%SERVER_IP% "cat /tmp/id_rsa.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && rm -f /tmp/id_rsa.pub"

:: ===== Step 7: Update local ssh config =====
if not exist "%USERPROFILE%\.ssh" mkdir "%USERPROFILE%\.ssh"
if not exist "%SSH_CONFIG%" type nul > "%SSH_CONFIG%"

:: append only if not exists
findstr /C:"Host %SERVER_IP%" "%SSH_CONFIG%" >nul 2>&1
if %errorlevel%==1 (
    (
        echo.
        echo Host %SERVER_IP%
        echo ^    HostName %SERVER_IP%
        echo ^    User %SERVER_USER%
        echo ^    IdentityFile %PRIV_KEY%
    )>> "%SSH_CONFIG%"
    echo Added config for %SERVER_IP% into %SSH_CONFIG%
) else (
    echo Config for %SERVER_IP% already exists, skipped.
)

echo.
echo ==== Script finished ====
pause
endlocal
