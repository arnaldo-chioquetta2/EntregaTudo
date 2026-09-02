@echo off
setlocal enabledelayedexpansion
title COMPILA ENTREGATUDO
color 0A
set START_TIME=%TIME%

echo ==================================================
echo       🚀 INICIANDO BUILD RELEASE ENTREGATUDO
echo ==================================================
echo.

REM Solicita a versão ao usuário
set /p VERSION="📌 Digite a versão do APK (ex: 1.0.0): "
if "!VERSION!"=="" (
    color 0C
    echo ❌ ERRO: Versão não informada!
    pause
    exit /b
)

echo.
echo ✅ Versão informada: !VERSION!
echo.

REM Caminho absoluto para o Flutter
set "FLUTTER_PATH=C:\Flutter\bin\flutter.bat"
set "APK_ORIG=build\app\outputs\flutter-apk\app-release.apk"
set "APK_FINAL=D:\Prog\entregatudo\EntregaTudo.apk"
set "UPA_BAT=D:\Prog\entregatudo\upa.bat"
set "BAK_FOLDER=D:\Prog\entregatudo\BakApk"

REM Cria pasta de backup se não existir
if not exist "%BAK_FOLDER%" (
    echo 📁 Criando pasta de backup...
    mkdir "%BAK_FOLDER%"
)

REM Prepara nome do arquivo de backup com versão e timestamp
for /f "tokens=1-3 delims=/- " %%a in ('date /t') do (
    set DATA=%%c%%b%%a
)
for /f "tokens=1-2 delims=:." %%a in ('echo %TIME%') do (
    set HORA=%%a%%b
)
set HORA=!HORA: =0!
set "APK_BACKUP=%BAK_FOLDER%\EntregaTudo_v!VERSION!_!DATA!_!HORA!.apk"

if not exist "%FLUTTER_PATH%" (
    color 0C
    echo ❌ ERRO: Flutter não encontrado em "%FLUTTER_PATH%"
    pause
    exit /b
)

cd /d "D:\Prog\entregatudo"

echo 🧹 Limpando build Flutter...
call "%FLUTTER_PATH%" clean || goto :erro

echo 📦 Instalando dependências...
call "%FLUTTER_PATH%" pub get || goto :erro

echo 🧱 Limpando Gradle...
cd android
if exist gradlew (
    call .\gradlew clean
) else (
    gradle clean
)
if %errorlevel% neq 0 goto :erro
cd ..

echo 🚀 Gerando APK Release...
call "%FLUTTER_PATH%" build apk --release --no-tree-shake-icons || goto :erro

if not exist "%APK_ORIG%" (
    color 0C
    echo ❌ Não foi encontrado o APK esperado em "%APK_ORIG%"
    pause
    exit /b
)

echo.
echo 💾 Criando backup versionado...
copy /Y "%APK_ORIG%" "%APK_BACKUP%"
if %errorlevel% neq 0 (
    color 0E
    echo ⚠️  AVISO: Falha ao criar backup, mas continuando...
)

echo 📦 Renomeando e movendo APK...
copy /Y "%APK_ORIG%" "%APK_FINAL%"
if %errorlevel% neq 0 goto :erro

echo --------------------------------------------------
echo ✅ BUILD FINALIZADO COM SUCESSO!
echo --------------------------------------------------
echo 📦 APK principal: %APK_FINAL%
echo 💾 Backup criado: %APK_BACKUP%
echo --------------------------------------------------
echo 🕒 Início: %START_TIME%
echo 🕒 Término: %TIME%
echo --------------------------------------------------
echo Chamando UPA.BAT...
echo --------------------------------------------------

call "%UPA_BAT%"
pause
goto :fim

:erro
color 0C
echo ❌ Erro durante a compilação.
pause
exit /b

:fim
pause
exit /b