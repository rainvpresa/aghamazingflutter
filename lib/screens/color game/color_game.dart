import 'package:flutter/material.dart';
import 'dart:math';
import '../../services/userprofile_service.dart';
import '../../services/player_stats_service.dart';
import '../../widgets/game_quit_handler.dart';

class ColorPuzzleGame extends StatefulWidget {
  const ColorPuzzleGame({Key? key}) : super(key: key);

  @override
  State<ColorPuzzleGame> createState() => _ColorPuzzleGameState();
}

class _ColorPuzzleGameState extends State<ColorPuzzleGame> with GameQuitHandler {
  // Game configuration
  static const int rows = 3;
  static const int bottlesPerRow = 3;
  static const int totalSpots = rows * bottlesPerRow;
  static const int emptySpots = 2;
  static const int segmentsPerBottle = 3;

  final List<Color> availableColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
  ];

  List<List<Color>?> bottles = [];
  int moveCount = 0;
  bool gameWon = false;
  bool isGameActive = false;

  final UserProfileService _profileService = UserProfileService();
  bool _isSavingRewards = false;

  @override
  void initState() {
    super.initState();
    initializeGame();
  }

  void initializeGame() {
    bottles = [];
    moveCount = 0;
    gameWon = false;
    isGameActive = true;

    Random random = Random();
    int numBottles = totalSpots - emptySpots;
    List<List<Color>?> allBottles = [];

    for (int row = 0; row < rows; row++) {
      Color rowColor = availableColors[row % availableColors.length];
      for (int i = 0; i < bottlesPerRow && allBottles.length < numBottles; i++) {
        allBottles.add(List.filled(segmentsPerBottle, rowColor));
      }
    }

    for (int i = 0; i < emptySpots; i++) {
      allBottles.add(null);
    }

    for (int shuffleRound = 0; shuffleRound < 5; shuffleRound++) {
      allBottles.shuffle(random);
      for (int swaps = 0; swaps < 10; swaps++) {
        int idx1 = random.nextInt(allBottles.length);
        int idx2 = random.nextInt(allBottles.length);
        var temp = allBottles[idx1];
        allBottles[idx1] = allBottles[idx2];
        allBottles[idx2] = temp;
      }
    }

    bottles = allBottles;

    int attempts = 0;
    while (checkWinCondition() && attempts < 20) {
      bottles.shuffle(random);
      attempts++;
    }

    setState(() {});
  }

  bool checkWinCondition() {
    for (int row = 0; row < rows; row++) {
      int startIndex = row * bottlesPerRow;
      List<List<Color>> rowBottles = [];
      for (int i = 0; i < bottlesPerRow; i++) {
        int bottleIndex = startIndex + i;
        if (bottles[bottleIndex] != null) {
          rowBottles.add(bottles[bottleIndex]!);
        }
      }
      if (rowBottles.isEmpty) continue;
      Color firstBottleColor = rowBottles[0][0];
      for (var bottle in rowBottles) {
        if (!bottle.every((c) => c == firstBottleColor)) return false;
      }
    }
    return true;
  }

  void onBottleTap(int index) {
    if (gameWon) return;
    if (bottles[index] == null) return;
    int? emptySpotIndex = _findAdjacentEmptySpot(index);
    if (emptySpotIndex != null) {
      setState(() {
        bottles[emptySpotIndex] = bottles[index];
        bottles[index] = null;
        moveCount++;
        if (checkWinCondition()) {
          gameWon = true;
          isGameActive = false;
          _showWinDialog();
        }
      });
    }
  }

  int? _findAdjacentEmptySpot(int index) {
    int row = index ~/ bottlesPerRow;
    int col = index % bottlesPerRow;
    List<List<int>> directions = [[-1, 0], [1, 0], [0, -1], [0, 1]];
    for (var dir in directions) {
      int newRow = row + dir[0];
      int newCol = col + dir[1];
      if (newRow >= 0 && newRow < rows && newCol >= 0 && newCol < bottlesPerRow) {
        int adjacentIndex = newRow * bottlesPerRow + newCol;
        if (bottles[adjacentIndex] == null) return adjacentIndex;
      }
    }
    return null;
  }

  Map<String, int> _calculateRewards({bool isQuitting = false}) {
    if (isQuitting && moveCount < 5) return {'points': 0, 'coins': 0};
    int basePoints = 100;
    int baseCoins  = 50;
    int optimalMoves = 12;
    int extraMoves   = max(0, moveCount - optimalMoves);
    int points = max(20, basePoints - (extraMoves * 3));
    int coins  = max(10, baseCoins  - (extraMoves * 2));
    if (isQuitting) {
      points = (points * 0.5).round();
      coins  = (coins  * 0.5).round();
    }
    return {'points': points, 'coins': coins};
  }

  Future<void> _saveRewards(int coins, int points, {bool won = true}) async {
    setState(() => _isSavingRewards = true);
    try {
      await _profileService.updateGameStats(
        gamesPlayed: 1,
        gamesWon: won ? 1 : 0,
        totalScore: points,
      );
      if (coins > 0) {
        await _profileService.addCoins(
          amount: coins,
          reason: 'Color Puzzle Game - $moveCount moves ${won ? "" : "(Quit early)"}',
        );
      }
      await PlayerStatsService().saveColorPuzzleSession(
        moveCount: moveCount,
        optimalMoves: 12,
        scoreEarned: points,
        coinsEarned: coins,
      );
    } catch (e) {
      debugPrint('❌ Error saving rewards: $e');
    } finally {
      setState(() => _isSavingRewards = false);
    }
  }

  void _onBackPressed() {
    if (!isGameActive || moveCount == 0) {
      Navigator.pop(context);
      return;
    }
    showQuitConfirmDialog(
      context,
      onConfirm: () async {
        setState(() => isGameActive = false);
        final rewards = _calculateRewards(isQuitting: true);
        await _saveRewards(rewards['coins']!, rewards['points']!, won: false);
        if (mounted) _showWinDialog(isQuitting: true);
      },
    );
  }

  // ── Arcade-themed win / end dialog ─────────────────────────────────────────
  void _showWinDialog({bool isQuitting = false}) async {
    final rewards      = _calculateRewards(isQuitting: isQuitting);
    final int coinsEarned  = rewards['coins']!;
    final int pointsEarned = rewards['points']!;

    if (!isQuitting) await _saveRewards(coinsEarned, pointsEarned);
    if (!mounted) return;

    final size = MediaQuery.of(context).size;
    final ref  = size.shortestSide;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(horizontal: size.width * 0.07),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ref * 0.068),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
              colors: isQuitting
                  ? [const Color(0xFF3D1F00), const Color(0xFF1E0E00)]
                  : [const Color(0xFF1A3800), const Color(0xFF0A1800)],
            ),
            border: Border.all(
              color: (isQuitting
                  ? const Color(0xFFFF9500)
                  : const Color(0xFF39E14B))
                  .withOpacity(0.75),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isQuitting
                    ? const Color(0xFFFF9500)
                    : const Color(0xFF39E14B))
                    .withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 4,
              ),
              const BoxShadow(
                  color: Color(0xCC000000),
                  blurRadius: 40,
                  offset: Offset(0, 16)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ref * 0.068),
            child: Stack(
              children: [
                // Gloss sheen
                Positioned(
                  top: 0, left: 0, right: 0, height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end:   Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(ref * 0.050),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // ── Icon ──────────────────────────────────────────────
                      _WinIcon(isQuitting: isQuitting, ref: ref),
                      SizedBox(height: ref * 0.026),

                      // ── Title ─────────────────────────────────────────────
                      Text(
                        isQuitting ? 'GAME ENDED' : '🎉 AMAZING! 🎉',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'LilitaOne',
                          fontSize:   ref * 0.058,
                          fontWeight: FontWeight.w900,
                          color:      Colors.white,
                          letterSpacing: 1.4,
                          shadows: [
                            Shadow(
                              color: (isQuitting
                                  ? const Color(0xFFFF9500)
                                  : const Color(0xFF39E14B))
                                  .withOpacity(0.8),
                              blurRadius: 12,
                            ),
                            const Shadow(
                                color: Color(0x99000000),
                                blurRadius: 4,
                                offset: Offset(0, 2)),
                          ],
                        ),
                      ),
                      SizedBox(height: ref * 0.020),

                      // ── Moves pill ────────────────────────────────────────
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: ref * 0.050, vertical: ref * 0.018),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(ref * 0.060),
                          color:  Colors.white.withOpacity(0.10),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.20), width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.moving_rounded,
                                color: Colors.white70, size: ref * 0.040),
                            SizedBox(width: ref * 0.016),
                            Text(
                              '$moveCount Moves',
                              style: TextStyle(
                                fontFamily: 'LilitaOne',
                                fontSize:   ref * 0.046,
                                fontWeight: FontWeight.w900,
                                color:      Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: ref * 0.028),

                      // ── Rewards panel ─────────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                            horizontal: ref * 0.040, vertical: ref * 0.030),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(ref * 0.040),
                          color:  Colors.white.withOpacity(0.07),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.14), width: 1),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'REWARDS SAVED',
                              style: TextStyle(
                                fontFamily:    'LilitaOne',
                                fontSize:      ref * 0.034,
                                color:         Colors.white70,
                                letterSpacing: 1.5,
                                fontWeight:    FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: ref * 0.022),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _ArcadeRewardItem(
                                  icon:  Icons.monetization_on_rounded,
                                  color: const Color(0xFFFFD700),
                                  value: '$coinsEarned',
                                  label: 'Coins',
                                  ref:   ref,
                                ),
                                Container(
                                  width: 1.5,
                                  height: ref * 0.10,
                                  color: Colors.white.withOpacity(0.15),
                                ),
                                _ArcadeRewardItem(
                                  icon:  Icons.stars_rounded,
                                  color: const Color(0xFFB97EFF),
                                  value: '$pointsEarned',
                                  label: 'Points',
                                  ref:   ref,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: ref * 0.030),

                      // ── Star divider ──────────────────────────────────────
                      _ArcadeStarDivider(ref: ref),
                      SizedBox(height: ref * 0.030),

                      // ── Buttons ───────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _ArcadeWinButton(
                              label:    'Play Again',
                              icon:     Icons.replay_rounded,
                              top:      const Color(0xFF39E14B),
                              bottom:   const Color(0xFF1CA12A),
                              shadow:   const Color(0xFF39E14B),
                              vPad:     ref * 0.032,
                              fontSize: ref * 0.038,
                              loading:  _isSavingRewards,
                              onTap: _isSavingRewards ? null : () {
                                Navigator.pop(ctx);
                                initializeGame();
                              },
                            ),
                          ),
                          SizedBox(width: ref * 0.025),
                          Expanded(
                            child: _ArcadeWinButton(
                              label:    'Menu',
                              icon:     Icons.home_rounded,
                              top:      const Color(0xFF9B2FFF),
                              bottom:   const Color(0xFF5A0FBB),
                              shadow:   const Color(0xFF9B2FFF),
                              vPad:     ref * 0.032,
                              fontSize: ref * 0.038,
                              loading:  false,
                              onTap: () {
                                Navigator.pop(ctx);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBackPressed();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end:   Alignment.bottomCenter,
              colors: [
                Color(0xFF87CEEB),
                Color(0xFF98D8E8),
                Color(0xFFFFA07A),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 10),
                _buildInfoPanel(),
                const SizedBox(height: 20),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(child: _buildGameBoard()),
                  ),
                ),
                _buildBottomButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _onBackPressed,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.shade400,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.4),
                    blurRadius: 8, offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Color Puzzle',
              style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold,
                color: Color(0xFF004A98),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.shade400,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.shade700, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 4, offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.stars, color: Colors.orange.shade900, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${100 - moveCount}',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.purple.shade600]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.4),
                    blurRadius: 8, offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text('MOVES',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold,
                          color: Colors.white70, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('$moveCount',
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    blurRadius: 8, offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Column(
                children: [
                  Text('GOAL',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold,
                          color: Colors.white70, letterSpacing: 1)),
                  SizedBox(height: 4),
                  Text('Match Rows!',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameBoard() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200, width: 2),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Slide bottles to empty spots!',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(rows, (rowIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(bottlesPerRow, (colIndex) {
                  int bottleIndex = rowIndex * bottlesPerRow + colIndex;
                  bool isEmpty  = bottles[bottleIndex] == null;
                  bool canMove  = !isEmpty && _findAdjacentEmptySpot(bottleIndex) != null;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: GestureDetector(
                      onTap: () => onBottleTap(bottleIndex),
                      child: isEmpty
                          ? const EmptySpotWidget()
                          : BottleWidget(
                        colors: bottles[bottleIndex]!,
                        canMove: canMove,
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600]),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.4),
              blurRadius: 12, offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: initializeGame,
            borderRadius: BorderRadius.circular(28),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh_rounded, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text('NEW GAME',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        color: Colors.white, letterSpacing: 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIN DIALOG SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _WinIcon extends StatelessWidget {
  final bool   isQuitting;
  final double ref;
  const _WinIcon({required this.isQuitting, required this.ref});

  @override
  Widget build(BuildContext context) {
    final accent = isQuitting
        ? const Color(0xFFFF9500)
        : const Color(0xFF39E14B);

    return Container(
      width:  ref * 0.22,
      height: ref * 0.22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          accent.withOpacity(0.3),
          const Color(0xFF1E0B00),
        ]),
        border: Border.all(color: accent.withOpacity(0.8), width: 2.5),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.7), blurRadius: 22, spreadRadius: 2),
          BoxShadow(color: accent.withOpacity(0.3), blurRadius: 40),
        ],
      ),
      child: Icon(
        isQuitting ? Icons.flag_rounded : Icons.emoji_events_rounded,
        color: accent,
        size: ref * 0.11,
        shadows: [Shadow(color: accent, blurRadius: 14)],
      ),
    );
  }
}

