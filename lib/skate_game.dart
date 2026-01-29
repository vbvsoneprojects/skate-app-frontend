import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'main.dart';

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
    
    if (sessionToken != null) {
      final result = await ApiService.submitScore(sessionToken!, finalScore);
      
      if (result != null && result['success'] == true) {
        final int points = (result['points_earned'] ?? 0) as int;
        final int streak = (result['current_streak'] ?? 1) as int;
        
        final bool isNewRecord = (result['new_record'] ?? false) as bool;
        
        UserData.puntosActuales += points;
        UserData.puntosHistoricos += points;
        UserData.rachaActual = streak;
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFFF6B35), width: 3),
              ),
              title: Column(
                children: [
                   if (isNewRecord) ...[
                      const Text(
                        "🏆 ¡NUEVO RÉCORD! 🏆",
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                   ],
                   const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, color: Color(0xFFFFD700), size: 30),
                      SizedBox(width: 8),
                      Text(
                        '¡PUNTOS GANADOS!',
                        style: TextStyle(
                          color: Color(0xFFFF6B35),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.star, color: Color(0xFFFFD700), size: 30),
                    ],
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '+$points',
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                  const Text(
                    'PUNTOS',
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white70,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total:', style: TextStyle(color: Colors.white70)),
                            Text(
                              '${UserData.puntosActuales}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Racha:', style: TextStyle(color: Colors.white70)),
                            Row(
                              children: [
                                const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                                const SizedBox(width: 5),
                                Text(
                                  '$streak días',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'CONTINUAR',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('SKATE STREET'),
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
            'SKATE STREET',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Color(0xFFFF6B35).withOpacity(0.5)),
            ),
            child: Column(
              children: const [
                Text(
                  '🛹 Tap = OLLIE (saltar)',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                SizedBox(height: 8),
                Text(
                  '🔥 Esquiva obstáculos',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                SizedBox(height: 8),
                Text(
                  '⚡ Velocidad aumenta',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ),
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
// GAME ENGINE MEJORADO
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
  
  // Player - POSICIÓN MEJORADA
  double playerY = 250; // Altura fija cómoda para jugar
  double playerVelocity = 0;
  bool isJumping = false;
  
  // Game
  int score = 0;
  double gameSpeed = 7.0;
  List<Obstacle> obstacles = [];
  double obstacleTimer = 0;
  
  // Physics mejoradas
  final double gravity = 1.5;
  final double jumpForce = -25.0; // Negativo para saltar hacia arriba
  final double playerGroundY = 250; // Posición en el suelo
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
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
      // Física del salto
      if (isJumping) {
        playerVelocity += gravity;
        playerY += playerVelocity;

        // Volver al suelo
        if (playerY >= playerGroundY) {
          playerY = playerGroundY;
          playerVelocity = 0;
          isJumping = false;
        }
      }

      // Mover obstáculos
      for (var obstacle in obstacles) {
        obstacle.x -= gameSpeed;
      }

      // Eliminar obstáculos fuera de pantalla
      obstacles.removeWhere((obs) => obs.x < -100);

      // Generar obstáculos
      obstacleTimer += 1;
      final int spawnInterval = max(50 - (score ~/ 8), 35);
      
      if (obstacleTimer > spawnInterval) {
        final random = Random();
        final obstacleType = random.nextInt(3);
        
        // Tipos de obstáculos variados
        if (obstacleType == 0) {
          // Cono de tráfico
          obstacles.add(Obstacle(x: 400, y: playerGroundY - 35, height: 35, width: 25, type: 'cone'));
        } else if (obstacleType == 1) {
          // Banca baja
          obstacles.add(Obstacle(x: 400, y: playerGroundY - 30, height: 30, width: 50, type: 'bench'));
        } else {
          // Tacho
          obstacles.add(Obstacle(x: 400, y: playerGroundY - 40, height: 40, width: 30, type: 'trash'));
        }
        
        obstacleTimer = 0;
        score += 1;
        
        // Aumentar velocidad
        if (score % 10 == 0 && gameSpeed < 14) {
          gameSpeed += 0.7;
        }
      }

      // Detectar colisiones
      _checkCollisions();
    });
  }

  void _checkCollisions() {
    const double playerX = 80;
    const double playerWidth = 40;
    const double playerHeight = 60;

    for (var obstacle in obstacles) {
      // Colisión con margen de error pequeño
      if (playerX + playerWidth - 10 > obstacle.x &&
          playerX + 10 < obstacle.x + obstacle.width &&
          playerY + playerHeight - 5 > obstacle.y) {
        _controller.stop();
        widget.onGameOver(score);
        return;
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Canvas del juego
            CustomPaint(
              painter: GamePainter(
                playerY: playerY,
                obstacles: obstacles,
                playerGroundY: playerGroundY,
              ),
              child: Container(),
            ),
            // Score grande
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFF6B35), width: 2),
                ),
                child: Text(
                  '$score',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6B35),
                  ),
                ),
              ),
            ),
            // Velocímetro
            Positioned(
              top: 100,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '⚡ ${gameSpeed.toStringAsFixed(1)}x',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
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
// PAINTER OPTIMIZADO
// ==========================================

class GamePainter extends CustomPainter {
  final double playerY;
  final List<Obstacle> obstacles;
  final double playerGroundY;

  GamePainter({
    required this.playerY,
    required this.obstacles,
    required this.playerGroundY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Suelo de ciudad con textura
    paint.color = const Color(0xFF2A2A2A);
    canvas.drawRect(
      Rect.fromLTWH(0, playerGroundY + 60, size.width, 100),
      paint,
    );
    
    // Líneas de carretera
    paint.color = const Color(0xFFFFFFFF).withOpacity(0.2);
    for (int i = 0; i < size.width; i += 80) {
      canvas.drawRect(
        Rect.fromLTWH(i.toDouble(), playerGroundY + 75, 50, 4),
        paint,
      );
    }

    // Skater
    _drawSkater(canvas, paint);

    // Obstáculos
    for (var obstacle in obstacles) {
      _drawObstacle(canvas, paint, obstacle);
    }
  }

  void _drawSkater(Canvas canvas, Paint paint) {
    const double playerX = 80;

    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 4;

    // Cabeza
    canvas.drawCircle(
      Offset(playerX + 20, playerY - 50),
      12,
      paint,
    );

    // Cuerpo inclinado (postura de skate)
    canvas.drawLine(
      Offset(playerX + 20, playerY - 38),
      Offset(playerX + 15, playerY - 10),
      paint,
    );

    // Brazos extendidos
    canvas.drawLine(
      Offset(playerX + 15, playerY - 25),
      Offset(playerX - 5, playerY - 20),
      paint,
    );
    canvas.drawLine(
      Offset(playerX + 15, playerY - 25),
      Offset(playerX + 35, playerY - 15),
      paint,
    );

    // Piernas flexionadas
    canvas.drawLine(
      Offset(playerX + 15, playerY - 10),
      Offset(playerX + 5, playerY + 5),
      paint,
    );
    canvas.drawLine(
      Offset(playerX + 15, playerY - 10),
      Offset(playerX + 25, playerY + 5),
      paint,
    );
    
    // Skateboard
    paint.color = const Color(0xFFFF6B35);
    paint.style = PaintingStyle.fill;
    final skateboardPath = Path();
    skateboardPath.moveTo(playerX, playerY + 5);
    skateboardPath.lineTo(playerX + 40, playerY + 5);
    skateboardPath.lineTo(playerX + 38, playerY + 10);
    skateboardPath.lineTo(playerX + 2, playerY + 10);
    skateboardPath.close();
    canvas.drawPath(skateboardPath, paint);

    // Ruedas
    paint.color = Colors.black;
    canvas.drawCircle(Offset(playerX + 8, playerY + 12), 4, paint);
    canvas.drawCircle(Offset(playerX + 32, playerY + 12), 4, paint);
  }

  void _drawObstacle(Canvas canvas, Paint paint, Obstacle obstacle) {
    paint.style = PaintingStyle.fill;

    if (obstacle.type == 'cone') {
      // Cono de tráfico naranja
      final conePath = Path();
      conePath.moveTo(obstacle.x + obstacle.width / 2, obstacle.y);
      conePath.lineTo(obstacle.x, obstacle.y + obstacle.height);
      conePath.lineTo(obstacle.x + obstacle.width, obstacle.y + obstacle.height);
      conePath.close();
      
      paint.color = const Color(0xFFFF6B35);
      canvas.drawPath(conePath, paint);
      
      // Franja blanca
      paint.color = Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(obstacle.x + 3, obstacle.y + obstacle.height - 15, obstacle.width - 6, 4),
        paint,
      );
    } else if (obstacle.type == 'bench') {
      // Banca de ciudad
      paint.color = const Color(0xFF8B4513);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(obstacle.x, obstacle.y, obstacle.width, obstacle.height),
          const Radius.circular(5),
        ),
        paint,
      );
      
      // Detalles de la banca
      paint.color = const Color(0xFF654321);
      for (int i = 0; i < 3; i++) {
        canvas.drawRect(
          Rect.fromLTWH(obstacle.x + (i * 15), obstacle.y, 2, obstacle.height),
          paint,
        );
      }
    } else {
      // Tacho de basura
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFF8C42),
          const Color(0xFFFF6B35),
        ],
      );

      paint.shader = gradient.createShader(
        Rect.fromLTWH(obstacle.x, obstacle.y, obstacle.width, obstacle.height),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(obstacle.x, obstacle.y, obstacle.width, obstacle.height),
          const Radius.circular(5),
        ),
        paint,
      );

      // Tapa
      paint.shader = null;
      paint.color = const Color(0xFFFFAA66);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(obstacle.x - 3, obstacle.y - 5, obstacle.width + 6, 6),
          const Radius.circular(3),
        ),
        paint,
      );
    }
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
  double width;
  double height;
  String type;

  Obstacle({
    required this.x,
    required this.y,
    required this.height,
    required this.width,
    required this.type,
  });
}
