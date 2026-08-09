cd /var/www/teletudo
python3 - <<'PY'
from pathlib import Path
path = Path('app/Http/Controllers/AdmController.php')
text = path.read_text(encoding='utf-8', errors='replace')
import_line = 'use App\\Services\\LoggerService;\n'
if 'use App\\Services\\LoggerService;' not in text:
    marker = 'use App\\Services\\FornecedorDisponibilidadeService;\n'
    if marker in text:
        text = text.replace(marker, marker + import_line, 1)
needle = "    public function index()\n    {\n"
insert = "    public function index()\n    {\n        LoggerService::loga('AdmController', 'index | ENTROU NO INDEX ADM', [\n            'ts' => LoggerService::agora()->format('Y-m-d H:i:s')\n        ]);\n"
if "index | ENTROU NO INDEX ADM" not in text and needle in text:
    text = text.replace(needle, insert, 1)
path.write_text(text, encoding='utf-8')
PY
php -l app/Http/Controllers/AdmController.php
php artisan view:clear
php artisan cache:clear
php artisan route:clear
php artisan config:clear
curl -k -L -s -o /tmp/adm_page.html -w "FINAL_URL=%{url_effective}\nHTTP_STATUS=%{http_code}\n" "https://teletudo.com/adm"
php -r 'require "vendor/autoload.php"; $app=require "bootstrap/app.php"; $kernel=$app->make(Illuminate\Contracts\Console\Kernel::class); $kernel->bootstrap(); $rows=Illuminate\Support\Facades\DB::table("tt_LogDebug")->select("Caminho","Header","Info","Data")->where("Caminho","AdmController")->orderByDesc("idLogDebug")->limit(5)->get(); foreach($rows as $row){ echo $row->Caminho," | ",$row->Header," | ",$row->Info," | ",$row->Data,PHP_EOL; }'