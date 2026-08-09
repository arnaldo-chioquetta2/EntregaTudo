cd /var/www/teletudo
grep -n "Quantidade de MotoBoys on-line" /tmp/adm_page.html || true
grep -n "1/" /tmp/adm_page.html | head -n 5 || true