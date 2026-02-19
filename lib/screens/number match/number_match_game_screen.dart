import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/userprofile_service.dart';

/// Number Match - 2048-style puzzle game
/// Swipe to merge matching numbers!
class NumberMatchGameScreen extends StatefulWidget {
  const NumberMatchGameScreen({super.key});

  @override
  State<NumberMatchGameScreen> createState() => _NumberMatchGameScreenState();
}

class _NumberMatchGameScreenState extends State<NumberMatchGameScreen>
    with TickerProviderStateMixin {
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
  }

  void _startGame() {
    _gameState = GameState.playing;
    _score = 0;
    _level = 1;
    _highestTile = 0;
    _grid = _createEmptyGrid();

    // Add 2 starting tiles
    _addRandomTile();
    _addRandomTile();

    // Trigger rebuild to show tiles
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
        if (_grid[row][col] == null) {
          emptyPositions.add(Position(row, col));
        }
      }
    }

    if (emptyPositions.isEmpty) return;

    final random = Random();
    final position = emptyPositions[random.nextInt(emptyPositions.length)];

    // 90% chance of 2, 10% chance of 4
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

    // Show swipe indicator
    _swipeIndicatorController.forward(from: 0);

    // Store previous state for animation
    final previousGrid = _copyGrid();

    bool moved = false;
    int scoreGained = 0;

    // Process the swipe
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
      // Set previous positions for animation
      _setPreviousPositions(previousGrid);

      // Animate slide
      await _slideController.forward(from: 0);

      setState(() {
        _score += scoreGained;

        // Check for level up (every 500 points)
        final newLevel = (_score ~/ 500) + 1;
        if (newLevel > _level) {
          _level = newLevel;
          _showLevelUpDialog();
        }

        // Clear merge flags and new flags
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

      // Animate merge effect
      if (scoreGained > 0) {
        await _mergeController.forward(from: 0);
      }

      // Add new tile
      setState(() {
        _addRandomTile();
      });

      // Animate new tile
      await _newTileController.forward(from: 0);

      // Check game over
      if (!_hasValidMoves()) {
        await Future.delayed(const Duration(milliseconds: 500));
        _gameOver();
      }
    }

    setState(() => _isAnimating = false);
  }

  List<GridCell?> _getRow(int row) {
    return List.from(_grid[row]);
  }

  void _setRow(int row, List<GridCell?> tiles) {
    for (int col = 0; col < gridSize; col++) {
      _grid[row][col] = tiles[col];
      if (tiles[col] != null) {
        _grid[row][col]!.row = row;
        _grid[row][col]!.col = col;
      }
    }
  }

  List<GridCell?> _getColumn(int col) {
    return List.generate(gridSize, (row) => _grid[row][col]);
  }

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
    // Remove nulls
    List<GridCell> tiles = line.where((cell) => cell != null).cast<GridCell>().toList();

    // Check if line was already compact (no empty spaces before tiles)
    final originalPositions = <int>[];
    for (int i = 0; i < line.length; i++) {
      if (line[i] != null) {
        originalPositions.add(i);
      }
    }

    bool moved = false;
    int scoreGained = 0;
    List<GridCell?> merged = [];

    int i = 0;
    while (i < tiles.length) {
      if (i + 1 < tiles.length && tiles[i].value == tiles[i + 1].value) {
        // Merge!
        final newValue = tiles[i].value * 2;
        scoreGained += newValue;

        // Track highest tile
        if (newValue > _highestTile) {
          _highestTile = newValue;
        }

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

    // Check if anything moved by comparing positions
    if (merged.length != tiles.length) {
      // Length changed means merge happened
      moved = true;
    } else if (merged.length != originalPositions.length) {
      // Different number of tiles
      moved = true;
    } else {
      // Check if tiles are in different positions
      for (int j = 0; j < merged.length; j++) {
        if (originalPositions[j] != j) {
          moved = true;
          break;
        }
      }
    }

    // Pad with nulls
    while (merged.length < gridSize) {
      merged.add(null);
    }

    return SlideResult(merged, moved, scoreGained);
  }

  List<List<GridCell?>> _copyGrid() {
    return List.generate(
      gridSize,
          (row) => List.generate(
        gridSize,
            (col) => _grid[row][col],
      ),
    );
  }

  void _setPreviousPositions(List<List<GridCell?>> previousGrid) {
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (_grid[row][col] != null) {
          // Find where this tile came from
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
    // Check for empty cells
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (_grid[row][col] == null) return true;
      }
    }

    // Check for possible merges
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final value = _grid[row][col]?.value;
        if (value == null) continue;

        // Check right
        if (col < gridSize - 1 && _grid[row][col + 1]?.value == value) {
          return true;
        }
        // Check down
        if (row < gridSize - 1 && _grid[row + 1][col]?.value == value) {
          return true;
        }
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
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Score: $_score',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                child: const Text(
                  'CONTINUE',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6B6B),
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
      await UserProfileService().saveNumberMatchRewards(_score);
    } catch (e) {
      debugPrint('Error saving score: $e');
    }
  }

  void _returnToMenu() {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _slideController.dispose();
    _mergeController.dispose();
    _newTileController.dispose();
    _swipeIndicatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFE5E5), // Soft pink
              Color(0xFFE5F3FF), // Soft blue
              Color(0xFFFFF5E5), // Soft peach
            ],
          ),
        ),
        child: SafeArea(
          child: _gameState == GameState.menu
              ? _buildMenuScreen()
              : _gameState == GameState.playing
              ? _buildGameScreen()
              : _buildGameOverScreen(),
        ),
      ),
    );
  }

  Widget _buildMenuScreen() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // Fun Title with Numbers
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9999), Color(0xFF87CEEB), Color(0xFFFFDD66)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF9999).withOpacity(0.5),
                    blurRadius: 25,
                    spreadRadius: 5,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Fun number emojis
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('2️⃣', style: TextStyle(fontSize: 32)),
                      SizedBox(width: 8),
                      Text('4️⃣', style: TextStyle(fontSize: 32)),
                      SizedBox(width: 8),
                      Text('8️⃣', style: TextStyle(fontSize: 32)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'NUMBER MATCH',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Swipe & Merge to 2048! 🎯',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // How to Play Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF87CEEB), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '📖',
                        style: TextStyle(fontSize: 24),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'HOW TO PLAY',
                        style: TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildInstructionRow('👆', 'Swipe to slide all tiles'),
                  _buildInstructionRow('✨', 'Merge matching numbers (2+2=4)'),
                  _buildInstructionRow('🎯', 'Keep combining to reach 2048!'),
                  _buildInstructionRow('⚡', 'Game ends when board is full'),
                ],
              ),
            ),

            const SizedBox(height: 50),

            // Start Button - Extra Fun
            GestureDetector(
              onTap: _startGame,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF87CEEB),
                      Color(0xFF6B9FFF),
                      Color(0xFF87CEEB),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF87CEEB).withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 5,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                    SizedBox(width: 8),
                    Text(
                      'START GAME',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            // Back Button
            TextButton.icon(
              onPressed: _returnToMenu,
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF6B9FFF), size: 24),
              label: const Text(
                'BACK TO MENU',
                style: TextStyle(
                  color: Color(0xFF6B9FFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionRow(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF333333),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameScreen() {
    return Column(
      children: [
        _buildTopBar(),
        const SizedBox(height: 10),
        _buildSwipeIndicator(),
        const SizedBox(height: 10),
        Expanded(
          child: Center(
            child: GestureDetector(
              onPanStart: (details) {},
              onPanUpdate: (details) {},
              onPanEnd: (details) {
                final dx = details.velocity.pixelsPerSecond.dx;
                final dy = details.velocity.pixelsPerSecond.dy;

                if (dx.abs() > dy.abs()) {
                  _handleSwipe(dx > 0 ? SwipeDirection.right : SwipeDirection.left);
                } else if (dy.abs() > 100) {
                  _handleSwipe(dy > 0 ? SwipeDirection.down : SwipeDirection.up);
                }
              },
              child: _buildGrid(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF87CEEB), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swipe, color: Color(0xFF6B9FFF), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Swipe to slide tiles. Match 2 numbers to merge!',
                    style: TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwipeIndicator() {
    if (_lastSwipeDirection == null) {
      return const SizedBox(height: 40);
    }

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
                  color: const Color(0xFFFF9999),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9999).withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getSwipeIcon(_lastSwipeDirection!),
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getSwipeText(_lastSwipeDirection!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
      case SwipeDirection.up: return const Offset(0, -1);
      case SwipeDirection.down: return const Offset(0, 1);
      case SwipeDirection.left: return const Offset(-1, 0);
      case SwipeDirection.right: return const Offset(1, 0);
    }
  }

  IconData _getSwipeIcon(SwipeDirection direction) {
    switch (direction) {
      case SwipeDirection.up: return Icons.arrow_upward;
      case SwipeDirection.down: return Icons.arrow_downward;
      case SwipeDirection.left: return Icons.arrow_back;
      case SwipeDirection.right: return Icons.arrow_forward;
    }
  }

  String _getSwipeText(SwipeDirection direction) {
    switch (direction) {
      case SwipeDirection.up: return 'UP';
      case SwipeDirection.down: return 'DOWN';
      case SwipeDirection.left: return 'LEFT';
      case SwipeDirection.right: return 'RIGHT';
    }
  }

  Widget _buildGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final gridPadding = 16.0;
    final cellSize = (screenWidth - (gridPadding * 2) - (gridSize * 8)) / gridSize;

    return Container(
      padding: EdgeInsets.all(gridPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(gridSize, (row) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(gridSize, (col) {
              return _buildCell(row, col, cellSize);
            }),
          );
        }),
      ),
    );
  }

  Widget _buildCell(int row, int col, double size) {
    final cell = _grid[row][col];

    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cell == null
            ? const Color(0xFFE8E8E8)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
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
        borderRadius: BorderRadius.circular(8),
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
          style: TextStyle(
            fontSize: cell.value >= 100 ? size * 0.35 : size * 0.45,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );

    // Animate new tiles
    if (cell.isNew && _newTileController.value > 0 && _newTileController.value < 1) {
      return AnimatedBuilder(
        animation: _newTileController,
        builder: (context, child) {
          final scale = Curves.elasticOut.transform(_newTileController.value);
          return Transform.scale(
            scale: scale,
            child: tileContent,
          );
        },
      );
    }

    // Animate sliding tiles
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
              scale: cell.isMerged
                  ? 1.0 + (0.2 * (1 - progress))
                  : 1.0,
              child: tileContent,
            ),
          );
        },
      );
    }

    return tileContent;
  }

  List<Color> _getColorForValue(int value) {
    switch (value) {
      case 2:
        return [const Color(0xFF87CEEB), const Color(0xFF5FAFDB)]; // Sky blue
      case 4:
        return [const Color(0xFFFF9999), const Color(0xFFFF6B6B)]; // Coral red
      case 8:
        return [const Color(0xFFFFB366), const Color(0xFFFF9933)]; // Orange
      case 16:
        return [const Color(0xFFFFDD66), const Color(0xFFFFCC33)]; // Yellow
      case 32:
        return [const Color(0xFF77DD77), const Color(0xFF55CC55)]; // Green
      case 64:
        return [const Color(0xFFFF6B6B), const Color(0xFFEE5A6F)]; // Deep coral
      case 128:
        return [const Color(0xFF6FEDD6), const Color(0xFF4FD1C5)]; // Turquoise
      case 256:
        return [const Color(0xFFFFB84D), const Color(0xFFFF9F1C)]; // Gold
      case 512:
        return [const Color(0xFFFF7AA2), const Color(0xFFFF5582)]; // Pink
      case 1024:
        return [const Color(0xFFB39DDB), const Color(0xFF9575CD)]; // Purple
      case 2048:
        return [const Color(0xFFFF6B6B), const Color(0xFF6B9FFF)]; // Red-Blue gradient
      default:
        return [const Color(0xFFFF9999), const Color(0xFF87CEEB)]; // Default gradient
    }
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatBox('SCORE', _score.toString(), const Color(0xFFFF9F66)), // Bright orange
          _buildStatBox('BEST TILE', _highestTile.toString(), const Color(0xFF6B9FFF)), // Bright blue
          _buildStatBox('LEVEL', _level.toString(), const Color(0xFF66DD99)), // Bright green
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.9),
              color.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverScreen() {
    final isWinner = _highestTile >= 2048;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Fun emoji/icon at top
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isWinner
                      ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
                      : [const Color(0xFFFF9999), const Color(0xFFFF6B6B)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isWinner ? const Color(0xFFFFD700) : const Color(0xFFFF9999))
                        .withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  isWinner ? '🎉' : '😢',
                  style: const TextStyle(fontSize: 60),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Game Over/You Win Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isWinner ? const Color(0xFFFFD700) : const Color(0xFFFF9999),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 30,
                    spreadRadius: 5,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    isWinner ? 'YOU WIN!' : 'GAME OVER',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: isWinner ? const Color(0xFFFFD700) : const Color(0xFFFF6B6B),
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: (isWinner ? const Color(0xFFFFD700) : const Color(0xFFFF6B6B))
                              .withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Score Container
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF87CEEB),
                          Color(0xFFB4E7FF),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF6B9FFF),
                        width: 3,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '✨ FINAL SCORE ✨',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _score.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '🏆 Highest: $_highestTile',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Level Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF66DD99), Color(0xFF55CC88)],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF66DD99).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '⚡',
                          style: TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Level $_level',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 35),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildGameOverButton(
                        'PLAY AGAIN',
                        const Color(0xFF87CEEB),
                        Icons.refresh_rounded,
                        _startGame,
                      ),
                      const SizedBox(width: 12),
                      _buildGameOverButton(
                        'MENU',
                        const Color(0xFFFF9999),
                        Icons.home_rounded,
                        _returnToMenu,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverButton(
      String text,
      Color color,
      IconData icon,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              color.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Models
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

// Replace the extension at the bottom
extension NumberMatchScore on UserProfileService {
  Future<void> saveNumberMatchRewards(int score) async {
    try {
      // Coins: 1 coin per 10 points
      final coinsEarned = (score / 10).floor().clamp(0, 999);

      await addCoins(
        amount: coinsEarned,
        reason: 'Number Match Score: $score',
      );

      await updateGameStats(
        gamesPlayed: 1,
        gamesWon: 1,
        totalScore: score,
      );

      debugPrint('✅ Number Match saved: $score pts, $coinsEarned coins');
    } catch (e) {
      debugPrint('❌ Error saving Number Match rewards: $e');
    }
  }
}