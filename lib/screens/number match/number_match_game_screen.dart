import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/userprofile_service.dart';
import '../../services/player_stats_service.dart';
import '../../widgets/game_quit_handler.dart';

/// Number Match - 2048-style puzzle game
/// Swipe to merge matching numbers!
class NumberMatchGameScreen extends StatefulWidget {
  const NumberMatchGameScreen({super.key});

  @override
  State<NumberMatchGameScreen> createState() => _NumberMatchGameScreenState();
}

class _NumberMatchGameScreenState extends State<NumberMatchGameScreen>
    with TickerProviderStateMixin, GameQuitHandler {
  // Game state
  GameState _gameState = GameState.menu;
  int _score = 0;
  int _level = 1;
  int _highestTile = 0;

  // Grid
  static const int gridSize = 4;
  List<List<GridCell?>> _grid = [];

  // Animation
  late AnimationController _slideController;
  late AnimationController _mergeController;
  late AnimationController _newTileController;
  bool _isAnimating = false;

  // Visual feedback
  SwipeDirection? _lastSwipeDirection;
  late AnimationController _swipeIndicatorController;

  // Tile float animation
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _mergeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _newTileController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _swipeIndicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  // ─────────────────────────── GAME LOGIC (UNTOUCHED) ───────────────────────────

  void _startGame() {
    _gameState = GameState.playing;
    _score = 0;
    _level = 1;
    _highestTile = 0;
    _grid = _createEmptyGrid();
    _addRandomTile();
    _addRandomTile();
    setState(() {});
  }

  List<List<GridCell?>> _createEmptyGrid() {
    return List.generate(
      gridSize,
          (row) => List.generate(gridSize, (col) => null),
    );
  }

  void _addRandomTile() {
    final emptyPositions = <Position>[];
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (_grid[row][col] == null) emptyPositions.add(Position(row, col));
      }
    }
    if (emptyPositions.isEmpty) return;
    final random = Random();
    final position = emptyPositions[random.nextInt(emptyPositions.length)];
    final value = random.nextDouble() < 0.9 ? 2 : 4;
    _grid[position.row][position.col] = GridCell(
      value: value,
      row: position.row,
      col: position.col,
      id: '${position.row}_${position.col}_${DateTime.now().microsecondsSinceEpoch}',
      isNew: true,
    );
  }

  Future<void> _handleSwipe(SwipeDirection direction) async {
    if (_isAnimating || _gameState != GameState.playing) return;
    setState(() {
      _isAnimating = true;
      _lastSwipeDirection = direction;
    });
    _swipeIndicatorController.forward(from: 0);
    final previousGrid = _copyGrid();
    bool moved = false;
    int scoreGained = 0;
    switch (direction) {
      case SwipeDirection.left:
        for (int row = 0; row < gridSize; row++) {
          final result = _slideAndMerge(_getRow(row), row, true, true);
          if (result.moved) moved = true;
          scoreGained += result.scoreGained;
          _setRow(row, result.tiles);
        }
        break;
      case SwipeDirection.right:
        for (int row = 0; row < gridSize; row++) {
          final tiles = _getRow(row).reversed.toList();
          final result = _slideAndMerge(tiles, row, false, true);
          if (result.moved) moved = true;
          scoreGained += result.scoreGained;
          _setRow(row, result.tiles.reversed.toList());
        }
        break;
      case SwipeDirection.up:
        for (int col = 0; col < gridSize; col++) {
          final result = _slideAndMerge(_getColumn(col), col, true, false);
          if (result.moved) moved = true;
          scoreGained += result.scoreGained;
          _setColumn(col, result.tiles);
        }
        break;
      case SwipeDirection.down:
        for (int col = 0; col < gridSize; col++) {
          final tiles = _getColumn(col).reversed.toList();
          final result = _slideAndMerge(tiles, col, false, false);
          if (result.moved) moved = true;
          scoreGained += result.scoreGained;
          _setColumn(col, result.tiles.reversed.toList());
        }
        break;
    }
    if (moved) {
      _setPreviousPositions(previousGrid);
      await _slideController.forward(from: 0);
      setState(() {
        _score += scoreGained;
        final newLevel = (_score ~/ 500) + 1;
        if (newLevel > _level) {
          _level = newLevel;
          _showLevelUpDialog();
        }
        for (int row = 0; row < gridSize; row++) {
          for (int col = 0; col < gridSize; col++) {
            if (_grid[row][col] != null) {
              _grid[row][col] = GridCell(
                value: _grid[row][col]!.value,
                row: row,
                col: col,
                id: _grid[row][col]!.id,
                previousRow: _grid[row][col]!.previousRow,
                previousCol: _grid[row][col]!.previousCol,
              );
            }
          }
        }
      });
      if (scoreGained > 0) await _mergeController.forward(from: 0);
      setState(() { _addRandomTile(); });
      await _newTileController.forward(from: 0);
      if (!_hasValidMoves()) {
        await Future.delayed(const Duration(milliseconds: 500));
        _gameOver();
      }
    }
    setState(() => _isAnimating = false);
  }

  List<GridCell?> _getRow(int row) => List.from(_grid[row]);

  void _setRow(int row, List<GridCell?> tiles) {
    for (int col = 0; col < gridSize; col++) {
      _grid[row][col] = tiles[col];
      if (tiles[col] != null) {
        _grid[row][col]!.row = row;
        _grid[row][col]!.col = col;
      }
    }
  }

  List<GridCell?> _getColumn(int col) =>
      List.generate(gridSize, (row) => _grid[row][col]);

  void _setColumn(int col, List<GridCell?> tiles) {
    for (int row = 0; row < gridSize; row++) {
      _grid[row][col] = tiles[row];
      if (tiles[row] != null) {
        _grid[row][col]!.row = row;
        _grid[row][col]!.col = col;
      }
    }
  }

  SlideResult _slideAndMerge(List<GridCell?> line, int lineIndex, bool isForward, bool isRow) {
    List<GridCell> tiles = line.where((cell) => cell != null).cast<GridCell>().toList();
    final originalPositions = <int>[];
    for (int i = 0; i < line.length; i++) {
      if (line[i] != null) originalPositions.add(i);
    }
    bool moved = false;
    int scoreGained = 0;
    List<GridCell?> merged = [];
    int i = 0;
    while (i < tiles.length) {
      if (i + 1 < tiles.length && tiles[i].value == tiles[i + 1].value) {
        final newValue = tiles[i].value * 2;
        scoreGained += newValue;
        if (newValue > _highestTile) _highestTile = newValue;
        merged.add(GridCell(
          value: newValue,
          row: isRow ? lineIndex : merged.length,
          col: isRow ? merged.length : lineIndex,
          id: '${tiles[i].id}_merged',
          isMerged: true,
        ));
        moved = true;
        i += 2;
      } else {
        merged.add(tiles[i]);
        i++;
      }
    }
    if (merged.length != tiles.length || merged.length != originalPositions.length) {
      moved = true;
    } else {
      for (int j = 0; j < merged.length; j++) {
        if (originalPositions[j] != j) { moved = true; break; }
      }
    }
    while (merged.length < gridSize) merged.add(null);
    return SlideResult(merged, moved, scoreGained);
  }

  List<List<GridCell?>> _copyGrid() {
    return List.generate(
      gridSize,
          (row) => List.generate(gridSize, (col) => _grid[row][col]),
    );
  }

  void _setPreviousPositions(List<List<GridCell?>> previousGrid) {
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (_grid[row][col] != null) {
          for (int pRow = 0; pRow < gridSize; pRow++) {
            for (int pCol = 0; pCol < gridSize; pCol++) {
              if (previousGrid[pRow][pCol]?.id == _grid[row][col]!.id ||
                  previousGrid[pRow][pCol]?.id == _grid[row][col]!.id.split('_merged').first) {
                _grid[row][col]!.previousRow = pRow;
                _grid[row][col]!.previousCol = pCol;
                break;
              }
            }
          }
        }
      }
    }
  }

  bool _hasValidMoves() {
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (_grid[row][col] == null) return true;
      }
    }
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final value = _grid[row][col]?.value;
        if (value == null) continue;
        if (col < gridSize - 1 && _grid[row][col + 1]?.value == value) return true;
        if (row < gridSize - 1 && _grid[row + 1][col]?.value == value) return true;
      }
    }
    return false;
  }

  void _showLevelUpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF9999), Color(0xFF87CEEB)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF9999).withOpacity(0.6),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Color(0xFFFFDD66), size: 80),
              const SizedBox(height: 20),
              Text(
                'LEVEL $_level',
                style: GoogleFonts.nunito(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Score: $_score',
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'CONTINUE',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFFF6B6B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _gameOver() {
    setState(() => _gameState = GameState.gameOver);
    _saveScore();
  }

  Future<void> _saveScore() async {
    try {
      await UserProfileService().saveNumberMatchRewards(_score, _highestTile, _level);
    } catch (e) {
      debugPrint('Error saving score: $e');
    }
  }

  void _onBackPressed() {
    if (_gameState != GameState.playing || _score == 0) {
      Navigator.pop(context);
      return;
    }
    showQuitConfirmDialog(context, onConfirm: _gameOver);
  }

  void _returnToMenu() => Navigator.pop(context);

  @override
  void dispose() {
    _slideController.dispose();
    _mergeController.dispose();
    _newTileController.dispose();
    _swipeIndicatorController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  // ─────────────────────────── TILE COLORS (UNTOUCHED) ───────────────────────────

  List<Color> _getColorForValue(int value) {
    switch (value) {
      case 2:    return [const Color(0xFF87CEEB), const Color(0xFF5FAFDB)];
      case 4:    return [const Color(0xFFFF9999), const Color(0xFFFF6B6B)];
      case 8:    return [const Color(0xFFFFB366), const Color(0xFFFF9933)];
      case 16:   return [const Color(0xFFFFDD66), const Color(0xFFFFCC33)];
      case 32:   return [const Color(0xFF77DD77), const Color(0xFF55CC55)];
      case 64:   return [const Color(0xFFFF6B6B), const Color(0xFFEE5A6F)];
      case 128:  return [const Color(0xFF6FEDD6), const Color(0xFF4FD1C5)];
      case 256:  return [const Color(0xFFFFB84D), const Color(0xFFFF9F1C)];
      case 512:  return [const Color(0xFFFF7AA2), const Color(0xFFFF5582)];
      case 1024: return [const Color(0xFFB39DDB), const Color(0xFF9575CD)];
      case 2048: return [const Color(0xFFFF6B6B), const Color(0xFF6B9FFF)];
      default:   return [const Color(0xFFFF9999), const Color(0xFF87CEEB)];
    }
  }

  // ─────────────────────────── BUILD ───────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBackPressed();
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Gradient background
            const _GradientBackground(),
            // Blobs
            const _BlobLayer(),
            // Safe area content
            SafeArea(
              child: _gameState == GameState.menu
                  ? _buildMenuScreen()
                  : _gameState == GameState.playing
                  ? _buildGameScreen()
                  : _buildGameOverScreen(),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── MENU SCREEN ───────────────────────────

  Widget _buildMenuScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Column(
          children: [
            // Top decorative tiles
            _buildDecoTiles(w),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title block
                  _buildTitleBlock(w),

                  SizedBox(height: h * 0.03),

                  // Score pills
                  _buildScorePills(w),

                  SizedBox(height: h * 0.025),

                  // How to play card
                  _buildHowToPlayCard(w),

                  SizedBox(height: h * 0.035),

                  // Start button
                  _buildStartButton(w),

                  SizedBox(height: h * 0.015),

                  // Back button
                  TextButton.icon(
                    onPressed: _onBackPressed,
                    icon: Icon(Icons.arrow_back_rounded,
                        color: const Color(0xFF6d28d9), size: w * 0.055),
                    label: Text(
                      'BACK',
                      style: GoogleFonts.nunito(
                        color: const Color(0xFF6d28d9),
                        fontSize: w * 0.038,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDecoTiles(double w) {
    final labels = ['2', '4', '8', '16', '32'];
    final colors = [
      const Color(0xFF5eb9f0),
      const Color(0xFF4cd6a0),
      const Color(0xFFff7eb3),
      const Color(0xFFffb347),
      const Color(0xFFa78bfa),
    ];
    final tileSize = w * 0.13;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: w * 0.04,
        horizontal: w * 0.04,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(labels.length, (i) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.015),
            child: AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                final phase = (i * 0.3);
                final val = sin((_floatController.value * 2 * pi) + phase);
                return Transform.translate(
                  offset: Offset(0, val * 5),
                  child: child,
                );
              },
              child: Container(
                width: tileSize,
                height: tileSize,
                decoration: BoxDecoration(
                  color: colors[i],
                  borderRadius: BorderRadius.circular(tileSize * 0.22),
                  boxShadow: [
                    BoxShadow(
                      color: colors[i].withOpacity(0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: tileSize * 0.38,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTitleBlock(double w) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF1a6fa8), Color(0xFF7c3aed), Color(0xFFdb2777)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            'NUMBER\nMATCH',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: w * 0.16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 0.95,
              letterSpacing: -1,
            ),
          ),
        ),
        SizedBox(height: w * 0.015),
        Text(
          'Swipe & Merge to 2048!',
          style: GoogleFonts.nunito(
            fontSize: w * 0.042,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF6d28d9),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildScorePills(double w) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: w * 0.08),
      child: Row(
        children: [
          Expanded(child: _buildScorePill('Points', _score.toString(), w)),
          SizedBox(width: w * 0.04),
          Expanded(child: _buildScorePill('Best Tile', _highestTile.toString(), w)),
        ],
      ),
    );
  }

  Widget _buildScorePill(String label, String value, double w) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: w * 0.035,
        horizontal: w * 0.04,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(w * 0.05),
        border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7c3aed).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: w * 0.08,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1e1b4b),
              height: 1,
            ),
          ),
          SizedBox(height: w * 0.01),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.nunito(
              fontSize: w * 0.028,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF6d28d9),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowToPlayCard(double w) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: w * 0.07),
      padding: EdgeInsets.all(w * 0.055),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(w * 0.065),
        border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7c3aed).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOW TO PLAY',
            style: GoogleFonts.nunito(
              fontSize: w * 0.03,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF7c3aed),
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: w * 0.03),
          Text(
            'Swipe to merge tiles and keep combining to reach the highest number! But careful — the game ends when the board is full.',
            style: GoogleFonts.nunito(
              fontSize: w * 0.042,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(double w) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: w * 0.07),
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: _startGame,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: w * 0.045),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6d28d9), Color(0xFFdb2777)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(w * 0.055),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6d28d9).withOpacity(0.38),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'START GAME',
              style: GoogleFonts.nunito(
                fontSize: w * 0.058,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── GAME SCREEN ───────────────────────────

  Widget _buildGameScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        return Column(
          children: [
            _buildTopBar(),
            SizedBox(height: h * 0.008),
            _buildSwipeIndicator(),
            SizedBox(height: h * 0.008),
            Expanded(  // ← grid takes all remaining space
              child: Center(
                child: GestureDetector(
                  onPanEnd: (details) {
                    final dx = details.velocity.pixelsPerSecond.dx;
                    final dy = details.velocity.pixelsPerSecond.dy;
                    if (dx.abs() > dy.abs()) {
                      _handleSwipe(dx > 0 ? SwipeDirection.right : SwipeDirection.left);
                    } else if (dy.abs() > 100) {
                      _handleSwipe(dy > 0 ? SwipeDirection.down : SwipeDirection.up);
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: w * 0.05),
                    child: _buildGrid(),
                  ),
                ),
              ),
            ),
            _buildGameHint(w),
            SizedBox(height: h * 0.012),
          ],
        );
      },
    );
  }

  Widget _buildGameHint(double w) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: w * 0.05),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: w * 0.05, vertical: w * 0.03),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.72),
          borderRadius: BorderRadius.circular(w * 0.05),
          border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7c3aed).withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swipe, color: const Color(0xFF6d28d9), size: w * 0.055),
            SizedBox(width: w * 0.03),
            Expanded(
              child: Text(
                'Swipe to slide tiles. Match 2 numbers to merge!',
                style: GoogleFonts.nunito(
                  color: const Color(0xFF374151),
                  fontSize: w * 0.035,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeIndicator() {
    if (_lastSwipeDirection == null) return const SizedBox(height: 40);
    return AnimatedBuilder(
      animation: _swipeIndicatorController,
      builder: (context, child) {
        return Opacity(
          opacity: 1.0 - _swipeIndicatorController.value,
          child: Transform.translate(
            offset: _getSwipeOffset(_lastSwipeDirection!) *
                _swipeIndicatorController.value * 20,
            child: Container(
              height: 40,
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6d28d9), Color(0xFFdb2777)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6d28d9).withOpacity(0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getSwipeIcon(_lastSwipeDirection!), color: Colors.white, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      _getSwipeText(_lastSwipeDirection!),
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Offset _getSwipeOffset(SwipeDirection direction) {
    switch (direction) {
      case SwipeDirection.up:    return const Offset(0, -1);
      case SwipeDirection.down:  return const Offset(0, 1);
      case SwipeDirection.left:  return const Offset(-1, 0);
      case SwipeDirection.right: return const Offset(1, 0);
    }
  }

  IconData _getSwipeIcon(SwipeDirection direction) {
    switch (direction) {
      case SwipeDirection.up:    return Icons.arrow_upward;
      case SwipeDirection.down:  return Icons.arrow_downward;
      case SwipeDirection.left:  return Icons.arrow_back;
      case SwipeDirection.right: return Icons.arrow_forward;
    }
  }

  String _getSwipeText(SwipeDirection direction) {
    switch (direction) {
      case SwipeDirection.up:    return 'UP';
      case SwipeDirection.down:  return 'DOWN';
      case SwipeDirection.left:  return 'LEFT';
      case SwipeDirection.right: return 'RIGHT';
    }
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        const gap = 8.0;
        const padding = 12.0;
        const borderWidth = 1.5;
        final inner = available - borderWidth * 2;  // account for border
        final cellSize = ((inner - padding * 2 - gap * gridSize) / gridSize).floorToDouble();

        return Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(available * 0.06),
            border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7c3aed).withOpacity(0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(gridSize, (row) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(gridSize, (col) {
                  return _buildCell(row, col, cellSize);
                }),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildCell(int row, int col, double size) {
    final cell = _grid[row][col];
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: cell == null ? const Color(0xFFE8DFF5) : Colors.transparent,
        borderRadius: BorderRadius.circular(size * 0.18),
      ),
      child: cell != null ? _buildTile(cell, size) : null,
    );
  }

  Widget _buildTile(GridCell cell, double size) {
    Widget tileContent = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getColorForValue(cell.value),
        ),
        borderRadius: BorderRadius.circular(size * 0.18),
        boxShadow: [
          BoxShadow(
            color: _getColorForValue(cell.value)[0].withOpacity(0.5),
            blurRadius: cell.isMerged ? 12 : 4,
            spreadRadius: cell.isMerged ? 2 : 0,
          ),
        ],
      ),
      child: Center(
        child: Text(
          cell.value.toString(),
          style: GoogleFonts.nunito(
            fontSize: cell.value >= 1000
                ? size * 0.28
                : cell.value >= 100
                ? size * 0.35
                : size * 0.42,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );

    if (cell.isNew && _newTileController.value > 0 && _newTileController.value < 1) {
      return AnimatedBuilder(
        animation: _newTileController,
        builder: (context, child) {
          final scale = Curves.elasticOut.transform(_newTileController.value);
          return Transform.scale(scale: scale, child: tileContent);
        },
      );
    }

    if (cell.previousRow != null && cell.previousCol != null) {
      return AnimatedBuilder(
        animation: _slideController,
        builder: (context, child) {
          final progress = Curves.easeOut.transform(_slideController.value);
          final rowDiff = cell.row - cell.previousRow!;
          final colDiff = cell.col - cell.previousCol!;
          final offsetX = -colDiff * (1 - progress) * (size + 8);
          final offsetY = -rowDiff * (1 - progress) * (size + 8);
          return Transform.translate(
            offset: Offset(offsetX, offsetY),
            child: Transform.scale(
              scale: cell.isMerged ? 1.0 + (0.2 * (1 - progress)) : 1.0,
              child: tileContent,
            ),
          );
        },
      );
    }

    return tileContent;
  }

  // ─────────────────────────── TOP BAR ───────────────────────────

  Widget _buildTopBar() {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: w * 0.03),
        child: Row(
          children: [
            // Back button
            GestureDetector(
              onTap: _onBackPressed,
              child: Container(
                padding: EdgeInsets.all(w * 0.025),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(w * 0.03),
                  border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.5),
                ),
                child: Icon(Icons.arrow_back_rounded,
                    color: const Color(0xFF6d28d9), size: w * 0.055),
              ),
            ),
            SizedBox(width: w * 0.025),
            Expanded(child: _buildStatPill('SCORE', _score.toString(), const Color(0xFF6d28d9), w)),
            SizedBox(width: w * 0.025),
            Expanded(child: _buildStatPill('BEST', _highestTile.toString(), const Color(0xFFdb2777), w)),
            SizedBox(width: w * 0.025),
            Expanded(child: _buildStatPill('LVL', _level.toString(), const Color(0xFF059669), w)),
          ],
        ),
      );
    });
  }

  Widget _buildStatPill(String label, String value, Color color, double w) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: w * 0.025, horizontal: w * 0.02),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(w * 0.03),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: w * 0.026,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 1,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: w * 0.055,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1e1b4b),
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── GAME OVER SCREEN ───────────────────────────

  Widget _buildGameOverScreen() {
    final isWinner = _highestTile >= 2048;

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;

      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: w * 0.07,
          vertical: h * 0.03,
        ),
        child: Column(
          children: [
            // Icon
            Container(
              width: w * 0.24,
              height: w * 0.24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isWinner
                      ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
                      : [const Color(0xFF6d28d9), const Color(0xFFdb2777)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isWinner
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF6d28d9)).withOpacity(0.45),
                    blurRadius: 30,
                    spreadRadius: 8,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                isWinner ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                color: Colors.white,
                size: w * 0.12,
              ),
            ),

            SizedBox(height: h * 0.02),

            // Title
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: isWinner
                    ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
                    : [const Color(0xFF6d28d9), const Color(0xFFdb2777)],
              ).createShader(bounds),
              child: Text(
                isWinner ? 'YOU WIN!' : 'GAME OVER',
                style: GoogleFonts.nunito(
                  fontSize: w * 0.11,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),

            SizedBox(height: h * 0.02),

            // Score + tile + level all in one card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(w * 0.06),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.78),
                borderRadius: BorderRadius.circular(w * 0.07),
                border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7c3aed).withOpacity(0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Score block
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                        vertical: h * 0.02, horizontal: w * 0.04),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6d28d9), Color(0xFFdb2777)],
                      ),
                      borderRadius: BorderRadius.circular(w * 0.05),
                    ),
                    child: Column(
                      children: [
                        Text('FINAL SCORE',
                            style: GoogleFonts.nunito(
                              color: Colors.white70,
                              fontSize: w * 0.032,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            )),
                        SizedBox(height: h * 0.005),
                        Text(_score.toString(),
                            style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontSize: w * 0.16,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            )),
                      ],
                    ),
                  ),

                  SizedBox(height: h * 0.015),

                  // Highest tile + level in a row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              vertical: h * 0.015, horizontal: w * 0.03),
                          decoration: BoxDecoration(
                            color: const Color(0xFFdb2777).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(w * 0.04),
                            border: Border.all(
                                color: const Color(0xFFdb2777).withOpacity(0.3),
                                width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Text('BEST TILE',
                                  style: GoogleFonts.nunito(
                                    color: const Color(0xFFdb2777),
                                    fontSize: w * 0.028,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  )),
                              Text(_highestTile.toString(),
                                  style: GoogleFonts.nunito(
                                    color: const Color(0xFF1e1b4b),
                                    fontSize: w * 0.09,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  )),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: w * 0.03),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              vertical: h * 0.015, horizontal: w * 0.03),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(w * 0.04),
                            border: Border.all(
                                color: const Color(0xFF059669).withOpacity(0.3),
                                width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Text('LEVEL',
                                  style: GoogleFonts.nunito(
                                    color: const Color(0xFF059669),
                                    fontSize: w * 0.028,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  )),
                              Text(_level.toString(),
                                  style: GoogleFonts.nunito(
                                    color: const Color(0xFF1e1b4b),
                                    fontSize: w * 0.09,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: h * 0.02),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildGameOverBtn(
                          'PLAY AGAIN', Icons.refresh_rounded,
                          const Color(0xFF6d28d9), _startGame, w,
                        ),
                      ),
                      SizedBox(width: w * 0.04),
                      Expanded(
                        child: _buildGameOverBtn(
                          'MENU', Icons.home_rounded,
                          const Color(0xFFdb2777), _returnToMenu, w,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: h * 0.03),
          ],
        ),
      );
    });
  }

  Widget _buildGameOverBtn(
      String text, IconData icon, Color color, VoidCallback onTap, double w) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: w * 0.038),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(w * 0.045),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: w * 0.055),
            SizedBox(width: w * 0.02),
            Text(
              text,
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: w * 0.038,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── BACKGROUND WIDGETS ───────────────────────────

class _GradientBackground extends StatelessWidget {
  const _GradientBackground();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFa8edea),
            Color(0xFFb8d4f5),
            Color(0xFFe0b8f5),
            Color(0xFFf9d4a0),
            Color(0xFFf9b8b8),
          ],
          stops: [0.0, 0.2, 0.45, 0.70, 1.0],
        ),
      ),
    );
  }
}