class _ArcadeRewardItem extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   value;
  final String   label;
  final double   ref;

  const _ArcadeRewardItem({
    required this.icon,  required this.color,
    required this.value, required this.label, required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: ref * 0.065,
            shadows: [Shadow(color: color, blurRadius: 10)]),
        SizedBox(height: ref * 0.010),
        Text(value, style: TextStyle(
          fontFamily:    'LilitaOne',
          fontSize:      ref * 0.058,
          fontWeight:    FontWeight.w900,
          color:         color,
          shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 8)],
        )),
        Text(label, style: TextStyle(
          fontFamily: 'LilitaOne',
          fontSize:   ref * 0.030,
          color:      Colors.white60,
          fontWeight: FontWeight.w700,
        )),
      ],
    );
  }
}

class _ArcadeStarDivider extends StatelessWidget {
  final double ref;
  const _ArcadeStarDivider({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final isCenter = i == 2;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: ref * 0.007),
          child: Icon(
            isCenter ? Icons.star_rounded : Icons.star_outline_rounded,
            color: isCenter
                ? const Color(0xFFFFD700)
                : Colors.white.withOpacity(0.28),
            size: isCenter ? ref * 0.046 : ref * 0.030,
            shadows: isCenter
                ? [const Shadow(color: Color(0xFFFFD700), blurRadius: 8)]
                : null,
          ),
        );
      }),
    );
  }
}

