import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'main.dart'; // Para ApiService y UserData

class SkateGameScreen extends StatefulWidget {
  const SkateGameScreen({super.key});

  @override
  State<SkateGameScreen> createState() => _SkateGameScreenState();
}

class _SkateGameScreenState extends State<SkateGameScreen> {
  bool gameStarted = false;
  bool gameOver = false;
  int score = 0;
  String? sessionToken;
  bool loading = false;

  void _startGame() async {
    setState(() => loading = true);
    
    // Iniciar sesión en el backend
    final session = await ApiService.startGameSession(UserData.id);
    
    if (session != null && session['session_token'] != null) {
      setState(() {
        sessionToken = session['session_token'];
        gameStarted = true;
        gameOver = false;
        score = 0;
        loading = false;
      });
    } else {
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error iniciando juego. ¿Límite diario alcanzado?'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onGameOver(int finalScore) async {
    setState(() {
      gameOver = true;
      score = finalScore;
    });
    
    // Enviar score al backend
    if (sessionToken != null) {
      final result = await ApiService.submitScore(sessionToken!, finalScore);
      
      if (result != null && result['success'] == true) {
        final int points = (result['points_earned'] ?? 0) as int;
        final int streak = (result['current_streak'] ?? 1) as int;
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('¡Ganaste $points puntos! Racha: $streak días'),
              backgroundColor: const Color(0xFFFF6B35),
            ),
          );
        }
        
        // Actualizar puntos locales
        UserData.puntosActuales += points;
        UserData.puntosHistoricos += points;
        UserData.rachaActual = streak;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('SKATE GAME'),
        backgroundColor: Colors.transparent,
      ),
      body: !gameStarted
          ? _buildStartScreen()
          : gameOver
              ? _buildGameOverScreen()
              : SkateGameWidget(onGameOver: _onGameOver),
    );
  }

  Widget _buildStartScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.skateboarding,
            size: 100,
            color: Color(0xFFFF6B35),
          ),
          const SizedBox(height: 30),
          const Text(
            'SKATE JUMP',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Toca para saltar tachos',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 50),
          ElevatedButton(
            onPressed: _startGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'JUGAR',
              style: TextStyle(fontSize: 24, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'GAME OVER',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Score: $score',
            style: const TextStyle(fontSize: 32, color: Colors.white),
          ),
          const SizedBox(height: 50),
          ElevatedButton(
            onPressed: () {
              setState(() {
                gameStarted = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'VOLVER A JUGAR',
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// GAME WIDGET CON CANVAS
// ==========================================

class SkateGameWidget extends StatefulWidget {
  final Function(int) onGameOver;

  const SkateGameWidget({required this.onGameOver, super.key});

  @override
  State<SkateGameWidget> createState() => _SkateGameWidgetState();
}

class _SkateGameWidgetState extends State<SkateGameWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  // Player
  double playerY = 0; // Posición Y del jugador (0 = suelo)
  double playerVelocity = 0;
  bool isJumping = false;
  
  // Game
  int score = 0;
  double gameSpeed = 5.0;
  List<Obstacle> obstacles = [];
  double obstacleTimer = 0;
  
  // Physics
  final double gravity = 0.8;
  final double jumpForce = -15.0;
  final double groundLevel = 0;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60 FPS
    )..addListener(_updateGame);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateGame() {
    setState(() {
      // Física del jugador
      playerVelocity += gravity;
      playerY += playerVelocity;

      // Limitar al suelo
      if (playerY >= groundLevel) {
        playerY = groundLevel;
        playerVelocity = 0;
        isJumping = false;
      }

      // Mover obstáculos
      for (var obstacle in obstacles) {
        obstacle.x -= gameSpeed;
      }

      // Eliminar obstáculos fuera de pantalla
      obstacles.removeWhere((obs) => obs.x < -100);

      // Generar nuevos obstáculos
      obstacleTimer += 1;
      if (obstacleTimer > 100) {
        obstacles.add(Obstacle(x: 400, y: 0));
        obstacleTimer = 0;
        score += 1;
        
        // Aumentar velocidad gradualmente
        if (score % 10 == 0) {
          gameSpeed += 0.5;
        }
      }

      // Detectar colisiones
      _checkCollisions();
    });
  }

  void _checkCollisions() {
    const double playerX = 50;
    const double playerWidth = 40;
    const double playerHeight = 60;

    for (var obstacle in obstacles) {
      // Hitbox del obstáculo
      if (playerX + playerWidth > obstacle.x &&
          playerX < obstacle.x + obstacle.width &&
          playerY + playerHeight > obstacle.y) {
        // Colisión detectada
        _controller.stop();
        widget.onGameOver(score);
      }
    }
  }

  void _jump() {
    if (!isJumping) {
      playerVelocity = jumpForce;
      isJumping = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _jump,
      child: Container(
        color: const Color(0xFF0A0A0A),
        child: Stack(
          children: [
            // Canvas del juego
            CustomPaint(
              painter: GamePainter(
                playerY: playerY,
                obstacles: obstacles,
              ),
              child: Container(),
            ),
            // Score
            Positioned(
              top: 20,
              right: 20,
              child: Text(
                'SCORE: $score',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF6B35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PAINTER DEL JUEGO
// ==========================================

class GamePainter extends CustomPainter {
  final double playerY;
  final List<Obstacle> obstacles;

  GamePainter({
    required this.playerY,
    required this.obstacles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Dibujar suelo
    paint.color = const Color(0xFF333333);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 50, size.width, 50),
      paint,
    );

    // Dibujar jugador (stickman simple)
    _drawPlayer(canvas, size, paint);

    // Dibujar obstáculos (tachos)
    for (var obstacle in obstacles) {
      _drawObstacle(canvas, size, paint, obstacle);
    }
  }

  void _drawPlayer(Canvas canvas, Size size, Paint paint) {
    const double playerX = 50;
    final double playerBottomY = size.height - 50 - playerY;

    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;

    // Cabeza
    canvas.drawCircle(
      Offset(playerX + 20, playerBottomY - 50),
      10,
      paint,
    );

    // Cuerpo
    canvas.drawLine(
      Offset(playerX + 20, playerBottomY - 40),
      Offset(playerX + 20, playerBottomY - 10),
      paint,
    );

    // Brazos
    canvas.drawLine(
      Offset(playerX + 20, playerBottomY - 30),
      Offset(playerX + 10, playerBottomY - 20),
      paint,
    );
    canvas.drawLine(
      Offset(playerX + 20, playerBottomY - 30),
      Offset(playerX + 30, playerBottomY - 20),
      paint,
    );

    // Piernas
    canvas.drawLine(
      Offset(playerX + 20, playerBottomY - 10),
      Offset(playerX + 10, playerBottomY),
      paint,
    );
    canvas.drawLine(
      Offset(playerX + 20, playerBottomY - 10),
      Offset(playerX + 30, playerBottomY),
      paint,
    );
  }

  void _drawObstacle(Canvas canvas, Size size, Paint paint, Obstacle obstacle) {
    final double obstacleY = size.height - 50 - obstacle.y;

    paint.color = const Color(0xFFFF6B35);
    paint.style = PaintingStyle.fill;

    // Tacho de basura (rectángulo + tapa)
    canvas.drawRect(
      Rect.fromLTWH(obstacle.x, obstacleY - 40, 30, 40),
      paint,
    );

    // Tapa
    paint.color = const Color(0xFFFF8C42);
    canvas.drawRect(
      Rect.fromLTWH(obstacle.x - 5, obstacleY - 45, 40, 5),
      paint,
    );
  }

  @override
  bool shouldRepaint(GamePainter oldDelegate) => true;
}

// ==========================================
// CLASE OBSTÁCULO
// ==========================================

class Obstacle {
  double x;
  double y;
  final double width = 30;
  final double height = 40;

  Obstacle({required this.x, required this.y});
}
