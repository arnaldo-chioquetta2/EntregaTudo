from pathlib import Path

def replace_once(path, anchor, addition):
    p = Path(path)
    data = p.read_bytes()
    a = anchor.encode('utf-8')
    if data.count(a) != 1:
        raise SystemExit('anchor count mismatch: ' + path)
    if addition.strip().splitlines()[0].encode('utf-8') in data:
        raise SystemExit('already changed: ' + path)
    p.write_bytes(data.replace(a, addition.encode('utf-8') + a, 1))

replace_once(
    'app/Http/Controllers/FornecedorHorarioController.php',
    '    public function status()',
    """    public function disponibilidade()
    {
        $userId = (int) auth('api')->id();

        if ($userId <= 0) {
            return response()->json([
                'success' => false,
                'erro' => 'nao_autenticado',
                'message' => 'Autenticacao necessaria.',
            ], 401);
        }

        $empresa = Empresa::where('idPessoa', $userId)
            ->where('Ativo', 1)
            ->orderByDesc('idEmpresa')
            ->first();

        if (!$empresa) {
            return response()->json([
                'success' => false,
                'erro' => 'fornecedor_invalido',
                'message' => 'Fornecedor invalido ou inativo.',
            ], 404);
        }

        $tipo = strtoupper(trim((string) $empresa->tipo_fornecedor));
        if (!in_array($tipo, ['HORARIO', 'MANUAL'], true)) {
            return response()->json([
                'success' => false,
                'erro' => 'tipo_fornecedor_invalido',
                'message' => 'Tipo de fornecedor invalido.',
            ], 422);
        }

        return response()->json([
            'success' => true,
            'data' => [
                'tipo' => $tipo,
                'disponivel' => FornecedorDisponibilidadeService::isOnline($empresa),
                'origem' => $tipo,
            ],
        ]);
    }

""",
)
replace_once(
    'routes/api.php',
    "Route::post('/fornecedor/off', 'AppController@fornOff');",
    "Route::post('/fornecedor/off', 'AppController@fornOff');\n"
    """Route::get('/fornecedor/disponibilidade', [FornecedorHorarioController::class, 'disponibilidade'])
    ->middleware(['jwt.auth', 'throttle:30,1']);
""".rstrip('\n'),
)
print('EDIT_OK')