class _ArcadeWinButton extends StatefulWidget {
  final String     label;
  final IconData   icon;
  final Color      top, bottom, shadow;
  final double     vPad, fontSize;
  final bool       loading;
  final VoidCallback? onTap;

  const _ArcadeWinButton({
    required this.label,   required this.icon,
    required this.top,     required this.bottom,  required this.shadow,
    required this.vPad,    required this.fontSize,
    required this.loading, required this.onTap,
  });

  @override
  State<_ArcadeWinButton> createState() => _ArcadeWinButtonState();
}

class _ArcadeWinButtonState extends State<_ArcadeWinButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   widget.onTap != null ? (_) => setState(() => _pressed = true)  : null,
      onTapUp:     widget.onTap != null ? (_) { setState(() => _pressed = false); widget.onTap!(); } : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale:    _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: widget.vPad),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: widget.onTap == null
                  ? [Colors.grey.shade600, Colors.grey.shade800]
                  : [widget.top, widget.bottom],
            ),
            boxShadow: widget.onTap == null ? [] : [
              BoxShadow(
                color:      widget.bottom.withOpacity(0.9),
                blurRadius: 0, spreadRadius: 0,
                offset:     Offset(0, _pressed ? 1 : 4),
              ),
              BoxShadow(color: widget.shadow.withOpacity(0.55), blurRadius: 14, spreadRadius: 1),
              BoxShadow(color: widget.shadow.withOpacity(0.22), blurRadius: 26),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.22), width: 1.5),
          ),
          child: Stack(alignment: Alignment.center, children: [
            // Gloss
            Positioned(
              top: 0, left: 0, right: 0, bottom: 10,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.white.withOpacity(0.28), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            widget.loading
                ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: Colors.white,
                        size: widget.fontSize + 4,
                        shadows: [Shadow(
                            color: Colors.black.withOpacity(0.45),
                            blurRadius: 4)]),
                    const SizedBox(width: 6),
                    Text(widget.label,
                        style: TextStyle(
                          fontFamily:    'LilitaOne',
                          color:         Colors.white,
                          fontSize:      widget.fontSize,
                          fontWeight:    FontWeight.w900,
                          letterSpacing: 0.8,
                          shadows: const [Shadow(
                              color: Color(0x99000000),
                              blurRadius: 4,
                              offset: Offset(0, 2))],
                        )),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  GAME WIDGETS (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class BottleWidget extends StatelessWidget {
  final List<Color> colors;
  final bool canMove;

  const BottleWidget({Key? key, required this.colors, this.canMove = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: SizedBox(
        width: 70, height: 130,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              bottom: 0,
              child: Container(
                width: 70, height: 100,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: canMove ? Colors.green.shade600 : Colors.grey.shade400,
                    width: canMove ? 3 : 2,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft:  Radius.circular(15),
                    bottomRight: Radius.circular(15),
                    topLeft:     Radius.circular(8),
                    topRight:    Radius.circular(8),
                  ),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: canMove
                          ? Colors.green.withOpacity(0.3)
                          : Colors.grey.shade300,
                      blurRadius: canMove ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft:  Radius.circular(13),
                    bottomRight: Radius.circular(13),
                    topLeft:     Radius.circular(6),
                    topRight:    Radius.circular(6),
                  ),
                  child: Column(
                    children: colors.map((color) => Expanded(
                      child: Container(
                        width: double.infinity,
                        color: color,
                        margin: const EdgeInsets.all(1),
                      ),
                    )).toList(),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: Container(
                width: 30, height: 35,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: canMove ? Colors.green.shade600 : Colors.grey.shade400,
                    width: canMove ? 3 : 2,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft:  Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  color: Colors.white,
                ),
              ),
            ),
            if (canMove)
              Positioned(
                top: 8,
                child: Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    color:  Colors.green.shade700,
                    shape:  BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 4, spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EmptySpotWidget extends StatelessWidget {
  const EmptySpotWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70, height: 130,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.grey.shade400, width: 3,
            style: BorderStyle.solid),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:  Colors.grey.shade300,
            border: Border.all(color: Colors.grey.shade400, width: 2),
          ),
        ),
      ),
    );
  }
}