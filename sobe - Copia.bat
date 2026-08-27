@echo off
echo 🔗 Repositório remoto configurado:
git remote -v
echo.
git status
set /p MSG=Digite a mensagem de commit e tecle ENTER: 
echo 📁 Adicionando arquivos modificados...
git add .
echo 💬 Commitando com a mensagem: "%MSG%"
git commit -m "%MSG%"
echo 🚀 Enviando para o GitHub...
git push origin main
pause
