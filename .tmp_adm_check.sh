cd /var/www/teletudo
php -l app/Http/Controllers/AdmController.php
grep -n "LoggerService::loga('AdmController', 'index | Entregadores online na ADM'" app/Http/Controllers/AdmController.php
grep -n '\$entregadoresOnline->count()' resources/views/adm/index.blade.php
if grep -n '\$cAdm->ListaEntregadoresAbertos()' resources/views/adm/index.blade.php; then true; else echo OLD_CALL_REMOVED; fi
php artisan view:clear
php artisan cache:clear
php artisan route:clear
php artisan config:clear