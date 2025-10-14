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
set "FLUTTER_PATH=C:\Flutter\bin\flutter.bat"
set "APK_ORIG=build\app\outputs\flutter-apk\app-release.apk"
set "APK_FINAL=D:\Prog\entregatudo\EntregaTudo.apk"
set "UPA_BAT=D:\Prog\entregatudo\upa.bat"

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
echo 📦 Renomeando e movendo APK...
copy /Y "%APK_ORIG%" "%APK_FINAL%"
if %errorlevel% neq 0 goto :erro

echo --------------------------------------------------
echo ✅ BUILD FINALIZADO COM SUCESSO!
echo 📦 APK copiado para:
echo   %APK_FINAL%
echo --------------------------------------------------
echo 🕒 Início: %START_TIME%
echo 🕒 Término: %TIME%
echo --------------------------------------------------
echo Chamando UPA.BAT...
echo --------------------------------------------------

call "%UPA_BAT%"
goto :fim

:erro
color 0C
echo ❌ Erro durante a compilação.
pause
exit /b

:fim
pause
exit /b
