@echo off
setlocal
title 🚀 UPA ENTREGATUDO
color 0A

echo ==================================================
echo       🚀 ENVIANDO APK PARA TELE TUDO
echo ==================================================

rem === Caminhos ===
set "APK_SOURCE=D:\Prog\entregatudo\EntregaTudo.apk"
set "APK_DEST=D:\Prog\TeleTudo\public_html\public\download\EntregaTudo.apk"
set "FTPC_EXE=D:\Prog\FTPc3\bin\Release\FTPc.exe"

rem === Verificações básicas ===
if not exist "%APK_SOURCE%" (
    color 0C
    echo ❌ Arquivo de origem não encontrado:
    echo    %APK_SOURCE%
    pause
    exit /b
)

if not exist "D:\Prog\TeleTudo\public_html\public\download" (
    color 0C
    echo ❌ Pasta de destino não encontrada:
    echo    D:\Prog\TeleTudo\public_html\public\download
    pause
    exit /b
)

echo 📁 Copiando APK para pasta de publicação...
copy /Y "%APK_SOURCE%" "%APK_DEST%" >nul
if %errorlevel% neq 0 (
    color 0C
    echo ❌ Erro ao copiar o APK.
    pause
    exit /b
)

echo ✅ APK copiado com sucesso!
echo   %APK_DEST%
echo --------------------------------------------------

echo ▶️ Executando FTPc.exe...
if exist "%FTPC_EXE%" (
    start "" "%FTPC_EXE%"
    echo ✅ FTPc.exe executado com sucesso.
) else (
    color 0C
    echo ❌ Executável não encontrado:
    echo   %FTPC_EXE%
    pause
    exit /b
)

echo --------------------------------------------------
echo 🏁 Processo concluído!
pause
exit /b
