import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ScoreboardServer {
  ScoreboardServer({
    required Map<String, dynamic> Function() getState,
    required Future<void> Function(
      String athlete,
      String action,
    ) onCommand,
  })  : _getState = getState,
        _onCommand = onCommand;

  final Map<String, dynamic> Function() _getState;
  final Future<void> Function(String athlete, String action) _onCommand;

  HttpServer? _server;

  static const int port = 8787;
  static const String pin = '4826';

  String? localAddress;

  bool get isRunning => _server != null;

  Future<void> start() async {
    if (_server != null) return;

    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );

    _server = server;

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4) {
            localAddress = address.address;
            break;
          }
        }
        if (localAddress != null) break;
      }
    } catch (_) {
      localAddress = null;
    }

    server.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    localAddress = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;

    response.headers.set(
      HttpHeaders.accessControlAllowOriginHeader,
      '*',
    );
    response.headers.set(
      HttpHeaders.accessControlAllowMethodsHeader,
      'GET, POST, OPTIONS',
    );
    response.headers.set(
      HttpHeaders.accessControlAllowHeadersHeader,
      'Content-Type',
    );

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      await response.close();
      return;
    }

    try {
      if (request.uri.path == '/' && request.method == 'GET') {
        response.headers.contentType = ContentType.html;
        response.write(_controlPage);
        await response.close();
        return;
      }

      if (request.uri.path == '/api/state' && request.method == 'GET') {
        if (request.uri.queryParameters['pin'] != pin) {
          await _sendJson(
            response,
            HttpStatus.unauthorized,
            {'error': 'PIN incorreto'},
          );
          return;
        }

        await _sendJson(
          response,
          HttpStatus.ok,
          _getState(),
        );
        return;
      }

      if (request.uri.path == '/api/command' && request.method == 'POST') {
        final body = await utf8.decoder.bind(request).join();
        final data = jsonDecode(body) as Map<String, dynamic>;

        if (data['pin'] != pin) {
          await _sendJson(
            response,
            HttpStatus.unauthorized,
            {'error': 'PIN incorreto'},
          );
          return;
        }

        final athlete = data['athlete'] as String?;
        final action = data['action'] as String?;

        const validAthletes = {'blue', 'white', 'none'};
        const validActions = {
          'add2',
          'add3',
          'add4',
          'advantage',
          'penalty',
          'undo',
        };

        if (athlete == null ||
            action == null ||
            !validAthletes.contains(athlete) ||
            !validActions.contains(action)) {
          await _sendJson(
            response,
            HttpStatus.badRequest,
            {'error': 'Comando inválido'},
          );
          return;
        }

        await _onCommand(athlete, action);

        await _sendJson(
          response,
          HttpStatus.ok,
          {
            'success': true,
            'state': _getState(),
          },
        );
        return;
      }

      await _sendJson(
        response,
        HttpStatus.notFound,
        {'error': 'Endereço não encontrado'},
      );
    } catch (_) {
      try {
        response.statusCode = HttpStatus.badRequest;
        response.headers.contentType = ContentType.json;
        response.write(
          jsonEncode({
            'error': 'Não foi possível processar a solicitação',
          }),
        );
        await response.close();
      } catch (_) {
        // A conexão pode já ter sido encerrada.
      }
    }
  }

  Future<void> _sendJson(
    HttpResponse response,
    int status,
    Object data,
  ) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
    await response.close();
  }

  static const String _controlPage = r'''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Controle do placar</title>
<style>
*{box-sizing:border-box}
body{margin:0;padding:16px;background:#f3f4f6;font-family:Arial,sans-serif;color:#111827}
h1{text-align:center;font-size:23px}
#login,.panel{max-width:600px;margin:16px auto;background:white;padding:16px;border-radius:16px}
input,button{font-size:17px;padding:12px;border-radius:10px}
input{width:100%;border:1px solid #bbb;margin:8px 0}
button{border:0;font-weight:bold;cursor:pointer}
.loginbtn{width:100%;background:#111827;color:white}
.athletes{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.athlete{padding:12px;border-radius:14px;text-align:center}
.blue{background:#1769d2;color:white}
.white{background:#e5e7eb;color:#111827}
.score{font-size:54px;font-weight:900;margin:8px}
.points{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}
.points button{background:#fff;color:#111827;border:1px solid #bbb}
.extra{display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-top:8px}
.extra button{background:#111827;color:white}
#status{text-align:center;font-size:14px;color:#555}
#timer{text-align:center;font-size:38px;font-weight:900}
#undo{display:block;width:100%;margin-top:12px;background:#b91c1c;color:white}
</style>
</head>
<body>
<h1>Controle do placar</h1>

<div id="login">
<label for="pin">PIN de acesso</label>
<input id="pin" type="password" inputmode="numeric" placeholder="Digite o PIN">
<button class="loginbtn" onclick="connect()">CONECTAR</button>
<p id="loginStatus"></p>
</div>

<div id="control" class="panel" hidden>
<div id="timer">--:--</div>

<div class="athletes">
<section class="athlete blue">
<h2>AZUL</h2>
<div class="score" id="bluePoints">0</div>
<div>Vantagens: <span id="blueAdvantages">0</span></div>
<div>Punições: <span id="bluePenalties">0</span></div>
<div class="points">
<button onclick="send('blue','add2')">+2</button>
<button onclick="send('blue','add3')">+3</button>
<button onclick="send('blue','add4')">+4</button>
</div>
<div class="extra">
<button onclick="send('blue','advantage')">VANTAGEM</button>
<button onclick="send('blue','penalty')">PUNIÇÃO</button>
</div>
</section>

<section class="athlete white">
<h2>BRANCO</h2>
<div class="score" id="whitePoints">0</div>
<div>Vantagens: <span id="whiteAdvantages">0</span></div>
<div>Punições: <span id="whitePenalties">0</span></div>
<div class="points">
<button onclick="send('white','add2')">+2</button>
<button onclick="send('white','add3')">+3</button>
<button onclick="send('white','add4')">+4</button>
</div>
<div class="extra">
<button onclick="send('white','advantage')">VANTAGEM</button>
<button onclick="send('white','penalty')">PUNIÇÃO</button>
</div>
</section>
</div>

<button id="undo" onclick="send('none','undo')">DESFAZER ÚLTIMA MARCAÇÃO</button>
<p id="status">Conectando...</p>
</div>

<script>
let pin = '';
let busy = false;

async function connect() {
  pin = document.getElementById('pin').value.trim();
  const status = document.getElementById('loginStatus');

  try {
    const response = await fetch('/api/state?pin=' + encodeURIComponent(pin));
    if (!response.ok) throw new Error('PIN incorreto ou acesso indisponível');

    document.getElementById('login').hidden = true;
    document.getElementById('control').hidden = false;
    render(await response.json());
    status.textContent = '';
    poll();
  } catch (e) {
    status.textContent = e.message;
  }
}

function render(s) {
  document.getElementById('timer').textContent = s.timeText ?? '--:--';

  for (const athlete of ['blue', 'white']) {
    document.getElementById(athlete + 'Points').textContent = s[athlete + 'Points'] ?? 0;
    document.getElementById(athlete + 'Advantages').textContent = s[athlete + 'Advantages'] ?? 0;
    document.getElementById(athlete + 'Penalties').textContent = s[athlete + 'Penalties'] ?? 0;
  }
}

async function poll() {
  try {
    const r = await fetch('/api/state?pin=' + encodeURIComponent(pin));
    if (r.status === 401) throw new Error('PIN inválido');
    if (r.ok) render(await r.json());
    document.getElementById('status').textContent = 'Conectado • atualização automática';
  } catch (e) {
    document.getElementById('status').textContent = 'Sem conexão. Tentando novamente...';
  }

  setTimeout(poll, 1000);
}

async function send(athlete, action) {
  if (busy) return;
  busy = true;

  try {
    const r = await fetch('/api/command', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({pin, athlete, action})
    });

    const result = await r.json();
    if (!r.ok) throw new Error(result.error || 'Falha ao enviar comando');

    render(result.state);
    document.getElementById('status').textContent = 'Marcação enviada';
  } catch (e) {
    document.getElementById('status').textContent = e.message;
  } finally {
    busy = false;
  }
}
</script>
</body>
</html>
''';
}
