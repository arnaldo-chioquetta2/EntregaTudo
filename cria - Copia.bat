@echo off
REM Cria o arquivo key.properties dentro de android\

setlocal

set "ANDROID_DIR=android"
set "KEY_FILE=%ANDROID_DIR%\key.properties"

echo storePassword=suasenhakeystore> "%KEY_FILE%"
echo keyPassword=suasenhakeystore>> "%KEY_FILE%"
echo keyAlias=entregatudo>> "%KEY_FILE%"
echo storeFile=entregatudo-release-key.jks>> "%KEY_FILE%"

echo.
echo Arquivo %KEY_FILE% criado com sucesso!
echo Lembre-se de substituir 'suasenhakeystore' pela senha real do seu JKS.
echo.

pause
