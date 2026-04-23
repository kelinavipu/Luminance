import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';

class Game2048Screen extends StatefulWidget {
  const Game2048Screen({super.key});

  @override
  State<Game2048Screen> createState() => _Game2048ScreenState();
}

class _Game2048ScreenState extends State<Game2048Screen> {
  static const int gridSize = 4;
  late List<List<int>> grid;
  int score = 0;
  int highScore = 0;
  final Random _random = Random();
  bool _isGameOverState = false;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _initGame();
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      highScore = prefs.getInt('2048_highscore') ?? 0;
    });
  }

  Future<void> _saveHighScore(int currentScore) async {
    final prefs = await SharedPreferences.getInstance();
    if (currentScore > highScore) {
      await prefs.setInt('2048_highscore', currentScore);
      setState(() {
        highScore = currentScore;
      });
    }
  }

  void _initGame() {
    grid = List.generate(gridSize, (i) => List.generate(gridSize, (j) => 0));
    score = 0;
    _isGameOverState = false;
    _addRandomTile();
    _addRandomTile();
    setState(() {});
  }

  void _addRandomTile() {
    List<Point<int>> emptySpots = [];
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (grid[r][c] == 0) {
          emptySpots.add(Point(r, c));
        }
      }
    }
    if (emptySpots.isEmpty) return;

    Point<int> p = emptySpots[_random.nextInt(emptySpots.length)];
    grid[p.x][p.y] = _random.nextDouble() < 0.9 ? 2 : 4;
  }

  void _handleSwipe(DragEndDetails details) {
    if (_isGameOverState) return;
    if (details.primaryVelocity == null) return;
    
    // Determine axis
    if (details.velocity.pixelsPerSecond.dx.abs() > details.velocity.pixelsPerSecond.dy.abs()) {
      // Horizontal
      if (details.primaryVelocity! > 0) {
        _moveRight();
      } else {
        _moveLeft();
      }
    } else {
      // Vertical
      if (details.primaryVelocity! > 0) {
        _moveDown();
      } else {
        _moveUp();
      }
    }
  }

  void _moveLeft() {
    bool moved = false;
    for (int r = 0; r < gridSize; r++) {
      List<int> row = grid[r].where((val) => val != 0).toList();
      for (int i = 0; i < row.length - 1; i++) {
        if (row[i] == row[i + 1]) {
          row[i] *= 2;
          score += row[i];
          row[i + 1] = 0;
          moved = true;
        }
      }
      row = row.where((val) => val != 0).toList();
      while (row.length < gridSize) {
        row.add(0);
      }
      if (grid[r].toString() != row.toString()) moved = true;
      grid[r] = row;
    }
    if (moved) _finishMove();
  }

  void _moveRight() {
    bool moved = false;
    for (int r = 0; r < gridSize; r++) {
      List<int> row = grid[r].where((val) => val != 0).toList();
      for (int i = row.length - 1; i > 0; i--) {
        if (row[i] == row[i - 1]) {
          row[i] *= 2;
          score += row[i];
          row[i - 1] = 0;
          moved = true;
        }
      }
      row = row.where((val) => val != 0).toList();
      List<int> newRow = List.generate(gridSize - row.length, (i) => 0)..addAll(row);
      if (grid[r].toString() != newRow.toString()) moved = true;
      grid[r] = newRow;
    }
    if (moved) _finishMove();
  }

  void _moveUp() {
    bool moved = false;
    for (int c = 0; c < gridSize; c++) {
      List<int> col = [];
      for (int r = 0; r < gridSize; r++) {
        if (grid[r][c] != 0) col.add(grid[r][c]);
      }
      for (int i = 0; i < col.length - 1; i++) {
        if (col[i] == col[i + 1]) {
          col[i] *= 2;
          score += col[i];
          col[i + 1] = 0;
          moved = true;
        }
      }
      col = col.where((val) => val != 0).toList();
      while (col.length < gridSize) {
        col.add(0);
      }
      for (int r = 0; r < gridSize; r++) {
        if (grid[r][c] != col[r]) moved = true;
        grid[r][c] = col[r];
      }
    }
    if (moved) _finishMove();
  }

  void _moveDown() {
    bool moved = false;
    for (int c = 0; c < gridSize; c++) {
      List<int> col = [];
      for (int r = 0; r < gridSize; r++) {
        if (grid[r][c] != 0) col.add(grid[r][c]);
      }
      for (int i = col.length - 1; i > 0; i--) {
        if (col[i] == col[i - 1]) {
          col[i] *= 2;
          score += col[i];
          col[i - 1] = 0;
          moved = true;
        }
      }
      col = col.where((val) => val != 0).toList();
      List<int> newCol = List.generate(gridSize - col.length, (i) => 0)..addAll(col);
      for (int r = 0; r < gridSize; r++) {
        if (grid[r][c] != newCol[r]) moved = true;
        grid[r][c] = newCol[r];
      }
    }
    if (moved) _finishMove();
  }

  void _finishMove() {
    _addRandomTile();
    _saveHighScore(score);
    if (_checkGameOver()) {
      setState(() {
        _isGameOverState = true;
      });
      _showGameOverDialog();
    } else {
      setState(() {});
    }
  }

  bool _checkGameOver() {
    // Check if any empty cell exists
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (grid[r][c] == 0) return false;
      }
    }
    
    // Check for possible horizontal merges
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize - 1; c++) {
        if (grid[r][c] == grid[r][c + 1]) return false;
      }
    }
    
    // Check for possible vertical merges
    for (int c = 0; c < gridSize; c++) {
      for (int r = 0; r < gridSize - 1; r++) {
        if (grid[r][c] == grid[r + 1][c]) return false;
      }
    }
    
    return true;
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Center(
            child: Text(
              'Game Over',
              style: TextStyle(
                color: AppTheme.textLight,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No more moves available!', style: TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('SCORE', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      Text('$score', style: const TextStyle(color: AppTheme.cyan, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('BEST', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      Text('$highScore', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Exit game screen
              },
              child: const Text('Exit', style: TextStyle(color: AppTheme.textMuted, fontSize: 18)),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cyan,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(context);
                _initGame();
              },
              child: const Text('Restart', style: TextStyle(color: AppTheme.darkBlue, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }

  // Theming tiles using AppTheme colors
  Color _getTileColor(int val) {
    if (val == 0) return AppTheme.cardBlue;
    
    // Gradually getting brighter cyan/blue colors
    switch (val) {
      case 2: return const Color(0xFF1B2E4B); // Deeper blue
      case 4: return const Color(0xFF223C60);
      case 8: return const Color(0xFF2E5383);
      case 16: return const Color(0xFF386AAB);
      case 32: return const Color(0xFF4581CC);
      case 64: return const Color(0xFF1E88E5);
      case 128: return const Color(0xFF039BE5);
      case 256: return const Color(0xFF00ACC1);
      case 512: return const Color(0xFF00BCD4);
      case 1024: return const Color(0xFF26C6DA);
      case 2048: return AppTheme.cyan; // Glowing cyan
      default: return const Color(0xFF84FFFF); // >2048 gets very bright
    }
  }

  Color _getTextColor(int val) {
    // Dark text for very bright tiles, light text for dark tiles
    if (val >= 1024) return AppTheme.darkBlue;
    return AppTheme.textLight;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('2048 Mindful Mini-game')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SCORE', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      Text('$score', style: const TextStyle(color: AppTheme.textLight, fontSize: 28, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('BEST', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      Text('$highScore', style: const TextStyle(color: AppTheme.cyan, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: _initGame,
                  icon: const Icon(Icons.refresh, color: AppTheme.cyan),
                  tooltip: 'Restart Game',
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onVerticalDragEnd: _handleSwipe,
                  onHorizontalDragEnd: _handleSwipe,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.darkerBlue,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.cyan.withOpacity(0.3), width: 2),
                    ),
                    constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridSize,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: gridSize * gridSize,
                      itemBuilder: (context, index) {
                        int r = index ~/ gridSize;
                        int c = index % gridSize;
                        int val = grid[r][c];
                        
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            color: _getTileColor(val),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: val >= 2048 ? [
                              BoxShadow(color: AppTheme.cyan.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)
                            ] : null,
                          ),
                          child: Center(
                            child: Text(
                              val == 0 ? '' : '$val',
                              style: TextStyle(
                                color: _getTextColor(val),
                                fontSize: val > 512 ? 24 : 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
