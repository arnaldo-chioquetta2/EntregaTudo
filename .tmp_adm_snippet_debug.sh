cd /var/www/teletudo
printf "ADM_CONTROLLER_SNIPPET\n"
sed -n '20,45p' app/Http/Controllers/AdmController.php
printf "\nADM_VIEW_SNIPPET\n"
sed -n '438,452p' resources/views/adm/index.blade.php
printf "\nTT_CONFIG_DEBUG\n"
mysql -N -e "SELECT Debug FROM tt_config LIMIT 1;" teletudo 2>/dev/null || true
printf "\nHTTPS_CALL\n"
curl -k -L -s -o /tmp/adm_page.html -w "FINAL_URL=%{url_effective}\nHTTP_STATUS=%{http_code}\n" "https://teletudo.com/adm"