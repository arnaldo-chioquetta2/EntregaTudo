from pathlib import Path
p = Path('routes/api.php')
data = p.read_bytes()
anchor = b"Route::post('/fornecedor/off', 'AppController@fornOff');"
addition = b"\nRoute::get('/fornecedor/disponibilidade', [FornecedorHorarioController::class, 'disponibilidade'])\n    ->middleware(['jwt.auth', 'throttle:30,1']);"
if data.count(anchor) != 1:
    raise SystemExit('route anchor count mismatch')
if b"Route::get('/fornecedor/disponibilidade'" in data:
    raise SystemExit('route already present')
p.write_bytes(data.replace(anchor, anchor + addition, 1))
print('ROUTE_EDIT_OK')
