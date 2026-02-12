import 'package:flutter/material.dart';
import 'dart:math';
import '../../services/userprofile_service.dart';

class ColorPuzzleGame extends StatefulWidget {
  const ColorPuzzleGame({Key? key}) : super(key: key);

  @override
  State<ColorPuzzleGame> createState() => _ColorPuzzleGameState();
}

class _ColorPuzzleGameState extends State<ColorPuzzleGame> {
  // Game configuration
  static const int rows = 3;
  static const int bottlesPerRow = 3;
  static const int totalSpots = rows * bottlesPerRow;
  static const int emptySpots = 2; // Number of empty spots
  static const int segmentsPerBottle = 3;

  // Available colors for the puzzle
  final List<Color> availableColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
  ];

  // Game state - null means empty spot
  List<List<Color>?> bottles = [];
  int moveCount = 0;
  bool gameWon = false;

  // Add service and saving state
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

    Random random = Random();

    // Calculate how many bottles we need
    int numBottles = totalSpots - emptySpots;

    // Create a pool of colors ensuring we have enough for complete rows
    // This guarantees the puzzle is solvable
    List<List<Color>?> allBottles = [];

    // For each row, create bottles of the same color
    for (int row = 0; row < rows; row++) {
      Color rowColor = availableColors[row % availableColors.length];

      for (int i = 0; i < bottlesPerRow && allBottles.length < numBottles; i++) {
        allBottles.add(List.filled(segmentsPerBottle, rowColor));
      }
    }

    // Add empty spots
    for (int i = 0; i < emptySpots; i++) {
      allBottles.add(null);
    }

    // NOW: Shuffle multiple times with different patterns for maximum randomization
    for (int shuffleRound = 0; shuffleRound < 5; shuffleRound++) {
      allBottles.shuffle(random);

      // Additional scrambling: swap random pairs
      for (int swaps = 0; swaps < 10; swaps++) {
        int idx1 = random.nextInt(allBottles.length);
        int idx2 = random.nextInt(allBottles.length);

        var temp = allBottles[idx1];
        allBottles[idx1] = allBottles[idx2];
        allBottles[idx2] = temp;
      }
    }

    bottles = allBottles;

    // Final check: make sure it's not already solved
    int attempts = 0;
    while (checkWinCondition() && attempts < 20) {
      bottles.shuffle(random);
      attempts++;
    }

    setState(() {});
  }

  bool checkWinCondition() {
    // Check if each row has bottles with matching colors (ignoring empty spots)
    for (int row = 0; row < rows; row++) {
      int startIndex = row * bottlesPerRow;

      // Get all non-empty bottles in this row
      List<List<Color>> rowBottles = [];
      for (int i = 0; i < bottlesPerRow; i++) {
        int bottleIndex = startIndex + i;
        if (bottles[bottleIndex] != null) {
          rowBottles.add(bottles[bottleIndex]!);
        }
      }

      // If row has no bottles, skip
      if (rowBottles.isEmpty) continue;

      // Get the color of the first bottle in the row
      Color firstBottleColor = rowBottles[0][0];

      // Check if all bottles in the row have the same uniform color
      for (var bottle in rowBottles) {
        // Check if all segments in bottle are the same color
        if (!bottle.every((c) => c == firstBottleColor)) {
          return false;
        }
      }
    }
    return true;
  }

  void onBottleTap(int index) {
    if (gameWon) return;

    // If tapped spot is empty, do nothing
    if (bottles[index] == null) return;

    // Find adjacent empty spots
    int? emptySpotIndex = _findAdjacentEmptySpot(index);

    if (emptySpotIndex != null) {
      setState(() {
        // Move bottle to empty spot
        bottles[emptySpotIndex] = bottles[index];
        bottles[index] = null;

        moveCount++;

        // Check win condition
        if (checkWinCondition()) {
          gameWon = true;
          _showWinDialog();
        }
      });
    }
  }

  int? _findAdjacentEmptySpot(int index) {
    int row = index ~/ bottlesPerRow;
    int col = index % bottlesPerRow;

    // Check all 4 directions: up, down, left, right
    List<List<int>> directions = [
      [-1, 0], // up
      [1, 0],  // down
      [0, -1], // left
      [0, 1],  // right
    ];

    for (var dir in directions) {
      int newRow = row + dir[0];
      int newCol = col + dir[1];

      // Check if new position is valid
      if (newRow >= 0 && newRow < rows && newCol >= 0 && newCol < bottlesPerRow) {
        int adjacentIndex = newRow * bottlesPerRow + newCol;

        // Check if this spot is empty
        if (bottles[adjacentIndex] == null) {
          return adjacentIndex;
        }
      }
    }

    return null; // No adjacent empty spot found
  }

  // Calculate rewards based on performance
  Map<String, int> _calculateRewards() {
    // Scoring system:
    // - Base points: 100
    // - Fewer moves = more coins and points
    // - Perfect game (minimum moves) gets maximum rewards

    int basePoints = 100;
    int baseCoins = 50;

    // Penalty for extra moves (reduce rewards for more moves)
    // Minimum possible moves is around 10-15 for this puzzle
    int optimalMoves = 12;
    int extraMoves = max(0, moveCount - optimalMoves);

    // Calculate points (max 100, min 20)
    int points = max(20, basePoints - (extraMoves * 3));

    // Calculate coins (max 50, min 10)
    int coins = max(10, baseCoins - (extraMoves * 2));

    return {
      'points': points,
      'coins': coins,
    };
  }

  // Save rewards to Firebase
  Future<void> _saveRewards(int coins, int points) async {
    setState(() => _isSavingRewards = true);

    try {
      // Update game stats
      await _profileService.updateGameStats(
        gamesPlayed: 1,
        gamesWon: 1,
        totalScore: points,
      );

      // Add coins
      await _profileService.addCoins(
        amount: coins,
        reason: 'Color Puzzle Game - $moveCount moves',
      );

      debugPrint('✅ Rewards saved: $coins coins, $points points');
    } catch (e) {
      debugPrint('❌ Error saving rewards: $e');
      // Still allow the user to continue even if save fails
    } finally {
      setState(() => _isSavingRewards = false);
    }
  }

  Widget _buildRewardItem(IconData icon, Color color, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showWinDialog() async {
    // Calculate rewards
    final rewards = _calculateRewards();
    final int coinsEarned = rewards['coins']!;
    final int pointsEarned = rewards['points']!;

    // Save rewards to Firebase
    await _saveRewards(coinsEarned, pointsEarned);

    // Show win dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.amber.shade300,
                Colors.orange.shade400,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Star icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: Colors.amber.shade700,
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                '🎉 AMAZING! 🎉',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Moves Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$moveCount Moves',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Rewards Display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'REWARDS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF004A98),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Coins
                        _buildRewardItem(
                          Icons.monetization_on,
                          Colors.amber.shade700,
                          '$coinsEarned',
                          'Coins',
                        ),
                        // Points
                        _buildRewardItem(
                          Icons.stars,
                          Colors.purple.shade600,
                          '$pointsEarned',
                          'Points',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Play Again button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSavingRewards
                      ? null
                      : () {
                    Navigator.pop(context);
                    initializeGame();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 8,
                  ),
                  child: _isSavingRewards
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.play_arrow, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'PLAY AGAIN',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF87CEEB), // Sky blue
              Color(0xFF98D8E8), // Light blue
              Color(0xFFFFA07A), // Light salmon
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Header with decorative elements
              _buildHeader(context),

              const SizedBox(height: 10),

              // Game info cards with playful design
              _buildInfoPanel(),

              const SizedBox(height: 20),

              // Game grid with decorative background
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: _buildGameBoard(),
                  ),
                ),
              ),

              // Bottom button area
              _buildBottomButtons(),
            ],
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
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button with circular design
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.shade400,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Title
          const Expanded(
            child: Text(
              'Color Puzzle',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF004A98),
              ),
            ),
          ),
          // Coins/Score display (decorative)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.shade400,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.shade700, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.stars,
                  color: Colors.orange.shade900,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  '${100 - moveCount}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
                  colors: [Colors.purple.shade400, Colors.purple.shade600],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'MOVES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$moveCount',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
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
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'GOAL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Match Rows!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
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
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Instruction text with icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200, width: 2),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Slide bottles to empty spots!',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Game grid
          ...List.generate(rows, (rowIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(bottlesPerRow, (colIndex) {
                  int bottleIndex = rowIndex * bottlesPerRow + colIndex;
                  bool isEmpty = bottles[bottleIndex] == null;
                  bool canMove = !isEmpty && _findAdjacentEmptySpot(bottleIndex) != null;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: GestureDetector(
                      onTap: () => onBottleTap(bottleIndex),
                      child: isEmpty
                          ? EmptySpotWidget()
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
            colors: [Colors.green.shade400, Colors.green.shade600],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: initializeGame,
            borderRadius: BorderRadius.circular(28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'NEW GAME',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BottleWidget extends StatelessWidget {
  final List<Color> colors;
  final bool canMove;

  const BottleWidget({
    Key? key,
    required this.colors,
    this.canMove = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: SizedBox(
        width: 70,
        height: 130,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Bottle body with colored segments
            Positioned(
              bottom: 0,
              child: Container(
                width: 70,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: canMove ? Colors.green.shade600 : Colors.grey.shade400,
                    width: canMove ? 3 : 2,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(15),
                    bottomRight: Radius.circular(15),
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
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
                    bottomLeft: Radius.circular(13),
                    bottomRight: Radius.circular(13),
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                  child: Column(
                    children: colors.map((color) {
                      return Expanded(
                        child: Container(
                          width: double.infinity,
                          color: color,
                          margin: const EdgeInsets.all(1),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // Bottle neck
            Positioned(
              top: 0,
              child: Container(
                width: 30,
                height: 35,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: canMove ? Colors.green.shade600 : Colors.grey.shade400,
                    width: canMove ? 3 : 2,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  color: Colors.white,
                ),
              ),
            ),

            // Move indicator (if can move) - Circle dot
            if (canMove)
              Positioned(
                top: 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
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

// Empty spot widget with playful design
class EmptySpotWidget extends StatelessWidget {
  const EmptySpotWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 130,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade400,
          width: 3,
          style: BorderStyle.solid,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade300,
            border: Border.all(
              color: Colors.grey.shade400,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}