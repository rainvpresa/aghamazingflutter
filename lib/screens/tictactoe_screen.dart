import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TicTacToeStartScreen extends StatefulWidget {
  const TicTacToeStartScreen({super.key});

  @override
  State<TicTacToeStartScreen> createState() => _TicTacToeStartScreenState();
}

class _TicTacToeStartScreenState extends State<TicTacToeStartScreen> {
  @override
  void initState() {
    super.initState();
    // Set full screen mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);

    // Auto-start game after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TicTacToeGameScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(fontFamily: 'LilitaOne'),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Background (YOUR IMAGE)
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/pngs/background.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Centered Logo
            Center(
              child: Image.asset(
                'assets/images/pngs/logo.png',
                height: 300, // ✅ BIG LOGO
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum GameState { starting, playing, gameOver }
enum Player { x, o, none }

class TicTacToeGameScreen extends StatefulWidget {
  const TicTacToeGameScreen({super.key});

  @override
  State<TicTacToeGameScreen> createState() => _TicTacToeGameScreenState();
}

class _TicTacToeGameScreenState extends State<TicTacToeGameScreen> {
  late Player currentPlayer;
  late Player aiSymbol;
  GameState gameState = GameState.playing;
  String gameOverMessage = '';
  final List<Player> board = List.filled(9, Player.none);
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    currentPlayer = Player.x;
    aiSymbol = Player.o;
    Future.delayed(const Duration(seconds: 1), _aiMove);
  }

  @override
  void dispose() {
    // Restore system UI when leaving the game
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  void _makeMove(int index) {
    if (gameState != GameState.playing || board[index] != Player.none) return;

    // User move
    if (mounted) {
      setState(() {
        board[index] = currentPlayer;
      });
    }

    // Check win/tie
    if (_checkWin(currentPlayer)) {
      _gameOver('YOU WIN!');
      return;
    }
    if (_checkTie()) {
      _gameOver('IT\'S A TIE!');
      return;
    }

    // AI move
    currentPlayer = aiSymbol;
    Future.delayed(const Duration(milliseconds: 600), _aiMove);
  }

  void _aiMove() {
    if (gameState != GameState.playing || !mounted) return;

    // 🌟 EASY MODE: 40% chance to play randomly (let user win sometimes!)
    if (_random.nextDouble() < 0.4) {
      _randomMove();
      return;
    }

    // Smart moves (60% of the time)
    // 1. Try to win
    int? winMove = _findWinningMove(aiSymbol);
    if (winMove != null) {
      _executeMove(winMove);
      return;
    }

    // 2. Block user win
    int? blockMove = _findWinningMove(Player.x);
    if (blockMove != null) {
      _executeMove(blockMove);
      return;
    }

    // 3. Take center
    if (board[4] == Player.none) {
      _executeMove(4);
      return;
    }

    // 4. Take corners
    final corners = [0, 2, 6, 8];
    final availableCorners = corners.where((i) => board[i] == Player.none).toList();
    if (availableCorners.isNotEmpty) {
      _executeMove(availableCorners[_random.nextInt(availableCorners.length)]);
      return;
    }

    // 5. Random move
    _randomMove();
  }

  void _randomMove() {
    final available = List.generate(9, (i) => i).where((i) => board[i] == Player.none).toList();
    if (available.isNotEmpty) {
      _executeMove(available[_random.nextInt(available.length)]);
    }
  }

  int? _findWinningMove(Player player) {
    // Check rows
    for (int i = 0; i < 3; i++) {
      final row = [i * 3, i * 3 + 1, i * 3 + 2];
      if (_countPlayerInPositions(row, player) == 2 &&
          _countPlayerInPositions(row, Player.none) == 1) {
        return row.firstWhere((pos) => board[pos] == Player.none);
      }
    }

    // Check columns
    for (int i = 0; i < 3; i++) {
      final col = [i, i + 3, i + 6];
      if (_countPlayerInPositions(col, player) == 2 &&
          _countPlayerInPositions(col, Player.none) == 1) {
        return col.firstWhere((pos) => board[pos] == Player.none);
      }
    }

    // Check diagonals
    final diagonals = [
      [0, 4, 8],
      [2, 4, 6]
    ];
    for (final diag in diagonals) {
      if (_countPlayerInPositions(diag, player) == 2 &&
          _countPlayerInPositions(diag, Player.none) == 1) {
        return diag.firstWhere((pos) => board[pos] == Player.none);
      }
    }

    return null;
  }

  int _countPlayerInPositions(List<int> positions, Player player) {
    return positions.where((pos) => board[pos] == player).length;
  }

  void _executeMove(int index) {
    if (!mounted) return;
    setState(() {
      board[index] = aiSymbol;
    });

    // Check win/tie
    if (_checkWin(aiSymbol)) {
      _gameOver('SMARTY WINS!');
      return;
    }
    if (_checkTie()) {
      _gameOver('IT\'S A TIE!');
      return;
    }

    // Back to user
    currentPlayer = Player.x;
  }

  bool _checkWin(Player player) {
    final wins = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // columns
      [0, 4, 8], [2, 4, 6]             // diagonals
    ];

    return wins.any((win) => win.every((i) => board[i] == player));
  }

  bool _checkTie() {
    return board.every((cell) => cell != Player.none);
  }

  void _gameOver(String message) {
    if (!mounted) return;
    setState(() {
      gameState = GameState.gameOver;
      gameOverMessage = message;
    });
  }

  void _resetGame() {
    if (!mounted) return;
    setState(() {
      board.fillRange(0, 9, Player.none);
      gameState = GameState.playing;
      currentPlayer = Player.x;
    });
    Future.delayed(const Duration(seconds: 1), _aiMove);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Theme(
      data: ThemeData(fontFamily: 'LilitaOne'),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Background (YOUR IMAGE)
              Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/pngs/background.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // Centered Game UI
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Board (CENTERED)
                    AspectRatio(
                      aspectRatio: 1.0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: 9,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => _makeMove(index),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: board[index] != Player.none
                                        ? (board[index] == Player.x
                                        ? Colors.blueAccent
                                        : Colors.redAccent)
                                        : Colors.white,
                                    width: 2.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    board[index] == Player.x
                                        ? 'X'
                                        : board[index] == Player.o
                                        ? 'O'
                                        : '',
                                    style: TextStyle(
                                      color: board[index] == Player.x
                                          ? Colors.blueAccent
                                          : Colors.redAccent,
                                      fontSize: size.width / 7,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Status message (BELOW BOARD)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Text(
                        gameState == GameState.playing
                            ? 'Your turn: X'
                            : gameOverMessage,
                        style: TextStyle(
                          color: gameState == GameState.gameOver
                              ? (gameOverMessage.contains('WIN') && !gameOverMessage.contains('SMARTY')
                              ? Colors.green.shade300
                              : gameOverMessage.contains('SMARTY')
                              ? Colors.red.shade300
                              : Colors.yellow)
                              : Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 8, offset: Offset(2, 2))
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Game Over Buttons (ONLY WHEN GAME OVER)
                    if (gameState == GameState.gameOver)
                      Column(
                        children: [
                          ElevatedButton(
                            onPressed: _resetGame,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade400,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 70,
                                vertical: 22,
                              ),
                              elevation: 12,
                            ),
                            child: const Text(
                              'TRY AGAIN',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade400,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 70,
                                vertical: 22,
                              ),
                              elevation: 12,
                            ),
                            child: const Text(
                              'EXIT',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
    );
  }
}
