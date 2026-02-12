import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/userprofile_service.dart';

/// Number Match - Strategic number matching puzzle game
/// Match adjacent numbers to reach the target!
class NumberMatchGameScreen extends StatefulWidget {
  const NumberMatchGameScreen({super.key});

  @override
  State<NumberMatchGameScreen> createState() => _NumberMatchGameScreenState();
}

class _NumberMatchGameScreenState extends State<NumberMatchGameScreen>
    with SingleTickerProviderStateMixin {
  // Game state
  GameState _gameState = GameState.menu;
  int _score = 0;
  int _moves = 30;
  int _target = 100;
  int _level = 1;

  // Grid
  static const int gridSize = 5;
  List<List<int>> _grid = [];

  // Selected cells
  final List<CellPosition> _selectedCells = [];

  // Animation
  late AnimationController _mergeController;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _mergeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _startGame() {
    setState(() {
      _gameState = GameState.playing;
      _score = 0;
      _moves = 30;
      _level = 1;
      _target = 100;
      _grid = _generateGrid();
      _selectedCells.clear();
    });
  }

  List<List<int>> _generateGrid() {
    final random = Random();
    return List.generate(
      gridSize,
          (_) => List.generate(
        gridSize,
            (_) => random.nextInt(5) + 1, // Numbers 1-5
      ),
    );
  }

  void _selectCell(int row, int col) {
    if (_isAnimating || _gameState != GameState.playing) return;

    final position = CellPosition(row, col);

    setState(() {
      if (_selectedCells.contains(position)) {
        // Deselect
        _selectedCells.remove(position);
      } else {
        // Check if adjacent to existing selection or first selection
        if (_selectedCells.isEmpty || _isAdjacent(position)) {
          _selectedCells.add(position);
        }
      }
    });
  }

  bool _isAdjacent(CellPosition pos) {
    if (_selectedCells.isEmpty) return true;

    final last = _selectedCells.last;
    final rowDiff = (pos.row - last.row).abs();
    final colDiff = (pos.col - last.col).abs();

    return (rowDiff == 1 && colDiff == 0) || (rowDiff == 0 && colDiff == 1);
  }

  Future<void> _mergeNumbers() async {
    if (_selectedCells.length < 2 || _isAnimating) return;

    // Check if all selected numbers are the same
    final numbers = _selectedCells.map((pos) => _grid[pos.row][pos.col]).toList();
    if (numbers.toSet().length != 1) {
      // Not all same - clear selection
      setState(() => _selectedCells.clear());
      return;
    }

    setState(() => _isAnimating = true);
    await _mergeController.forward();

    // Calculate new value
    final baseValue = numbers.first;
    final multiplier = _selectedCells.length;
    final newValue = baseValue * multiplier;

    // Update score
    final points = newValue * _selectedCells.length;

    setState(() {
      _score += points;

      // Clear all selected cells except first
      for (int i = 1; i < _selectedCells.length; i++) {
        final pos = _selectedCells[i];
        _grid[pos.row][pos.col] = 0;
      }

      // Update first cell with new value
      final firstPos = _selectedCells.first;
      _grid[firstPos.row][firstPos.col] = newValue;

      _selectedCells.clear();
      _moves--;

      // Apply gravity
      _applyGravity();
      _fillEmptyCells();

      // Check win/lose conditions
      if (_score >= _target) {
        _levelUp();
      } else if (_moves <= 0) {
        _gameOver();
      }
    });

    await _mergeController.reverse();
    setState(() => _isAnimating = false);
  }

  void _applyGravity() {
    for (int col = 0; col < gridSize; col++) {
      // Collect non-zero numbers
      final nonZero = <int>[];
      for (int row = 0; row < gridSize; row++) {
        if (_grid[row][col] != 0) {
          nonZero.add(_grid[row][col]);
        }
      }

      // Fill column from bottom
      for (int row = gridSize - 1; row >= 0; row--) {
        if (nonZero.isNotEmpty) {
          _grid[row][col] = nonZero.removeLast();
        } else {
          _grid[row][col] = 0;
        }
      }
    }
  }

  void _fillEmptyCells() {
    final random = Random();
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (_grid[row][col] == 0) {
          _grid[row][col] = random.nextInt(5) + 1;
        }
      }
    }
  }

  void _levelUp() {
    setState(() {
      _level++;
      _target = _target + (50 * _level);
      _moves += 15;
    });

    _showLevelUpDialog();
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
              colors: [Color(0xFF4A90E2), Color(0xFF6C5CE7)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Color(0xFFF2C94C), size: 80),
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
                'New Target: $_target',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF2C94C),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                child: const Text(
                  'CONTINUE',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
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
    setState(() {
      _gameState = GameState.gameOver;
    });

    _saveScore();
  }

  Future<void> _saveScore() async {
    try {
      await UserProfileService().updateNumberMatchScore(_score);
    } catch (e) {
      debugPrint('Error saving score: $e');
    }
  }

  void _returnToMenu() {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _mergeController.dispose();
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
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE74C3C), Color(0xFFF2C94C)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Text(
              'NUMBER MATCH',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 3,
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Instructions
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: Column(
              children: [
                const Text(
                  'HOW TO PLAY',
                  style: TextStyle(
                    color: Color(0xFFF2C94C),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInstructionRow('1️⃣', 'Select matching adjacent numbers'),
                _buildInstructionRow('➕', 'Merge to multiply their value'),
                _buildInstructionRow('🎯', 'Reach the target score'),
                _buildInstructionRow('⚡', 'More matches = higher combo!'),
              ],
            ),
          ),

          const SizedBox(height: 60),

          // Start button
          GestureDetector(
            onTap: _startGame,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A90E2), Color(0xFF6C5CE7)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A90E2).withOpacity(0.6),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: const Text(
                'START GAME',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Back button
          TextButton.icon(
            onPressed: _returnToMenu,
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            label: const Text(
              'BACK TO MENU',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ],
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
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameScreen() {
    final screenWidth = MediaQuery.of(context).size.width;
    final gridPadding = 20.0;
    final cellSize = (screenWidth - (gridPadding * 2)) / gridSize - 8;

    return Column(
      children: [
        // Top stats
        _buildTopBar(),

        const SizedBox(height: 20),

        // Grid
        Expanded(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(gridPadding),
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
            ),
          ),
        ),

        // Merge button
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedCells.length >= 2 ? _mergeNumbers : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE74C3C),
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _selectedCells.length >= 2
                        ? 'MERGE ${_selectedCells.length} NUMBERS'
                        : 'SELECT NUMBERS',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  onPressed: () => setState(() => _selectedCells.clear()),
                  icon: const Icon(Icons.clear, color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCell(int row, int col, double size) {
    final value = _grid[row][col];
    final position = CellPosition(row, col);
    final isSelected = _selectedCells.contains(position);

    return GestureDetector(
      onTap: () => _selectCell(row, col),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [const Color(0xFFF2C94C), const Color(0xFFE74C3C)]
                : _getColorForValue(value),
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: isSelected ? 3 : 2,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: const Color(0xFFF2C94C).withOpacity(0.6),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ]
              : [],
        ),
        child: Center(
          child: Text(
            value.toString(),
            style: TextStyle(
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _getColorForValue(int value) {
    if (value <= 3) {
      return [const Color(0xFF4A90E2), const Color(0xFF357ABD)];
    } else if (value <= 10) {
      return [const Color(0xFF6C5CE7), const Color(0xFF5548C8)];
    } else if (value <= 30) {
      return [const Color(0xFFE74C3C), const Color(0xFFC0392B)];
    } else {
      return [const Color(0xFFF2C94C), const Color(0xFFE1B33D)];
    }
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatBox('SCORE', _score.toString(), const Color(0xFFF2C94C)),
          _buildStatBox('TARGET', _target.toString(), const Color(0xFF4A90E2)),
          _buildStatBox('MOVES', _moves.toString(), const Color(0xFFE74C3C)),
          _buildStatBox('LEVEL', _level.toString(), const Color(0xFF6C5CE7)),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverScreen() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2a2a3e),
              Color(0xFF1a1a2e),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFE74C3C), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _score >= _target ? 'VICTORY!' : 'GAME OVER',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: _score >= _target
                    ? const Color(0xFFF2C94C)
                    : const Color(0xFFE74C3C),
                letterSpacing: 3,
              ),
            ),

            const SizedBox(height: 30),

            // Final score
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF6C5CE7), width: 2),
              ),
              child: Column(
                children: [
                  const Text(
                    'FINAL SCORE',
                    style: TextStyle(
                      color: Color(0xFFF2C94C),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _score.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Level $_level Reached',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 20,
              ),
            ),

            const SizedBox(height: 40),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGameOverButton(
                  'PLAY AGAIN',
                  const Color(0xFF4A90E2),
                  Icons.refresh,
                  _startGame,
                ),
                _buildGameOverButton(
                  'MENU',
                  const Color(0xFFE74C3C),
                  Icons.home,
                  _returnToMenu,
                ),
              ],
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
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
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Cell position model
class CellPosition {
  final int row;
  final int col;

  CellPosition(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is CellPosition && row == other.row && col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}

// Game state enum - ADD THIS
enum GameState {
  menu,
  playing,
  gameOver,
}

// Extension to UserProfileService
extension NumberMatchScore on UserProfileService {
  Future<void> updateNumberMatchScore(int score) async {
    debugPrint('Number Match Score: $score');
  }
}

