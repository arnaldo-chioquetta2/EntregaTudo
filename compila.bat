@echo off
setlocal enabledelayedexpansion
title COMPILA ENTREGATUDO
color 0A

set START_TIME=%TIME%

echo ==================================================
echo       🚀 INICIANDO BUILD RELEASE ENTREGATUDO
echo ==================================================
echo.

REM Caminho absoluto para o Flutter
set FLUTTER_PATH=C:\Flutter\bin\flutter.bat

if not exist "%FLUTTER_PATH%" (
    color 0C
    echo ❌ ERRO: Flutter não encontrado em "%FLUTTER_PATH%"
    echo Verifique o caminho e atualize o script.
    pause
    exit /b
)

cd /d "D:\Prog\entregatudo"

echo 🧹 Limpando build Flutter...
call "%FLUTTER_PATH%" clean
if %errorlevel% neq 0 (
    color 0C
    echo ❌ Erro no comando flutter clean
    pause
    exit /b
)

echo 📦 Instalando dependências...
call "%FLUTTER_PATH%" pub get
if %errorlevel% neq 0 (
    color 0C
    echo ❌ Erro no comando flutter pub get
    pause
    exit /b
)

echo 🧱 Limpando Gradle...
cd android
if exist gradlew (
    call .\gradlew clean
) else (
    echo ⚠️  gradlew não encontrado, tentando com gradle...
    gradle clean
)
if %errorlevel% neq 0 (
    color 0C
    echo ❌ Erro ao limpar o Gradle
    pause
    exit /b
)

echo ⬆️ Voltando à raiz do projeto...
cd ..

echo 🚀 Gerando APK Release...
call "%FLUTTER_PATH%" build apk --release --no-tree-shake-icons
if %errorlevel% neq 0 (
    color 0C
    echo ❌ Erro ao gerar o APK.
    pause
    exit /b
)

set APK_PATH=build\app\outputs\flutter-apk\app-release.apk

echo.
if exist "%APK_PATH%" (
    color 0A
    echo ✅ BUILD FINALIZADO COM SUCESSO!
    echo --------------------------------------------------
    echo 📦 Caminho do APK gerado:
    echo %cd%\%APK_PATH%
    echo --------------------------------------------------
) else (
    color 0C
    echo ❌ A compilação terminou, mas o APK não foi encontrado!
    echo Verifique se o build foi interrompido ou falhou silenciosamente.
)

echo.
echo 🕒 Início: %START_TIME%
echo 🕒 Término: %TIME%
echo.
pause
