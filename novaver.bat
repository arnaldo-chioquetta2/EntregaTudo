@echo off
setlocal
title 🚀 Build Release EntregaTudo + FTP Upload
color 0A

echo ==================================================
echo       🚀 INICIANDO BUILD RELEASE ENTREGATUDO
echo ==================================================
echo.

REM === Caminho do Flutter ===
set FLUTTER_PATH=C:\Flutter\bin\flutter.bat
set APP_DIR=D:\Prog\entregatudo
set APK_PATH=%APP_DIR%\build\app\outputs\flutter-apk\app-release.apk
set FINAL_APK=%APP_DIR%\EntregaTudo.apk

cd /d "%APP_DIR%"

echo 🧹 Limpando projeto...
call "%FLUTTER_PATH%" clean

echo 📦 Obtendo dependências...
call "%FLUTTER_PATH%" pub get

echo 🔨 Gerando APK Release...
call "%FLUTTER_PATH%" build apk --release --no-tree-shake-icons
if %errorlevel% neq 0 (
    color 0C
    echo ❌ Erro ao gerar o APK!
    pause
    exit /b
)

echo 🔄 Renomeando APK...
if exist "%FINAL_APK%" del "%FINAL_APK%"
move "%APK_PATH%" "%FINAL_APK%"

if not exist "%FINAL_APK%" (
    color 0C
    echo ❌ APK não encontrado após build.
    pause
    exit /b
)

echo 📤 Enviando para FTP...

REM === Cria um arquivo temporário com os comandos de FTP ===
set FTP_SCRIPT=%TEMP%\ftp_commands.txt
echo open ftp.teletudo.com> "%FTP_SCRIPT%"
echo user admin_segu ufrs3753!>> "%FTP_SCRIPT%"
echo binary>> "%FTP_SCRIPT%"
echo cd /public_html/public/download>> "%FTP_SCRIPT%"
echo put "%FINAL_APK%">> "%FTP_SCRIPT%"
echo bye>> "%FTP_SCRIPT%"

REM === Executa o envio ===
ftp -n -s:"%FTP_SCRIPT%"

del "%FTP_SCRIPT%"

echo ✅ Upload concluído com sucesso!
pause
