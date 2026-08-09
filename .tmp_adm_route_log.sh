cd /var/www/teletudo
printf "APP_URL="
grep '^APP_URL=' .env || true
printf "\nROUTE_ADM\n"
php artisan route:list --path=adm --columns=Method,URI,Name,Action | sed -n '1,20p'
APP_URL=$(grep '^APP_URL=' .env | cut -d= -f2- | tr -d '"' | tr -d '\r')
if [ -z "$APP_URL" ]; then APP_URL="http://127.0.0.1"; fi
printf "\nHTTP_CALL %s/adm\n" "$APP_URL"
curl -k -s -o /tmp/adm_page.html -w "HTTP_STATUS=%{http_code}\n" "$APP_URL/adm"
printf "\nRECENT_LOGS\n"
mysql -N -e "SELECT Caminho, Header, Info, Data FROM tt_LogDebug WHERE Caminho='AdmController' OR Caminho='AdmController::ListaEntregadoresAbertos' ORDER BY idLogDebug DESC LIMIT 10;" teletudo 2>/dev/null || true