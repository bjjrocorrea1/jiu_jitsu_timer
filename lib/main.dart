import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/services.dart';

import 'scoreboard_server.dart';

void main() => runApp(const JiuJitsuTimerApp());

const Color appGreen = Color(0xFF20B85A);
const Color competitionBlue = Color(0xFF1769D2);
const Color competitionWhite = Color(0xFFE5E7EB);
const Color darkBackground = Color(0xFF111318);

class JiuJitsuTimerApp extends StatelessWidget {
  const JiuJitsuTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jiu-Jitsu Timer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: appGreen),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const ModeSelectionPage(),
    );
  }
}

// ============================================================
// TELA INICIAL: ESCOLHA DO MODO
// ============================================================

class ModeSelectionPage extends StatelessWidget {
  const ModeSelectionPage({super.key});

  void _openMode(BuildContext context, {required bool competition}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TimerHomePage(
          competitionMode: competition,
        ),
      ),
    );
  }

  Widget _modeCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required bool competition,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        color: const Color(0xFFF4F5F7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _openMode(
            context,
            competition: competition,
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 650),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          color: appGreen,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: const Icon(
                          Icons.sports_martial_arts,
                          size: 52,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'JIU-JITSU TIMER',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Escolha como deseja treinar',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 36),
                      _modeCard(
                        context: context,
                        icon: Icons.timer,
                        title: 'TREINO DIÁRIO',
                        description: 'Cronômetro, descanso e bipes. '
                            'Sem placar na tela.',
                        color: appGreen,
                        competition: false,
                      ),
                      const SizedBox(height: 16),
                      _modeCard(
                        context: context,
                        icon: Icons.emoji_events,
                        title: 'MODO COMPETIÇÃO',
                        description: 'Placar azul e branco, pontos, vantagens, '
                            'punições e controle pelo celular.',
                        color: competitionBlue,
                        competition: true,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'O cronômetro funciona sem internet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

enum TimerPhase { ready, roll, rest, finished }

// ============================================================
// CRONÔMETRO E PLACAR
// ============================================================

class TimerHomePage extends StatefulWidget {
  const TimerHomePage({
    super.key,
    required this.competitionMode,
  });

  final bool competitionMode;

  @override
  State<TimerHomePage> createState() => _TimerHomePageState();
}

class _TimerHomePageState extends State<TimerHomePage> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Timer? _ticker;
  Timer? _blinkTicker;

  int _rollMinutes = 5;
  int _restSeconds = 60;
  int _totalRolls = 6;
  int _completedRolls = 0;
  int _secondsLeft = 300;

  TimerPhase _phase = TimerPhase.ready;

  bool _isRunning = false;
  bool _blinkOn = false;
  bool _lastTenAlertPlayed = false;

  int _bluePoints = 0;
  int _whitePoints = 0;
  int _blueAdvantages = 0;
  int _whiteAdvantages = 0;
  int _bluePenalties = 0;
  int _whitePenalties = 0;

  final List<Map<String, int>> _scoreHistory = [];

  ScoreboardServer? _scoreboardServer;
  String? _serverError;

  String get _timeText {
    final minutes = _secondsLeft ~/ 60;
    final seconds = _secondsLeft % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String get _phaseLabel {
    switch (_phase) {
      case TimerPhase.ready:
        return 'PRONTO PARA COMEÇAR';
      case TimerPhase.roll:
        return 'ROLA EM ANDAMENTO';
      case TimerPhase.rest:
        return 'DESCANSO';
      case TimerPhase.finished:
        return 'TREINO CONCLUÍDO';
    }
  }

  Color get _phaseColor {
    if (_phase == TimerPhase.rest) {
      return const Color(0xFFFF3030);
    }

    if (_phase == TimerPhase.finished) {
      return competitionWhite;
    }

    return appGreen;
  }

  Color get _timerPanelColor {
    if (_phase == TimerPhase.roll &&
        _secondsLeft <= 10 &&
        _isRunning &&
        _blinkOn) {
      return const Color(0xFFFF2020);
    }

    return _phaseColor;
  }

  String _durationLabel(int seconds) {
    if (seconds == 0) return 'Sem descanso';
    if (seconds < 60) return '$seconds s';
    if (seconds % 60 == 0) return '${seconds ~/ 60} min';

    return '${seconds ~/ 60} min ${seconds % 60} s';
  }

  @override
  void initState() {
    super.initState();

    // O servidor remoto só é iniciado no modo competição.
    if (widget.competitionMode) {
      _scoreboardServer = ScoreboardServer(
        getState: _getScoreboardState,
        onCommand: _handleScoreCommand,
      );

      unawaited(_startScoreboardServer());
    }
  }

  Map<String, dynamic> _getScoreboardState() {
    return {
      'timeText': _timeText,
      'bluePoints': _bluePoints,
      'whitePoints': _whitePoints,
      'blueAdvantages': _blueAdvantages,
      'whiteAdvantages': _whiteAdvantages,
      'bluePenalties': _bluePenalties,
      'whitePenalties': _whitePenalties,
      'isRunning': _isRunning,
      'phase': _phase.name,
      'completedRolls': _completedRolls,
      'totalRolls': _totalRolls,
    };
  }

  Future<void> _startScoreboardServer() async {
    final server = _scoreboardServer;
    if (server == null) return;

    try {
      await server.start();

      if (!mounted) return;

      setState(() {
        _serverError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _serverError = error.toString();
      });
    }
  }

  Future<void> _handleScoreCommand(
    String athlete,
    String action,
  ) async {
    if (!mounted) return;

    if (action == 'undo') {
      if (_scoreHistory.isEmpty) return;

      final previous = _scoreHistory.removeLast();

      setState(() {
        _bluePoints = previous['bluePoints']!;
        _whitePoints = previous['whitePoints']!;
        _blueAdvantages = previous['blueAdvantages']!;
        _whiteAdvantages = previous['whiteAdvantages']!;
        _bluePenalties = previous['bluePenalties']!;
        _whitePenalties = previous['whitePenalties']!;
      });

      return;
    }

    if (athlete != 'blue' && athlete != 'white') return;

    const validActions = {
      'add2',
      'add3',
      'add4',
      'advantage',
      'penalty',
    };

    if (!validActions.contains(action)) return;

    _scoreHistory.add({
      'bluePoints': _bluePoints,
      'whitePoints': _whitePoints,
      'blueAdvantages': _blueAdvantages,
      'whiteAdvantages': _whiteAdvantages,
      'bluePenalties': _bluePenalties,
      'whitePenalties': _whitePenalties,
    });

    setState(() {
      if (athlete == 'blue') {
        switch (action) {
          case 'add2':
            _bluePoints += 2;
          case 'add3':
            _bluePoints += 3;
          case 'add4':
            _bluePoints += 4;
          case 'advantage':
            _blueAdvantages++;
          case 'penalty':
            _bluePenalties++;
        }
      } else {
        switch (action) {
          case 'add2':
            _whitePoints += 2;
          case 'add3':
            _whitePoints += 3;
          case 'add4':
            _whitePoints += 4;
          case 'advantage':
            _whiteAdvantages++;
          case 'penalty':
            _whitePenalties++;
        }
      }
    });
  }

  Future<void> _beep({bool doubleBeep = false}) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/beep.wav'));

      if (doubleBeep) {
        await Future<void>.delayed(
          const Duration(milliseconds: 450),
        );
        await _audioPlayer.play(AssetSource('sounds/beep.wav'));
      }
    } catch (_) {
      // O cronômetro continua mesmo se o áudio falhar.
    }
  }

  void _startBlinking() {
    if (_blinkTicker != null || !_isRunning || _phase != TimerPhase.roll) {
      return;
    }

    _blinkTicker = Timer.periodic(
      const Duration(milliseconds: 450),
      (_) {
        if (!mounted || !_isRunning || _phase != TimerPhase.roll) {
          return;
        }

        setState(() {
          _blinkOn = !_blinkOn;
        });
      },
    );
  }

  void _stopBlinking() {
    _blinkTicker?.cancel();
    _blinkTicker = null;
    _blinkOn = false;
  }

  void _start() {
    if (_isRunning || _phase == TimerPhase.finished) return;

    setState(() {
      if (_phase == TimerPhase.ready) {
        _phase = TimerPhase.roll;
        _secondsLeft = _rollMinutes * 60;
        _lastTenAlertPlayed = false;
        unawaited(_beep());
      }

      _isRunning = true;
    });

    if (_phase == TimerPhase.roll && _secondsLeft <= 10) {
      _startBlinking();
    }

    unawaited(WakelockPlus.enable());

    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tick(),
    );
  }

  void _tick() {
    if (!mounted || !_isRunning) return;

    if (_secondsLeft > 1) {
      final nextSeconds = _secondsLeft - 1;

      setState(() {
        _secondsLeft = nextSeconds;
      });

      if (_phase == TimerPhase.roll &&
          nextSeconds <= 10 &&
          !_lastTenAlertPlayed) {
        _lastTenAlertPlayed = true;
        unawaited(_beep());
        _startBlinking();
      }

      return;
    }

    _advancePhase();
  }

  void _advancePhase() {
    _ticker?.cancel();
    _stopBlinking();

    if (_phase == TimerPhase.roll) {
      _completedRolls++;

      if (_completedRolls >= _totalRolls) {
        setState(() {
          _completedRolls = _totalRolls;
          _secondsLeft = 0;
          _phase = TimerPhase.finished;
          _isRunning = false;
          _lastTenAlertPlayed = false;
        });

        unawaited(_beep(doubleBeep: true));
        unawaited(WakelockPlus.disable());
        return;
      }

      setState(() {
        _phase = _restSeconds == 0 ? TimerPhase.roll : TimerPhase.rest;
        _secondsLeft = _restSeconds == 0 ? _rollMinutes * 60 : _restSeconds;
        _lastTenAlertPlayed = false;
      });

      unawaited(_beep(doubleBeep: true));
    } else if (_phase == TimerPhase.rest) {
      setState(() {
        _phase = TimerPhase.roll;
        _secondsLeft = _rollMinutes * 60;
        _lastTenAlertPlayed = false;
      });

      unawaited(_beep());
    }

    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tick(),
    );
  }

  void _pause() {
    _ticker?.cancel();
    _ticker = null;
    _stopBlinking();

    setState(() {
      _isRunning = false;
    });

    unawaited(WakelockPlus.disable());
  }

  void _reset() {
    _ticker?.cancel();
    _ticker = null;
    _stopBlinking();
    unawaited(WakelockPlus.disable());

    setState(() {
      _isRunning = false;
      _completedRolls = 0;
      _lastTenAlertPlayed = false;
      _phase = TimerPhase.ready;
      _secondsLeft = _rollMinutes * 60;

      _bluePoints = 0;
      _whitePoints = 0;
      _blueAdvantages = 0;
      _whiteAdvantages = 0;
      _bluePenalties = 0;
      _whitePenalties = 0;
      _scoreHistory.clear();
    });
  }

  Future<void> _confirmReset() async {
    if (_completedRolls == 0 && _phase == TimerPhase.ready) {
      _reset();
      return;
    }

    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reiniciar treino?'),
        content: const Text(
          'O cronômetro e o placar dos dois atletas serão zerados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('REINICIAR'),
          ),
        ],
      ),
    );

    if (shouldReset == true && mounted) {
      _reset();
    }
  }

  void _updateSettings({
    int? roll,
    int? restSeconds,
    int? total,
  }) {
    if (_isRunning ||
        (_phase != TimerPhase.ready && _phase != TimerPhase.finished)) {
      return;
    }

    setState(() {
      if (roll != null) _rollMinutes = roll;
      if (restSeconds != null) _restSeconds = restSeconds;
      if (total != null) _totalRolls = total;

      _secondsLeft = _rollMinutes * 60;
      _completedRolls = 0;
      _lastTenAlertPlayed = false;
      _phase = TimerPhase.ready;
    });
  }

  // ==========================================================
  // PLACAR DOS ATLETAS
  // ==========================================================

  Widget _scoreboardRow({bool compact = false}) {
    return Row(
      children: [
        Expanded(
          child: _scoreCard(
            name: 'AZUL',
            points: _bluePoints,
            advantages: _blueAdvantages,
            penalties: _bluePenalties,
            background: competitionBlue,
            foreground: Colors.white,
            compact: compact,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _scoreCard(
            name: 'BRANCO',
            points: _whitePoints,
            advantages: _whiteAdvantages,
            penalties: _whitePenalties,
            background: competitionWhite,
            foreground: Colors.black,
            compact: compact,
          ),
        ),
      ],
    );
  }

  Widget _scoreCard({
    required String name,
    required int points,
    required int advantages,
    required int penalties,
    required Color background,
    required Color foreground,
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 5 : 10,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 12 : 16,
                ),
              ),
              Text(
                '$points',
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 26 : 40,
                ),
              ),
            ],
          ),
          Text(
            'Vantagens: $advantages  •  Punições: $penalties',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 9 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _remoteControlCard() {
    final server = _scoreboardServer;
    final address = server?.localAddress;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.wifi, size: 20),
              SizedBox(width: 8),
              Text(
                'CONTROLE PELO CELULAR',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Para usar sem internet ou roteador, conecte o celular '
            'ao ponto de acesso Wi-Fi do tablet.',
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                const channel = MethodChannel('tako_bjj/network');

                try {
                  await channel.invokeMethod('openHotspotSettings');

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Ative o ponto de acesso Wi-Fi do tablet '
                        'nas configurações do Android.',
                      ),
                    ),
                  );
                } on PlatformException catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Não foi possível abrir as configurações: ${e.message}',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('CONFIGURAR CONEXÃO SEM INTERNET'),
            ),
          ),
          const SizedBox(height: 10),
          if (address != null) ...[
            const Text(
              'Depois de conectar o celular à rede Wi-Fi do tablet, '
              'abra este endereço no navegador:',
            ),
            const SizedBox(height: 4),
            SelectableText(
              'http://$address:8787',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text('PIN configurado: 4826'),
          ] else if (_serverError != null) ...[
            Text(
              'O servidor remoto não iniciou: $_serverError',
              style: const TextStyle(color: Colors.red),
            ),
          ] else if (server?.isRunning == true) ...[
            const Text(
              'O servidor está ativo, mas não foi encontrado um endereço '
              'de rede. Verifique a conexão Wi-Fi do tablet.',
            ),
          ] else ...[
            const Text('Iniciando o servidor de controle...'),
          ],
        ],
      ),
    );
  }

  // ==
  // TELA PRINCIPAL DO MODO ESCOLHIDO
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final progress = _phase == TimerPhase.rest
        ? (_restSeconds == 0 ? 0.0 : 1 - (_secondsLeft / _restSeconds))
        : _phase == TimerPhase.roll
            ? 1 - (_secondsLeft / (_rollMinutes * 60))
            : _phase == TimerPhase.finished
                ? 1.0
                : 0.0;

    if (_phase == TimerPhase.roll || _phase == TimerPhase.rest) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = constraints.maxWidth > constraints.maxHeight;

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 12 : 20,
                  vertical: isLandscape ? 4 : 10,
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: isLandscape ? 38 : 44,
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Voltar ao menu',
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints.tightFor(
                              width: isLandscape ? 36 : 42,
                              height: isLandscape ? 36 : 44,
                            ),
                            icon: const Icon(Icons.home_outlined),
                          ),
                          Icon(
                            Icons.sports_martial_arts,
                            size: isLandscape ? 23 : 28,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.competitionMode
                                  ? 'MODO COMPETIÇÃO'
                                  : 'TREINO DIÁRIO',
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Reiniciar contagem',
                            onPressed: _confirmReset,
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints.tightFor(
                              width: isLandscape ? 40 : 48,
                              height: isLandscape ? 36 : 44,
                            ),
                            icon: const Icon(Icons.restart_alt),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isLandscape ? 4 : 8),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: isLandscape ? 10 : 12,
                          vertical: isLandscape ? 5 : 12,
                        ),
                        decoration: BoxDecoration(
                          color: _timerPanelColor,
                          borderRadius: BorderRadius.circular(
                            isLandscape ? 20 : 28,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (widget.competitionMode)
                              _scoreboardRow(compact: true),
                            Text(
                              _phase == TimerPhase.roll && _secondsLeft <= 10
                                  ? '⚠ TEMPO ACABANDO!'
                                  : _phaseLabel,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: isLandscape ? 15 : 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: isLandscape ? 0.5 : 1.1,
                              ),
                            ),
                            Expanded(
                              child: SizedBox(
                                width: double.infinity,
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: Text(
                                    _timeText,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: isLandscape ? 190 : 230,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_phase == TimerPhase.roll && _secondsLeft <= 10)
                              Text(
                                'ÚLTIMOS 10 SEGUNDOS',
                                maxLines: 1,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: isLandscape ? 12 : 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                minHeight: isLandscape ? 7 : 10,
                                backgroundColor: const Color(0xFFE5E7EB),
                                color: _phaseColor,
                              ),
                            ),
                            Text(
                              'ROLA ${_completedRolls + 1} DE $_totalRolls',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: isLandscape ? 16 : 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isLandscape ? 5 : 12),
                    SizedBox(
                      width: double.infinity,
                      height: isLandscape ? 48 : 68,
                      child: FilledButton.icon(
                        onPressed: _isRunning ? _pause : _start,
                        icon: Icon(
                          _isRunning
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: isLandscape ? 28 : 34,
                        ),
                        label: Text(
                          _isRunning ? 'PAUSAR' : 'CONTINUAR',
                          style: TextStyle(
                            fontSize: isLandscape ? 18 : 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _phaseColor,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar ao menu',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          widget.competitionMode ? 'MODO COMPETIÇÃO' : 'TREINO DIÁRIO',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Column(
                  children: [
                    _settingsPanel(),
                    if (widget.competitionMode) ...[
                      const SizedBox(height: 12),
                      _scoreboardRow(),
                      const SizedBox(height: 12),
                      _remoteControlCard(),
                    ],
                    const SizedBox(height: 24),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 22,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _timerPanelColor,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _phaseLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _timeText,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 76,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                fontFeatures: [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE5E7EB),
                        color: _phaseColor,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      _phase == TimerPhase.finished
                          ? 'TREINO CONCLUÍDO: '
                              '$_totalRolls DE $_totalRolls'
                          : 'PRÓXIMA ROLA: ${_completedRolls + 1} '
                              'DE $_totalRolls',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_completedRolls rola(s) concluído(s)',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _infoCard(
                            'TEMPO DO ROLA',
                            '$_rollMinutes min',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _infoCard(
                            'DESCANSO',
                            _durationLabel(_restSeconds),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 66,
                      child: FilledButton.icon(
                        onPressed: _phase == TimerPhase.finished
                            ? _reset
                            : _isRunning
                                ? _pause
                                : _start,
                        icon: Icon(
                          _phase == TimerPhase.finished
                              ? Icons.replay
                              : _isRunning
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                          size: 30,
                        ),
                        label: Text(
                          _phase == TimerPhase.finished
                              ? 'NOVO TREINO'
                              : _isRunning
                                  ? 'PAUSAR'
                                  : 'COMEÇAR TREINO',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _phaseColor,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _confirmReset,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text(
                          'REINICIAR CONTAGEM',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================================
  // CONFIGURAÇÕES E CARTÕES
  // ==========================================================

  Widget _settingsPanel() {
    final locked = _isRunning ||
        (_phase != TimerPhase.ready && _phase != TimerPhase.finished);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, size: 18),
              SizedBox(width: 8),
              Text(
                'CONFIGURAR TREINO',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _settingControl(
                  label: 'Rola (min)',
                  value: _rollMinutes,
                  options: const [3, 4, 5, 6, 7, 8],
                  enabled: !locked,
                  onChanged: (v) => _updateSettings(roll: v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _settingControl(
                  label: 'Descanso (seg)',
                  value: _restSeconds,
                  options: const [
                    0,
                    10,
                    15,
                    20,
                    30,
                    45,
                    60,
                    90,
                    120,
                    180,
                  ],
                  enabled: !locked,
                  onChanged: (v) => _updateSettings(restSeconds: v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _settingControl(
                  label: 'Nº de rolas',
                  value: _totalRolls,
                  options: const [
                    1,
                    2,
                    3,
                    4,
                    5,
                    6,
                    8,
                    10,
                    12,
                    15,
                  ],
                  enabled: !locked,
                  onChanged: (v) => _updateSettings(total: v),
                ),
              ),
            ],
          ),
          if (locked)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Pause e reinicie o treino para alterar as configurações.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _settingControl({
    required String label,
    required int value,
    required List<int> options,
    required bool enabled,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              isDense: true,
              iconSize: 18,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
              dropdownColor: Colors.white,
              onChanged: enabled
                  ? (v) {
                      if (v != null) onChanged(v);
                    }
                  : null,
              items: options.map((v) {
                return DropdownMenuItem<int>(
                  value: v,
                  child: Text(
                    label.startsWith('Descanso') ? _durationLabel(v) : '$v',
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 15,
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _blinkTicker?.cancel();

    unawaited(_audioPlayer.dispose());
    unawaited(WakelockPlus.disable());

    final server = _scoreboardServer;
    if (server != null) {
      unawaited(server.stop());
    }

    super.dispose();
  }
}
