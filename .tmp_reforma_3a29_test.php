<?php

namespace Tests\Feature;

use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class FornecedorDisponibilidadeTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config(['database.default' => 'sqlite', 'database.connections.sqlite.database' => ':memory:']);
        DB::purge('sqlite');
        DB::reconnect('sqlite');

        Schema::create('tt_empresa', function (Blueprint $table) {
            $table->unsignedInteger('idEmpresa')->primary();
            $table->unsignedInteger('idPessoa')->nullable();
            $table->unsignedTinyInteger('Ativo')->default(1);
            $table->string('tipo_fornecedor')->default('MANUAL');
            $table->dateTime('dtON')->nullable();
        });
        Schema::create('tt_empresa_horarios', function (Blueprint $table) {
            $table->increments('id');
            $table->unsignedInteger('idEmpresa');
            $table->unsignedTinyInteger('dia_semana');
            $table->unsignedTinyInteger('ativo')->default(1);
            $table->time('hora_inicio_atendimento')->nullable();
            $table->time('hora_fim_atendimento')->nullable();
            $table->unsignedTinyInteger('possui_intervalo')->default(0);
            $table->time('hora_inicio_intervalo')->nullable();
            $table->time('hora_fim_intervalo')->nullable();
        });
    }

    protected function tearDown(): void
    {
        DB::disconnect('sqlite');
        parent::tearDown();
    }

    public function test_route_is_jwt_protected_and_throttled(): void
    {
        $route = app('router')->getRoutes()->match(Request::create('/api/fornecedor/disponibilidade', 'GET'));
        $this->assertContains('jwt.auth', $route->middleware());
        $this->assertContains('throttle:30,1', $route->middleware());
    }

    public function test_unauthenticated_request_is_rejected(): void
    {
        $this->assertSame(401, $this->invoke()->getStatusCode());
    }

    public function test_horario_open_and_closed_use_existing_service(): void
    {
        $now = Carbon::now('America/Sao_Paulo');
        $this->seed(10, 100, 'HORARIO');
        $this->authenticateAs(100);
        DB::table('tt_empresa_horarios')->insert([
            'idEmpresa' => 10, 'dia_semana' => $now->isoWeekday(), 'ativo' => 1,
            'hora_inicio_atendimento' => $now->copy()->subHour()->format('H:i:s'),
            'hora_fim_atendimento' => $now->copy()->addHour()->format('H:i:s'),
            'possui_intervalo' => 0,
        ]);
        $this->assertTrue($this->invoke()->getData(true)['data']['disponivel']);
        DB::table('tt_empresa_horarios')->update([
            'dia_semana' => $now->isoWeekday() === 7 ? 1 : 7,
        ]);
        $this->assertFalse($this->invoke()->getData(true)['data']['disponivel']);
    }

    public function test_manual_active_and_inactive_use_existing_service(): void
    {
        $this->seed(10, 100, 'MANUAL', Carbon::now('America/Sao_Paulo')->subMinute());
        $this->authenticateAs(100);
        $this->assertTrue($this->invoke()->getData(true)['data']['disponivel']);
        DB::table('tt_empresa')->update(['dtON' => Carbon::now('America/Sao_Paulo')->subMinutes(5)]);
        $this->assertFalse($this->invoke()->getData(true)['data']['disponivel']);
    }

    public function test_identity_from_query_is_ignored_and_response_is_minimal(): void
    {
        $this->seed(10, 100, 'MANUAL', Carbon::now('America/Sao_Paulo')->subMinute());
        $this->authenticateAs(200);
        $response = $this->get('/api/fornecedor/disponibilidade?userid=100&idFornecedor=10');
        $this->assertSame(404, $response->getStatusCode());

        $this->authenticateAs(100);
        $payload = $this->invoke()->getData(true);
        $this->assertSame(['success', 'data'], array_keys($payload));
        $this->assertSame(['tipo', 'disponivel', 'origem'], array_keys($payload['data']));
    }

    private function seed(int $empresa, int $pessoa, string $tipo, ?Carbon $dton = null): void
    {
        DB::table('tt_empresa')->insert([
            'idEmpresa' => $empresa, 'idPessoa' => $pessoa, 'Ativo' => 1,
            'tipo_fornecedor' => $tipo, 'dtON' => $dton,
        ]);
    }

    private function authenticateAs(int $id): void
    {
        $user = new User();
        $user->id = $id;
        auth('api')->setUser($user);
    }

    private function invoke()
    {
        return $this->get('/api/fornecedor/disponibilidade');
    }
}