class _BlobLayer extends StatelessWidget {
  const _BlobLayer();
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        Positioned(
          top: -size.width * 0.1,
          left: -size.width * 0.15,
          child: _Blob(size: size.width * 0.6, color: const Color(0xFF7ecfff)),
        ),
        Positioned(
          bottom: -size.width * 0.08,
          right: -size.width * 0.12,
          child: _Blob(size: size.width * 0.55, color: const Color(0xFFffb3d9)),
        ),
        Positioned(
          top: size.height * 0.4,
          left: size.width * 0.5,
          child: _Blob(size: size.width * 0.38, color: const Color(0xFFffe08a)),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.45),
      ),
      child: BackdropFilter(
        filter: const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.0),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── MODELS (UNTOUCHED) ───────────────────────────

class GridCell {
  final int value;
  int row;
  int col;
  final String id;
  final bool isMerged;
  final bool isNew;
  int? previousRow;
  int? previousCol;

  GridCell({
    required this.value,
    required this.row,
    required this.col,
    required this.id,
    this.isMerged = false,
    this.isNew = false,
    this.previousRow,
    this.previousCol,
  });
}

class Position {
  final int row;
  final int col;
  Position(this.row, this.col);
}

class SlideResult {
  final List<GridCell?> tiles;
  final bool moved;
  final int scoreGained;
  SlideResult(this.tiles, this.moved, this.scoreGained);
}

enum SwipeDirection { up, down, left, right }
enum GameState { menu, playing, gameOver }

extension NumberMatchScore on UserProfileService {
  Future<void> saveNumberMatchRewards(int score, int highestTile, int level) async {
    try {
      final coinsEarned = (score / 10).floor().clamp(0, 999);
      await addCoins(amount: coinsEarned, reason: 'Number Match Score: $score');
      final bool won = highestTile >= 2048;
      await updateGameStats(gamesPlayed: 1, gamesWon: won ? 1 : 0, totalScore: score);
      await PlayerStatsService().saveNumberMatchSession(
        finalScore: score,
        highestTile: highestTile,
        levelReached: level,
        coinsEarned: coinsEarned,
      );
      debugPrint('✅ Number Match saved: $score pts, $coinsEarned coins');
    } catch (e) {
      debugPrint('❌ Error saving Number Match rewards: $e');
    }
  }
}