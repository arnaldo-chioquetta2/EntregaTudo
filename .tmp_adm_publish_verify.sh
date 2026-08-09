cd /var/www/teletudo
php -l app/Http/Controllers/AdmController.php
grep -n "LoggerService::loga('AdmController', 'index | Entregadores online na ADM'" app/Http/Controllers/AdmController.php
if grep -n "ENTROU NO INDEX ADM" app/Http/Controllers/AdmController.php; then true; else echo TEMP_LOG_REMOVED; fi
grep -n '\$entregadoresOnline = \$this->ListaEntregadoresAbertos();' app/Http/Controllers/AdmController.php
grep -n "'entregadoresOnline'" app/Http/Controllers/AdmController.php
grep -n '\$entregadoresOnline->count()' resources/views/adm/index.blade.php
if grep -n '\$cAdm->ListaEntregadoresAbertos()' resources/views/adm/index.blade.php; then true; else echo OLD_BLADE_CALL_REMOVED; fi
php artisan view:clear
php artisan cache:clear
php artisan route:clear
php artisan config:clear
curl -k -L -s -o /tmp/adm_page.html -w "FINAL_URL=%{url_effective}\nHTTP_STATUS=%{http_code}\n" "https://teletudo.com/adm"
php -r 'require "vendor/autoload.php"; $app=require "bootstrap/app.php"; $kernel=$app->make(Illuminate\Contracts\Console\Kernel::class); $kernel->bootstrap(); $rows=Illuminate\Support\Facades\DB::table("tt_LogDebug")->select("id","Caminho","Header","Tipo","created_at")->where("Caminho","AdmController")->where("Header","like","%Entregadores online na ADM%")->orderByDesc("id")->limit(5)->get(); foreach($rows as $row){ echo $row->id," | ",$row->Caminho," | ",$row->Header," | ",$row->Tipo," | ",$row->created_at,PHP_EOL; } if (count($rows)===0) { echo "NO_ADM_ONLINE_LOG", PHP_EOL; }'