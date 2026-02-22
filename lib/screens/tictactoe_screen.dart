import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/energy_manager.dart';
import '../services/userprofile_service.dart';
import '../services/player_stats_service.dart';

// ═══════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════
enum Player { x, o, none }
enum Difficulty { easy, medium, hard }

// ═══════════════════════════════════════════════════════════════
// BRAND COLOURS — shared across all screens
// ═══════════════════════════════════════════════════════════════
class _C {
  static const blue   = Color(0xFF004A98);
  static const red    = Color(0xFFED262A);
  static const white  = Color(0xFFFFFFFF);
  static const dark   = Color(0xFF0D1117);
  static const xColor = Color(0xFF4FC3F7); // light blue for X
  static const oColor = Color(0xFFFF7043); // deep orange for O
}

// ═══════════════════════════════════════════════════════════════
// START SCREEN — logo splash → auto goes to setup
// ═══════════════════════════════════════════════════════════════
class TicTacToeStartScreen extends StatefulWidget {
  const TicTacToeStartScreen({super.key});

  @override
  State<TicTacToeStartScreen> createState() => _TicTacToeStartScreenState();
}

class _TicTacToeStartScreenState extends State<TicTacToeStartScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TicTacToeSetupScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.dark,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/pngs/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.5)),
          Center(
            child: Image.asset(
              'assets/images/pngs/logo.png',
              height: 300,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SETUP SCREEN — pick symbol + difficulty, costs 10 energy
// ═══════════════════════════════════════════════════════════════
class TicTacToeSetupScreen extends StatefulWidget {
  /// Pre-filled when the loser of the previous round gets to choose
  final Player? preSelectedSymbol;

  const TicTacToeSetupScreen({super.key, this.preSelectedSymbol});

  @override
  State<TicTacToeSetupScreen> createState() => _TicTacToeSetupScreenState();
}

class _TicTacToeSetupScreenState extends State<TicTacToeSetupScreen> {
  Player _symbol = Player.x;
  Difficulty _diff = Difficulty.medium;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedSymbol != null) _symbol = widget.preSelectedSymbol!;
  }

  Future<void> _play() async {
    setState(() => _loading = true);

    final hasEnergy = await EnergyManager.instance.hasEnoughEnergy(required: 10);
    if (!mounted) return;
    if (!hasEnergy) {
      setState(() => _loading = false);
      _alert('Not Enough Energy',
          'You need 10 energy to play. Wait for it to regenerate!');
      return;
    }

    final ok = await EnergyManager.instance.useEnergy(amount: 10);
    if (!mounted) return;
    if (!ok) {
      setState(() => _loading = false);
      _alert('Error', 'Something went wrong. Please try again.');
      return;
    }

    setState(() => _loading = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TicTacToeGameScreen(
          playerSymbol: _symbol,
          difficulty: _diff,
        ),
      ),
    );
  }

  void _alert(String title, String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(color: _C.white, fontFamily: 'LilitaOne')),
        content: Text(msg, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: _C.xColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.dark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // BG
          Image.asset('assets/images/pngs/background.png', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.72)),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Title ──────────────────────────────────
                    const Text('TIC TAC TOE',
                        style: TextStyle(
                          fontFamily: 'LilitaOne',
                          fontSize: 38,
                          color: _C.white,
                          letterSpacing: 4,
                          shadows: [
                            Shadow(color: _C.xColor, blurRadius: 18),
                          ],
                        )),
                    const SizedBox(height: 4),
                    const Text('O goes first  ·  X goes second',
                        style:
                        TextStyle(color: Colors.white38, fontSize: 12.5)),
                    const SizedBox(height: 36),

                    // ── Symbol picker ───────────────────────────
                    _Card(
                      label: 'YOUR SYMBOL',
                      child: Row(
                        children: [
                          _SymbolTile(
                            letter: 'O',
                            sub: 'Goes First',
                            accent: _C.oColor,
                            chosen: _symbol == Player.o,
                            onTap: () => setState(() => _symbol = Player.o),
                          ),
                          const SizedBox(width: 12),
                          _SymbolTile(
                            letter: 'X',
                            sub: 'Goes Second',
                            accent: _C.xColor,
                            chosen: _symbol == Player.x,
                            onTap: () => setState(() => _symbol = Player.x),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Difficulty picker ───────────────────────
                    _Card(
                      label: 'DIFFICULTY',
                      child: Row(
                        children: [
                          _DiffTile(
                            label: 'EASY',
                            accent: Colors.green.shade400,
                            chosen: _diff == Difficulty.easy,
                            onTap: () => setState(() => _diff = Difficulty.easy),
                          ),
                          const SizedBox(width: 8),
                          _DiffTile(
                            label: 'MEDIUM',
                            accent: Colors.orange.shade400,
                            chosen: _diff == Difficulty.medium,
                            onTap: () =>
                                setState(() => _diff = Difficulty.medium),
                          ),
                          const SizedBox(width: 8),
                          _DiffTile(
                            label: 'HARD',
                            accent: Colors.red.shade400,
                            chosen: _diff == Difficulty.hard,
                            onTap: () => setState(() => _diff = Difficulty.hard),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Energy badge ────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt,
                            color: Colors.orange.shade300, size: 16),
                        const SizedBox(width: 5),
                        Text('Costs 10 Energy',
                            style: TextStyle(
                                color: Colors.orange.shade300,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // ── PLAY ────────────────────────────────────
                    _BigButton(
                      label: 'PLAY',
                      color: _C.blue,
                      loading: _loading,
                      onTap: _loading ? null : _play,
                    ),
                    const SizedBox(height: 14),

                    // ── EXIT ────────────────────────────────────
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('EXIT',
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 15,
                              letterSpacing: 1.5,
                              fontFamily: 'LilitaOne')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GAME SCREEN
// No AnimationController — removed _winAnim entirely (was causing
// the unwanted 3-star Flutter celebration overlay)
// ═══════════════════════════════════════════════════════════════
class TicTacToeGameScreen extends StatefulWidget {
  final Player playerSymbol;
  final Difficulty difficulty;

  const TicTacToeGameScreen({
    super.key,
    required this.playerSymbol,
    required this.difficulty,
  });

  @override
  State<TicTacToeGameScreen> createState() => _TicTacToeGameScreenState();
}

// No SingleTickerProviderStateMixin — removed since _winAnim is gone
class _TicTacToeGameScreenState extends State<TicTacToeGameScreen> {
  late final Player _me;
  late final Player _ai;
  final List<Player> _board = List.filled(9, Player.none);
  late Player _turn; // who moves next (O always first)
  bool _aiThinking = false;
  bool _over = false;
  Player _winner = Player.none;
  List<int> _winLine = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _me = widget.playerSymbol;
    _ai = _me == Player.x ? Player.o : Player.x;
    _turn = Player.o; // O always goes first
    // If AI is O, it moves immediately
    if (_ai == Player.o) _scheduleAi();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  // ── Player taps ─────────────────────────────────────────────
  void _tap(int i) {
    if (_over || _aiThinking || _board[i] != Player.none || _turn != _me) return;
    _place(i, _me);
  }

  void _place(int i, Player p) {
    setState(() {
      _board[i] = p;
      _turn = p == _me ? _ai : _me;
    });

    final won = _winOf(p);
    if (won != null) { _finish(p, won); return; }
    if (_tied())     { _finish(Player.none, []); return; }

    if (p == _me) _scheduleAi();
  }

  // ── AI ───────────────────────────────────────────────────────
  void _scheduleAi() {
    setState(() => _aiThinking = true);
    final ms = switch (widget.difficulty) {
      Difficulty.easy   => 350,
      Difficulty.medium => 600,
      Difficulty.hard   => 900,
    };
    Future.delayed(Duration(milliseconds: ms), () {
      if (!mounted || _over) return;
      final move = _aiMove();
      if (move == null) return;
      setState(() => _aiThinking = false);
      _place(move, _ai);
    });
  }

  int? _aiMove() {
    final empty = [for (int i = 0; i < 9; i++) if (_board[i] == Player.none) i];
    if (empty.isEmpty) return null;

    return switch (widget.difficulty) {
      Difficulty.easy   => _rng.nextDouble() < 0.70
          ? empty[_rng.nextInt(empty.length)]
          : (_smart() ?? empty[_rng.nextInt(empty.length)]),
      Difficulty.medium => _rng.nextDouble() < 0.40
          ? empty[_rng.nextInt(empty.length)]
          : (_smart() ?? empty[_rng.nextInt(empty.length)]),
      Difficulty.hard   => _minimaxMove(),
    };
  }

  int? _smart() {
    // Win
    final w = _best(_ai); if (w != null) return w;
    // Block
    final b = _best(_me); if (b != null) return b;
    // Centre
    if (_board[4] == Player.none) return 4;
    // Corner
    final corners = [0,2,6,8].where((i) => _board[i] == Player.none).toList();
    if (corners.isNotEmpty) return corners[_rng.nextInt(corners.length)];
    return null;
  }

  int? _best(Player p) {
    const lines = [
      [0,1,2],[3,4,5],[6,7,8],
      [0,3,6],[1,4,7],[2,5,8],
      [0,4,8],[2,4,6],
    ];
    for (final l in lines) {
      if (l.where((i) => _board[i] == p).length == 2 &&
          l.where((i) => _board[i] == Player.none).length == 1) {
        return l.firstWhere((i) => _board[i] == Player.none);
      }
    }
    return null;
  }

  int _minimaxMove() {
    int best = -99, bestIdx = -1;
    for (int i = 0; i < 9; i++) {
      if (_board[i] != Player.none) continue;
      _board[i] = _ai;
      final s = _mm(false, -99, 99, 0);
      _board[i] = Player.none;
      if (s > best) { best = s; bestIdx = i; }
    }
    return bestIdx;
  }

  int _mm(bool max, int alpha, int beta, int depth) {
    if (_winOf(_ai) != null) return 10 - depth;
    if (_winOf(_me) != null) return depth - 10;
    if (_tied()) return 0;
    if (max) {
      int v = -99;
      for (int i = 0; i < 9; i++) {
        if (_board[i] != Player.none) continue;
        _board[i] = _ai;
        v = v > _mm(false, alpha, beta, depth + 1) ? v : _mm(false, alpha, beta, depth + 1);
        _board[i] = Player.none;
        alpha = alpha > v ? alpha : v;
        if (beta <= alpha) break;
      }
      return v;
    } else {
      int v = 99;
      for (int i = 0; i < 9; i++) {
        if (_board[i] != Player.none) continue;
        _board[i] = _me;
        v = v < _mm(true, alpha, beta, depth + 1) ? v : _mm(true, alpha, beta, depth + 1);
        _board[i] = Player.none;
        beta = beta < v ? beta : v;
        if (beta <= alpha) break;
      }
      return v;
    }
  }

  // ── Detection ────────────────────────────────────────────────
  static const _lines = [
    [0,1,2],[3,4,5],[6,7,8],
    [0,3,6],[1,4,7],[2,5,8],
    [0,4,8],[2,4,6],
  ];

  List<int>? _winOf(Player p) {
    for (final l in _lines) {
      if (l.every((i) => _board[i] == p)) return l;
    }
    return null;
  }

  bool _tied() => _board.every((c) => c != Player.none);

  // ── End ──────────────────────────────────────────────────────
  void _finish(Player w, List<int> line) {
    if (_over) return;
    setState(() {
      _over       = true;
      _winner     = w;
      _winLine    = line;
      _aiThinking = false;
    });
    _saveGameResult(w); // ← replaces if (w == _me) _giveCoins()
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _showResult();
    });
  }

  Future<void> _saveGameResult(Player winner) async {
    try {
      final iWon  = winner == _me;
      final isTie = winner == Player.none;

      final String result = isTie ? 'tie' : iWon ? 'win' : 'loss';

      final coins = iWon
          ? switch (widget.difficulty) {
        Difficulty.easy   => 5,
        Difficulty.medium => 15,
        Difficulty.hard   => 30,
      }
          : 0;

      if (coins > 0) {
        await UserProfileService()
            .addCoins(amount: coins, reason: 'Won Tic Tac Toe');
      }

      await UserProfileService().updateGameStats(
        gamesPlayed: 1,
        gamesWon: iWon ? 1 : 0,
      );

      await PlayerStatsService().saveTicTacToeSession(
        result: result,
        scoreEarned: coins,
      );
    } catch (e) {
      debugPrint('Game save error: $e');
    }
  }

  // ── Result dialog ─────────────────────────────────────────────
  void _showResult() {
    final iWon = _winner == _me;
    final isTie = _winner == Player.none;

    final accent = isTie
        ? Colors.yellow.shade400
        : iWon
        ? Colors.green.shade400
        : _C.red;

    final coins = switch (widget.difficulty) {
      Difficulty.easy   => 5,
      Difficulty.medium => 15,
      Difficulty.hard   => 30,
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: accent.withOpacity(0.35),
                  blurRadius: 28,
                  spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Result icon
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 2),
                ),
                child: Icon(
                  isTie
                      ? Icons.handshake_rounded
                      : iWon
                      ? Icons.emoji_events_rounded
                      : Icons.sentiment_dissatisfied_rounded,
                  color: accent,
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),

              // Result text
              Text(
                isTie ? "IT'S A TIE!" : iWon ? 'YOU WIN!' : 'SMARTY WINS!',
                style: TextStyle(
                  fontFamily: 'LilitaOne',
                  fontSize: 30,
                  color: accent,
                  letterSpacing: 1.5,
                  shadows: [Shadow(color: accent.withOpacity(0.5), blurRadius: 12)],
                ),
                textAlign: TextAlign.center,
              ),

              // Coins notice
              if (iWon) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monetization_on_rounded,
                        color: Colors.amber, size: 18),
                    const SizedBox(width: 5),
                    Text('+$coins coins earned!',
                        style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],

              const SizedBox(height: 8),
              Text(
                isTie
                    ? 'You get to choose next!'
                    : iWon
                    ? 'Smarty picks next symbol'
                    : 'You choose your setup!',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // PLAY AGAIN
              _BigButton(
                label: 'PLAY AGAIN',
                color: _C.blue,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _again(iWon: iWon, isTie: isTie);
                },
              ),
              const SizedBox(height: 10),

              // EXIT
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('EXIT',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                        letterSpacing: 1.5,
                        fontFamily: 'LilitaOne')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _again({required bool iWon, required bool isTie}) {
    if (isTie) {
      // Tie → player chooses
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const TicTacToeSetupScreen()));
      return;
    }
    if (iWon) {
      // Player won → bot randomly assigns symbols, no setup screen
      final botIsX = _rng.nextBool();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TicTacToeGameScreen(
            playerSymbol: botIsX ? Player.o : Player.x,
            difficulty: widget.difficulty,
          ),
        ),
      );
    } else {
      // Player lost → player gets to choose
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TicTacToeSetupScreen(preSelectedSymbol: _me),
        ),
      );
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final statusText = _over
        ? ''
        : _aiThinking
        ? 'Smarty is thinking...'
        : 'Your turn (${_me == Player.x ? "X" : "O"})';

    return Scaffold(
      backgroundColor: _C.dark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/pngs/background.png', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.72)),

          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      // Difficulty chip
                      _Chip(
                        label: widget.difficulty.name.toUpperCase(),
                        color: _diffColor(widget.difficulty),
                      ),
                      const Spacer(),
                      // Player symbol chip
                      _Chip(
                        label: 'You: ${_me == Player.x ? "X" : "O"}',
                        color: _me == Player.x ? _C.xColor : _C.oColor,
                      ),
                    ],
                  ),
                ),

                // ── Status ───────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    statusText,
                    key: ValueKey(statusText),
                    style: TextStyle(
                      fontFamily: 'LilitaOne',
                      fontSize: 20,
                      color: _aiThinking
                          ? Colors.orange.shade300
                          : Colors.white,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 8)
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Board ─────────────────────────────────────
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: 9,
                          itemBuilder: (_, i) => _Cell(
                            player: _board[i],
                            isWin: _winLine.contains(i),
                            winner: _winner,
                            meSymbol: _me,
                            canTap: !_over &&
                                !_aiThinking &&
                                _board[i] == Player.none &&
                                _turn == _me,
                            cellSize: size.width / 3.5,
                            onTap: () => _tap(i),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _diffColor(Difficulty d) => switch (d) {
    Difficulty.easy   => Colors.green.shade400,
    Difficulty.medium => Colors.orange.shade400,
    Difficulty.hard   => Colors.red.shade400,
  };
}

// ═══════════════════════════════════════════════════════════════
// CELL WIDGET — extracted for clarity
// ═══════════════════════════════════════════════════════════════
class _Cell extends StatelessWidget {
  final Player player;
  final bool isWin;
  final Player winner;
  final Player meSymbol;
  final bool canTap;
  final double cellSize;
  final VoidCallback onTap;

  const _Cell({
    required this.player,
    required this.isWin,
    required this.winner,
    required this.meSymbol,
    required this.canTap,
    required this.cellSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color cellBorder;
    final Color cellBg;

    if (isWin) {
      final iPlayerWon = winner == meSymbol;
      cellBg     = (iPlayerWon ? Colors.green : _C.red).withOpacity(0.2);
      cellBorder = iPlayerWon ? Colors.green.shade300 : Colors.red.shade300;
    } else if (player != Player.none) {
      cellBg     = (player == Player.x ? _C.xColor : _C.oColor).withOpacity(0.1);
      cellBorder = player == Player.x ? _C.xColor : _C.oColor;
    } else {
      cellBg     = Colors.white.withOpacity(0.06);
      cellBorder = Colors.white.withOpacity(0.18);
    }

    return GestureDetector(
      onTap: canTap ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: cellBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cellBorder,
            width: isWin ? 2.5 : 1.8,
          ),
          boxShadow: isWin
              ? [
            BoxShadow(
              color: cellBorder.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 1,
            )
          ]
              : [],
        ),
        child: Center(
          child: player == Player.none
              ? (canTap
              ? Icon(Icons.add,
              color: Colors.white.withOpacity(0.12),
              size: cellSize * 0.45)
              : const SizedBox())
              : Text(
            player == Player.x ? 'X' : 'O',
            style: TextStyle(
              fontFamily: 'LilitaOne',
              fontSize: cellSize * 0.65,
              color:
              player == Player.x ? _C.xColor : _C.oColor,
              shadows: [
                Shadow(
                  color: (player == Player.x ? _C.xColor : _C.oColor)
                      .withOpacity(0.6),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════
class _Card extends StatelessWidget {
  final String label;
  final Widget child;
  const _Card({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10.5,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SymbolTile extends StatelessWidget {
  final String letter;
  final String sub;
  final Color accent;
  final bool chosen;
  final VoidCallback onTap;
  const _SymbolTile(
      {required this.letter,
        required this.sub,
        required this.accent,
        required this.chosen,
        required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: chosen ? accent.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: chosen ? accent : Colors.white.withOpacity(0.18),
              width: chosen ? 2.5 : 1.5),
        ),
        child: Column(children: [
          Text(letter,
              style: TextStyle(
                  fontFamily: 'LilitaOne',
                  fontSize: 38,
                  color: chosen ? accent : Colors.white24,
                  shadows: chosen
                      ? [Shadow(color: accent.withOpacity(0.6), blurRadius: 12)]
                      : [])),
          const SizedBox(height: 4),
          Text(sub,
              style: TextStyle(
                  fontSize: 10.5,
                  color: chosen ? accent : Colors.white24,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    ),
  );
}

class _DiffTile extends StatelessWidget {
  final String label;
  final Color accent;
  final bool chosen;
  final VoidCallback onTap;
  const _DiffTile(
      {required this.label,
        required this.accent,
        required this.chosen,
        required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: chosen ? accent.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: chosen ? accent : Colors.white.withOpacity(0.18),
              width: chosen ? 2.5 : 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: chosen ? accent : Colors.white24),
            textAlign: TextAlign.center),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.6), width: 1.5),
    ),
    child: Text(label,
        style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5)),
  );
}

class _BigButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;
  const _BigButton(
      {required this.label,
        required this.color,
        this.onTap,
        this.loading = false});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: onTap == null ? color.withOpacity(0.4) : color,
        padding: const EdgeInsets.symmetric(vertical: 17),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 8,
      ),
      child: loading
          ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              color: _C.white, strokeWidth: 2))
          : Text(label,
          style: const TextStyle(
              fontFamily: 'LilitaOne',
              fontSize: 20,
              color: _C.white,
              letterSpacing: 2)),
    ),
  );
}