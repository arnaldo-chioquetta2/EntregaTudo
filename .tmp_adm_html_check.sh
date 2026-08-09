cd /var/www/teletudo
python3 - <<'PY'
from pathlib import Path
html = Path('/tmp/adm_page.html').read_text(encoding='utf-8', errors='replace')
for line in html.splitlines():
    if 'Quantidade de MotoBoys on-line' in line or '<strong>' in line and '/'+'' in line:
        print(line.strip())
PY